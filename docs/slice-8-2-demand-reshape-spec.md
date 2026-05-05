## Slice-8.2 — DemandSystem Reshape Spec (drain + partial conservation)

Status: design — handoff to Scene Architect after read.
Supersedes: slice-8 DemandSystem rise-toward-cap loop (saturation flaw confirmed by `tools/measure_demand_drift.gd` at tick 100).
Depends on: slice-8.1 asymmetric initial fill (`decisions/2026-05-05-slice-8-1-asymmetric-initial-demand-fill-by-tag.md`), slice-8 pricing formula (locked).

### 1. Pattern reference

Leaky-integrator equilibrium with a memory anchor — standard resource-simulation shape (cf. logistic decay, RC circuit fill). Decay refills toward cap (already shipped); a proportional drain pulls fill back down. Steady state: `pool*/cap = decay / drain`. The "partial conservation" rider is a memory-anchor pattern (cf. soil-fertility models in farming sims, vegetation regrowth in survival sims): each player sell permanently lowers the local cap by a small fraction, so trade history leaves a fading scar on the node. Texture pillar reads as: "this node has been sold to a lot; its baseline demand is lower than its untouched neighbour."

Closest direct analogue: Dwarf Fortress / RimWorld trade-stockpile decay, but here applied per-(node, good) on the demand side.

### 2. Loop diagram

```
tick_advanced
  |
  +-- DemandSystem._on_tick_advanced(world)
  |     for each node, good_id in node.demand_pools:
  |       1. compute pool_after_decay = mini(cap, pool + decay_rate * dt_accum)   [unchanged from 8.0]
  |       2. compute drain_units      = drain_rate * (pool_after_decay / cap)     [NEW]
  |       3. pool = maxi(0, pool_after_decay - drain_units)                       [NEW, clamped]
  |       4. write back pool, decay_accum, drain_accum
  |
  +-- (later) Trade.try_sell(node, good_id)
        1. WorldState.decrement_demand(node, good_id)              [unchanged]
        2. with prob CONSERVATION_FRACTION, WorldState.decrement_demand_cap_permanent(node, good_id, 1)   [NEW]
              -> demand_caps[good_id] -= 1, with min floor MIN_DEMAND_CAP_AFTER_EROSION (2)

tick t+1: drain pulls toward new equilibrium = decay_rate / drain_rate * cap_now
                                                                    ^^^^^^^
                                                            cap_now reflects erosion
```

The two effects are decoupled fields: drain modifies `demand_pools[g]`; conservation modifies `demand_caps[g]`. They interact only through the ratio in the equilibrium equation.

### 3. Inputs / outputs

**Reads per tick (DemandSystem):**
- `node.demand_pools[g]`, `node.demand_caps[g]` (current state)
- `node.demand_decay_rates[g]`, `node.demand_decay_accumulators[g]` (existing)
- `node.demand_drain_rates[g]`, `node.demand_drain_accumulators[g]` (NEW — written at gen time)

**Writes per tick:**
- `node.demand_pools[g]` (mutated by both decay and drain in the same per-(node,good) pass)
- `node.demand_decay_accumulators[g]`, `node.demand_drain_accumulators[g]`

**Trade.try_sell (rule extension, not new system):**
- Reads: same as today.
- Writes: `node.demand_pools[g]` (existing), `node.demand_caps[g]` (NEW, probabilistic).

Read-before-write order within DemandSystem: decay first (matches 8.0 semantics — refill is the first thing a tick wants to do), drain second on the post-decay value. Same per-(node,good) iteration; no two-pass needed.

### 4. Rules

**R1 — Drain formula (proportional to fill).** Per tick, after decay applied:
```
drain_accum[g] += drain_rate[g] * (pool / cap)
units = int(drain_accum[g])
pool = maxi(0, pool - units)
drain_accum[g] -= float(units)
```
Drain is proportional to current fill, not flat. Empty pool → no drain (cell has nothing to consume). Full pool → maximum drain. This is what gives the equilibrium its analytic shape.

**R2 — Tag-differentiated drain rates.** Authored at world-gen by `WorldGen._author_demand` alongside existing decay rates. Tag derived from `produces` / `consumes` membership (existing 3-tag taxonomy, not extended):

```
producer:  drain_rate = good.base_demand_decay_rate * DEMAND_DRAIN_MULT_PRODUCER
neutral:   drain_rate = good.base_demand_decay_rate * DEMAND_DRAIN_MULT_NEUTRAL
consumer:  drain_rate = good.base_demand_decay_rate * DEMAND_DRAIN_MULT_CONSUMER
```

Drain multipliers chosen so steady-state ratio differs by tag (see §5).

**R3 — Steady-state equation (analytic, the tuning anchor).** With proportional drain, equilibrium where `decay = drain * (pool*/cap)`:
```
pool*/cap  =  decay_rate / drain_rate
            =  (DEMAND_DECAY_MULT_<tag>) / (DEMAND_DRAIN_MULT_<tag>)
```
The `base_demand_decay_rate` factor cancels — steady-state ratio is purely the *ratio of tag multipliers*. This is mechanical to retune: pick target ratio, set drain mult = decay mult / target ratio.

**R4 — Partial conservation on sell.** When `Trade.try_sell` succeeds at (node, g), in addition to `decrement_demand`:
```
if rng.randf() < CONSERVATION_FRACTION:
    new_cap = maxi(MIN_DEMAND_CAP_AFTER_EROSION, demand_caps[g] - 1)
    demand_caps[g] = new_cap
```
RNG seeded as `hash([world_seed, tick, node_id, good_id, "conservation"])` for save/replay determinism (mirrors PricingMath perturbation seed shape). Cap is the field that erodes — drain rate stays, so a heavily-sold node converges to the same *ratio* but at a lower absolute pool. Sell prices at that node trend lower; texture reads as "this place is sold-out of demand."

**R5 — Drain and decay touch the same field, conservation touches a different field.** Drain and decay both mutate `demand_pools[g]` (composing into a net per-tick delta). Conservation mutates `demand_caps[g]`. Pool is clamped to `[0, cap]` after every mutation; if conservation drops cap below current pool, pool is also re-clamped down to the new cap on the *next* DemandSystem tick (cheap; no special path).

### 5. Numbers

Starting values (pure starting values; treat as `[needs playtesting]` once headless tool reports first numbers).

**Drain multipliers — chosen against the tag-differentiated ratio targets:**

| tag      | decay mult | drain mult | steady-state ratio |
|----------|-----------:|-----------:|-------------------:|
| producer |       0.2  |      0.67  |               0.30 |
| neutral  |       1.0  |      1.67  |               0.60 |
| consumer |       5.0  |      5.88  |               0.85 |

```
DEMAND_DRAIN_MULT_PRODUCER = 0.67
DEMAND_DRAIN_MULT_NEUTRAL  = 1.67
DEMAND_DRAIN_MULT_CONSUMER = 5.88
```

Justification:
- Producer ratio 0.30: producer node's own-good demand should remain unattractive to sell to (kernel collision: don't let a producer be a sell target for its own surplus). Sell price `~ base * 1.30` at equilibrium.
- Neutral ratio 0.60: matches the slice-8.1 initial-fill decision (0.5) almost exactly — the steady state is close to the gen-time fill, so the texture doesn't visibly snap-shift after tick 0. Sell price `~ base * 1.60`.
- Consumer ratio 0.85: consumer nodes remain the high-value sell target but no longer max out at 2x base. Sell price `~ base * 1.85`. The 0.15 headroom means a freshly-arriving trader at a consumer that's been *under-served* (cap not eroded) sees it as a slightly-more-valuable target than its erodec neighbour — which is the texture pillar working.

Cross-node spread on the same good, untouched world: producer (0.30) vs consumer (0.85) = **0.55**, well above the 0.20 floor.

**Conservation:**
```
CONSERVATION_FRACTION = 0.10            # 1 in 10 sells permanently lowers cap by 1
MIN_DEMAND_CAP_AFTER_EROSION = 2        # floor; below this, a node would price-explode
```
Justification: at 0.10 a player who sells 50 units to a single node erodes its cap by ~5 (floor-and-mean expected ~5). With consumer cap typically `4 * base_demand_cap` (~16-32), 5 units of erosion is a perceptible 15-30% reduction of the local sell ceiling. Doesn't kill the node — drain still pulls it to its tag's steady-state *ratio*, but the absolute pool is smaller.

**Decay rates:** unchanged from slice-8. The equilibrium equation explicitly cancels `base_demand_decay_rate`, so a retune of the drain mult is a 1-line constants change with no decay-side fallout. *No retune of decay rates required for 8.2's pass criteria.*

### 6. Feedback

Two feedback layers, both load-bearing:

**(a) Within first 100 ticks.** From tick 0 the slice-8.1 initial fill seeds `(0, 0.5, 1.0)`. Without 8.2's drain, those slowly converge to `(1, 1, 1)` — the saturation flaw. With 8.2: producer cells *fall back* from initial 0.0... wait, they start at 0 and drift up toward 0.30 (decay > drain at low fill). Consumer cells *fall* from 1.0 to 0.85 (drain > decay at high fill). Neutral cells nudge from 0.5 to 0.60. The player sees: prices visibly drift in the first 100 ticks toward their tag-stable values. Within-node spread *widens* over the first ~50 ticks (good news for legibility), then stabilises.

**(b) Sell-mark legibility.** When the player sells repeatedly to one node, that node's sell price visibly trends downward over a session — not because the pool is empty (drain refills the ratio), but because the cap itself is shrinking. The price label is the player's window into trade memory. The cap erosion is gradual (10% per sell), so a single sell doesn't visibly nudge the price; ~10 sells produce a clear shift.

No new UI required. Existing NodePanel sell row already pulls live from `PricingMath.sell_price_for`, which reads `demand_pools` and `demand_caps`. The reshape is invisible to UI code.

### 7. Edge cases

**E1 — `demand_pool == 0` at sell time.** Already gated by `decrement_demand`'s "pool <= 0 → no-op" guard. Conservation tick still runs only on a *successful* sell; a no-op sell does not erode cap.
**E2 — Drain pulls pool below 0.** `maxi(0, pool - units)` clamp. Drain accumulator reset is *not* required when pool clamps to 0 (unlike at-cap decay reset) because the drain-rate term is already 0 when pool is 0 (proportional shape).
**E3 — Conservation lowers cap below current pool.** Pool now exceeds cap. PricingMath has a defensive `clampi(pool, 0, cap)` already (line 85). Next DemandSystem tick re-clamps pool to cap inside the per-(node,good) loop; one-tick window of "pool > cap" is harmless.
**E4 — Conservation lowers cap to floor (`MIN_DEMAND_CAP_AFTER_EROSION = 2`).** Further sells decrement pool but no longer erode cap. Sell price stays at `base * (1 + drain_mult/decay_mult ratio)` of a 2-cap pool — small absolute pool, low absolute sell price. Texture reads "this town's market is exhausted." Intended.
**E5 — Tick-0 interaction with slice-8.1 initial fill.** At tick 0, ratios are (producer=0.0, neutral=0.5, consumer=1.0); the drain shape pulls these toward (0.30, 0.60, 0.85). Producer goes *up* (decay dominates at low fill); consumer goes *down*; neutral barely moves. Slice-8.1's tag-asymmetric tick-0 still does its kernel-collision job (producer sell price stays at base for ~tick 0-30 while it climbs, no same-node arb).
**E6 — Conservation disabled (CONSERVATION_FRACTION = 0).** System reduces to pure drain+decay. Steady-state property still holds; trade-mark texture goes away. Treat as a debug switch, not a ship config.

### 8. Open questions

- **Conservation determinism — does the seed need `tick` in it?** [needs Architect call] Without `tick`, two sells in the same tick at the same node would produce the same coin-flip — bad. Spec calls for `hash([world_seed, tick, node_id, good_id, "conservation"])`, but if multiple sells happen in the same tick this still collides. May need a per-call counter. Architect to decide field placement (TraderState sell-counter? per-NodeState?).
- **Should decay-rate retune actually happen?** Critic listed it as a hidden cost. Designer's read: equilibrium math says no — the ratio cancels `base_demand_decay_rate`, so the existing decay rates work as-is. Flagging in case Critic's headless tool surfaces a transient (not steady-state) issue that wants a retune.
- **Conservation floor value — is 2 right?** [needs playtesting] Picked to keep `pool / cap` arithmetic well-defined and prevent a node from becoming sell-immune (cap=0 would zero the curve). Could be 1, 3, or `0.05 * original_cap`. First headless run with 200 seeds at tick 2000 will reveal the distribution of eroded caps.
- **Should producer-tag drain even exist?** Producer cells start at pool=0 (slice-8.1) and rise to ratio 0.30. Alternative: producer drain so high that ratio stays near 0 forever (sell-dead). Designer chose 0.30 because completely sell-dead is a content cliff; small sell margin is texture. Open for Director call if "producer is sell-dead" is a stronger pillar read.

### 9. Pass criteria

Critic's three, restated and refined:

1. **Convergence** (tick 2000): mean per-cell `|ratio(t=2000) - ratio(t=1500)| < 0.02`. **Accepted.**
2. **Below-cap** (tick 2000): `max ratio <= 0.95`, `mean ratio <= 0.80`. **Accepted.** Math says max ratio = 0.85 at consumer cells (with no eroded caps in trader-free measurement); 0.95 is fine headroom for the proportional-drain transient.
3. **Cross-node legibility** (tick 2000): mean cross-node spread `>= 0.25`. *Originally specced at `>= 0.40` against Designer's 0.85 consumer ratio. Slice-8.2.1 retune (Director-ratified) lowered consumer ratio to ~0.43 to respect the kernel-collision shadow (cheapest edge / iron base = 9/22 ~= 0.41, the structural ceiling on consumer ratio under the locked formula and current goods catalogue). The 0.40 floor became mathematically unreachable; 0.25 is the empirical floor under shadow-respecting ratios. Still above Critic's original 0.20 hedge.*

4. **Same-node arbitrage shadow** (slice-8.2.1, Director-ratified permanent gate): for every (node, good) at tick 2000, `max(0, sell_price - buy_price) <= cheapest_edge_travel_cost` for that world. Falsifies any future tag-ratio change that breaches the kernel collision. This is now the load-bearing pillar 1 gate; cross-node spread is a pillar 2 texture metric only.

Headless tool extension required: `measure_demand_drift.gd` must (a) run the new drain step in `_apply_decay` (rename to `_apply_demand_tick`), (b) add tick 1500 to `SAMPLE_TICKS`, (c) compute per-cell delta between 1500 and 2000.

### 10. Migration note

Schema bump: **v7 → v8**.

New `NodeState` fields:
- `demand_drain_rates: Dictionary[String, float]` (authored at gen, persisted)
- `demand_drain_accumulators: Dictionary[String, float]` (per-tick float remainder, persisted)

`demand_caps` field shape unchanged but its *semantics* extend: it's now mutable post-gen via conservation. The Resource type does not change.

`from_dict` / `to_dict` extend the demand quad to a sextet (caps, decay_rates, decay_accumulators, drain_rates, drain_accumulators, pools). Six parallel dicts share one key set per node.

**Migration policy: strict reject v7 saves.** Follow slice-8.1's precedent (`from_dict` returns null on schema mismatch; corruption-toast/regen path takes over). Justification: v7 saves carry the saturation flaw, so even a successful migration would drop the player into a "demand-flat" world that 8.2 immediately invalidates. The regen cost is one-time and aligns with the project's no-dialogue-no-story brief — saves are not narrative artifacts.

Constants added to `WorldRules`:
```
DEMAND_DRAIN_MULT_PRODUCER: float = 0.67
DEMAND_DRAIN_MULT_NEUTRAL:  float = 1.67
DEMAND_DRAIN_MULT_CONSUMER: float = 5.88
CONSERVATION_FRACTION:       float = 0.10
MIN_DEMAND_CAP_AFTER_EROSION: int  = 2
```

No `WorldRules` *removals*. No `PricingMath` changes (the locked formula reads pool and cap as before).

---

**Handoff:** Scene Architect — please structure the `Trade.try_sell` conservation hook (Architect's call: extend `WorldState` with a `decrement_demand_cap_permanent` mutator mirroring `decrement_demand`, or fold it into the existing `decrement_demand` call). Drain math lives in DemandSystem proper. The two-system separation (DemandSystem ticks; Trade verbs) is unchanged.
