## Slice-8.2 Architect Handoff -- Demand Reshape (drain + partial conservation)

Source spec: `docs/slice-8-2-demand-reshape-spec.md` (ratified, do not redesign).
Audience: GDScript Engineer.
Scope: structure, signatures, ordering. No mechanics changes.

### 1. Files touched

| Path | Change kind | What |
|------|-------------|------|
| `godot/world/node_state.gd` | extend | Add `demand_drain_rates`, `demand_drain_accumulators` exports parallel to existing decay quad. Bump comment to slice-8.2. |
| `godot/world/world_state.gd` | extend | Bump `SCHEMA_VERSION` 7 -> 8. Extend `to_dict` / `_node_from_dict` for the two new dicts. Add new mutator `decrement_demand_cap_permanent`. Strict-reject all non-v8. |
| `godot/shared/world_rules.gd` | extend (constants only) | Add `DEMAND_DRAIN_MULT_PRODUCER/NEUTRAL/CONSUMER`, `CONSERVATION_FRACTION`, `MIN_DEMAND_CAP_AFTER_EROSION`. No removals. |
| `godot/game/world_gen.gd` | extend | `_author_demand` writes `demand_drain_rates[good.id]` (= base_demand_decay_rate * tag drain mult) and `demand_drain_accumulators[good.id] = 0.0`. `forward_port_goods` already routes through `_author_demand`, so no separate plumbing. Add an authoring sanity assert that drain_rate is finite and non-negative. |
| `godot/systems/demand/demand_system.gd` | extend | Per-(node, good) loop adds drain step after the existing decay step. See section 4 below. |
| `godot/travel/trade.gd` | extend | After successful sell + `decrement_demand`, run conservation roll using `WorldState.decrement_demand_cap_permanent`. See section 5. |
| `godot/tools/measure_demand_drift.gd` | extend | Rename `_apply_decay` -> `_apply_demand_tick`, fold drain step in, add tick 1500 to `SAMPLE_TICKS`, compute per-cell convergence delta between 1500 and 2000. See section 7. |

No new files. No new scenes. No new autoloads. No new signals (see section 9).

### 2. System layout (text tree)

```
Main (Node, scene root -- existing)
+-- Game (autoload, existing) --> tick_advanced
+-- StockSystem (Node, existing)            [tick listener -- mutates stocks/refill_*]
+-- DemandSystem (Node, existing)           [tick listener -- mutates demand_pools/_decay_/_drain_]
|     reads:  node.demand_caps, demand_decay_rates, demand_decay_accumulators,
|             demand_drain_rates [NEW], demand_drain_accumulators [NEW]
|     writes: node.demand_pools, demand_decay_accumulators,
|             demand_drain_accumulators [NEW]
+-- Trade (Node, existing)
|     try_sell --> WorldState.decrement_demand            (existing)
|                  WorldState.decrement_demand_cap_permanent  [NEW, probabilistic]
+-- WorldState (Resource, existing) --- field surface ---
      NodeState (Resource):
        existing: stocks/stock_caps/refill_rates/refill_accumulators
                  demand_pools/demand_caps/demand_decay_rates/demand_decay_accumulators
        NEW:      demand_drain_rates: Dictionary[String, float]
                  demand_drain_accumulators: Dictionary[String, float]
```

The system boundary does not move. DemandSystem still owns per-tick demand mutations; Trade still owns sell-induced mutations. Conservation is a sell-side mutation, so it stays inside Trade -- not pushed into a new system.

### 3. WorldState API additions

Existing `decrement_demand` is unchanged.

```gdscript
## Slice-8.2 partial-conservation mutator. Erodes the demand cap for
## (node_id, good_id) by `amount`, floored at MIN_DEMAND_CAP_AFTER_EROSION.
## Defensive no-op on unknown node, unknown good, or amount <= 0. Mirrors the
## decrement_demand defensive shape; called only from Trade.try_sell after the
## probabilistic gate fires. Does NOT clamp demand_pools to the new cap --
## PricingMath has a defensive clampi at read time, and DemandSystem's next
## tick re-clamps inside the per-(node, good) loop.
func decrement_demand_cap_permanent(node_id: String, good_id: String, amount: int) -> void
```

Drain is **not** a `WorldState` mutator. DemandSystem reads/writes `node.demand_pools` and `node.demand_drain_accumulators` directly inside its tick loop, mirroring how decay is already handled. No `decrement_demand_pool_by_drain` or similar -- that would be a wrapper around a single arithmetic op the system already does inline.

### 4. DemandSystem tick-loop structure

Read-before-write order is critical. Decay is computed first against the pre-tick pool; drain is computed second against the post-decay pool. One pass per (node, good); no two-pass.

```
for node in world.nodes:
    for good_id in node.demand_pools.keys():
        cap         = node.demand_caps[good_id]
        pool        = node.demand_pools[good_id]
        decay_rate  = node.demand_decay_rates[good_id]
        decay_accum = node.demand_decay_accumulators[good_id]
        drain_rate  = node.demand_drain_rates[good_id]        # NEW
        drain_accum = node.demand_drain_accumulators[good_id] # NEW

        # --- Step 1: decay (refill toward cap), unchanged from 8.0/8.1 ---
        if pool >= cap:
            decay_accum = 0.0          # at-cap reset; existing rule
        else:
            decay_accum += decay_rate
            whole = int(decay_accum)
            if whole > 0:
                pool = mini(cap, pool + whole)
                decay_accum -= float(whole)

        # --- Step 2: drain (proportional to fill), NEW ---
        # Drain accum increment uses post-decay pool; no at-zero reset needed
        # because the increment is proportional to pool/cap and is already 0
        # when pool == 0 (E2 in spec).
        if cap > 0:
            drain_accum += drain_rate * (float(pool) / float(cap))
            whole_drain = int(drain_accum)
            if whole_drain > 0:
                pool = maxi(0, pool - whole_drain)
                drain_accum -= float(whole_drain)

        # --- Write back ---
        node.demand_pools[good_id] = pool
        node.demand_decay_accumulators[good_id] = decay_accum
        node.demand_drain_accumulators[good_id] = drain_accum

Game.emit_state_dirty.call()    # unchanged tail
```

Notes:
- `cap > 0` guard is defensive; `_author_demand`'s `maxi(1, ...)` already ensures cap >= 1, but the conservation floor of 2 means cap can drop, and an explicit guard keeps the division safe even if a future change loosens the floor.
- The two accumulators stay independent. Decay accum resets at-cap; drain accum does not need an at-zero reset because its increment is `~ pool/cap`, naturally zeroed at `pool == 0`.
- One write per field per (node, good); no torn read because we compute everything in locals first.

### 5. Trade.try_sell hook structure

The conservation hook fires **after** the existing `decrement_demand` and **after** gold has been credited (mirroring how try_buy decrements stock before crediting inventory: world-side mutation lands first, but conservation specifically wants to fire only on a confirmed-successful sell, so it goes at the end of the success path, just before the history push).

```
# Existing path through try_sell, abbreviated:
...inventory and gold gates...
_world.decrement_demand(node.id, good_id)               # existing
_trader.apply_gold_delta(price, ...)                    # existing

# NEW: partial conservation. Seeded RNG -- see Call 1 resolution below.
var roll_seed: int = hash([
    _world.world_seed, _world.tick, node.id, good_id,
    node.sell_seed_counter,                             # NEW NodeState int field
    "conservation",
])
node.sell_seed_counter += 1                             # increment AFTER hashing
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
rng.seed = roll_seed
if rng.randf() < WorldRules.CONSERVATION_FRACTION:
    _world.decrement_demand_cap_permanent(node.id, good_id, 1)

_push_history("sell", good_id, price)                   # existing
...await save_service.write_now()...                    # existing
```

Order rationale:
- Conservation roll fires on **successful** sells only (after the inventory/gold gate is past). Edge case E1 (zero-pool sell) is already gated upstream.
- `sell_seed_counter` is incremented after seeding so the first sell at a fresh node uses counter=0 deterministically.
- The history push must remain after conservation so a save written between sells captures the post-erosion cap. This is a free property because conservation is synchronous; the `await save_service.write_now()` at the tail still observes both writes.

### 6. Save schema v7 -> v8 plumbing

**Bump.** `WorldState.SCHEMA_VERSION` from 7 to 8.

**`NodeState` additions (also stored in dict form):**

```
"demand_drain_rates":         Dictionary[String, float]
"demand_drain_accumulators":  Dictionary[String, float]
"sell_seed_counter":          int
```

The demand quad becomes a sextet (caps, decay_rates, decay_accumulators, drain_rates, drain_accumulators, pools), all sharing one good-id key set per node. `sell_seed_counter` is a plain `int` field on `NodeState`, default 0.

**Strict-reject sites (extend existing pattern):**
- `from_dict`: existing `loaded_version != SCHEMA_VERSION` line is the rejection point. v7 falls through here automatically once `SCHEMA_VERSION` bumps.
- `_node_from_dict`: add three required-key checks alongside existing ones (`demand_drain_rates`, `demand_drain_accumulators`, `sell_seed_counter`); add typed-dict round-trip via existing `_typed_float_dict` helper for the two dicts.
- No migration code path. Spec §10 ratifies strict reject; corruption-toast/regen takes over.

**`to_dict`:** mirror the slice-8.1 demand dict serialisation. Add three lines per node alongside `demand_decay_*`.

**`forward_port_goods`:** no change. It calls `_author_demand`, which writes the new dicts uniformly.

### 7. measure_demand_drift.gd extension

Existing structure to preserve:
- `_initialize` outer seed loop, per-checkpoint stats accumulator, sample-then-mutate ordering.
- `_sample_world` ratio collection over (node, good).
- `_apply_refill` (do NOT touch).
- Print scaffolding.

Required changes:
1. Rename `_apply_decay(world)` -> `_apply_demand_tick(world)`. Inside, replicate the new DemandSystem two-step (decay then drain) byte-equivalent to section 4 above. The tool must mirror DemandSystem; the shared body is the contract.
2. `SAMPLE_TICKS`: `[0, 100, 500, 2000]` -> `[0, 100, 500, 1500, 2000]`.
3. Add a per-cell convergence-delta metric: for every (seed, node, good), capture `ratio_at_1500` and `ratio_at_2000`, compute `abs(r2000 - r1500)`. Report `mean / max` of the resulting array under a new `=== convergence (1500 -> 2000) ===` block. The pass criterion is `mean < 0.02` (spec §9 #1).
4. Per-cell capture path: change `per_tick_stats[t]` to optionally record an extra `ratios_by_cell: Dictionary[Vector2i_or_string_pair, float]` keyed by `(seed, node_idx, good_idx)` so the delta can be computed across two ticks for the same cell. Engineer's call on whether to use a flat parallel array indexed by `(seed_idx * cells_per_seed + cell_idx)` or a dict; the flat-array form matches the existing `ratios_all` style.
5. Pass-criteria reporting block: `convergence_mean`, `convergence_max`, `cross_node_spread_mean_at_2000` (already computed; surface explicitly against the `>= 0.40` threshold), `max_ratio_at_2000` (already implicit; surface explicitly against `<= 0.95`).

The tool stays non-gating diagnostic. The Reviewer reads the numbers and decides.

### 8. Resolutions for Architect calls

**Call 1 -- Conservation RNG seed disambiguation: per-NodeState `sell_seed_counter`.**

Choice: add `@export var sell_seed_counter: int = 0` to `NodeState`. Increment after each conservation hash, regardless of whether the roll succeeded.

Reasoning:
- *Determinism across save/load*: counter is a persisted field, restored byte-identical via `from_dict`. Hashing the same (seed, tick, node, good, counter) tuple after reload yields the same coin.
- *No new singletons*: counter lives on the existing `NodeState` resource.
- *Save footprint*: one `int` per node (~7 ints in current world). Negligible.
- *Locality*: the counter is read and written in the same place it's used (Trade.try_sell at one specific node). No coupling to TraderState; `Trade` already has the `node` reference.
- *Resilience to tick-reset edge cases*: the per-NodeState scope means even if two different traders sold at the same node in the same tick (irrelevant for single-player but cheap insurance), the counter still disambiguates.

Why not the alternatives:
- Per-TraderState counter couples the demand-side mutation seed to a player field; if save/replay ever wants to model trader-free world ticks (the headless tool does this -- though it doesn't sell), the seed shape diverges.
- In-tick local counter loses determinism on save/load mid-tick: a save written between two same-tick sells would re-roll the counter to 0 on reload.
- Implicit-from-cap-erosion seed makes the seed depend on the conservation outcome it's meant to determine -- circular and fragile when conservation is later disabled (`CONSERVATION_FRACTION = 0`).

**Call 2 -- `Trade.try_sell` conservation hook: separate mutator `decrement_demand_cap_permanent`.**

Choice: add a new mutator on `WorldState`, mirroring `decrement_demand`'s defensive shape. Do **not** fold into `decrement_demand`.

Reasoning:
- *Semantic separation*: `decrement_demand` is per-tick consumption (transient pool-state); cap erosion is a permanent structural change to the node. Same-named verb hides this distinction at every call site.
- *Testability*: the two effects are individually triggerable in headless tools. A future tool that wants to measure pure conservation drift without the per-sell pool decrement can call the cap mutator alone.
- *Call-site clarity*: `try_sell` reads as two sequential, named operations -- "drain the pool, then maybe erode the ceiling." A merged verb requires a comment to recover that intent.
- *Cost of separation*: a single extra public method on `WorldState`. Trivial.

Spec §11 directly leans this way; this confirms it.

### 9. Signal / event surface

No new signals. Designer's spec calls for none and confirmation holds:

- DemandSystem already raises `Game.emit_state_dirty` once per tick after its loop. The new drain step is folded into the same loop, so the existing dirty raise covers both decay and drain mutations.
- Trade's existing pattern (mutate, history push, `await save_service.write_now()`) covers the conservation write. No additional dirty signal needed; `write_now` reads the current world state, which already reflects the cap erosion.
- UI is read-through-PricingMath; no UI-visible signal, no observer pattern needed. The NodePanel sell row repaints on its existing tick/dirty cadence.

If conservation later wants a player-visible "this market is wearing out" UI cue, that is a new slice. Out of 8.2.

### 10. Lifecycle / order-of-init

The lifecycle invariant is: **`WorldGen._author_demand` must write `demand_drain_rates` and `demand_drain_accumulators` before any DemandSystem tick fires.** This is already structurally guaranteed:

- `WorldGen.generate` returns a fully-authored `WorldState`. All four (now six) demand dicts are populated inside the same `for node / for good` loop in `generate` before the world is handed to `Main`.
- `Main` setup-injects the world into `DemandSystem` via `setup(world)` before the first `Game.tick_advanced` fires (existing slice-8 ordering, untouched).
- `forward_port_goods` extends the same `_author_demand` call to missing goods, so a save loaded onto a wider catalogue writes the new dicts before its first post-load tick.
- v7 saves are strict-rejected, so a v7 save can never reach DemandSystem with missing drain dicts.

`sell_seed_counter` defaults to 0 via the `@export` initializer and is also defaulted to 0 in `_node_from_dict` if absent (defensive even though strict-reject prevents the absent case). No init-order risk.

### 11. Open questions for Engineer

These are code-level discoveries genuinely worth flagging; they do not punt mechanics back.

- **`Vector2i` as Dictionary key for `ratios_by_cell` in the headless tool.** GDScript 4.5 supports `Vector2i` keys, but the existing tool uses parallel `Array[float]`s exclusively. Engineer should pick the cheaper-to-read shape (likely flat parallel arrays indexed by stable cell ordering), not redesign for dict keys unless the latter clearly reads better.
- **`sell_seed_counter` save backwards-compatibility within v8.** When the counter is added, every fresh-gen v8 save starts at 0. A future v8.x save format that wants to add other per-node counters should follow the same pattern (default 0, defensive read in `_node_from_dict`). Not a 8.2 decision; flagging so Engineer doesn't accidentally pattern around the counter as a one-off.
- **`Game` autoload signal name -- confirm `emit_state_dirty` is a `Callable` field, not a signal.** From the existing `DemandSystem` body, the call site is `Game.emit_state_dirty.call()`, suggesting it is a Callable. New code must follow that idiom byte-for-byte; don't accidentally introduce a `Game.state_dirty.emit()` form.
- **`WorldGen` drain-rate authoring assert.** Engineer should follow the existing `_author_supply` / `_author_demand` precedent (`assert(rate < float(cap), ...)`) and add a parallel sanity rail for `drain_rate`. The sanity is "`drain_rate / cap` per tick should not zero a full pool in one tick" -- formally `drain_rate < cap`. Confirm the assert matches the existing rail's tone before committing.

Handoff complete. Engineer to implement; Reviewer to validate against spec §9 pass criteria using the extended headless tool.
