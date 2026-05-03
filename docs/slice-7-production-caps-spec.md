# Medieval Trader -- Slice 7 (Per-Node Production Caps + Character-Tuned Refill) Spec

> **Ratified frame (2026-05-03):** Director scoped slice-7 to add per-(node, good) stock that caps how much the player can buy at each node, with per-tick refill rates tuned by node character. The mechanic answers slice-6's structural ceiling head-on -- per-node production caps were one of the three out-of-scope mechanics named in `slice-6-weight-cargo-spec.md` §13.3 to break the single-good-per-leg degeneracy. Critic compressed scope to "buy-side cap only, refill per-tick everywhere, schema bump coalesces stock state with the slice-6.1 `TraderState.cargo_capacity` migration that's been waiting since slice-6." Branch: refill-on-arrival vs. per-tick (we picked per-tick); sell-side cap; bandits-respect-stock; multi-leg commitments; per-good stack rot/perish -- all out of slice.
>
> Anti-goal carried forward (Director, repeat for the Engineer): **stock is world memory, not an inventory-management surface.** The slice's drift edge is "show stock at each row" growing into "trader plans which nodes to skim and which to drain." The UI spec keeps that line clear: there is no reservation verb, no queue verb, no remote-stock readout, no at-a-glance "best-stocked node" map overlay. The buy gate plus the `[N left]` row label is the entire mechanic; the refill is invisible (tick-paced, no animation, no log line). Stock state is a passive readout, not a controller.
>
> **Schema bump v3 -> v4 coalesces two concerns** so we pay the migration cost once: per-(node, good) stock state on `WorldState`, AND the slice-6.1 `TraderState.cargo_capacity` field that was deferred. Old saves load with every stock at its refill ceiling (full, no save-scumming). Old `TraderState` gets `cargo_capacity = WorldRules.CARGO_CAPACITY` (60).

## 1. Kernel framing

The kernel is unchanged: arbitrage profit perpendicular to travel cost. What changes is that **the world has memory now.** Before slice-7, every node was a stateless price oracle -- the player walked in, prices were what they were, the player could buy as much as gold and (slice-6) cart allowed. After slice-7, each (node, good) pair carries a stock count that decrements on buy and refills per tick at a rate authored by node character. Nodes accumulate scarcity when the player visits them; nodes recover when the player is elsewhere. The player's route is no longer "go where the spread is widest" but "go where the spread is widest *and the stock is deep enough to matter*." Coming back to a node you just emptied is a real cost; rotating between nodes is a real strategy. The kernel's two pillars (profit, travel cost) stay primary; this slice adds a third texture, **temporal availability**, that makes route planning a multi-stop concern instead of a one-leg one.

The slice-6 §13.3 prediction was that per-node production caps would unlock per-leg portfolio depth by "forcing the player to mix because the best good runs out." Slice-7 tests that prediction with the harness in §7. If the prediction holds, the slice-6 single-good degeneracy breaks and multi-good carts become common; if it fails, we will know exactly why (tuning vs. structural) before the next slice.

## 2. Player-facing decision

**Before slice-7 (current state):** the player walks into Hillfarm with 240g and a 60-unit cart. Iron is `(plentiful)` at 14g. Salt is `(plentiful)` at 4g. The player computes profit-per-weight for each good against Rivertown's prices, picks the winner (say salt), buys 30 salt (cart full), travels. Returns to Hillfarm next tick: salt is still 4g, infinite stock. Buys 30 salt again. Same loop forever.

**After slice-7:** the player walks into Hillfarm. The buy panel now reads:

```
Hillfarm
Cart: 0/60
  wool   12g (plentiful)        x0  [4 left]   [Buy] [Sell]
  cloth  11g                    x0  [2 left]   [Buy] [Sell]
  salt    4g (plentiful)        x0  [12 left]  [Buy] [Sell]
  iron   14g                    x0  [1 left]   [Buy] [Sell]
```

The player wanted 30 salt. There are 12. They buy 12 (cart at 24/60), then the salt row reads `x12 [0 left]` and the salt Buy button greys out with tooltip `"out of stock"`. Cart is half-empty. The player now has a real choice: travel to Rivertown with a half-cart (and lose the spread on the empty cart space), or buy the second-best good at Hillfarm to fill the rest (wool? iron? cloth?). The cart-composition decision is now **forced by world state**, not just by gold or by spread math.

A full multi-leg loop now feels different. The player runs Hillfarm -> Rivertown -> Hillfarm. First leg: 12 salt + 4 wool fills cart. Sells at Rivertown for profit. Returns to Hillfarm: salt has refilled by 4 (one tick has passed -- the tick that the player consumed travelling). Stock is now 4 salt, not 12. Buying out salt again means a smaller haul; the player either takes a smaller load or commits to a third stop where stock is fresher. **Rotating routes (A->B->C->A instead of A->B->A->B) becomes the optimal strategy** when local stock cannot support a tight loop.

The "cleaned out" feel is the load-bearing texture. A node the player just emptied reads as `[0 left]` across three rows; the player feels that they shaped the world by visiting. The world remembers them.

Concrete numbers: under the §6 authoring, Hillfarm starts with 16 wool (cap, plentiful), refills 2/tick. Hillfarm starts with 4 salt (cap, plentiful at this node), refills 1/tick. Hillfarm starts with 1 iron (cap, scarce -- not produced here), refills 0.2/tick (1 unit every 5 ticks via integer accumulator -- see §3 for how the fractional rate works in integer stock). The player learns that wool is what Hillfarm churns out, salt comes back slow, iron almost never -- and that learning maps directly onto the (plentiful) / (scarce) tags they already know.

## 3. Mechanic spec

### 3.1 The buy gate, revised

At buy time, refuse the purchase if **any** of the following hold:

1. `gold < price` (slice-1 gold gate -- unchanged)
2. `current_load + good.weight > CARGO_CAPACITY` (slice-6 cargo gate -- unchanged)
3. `node_stock[node_id][good_id] <= 0` (slice-7 stock gate -- NEW)

On a successful buy, decrement `node_stock[node_id][good_id] -= 1` atomically with the existing `apply_inventory_delta(good_id, +1)` and `apply_gold_delta(-price)`. The decrement happens after the cargo gate passes, before the inventory delta -- if the inventory delta somehow fails, the stock decrement would already be committed and we'd lose a unit to the void. (Inventory delta can't actually fail on a +1 against a non-negative stack, but contract-honesty matters; see §3.4.)

### 3.2 The refill rule

Each (node, good) pair carries:

- `cap: int` -- the maximum stock the slot can hold. Authored, immutable.
- `refill_per_tick: float` -- units added per tick. Authored, immutable. Stored as float because plentiful/scarce ratio (§6) wants 0.2-0.4-style fractional rates.
- `stock: int` -- current stock count. Mutated by buy (decrement) and tick (refill).
- `refill_accumulator: float` -- carries the fractional remainder between ticks so a 0.2/tick rate produces 1 unit every 5 ticks deterministically. Mutated only by the tick refill. **Stored.** (See §4 for the alternative-rejected discussion.)

On each tick, for each (node, good) pair:

```
if stock < cap:
    refill_accumulator += refill_per_tick
    var whole_units: int = int(refill_accumulator)
    if whole_units > 0:
        stock = mini(cap, stock + whole_units)
        refill_accumulator -= whole_units
```

**Stock saturates at cap.** The accumulator does not grow past `1.0` once stock is at cap (the `if stock < cap` guard means we don't accumulate when full -- this prevents a "node was full for 50 ticks, now player buys 1, instantly 50 units arrive from accumulator" exploit). When `stock == cap`, `refill_accumulator = 0.0` is the steady state; we reset to 0 on hitting cap.

### 3.3 Tick ordering

This is load-bearing. The current tick pipeline (per `travel_controller.gd:73-110`):

1. `_world.tick += 1`
2. Travel decrement (`ticks_remaining -= 1`)
3. Arrival branch (mutex restore, encounter apply, save)
4. `Game.emit_state_dirty.call()`
5. `Game.tick_advanced.emit(_world.tick)` -- listeners run synchronously
   - `PriceModel._on_tick_advanced` drifts prices
   - **NEW: `StockSystem._on_tick_advanced` refills stock**
   - `SaveService._on_tick_advanced` writes
6. Wall-clock timer

The order **within** the tick_advanced listeners is not currently deterministic across listeners, but each listener mutates orthogonal state (PriceModel -> `node.prices`, StockSystem -> `node.stocks`, SaveService reads both). No coupling. Engineer should not need to enforce listener ordering for slice-7; verify by inspection that StockSystem and PriceModel mutate disjoint fields.

**Refill happens once per tick, on every tick.** Travel ticks: yes. Player-driven ticks (buy/sell don't advance the tick today; only travel does): n/a -- there are no non-travel ticks. **There is no refill on player arrival, no refill on save-load, no refill on idle, no refill burst on first-visit-after-long-absence.** The world's clock is the tick counter; the tick counter only advances during travel. A player who never travels never refills any stock -- **intended.** The kernel pillar "travel costs bite" extends to "travel is what makes the world tick"; refills are a side effect of leaving and coming back.

**Buy ordering within a tick:** buys do not advance the tick (slice-1 contract). A player at Hillfarm can buy 1 salt, 1 wool, 1 iron in three clicks; each click decrements its row's stock. The next tick's refill applies to the post-decrement stock count. So a player buying out a node leaves it at 0 stock on tick T, and the refill applies on tick T+1 (the next time the player travels). The "you visited and emptied this place" memory persists across at least one travel leg -- exactly the texture §2 promised.

### 3.4 Pseudocode

`Trade.try_buy(good_id)` -- annotated with the new gate:

```
try_buy(good_id):
    ... existing slice-1 setup ...
    if travel != null: return false
    node = world.get_node_by_id(trader.location_node_id)
    if node == null or not node.prices.has(good_id): return false

    # NEW: stock gate. Read-only check -- mutation happens after the cargo gate.
    var stock: int = world.stock_for(node.id, good_id)   # see §4 for accessor shape
    if stock <= 0:
        return false

    price = int(node.prices[good_id])
    if not trader.apply_gold_delta(-price, ...): return false

    # Existing slice-6 cargo gate:
    var good: Good = Game.goods_by_id.get(good_id)
    if good == null:
        trader.apply_gold_delta(price, ...)   # refund
        push_warning("try_buy: orphan good_id ...")
        return false
    var weight: int = good.weight
    var current_load: int = CargoMath.compute_load(trader.inventory, Game.goods_by_id)
    if current_load + weight > WorldRules.CARGO_CAPACITY:
        trader.apply_gold_delta(price, ...)   # refund
        push_warning("try_buy: cart-overflow ...")
        return false

    # NEW: re-read stock after gold/cargo gates (defensive against any
    # interleaving introduced later). If stock is now zero, refund and bail.
    # Belt-and-braces; under current single-threaded coroutine model it cannot
    # change between the entry check and here, but the contract should be
    # closed by the verb itself, not by upstream sequencing.
    if world.stock_for(node.id, good_id) <= 0:
        trader.apply_gold_delta(price, ...)
        push_warning("try_buy: stock-race defensive gate fired")
        return false

    # NEW: atomic-ish triple. Order: stock decrement -> inventory increment.
    # If apply_inventory_delta could fail (it can't for +1, but the contract
    # treats it as fallible), we'd need a stock-restore branch here.
    world.decrement_stock(node.id, good_id)   # see §4 for mutator shape
    trader.apply_inventory_delta(good_id, 1, ...)
    _push_history("buy", good_id, -price)
    ... write_now ...
    return true
```

`StockSystem._on_tick_advanced(new_tick)` -- the refill mutator:

```
_on_tick_advanced(new_tick):
    if _world == null: return
    for node: NodeState in _world.nodes:
        for good_id: String in node.stocks.keys():     # see §4 for the shape
            var cap: int = node.stock_caps[good_id]
            var rate: float = node.refill_rates[good_id]
            var stock: int = node.stocks[good_id]
            var accum: float = node.refill_accumulators[good_id]
            if stock >= cap:
                node.refill_accumulators[good_id] = 0.0   # steady-state reset
                continue
            accum += rate
            var whole_units: int = int(accum)
            if whole_units > 0:
                stock = mini(cap, stock + whole_units)
                accum -= float(whole_units)
                node.stocks[good_id] = stock
            node.refill_accumulators[good_id] = accum
    Game.emit_state_dirty.call()
```

`NodePanel._update_row` -- adds the `[N left]` segment and the new disabled branch:

```
_update_row(good, node, trader, current_load, force_disabled):
    ... existing setup ...
    var stock: int = world.stock_for(node.id, good.id) if node else 0
    var stock_segment: String = "[%d left]" % stock
    # Render: "Price: 12g (plentiful) [4 left]"
    price_label.text = "Price: %dg%s %s" % [price, tag, stock_segment]

    if force_disabled:
        buy_button.disabled = true
        buy_button.tooltip_text = ""
        sell_button.disabled = true
        return

    var affordable: bool = price > 0 and trader.gold >= price
    var fits_in_cart: bool = current_load + good.weight <= WorldRules.CARGO_CAPACITY
    var in_stock: bool = stock > 0    # NEW
    buy_button.disabled = not affordable or not fits_in_cart or not in_stock
    buy_button.tooltip_text = _buy_tooltip(...)   # extended; see §8
    sell_button.disabled = owned <= 0
```

Sell does not consult stock. Selling 1 wool at a node does not increase the node's wool stock. (The narrative is "the trader unloads goods to local merchants, who absorb them into a separate channel." Mechanically: sell-side has no cap and no feedback into stock; this is the slice-1 contract carried forward.)

## 4. Data model

### 4.1 Where does stock live?

Two options on the table:

**(a) On `NodeState`, three new dictionaries** keyed by good_id:

```
class NodeState:
    @export var stocks: Dictionary[String, int]
    @export var stock_caps: Dictionary[String, int]
    @export var refill_rates: Dictionary[String, float]
    @export var refill_accumulators: Dictionary[String, float]
```

**(b) On `WorldState`, one nested dictionary** keyed by node_id then good_id:

```
class WorldState:
    @export var node_stocks: Dictionary[String, Dictionary[String, int]]
    @export var node_stock_caps: Dictionary[String, Dictionary[String, int]]
    @export var node_refill_rates: Dictionary[String, Dictionary[String, float]]
    @export var node_refill_accumulators: Dictionary[String, Dictionary[String, float]]
```

**Designer's call: option (a), per-node.** Reasoning:

- *Locality.* Stock is per-node-state -- it lives where `prices`, `bias`, `produces`, `consumes` already live. Putting the four parallel dicts on `NodeState` matches the existing shape of the file. Adding `node_stocks` as a top-level `WorldState` field would be the only per-(node, good) field on `WorldState` not folded into the per-node iteration; that's structural inconsistency.
- *Iteration shape.* `StockSystem._on_tick_advanced` already needs to walk `_world.nodes` (mirroring `PriceModel._on_tick_advanced`). Per-node fields make the inner loop one-level (good_id over `node.stocks.keys()`); per-world fields make it two-level with an extra dict lookup per node. Negligible for N=7 nodes * 4 goods, but cleaner.
- *Save shape.* In `WorldState.to_dict`, the existing per-node loop already emits `prices`, `bias`, `produces`, `consumes`. Adding three more dicts to the same loop is a one-line-per-dict addition; option (b) would add four top-level fields to the WorldState dict, requiring four new top-level keys in `from_dict` REQUIRED_KEYS.
- *Forward-port.* `WorldGen.forward_port_goods` already iterates per-node when the slice-6.1->7 boundary lands a save with missing goods. Per-node stocks slot into that forward-port path naturally (mirror the prices path); per-world stocks need a parallel forward-port routine.

**Decision: per-node.** Architect ratifies the exact field layout (three parallel dicts vs. one dict-of-records) under §11.

### 4.2 Where do caps and refill rates live -- authored or derived?

The user's brief said "authored in node `.tres` files." But the project's load-bearing decision (`2026-04-29-procgen-world-authored-vocabulary`) is that **nodes are procgen, not authored.** There are no `node_*.tres` files; nodes are built by `WorldGen.generate` at world birth. The brief's intent ("Hillfarm refills wool faster than salt") must be expressed via the existing per-node character vocabulary, which is the `produces` (plentiful) / `consumes` (scarce) tag set.

**Designer's call: caps and refill rates are derived at world-gen time from per-good base values (authored on `Good.tres`) multiplied by per-node tag adjustments (read off `produces`/`consumes`).** Specifically:

```
class Good:
    @export var base_stock_cap: int        # NEW
    @export var base_refill_rate: float    # NEW
```

At world-gen, `WorldGen._author_stock(node, good)` produces:

```
func _author_stock(node, good):
    var tag_multiplier_cap: float = 1.0
    var tag_multiplier_rate: float = 1.0
    if good.id in node.produces:        # plentiful -- this node makes it
        tag_multiplier_cap = 4.0
        tag_multiplier_rate = 5.0
    elif good.id in node.consumes:      # scarce -- this node uses it up
        tag_multiplier_cap = 0.25
        tag_multiplier_rate = 0.2
    # else: untagged -- baseline cap/rate, no multiplier

    node.stock_caps[good.id] = maxi(1, roundi(good.base_stock_cap * tag_multiplier_cap))
    node.refill_rates[good.id] = good.base_refill_rate * tag_multiplier_rate
    node.stocks[good.id] = node.stock_caps[good.id]      # start full
    node.refill_accumulators[good.id] = 0.0
```

Why this derivation, not direct authoring on a per-node `.tres`:

- *Procgen contract.* `2026-04-29-procgen-world-authored-vocabulary` says nodes are procgen, vocabulary (goods, tags) is authored. Caps and refill rates are *vocabulary-shaped* (per-good Good.tres + tag multiplier table) and the *derivation* is procgen-shaped (per-node tags drive per-(node, good) numbers). This decision honours both layers.
- *Tag-meaning-tightening.* Slice-3 introduced (plentiful) and (scarce) as cosmetic labels with bias-driven price meaning. Slice-7 makes the tags **load-bearing** for stock too. The player who learned "plentiful = lower price, biased producer" in slice-3 now learns "plentiful = also more stock and faster refill." The tags do real work; they no longer drift toward decorative.
- *Tuning surface.* Two per-good values (`base_stock_cap`, `base_refill_rate`) plus four global multipliers (cap-plentiful, cap-scarce, rate-plentiful, rate-scarce) is a small tuning matrix. Authoring per-(node, good) directly would be 7 nodes * 4 goods = 28 numbers per world, none of which transfer between worlds (procgen, every world has different node ids). **The vocabulary stays stable across worlds**; the per-(node, good) numbers vary, but only via the procgen tag derivation.
- *Schema cost.* Per-good base values on `Good.tres` ride the slice-6 `weight` precedent (forward-port: ride the on-disk `.tres`, do not serialise into the save). Per-node `stock_caps` and `refill_rates` are saved on `NodeState` as slice-7 schema additions. Cap and rate are stored even though they are derivable, because the multiplier table is global state that could be retuned post-world-gen and we want the world's *as-generated* values frozen on save (player who saves a world expects "their world" to behave consistently). Architect ratifies this storage decision under §11.

### 4.3 The accumulator: store or recompute?

The fractional `refill_accumulator` is the determinism question. Two options:

**(a) Store it on NodeState** (per the dict in §4.1). The save grows by N nodes * N goods floats (28 floats at present scale).

**(b) Recompute from world.tick** as `(world.tick * refill_rate) mod 1.0` and clamp by cap. No storage.

**Designer's call: store it.** Reasoning:

- *Buy-decrement-then-refill semantics.* The accumulator is not pure-tick state -- it is *tick state minus tick state at the moment of last cap-saturation*. Once the player buys out a stock, the accumulator starts from 0 again on that good. A pure `world.tick * rate mod 1` recomputation cannot reproduce this without also tracking "the tick at which stock last hit cap" per (node, good), which is an equivalent storage cost.
- *Save-determinism.* The kernel decision (`2026-04-29-deterministic-price-drift`) seeds drift on `hash(world_seed, tick, node, good)`. Refill is *not* random; it is deterministic on accumulator state, which is itself deterministic on buy history. Storing the accumulator is the cheapest way to keep the save state self-contained; recomputing it would require replaying the buy history, which is bounded but ugly.
- *Storage cost.* 28 floats * 8 bytes = 224 bytes. Web export budget impact: nil.

Architect ratifies the per-good vs. per-record storage shape under §11; the *whether* is settled here.

### 4.4 `WorldState` accessor shape

The mutators `decrement_stock(node_id, good_id)` and accessor `stock_for(node_id, good_id)` should live on `WorldState`. Mirror the existing `get_node_by_id(node_id)` accessor pattern. Engineer should not reach into `world.nodes[i].stocks` directly from `Trade.try_buy`; the seam is `world.stock_for(...)` and `world.decrement_stock(...)`. This isolates the per-node data model choice from the call sites; if option (b) ever wins out, only the `WorldState` accessors change.

## 5. Schema bump v3 -> v4

The `WorldState.SCHEMA_VERSION` is currently 4 (per `world_state.gd:6`) -- it was bumped at slice-6.1 anticipation but the field never landed. Slice-7 takes the bump number forward to **5** and lands two fields in one migration: per-node stock state on `WorldState`, and `cargo_capacity` on `TraderState`.

> **Note for Engineer**: the brief calls this "v3 -> v4" but the on-disk constant is already 4. The actual mechanical bump is **4 -> 5**; "v3 -> v4" in the brief is a numbering shorthand inherited from earlier conversation. Use the on-disk number (5) in code; both spec and decision-log entries should mention the brief's numbering for traceability.

### 5.1 `NodeState.to_dict` / `from_dict` additions

`NodeState.to_dict` gains three dict fields (caps, rates, stocks) plus accumulators. Wire format mirrors the existing per-good keyed dicts:

```
{
    "id": ...,
    "name": ...,
    "pos": ...,
    "prices": {...},
    "bias": {...},
    "produces": [...],
    "consumes": [...],
    "stock_caps": {"wool": 16, "cloth": 4, "salt": 4, "iron": 1},          # NEW
    "refill_rates": {"wool": 1.0, "cloth": 0.2, "salt": 0.2, "iron": 0.04}, # NEW
    "stocks": {"wool": 12, "cloth": 4, "salt": 0, "iron": 1},               # NEW
    "refill_accumulators": {"wool": 0.6, "cloth": 0.0, "salt": 0.4, "iron": 0.32}, # NEW
}
```

`NodeState._from_dict` adds four required keys to the existing six. On migration (when loading a v3 save under v5 code), the four new dicts are absent; we synthesise them from `Good.base_stock_cap` * tag-multiplier and start every stock at cap (full). See §5.4.

### 5.2 `TraderState.to_dict` / `from_dict` additions

`TraderState.to_dict` gains one int field:

```
{
    "gold": ...,
    "age_ticks": ...,
    "location_node_id": ...,
    "travel": ...,
    "inventory": ...,
    "cargo_capacity": 60,    # NEW
}
```

`TraderState._from_dict` adds `cargo_capacity` to REQUIRED_KEYS. On migration (v3 save under v5 code), the field is absent; we synthesise it from `WorldRules.CARGO_CAPACITY` (the existing constant).

### 5.3 Schema version bump

`WorldState.SCHEMA_VERSION` advances from 4 to 5. The strict-reject in `WorldState.from_dict` currently reads:

```
if int(d["schema_version"]) != SCHEMA_VERSION:
    return null
```

This must change to a **migration-aware** check: accept v4 or v5 on input, route v4 through the migration helper, reject anything else. Sketch:

```
var loaded_version: int = int(d["schema_version"])
if loaded_version == SCHEMA_VERSION:
    pass  # current path, no migration
elif loaded_version == 4:
    d = _migrate_v4_to_v5(d)
    if d == null:
        return null   # migration could fail (e.g. corrupt nodes)
else:
    return null
```

The same shape applies to `TraderState`. Architect picks the exact placement of `_migrate_v4_to_v5` (free function on `WorldState`? Separate `SaveMigration` script-only class?); see §11.

### 5.4 Migration spec, v4 -> v5

**On `WorldState`:** for each node in the loaded v4 dict:
1. Read `produces` and `consumes` (already present).
2. For each good in `Game.goods` (note: iterate the live catalogue, not whatever happens to be in `node.prices.keys()` -- an absent good means no stock, but a future-add good loaded under a future build needs the right derivation):
   - Compute `cap` and `rate` from `good.base_stock_cap`, `good.base_refill_rate`, and the tag multipliers (§4.2). This is exactly the world-gen path.
   - Set `stock_caps[good.id] = cap`, `refill_rates[good.id] = rate`, `stocks[good.id] = cap` (full -- "old saves load with every stock at its refill ceiling, no save-scumming"), `refill_accumulators[good.id] = 0.0`.
3. Bump `schema_version` to 5.

**On `TraderState`:** if `cargo_capacity` is absent in the dict, set it to `WorldRules.CARGO_CAPACITY` (60).

The migration must not depend on world-seed state (no RNG, no procgen retry); it is a pure rewrite of dict-shape from v4 to v5. **The migration is one-way.** A save written under v5 cannot be loaded under v4 code; that is acceptable -- old builds are not a forward-compat target this slice.

### 5.5 Determinism check

Old saves loaded under v5 will start with stocks at cap, accumulators at 0.0. This is **not byte-identical** to a fresh v5 world generated from the same seed -- a fresh world also starts with stocks at cap and accumulators at 0.0, but v4-loaded worlds have a different `world.tick` count (>0 typically) and the buy history is replayed in the player's interaction, not in stock state. The migration sets stocks to "full as if no buys had ever happened" -- this is the user's "no save-scumming" rule applied: a player upgrading to v5 cannot exploit a stale stock state, because there was no stock state.

A subtlety: the v4 save may have been created at `world.tick = 200`; loading under v5 sets stocks to cap. This means the v5-migrated world's stock state at tick 200 is identical to a freshly generated v5 world's stock state at tick 0 -- the player effectively gets a "free refill" on upgrade. **This is the migration cost we accept**; the alternative (synthesise plausible buy history) is unbounded scope.

## 6. Authoring -- the numbers

### 6.1 Per-good base values (on `Good.tres`)

| Good | base_price | weight | base_stock_cap | base_refill_rate |
|---|---|---|---|---|
| **wool** | 12 | 4 | 4 | 0.2 |
| **cloth** | 11 | 3 | 4 | 0.2 |
| **salt** | 7 | 2 | 4 | 0.2 |
| **iron** | 22 | 10 | 4 | 0.2 |

Each good has the same baseline cap (4 units) and refill rate (0.2/tick = 1 unit / 5 ticks). The character of a node-good slot comes from the tag multipliers (§6.2), not from per-good baseline asymmetry. Goods are **shaped equally** at the source; nodes shape them differently.

`[needs playtesting]` These four base values are the slice's load-bearing tuning surface, second only to the multipliers in §6.2. The harness (§7) sweeps both. The committed values are the harness PASS. If playtest shows iron-only runs are infeasible (cap=16 at producer node = 16 iron = 160 weight, exceeds cart at 60), the iron base cap may need a separate floor; see §11.

### 6.2 Tag multipliers (in `WorldRules` or a new `StockRules`)

| Tag | cap multiplier | rate multiplier |
|---|---|---|
| **plentiful** (`good in node.produces`) | 4.0 | 5.0 |
| neutral (no tag) | 1.0 | 1.0 |
| **scarce** (`good in node.consumes`) | 0.25 | 0.2 |

So a (plentiful) slot at a node has cap = 16 and rate = 1.0/tick. A (scarce) slot has cap = 1 and rate = 0.04/tick (1 unit / 25 ticks). A neutral slot has cap = 4 and rate = 0.2/tick (1 unit / 5 ticks).

`[needs playtesting]` These are the load-bearing tuning knobs. Symptoms:
- *plentiful too high:* the player can buy out a producer node and refill it before they get back from a sell trip; stock cap is theatre. Symptom: gate 1 in §7 fails (cap-binding rate < 20%).
- *plentiful too low:* even a producer node runs dry on a single buy; the player feels punished by the kernel. Symptom: every leg is a half-cart leg, multi-good rate spikes for a wrong reason (no good has stock, so the player carries a mix of half-empty rows -- pyrrhic gate 2 pass).
- *scarce too high:* (scarce) tags lose their meaning; the player gets enough of the rare good to never need to plan around it.
- *scarce too low:* the (scarce) row is permanently `[0 left]` and the player learns to ignore it (tag becomes invisible).

### 6.3 Working example: a 7-node, 4-good world

At world-gen, each node gets per-good (plentiful) / neutral / (scarce) tags from the bias derivation (`world_gen.gd:301-311`). A typical layout might be:

| Node | wool | cloth | salt | iron |
|---|---|---|---|---|
| Hillfarm | (plentiful) | neutral | (plentiful) | (scarce) |
| Rivertown | (scarce) | neutral | (scarce) | neutral |
| Thornhold | neutral | (scarce) | neutral | (plentiful) |
| Oxmere | neutral | (plentiful) | neutral | (scarce) |
| Brackenford | (scarce) | (plentiful) | neutral | neutral |
| Stoneholt | (plentiful) | (scarce) | (plentiful) | neutral |
| Ashbridge | neutral | neutral | (scarce) | (plentiful) |

(Exact layout is procgen; this is illustrative.)

Hillfarm's (wool, plentiful) slot: cap = 16, rate = 1.0/tick. Hillfarm's (iron, scarce) slot: cap = 1, rate = 0.04/tick. Hillfarm's (cloth, neutral) slot: cap = 4, rate = 0.2/tick. The player learns Hillfarm as "the wool/salt town" by feel: those rows refill visibly, those rows are always at-or-near cap when they arrive. Ashbridge becomes "the iron town" the same way. The (scarce) labels reinforce: "salt is scarce here -- don't expect more than 1 unit, and good luck refilling it."

This is the **route-shape decision** slice-6 §13.2 promised, now with a temporal axis: rotating between Hillfarm (wool/salt) and Ashbridge (iron) -- with maybe a stop at Oxmere (cloth) -- is the natural three-stop loop. The kernel forces routes to be *node-aware*, not just *spread-aware*.

### 6.4 Out-of-scope authoring decisions

- **Initial stock != cap.** Some games have nodes start at random stock between [cap/2, cap] for variety. Not slice-7. All worlds start at full cap; randomness adds determinism cost (re-roll seam) and design surface (do new-game and after-load behave the same?) for low gain.
- **Per-node-character refill irrespective of tags.** "Hillfarm always refills fast even on goods it doesn't produce" was a possible read of the brief. Rejected -- it severs the link between (plentiful)/(scarce) tags and stock behaviour. The tags are the character; refill is what the tags do.

## 7. Harness -- two-gate predicate

The slice-6 lesson (§13 of the slice-6 spec) was: a single multi-good rate threshold conflates two distinct claims. Slice-7's harness splits cleanly.

**File:** new `tools/measure_production_caps.gd`, mirroring `tools/measure_cargo_decision_divergence.gd`. Reuses the seed sweep (`0..999`) and the per-(weight, cap, gold) block structure -- but the swept variable is now refill rate (and cap multiplier).

### 7.1 What it measures

Per (refill_rate_multiplier, seed, edge):
1. Generate the world. Run an internal "warm-up" of K ticks of refill+buy-out simulation to reach a steady state (defaults to K=20, Engineer's call on the exact number; the harness output should print this so it's auditable).
2. For each directed edge (from, to) and each tick t in some sample window: compute the *optimal cart* the player would carry from `from` to `to`, subject to:
   - cargo capacity (`current_load <= 60`)
   - gold cap (parameterised, swept at [120, 200, 400] like slice-6)
   - **stock cap** (`qty_g <= node[from].stocks[g]`) -- the new constraint
3. Record:
   - **`cap_binding`**: did the optimal cart's headline good (highest-share good in the cart) hit its source-node stock cap? I.e., did the optimization want more of that good but stock said no?
   - **`multi_good_when_cap_bound`**: given `cap_binding == true`, did the optimal cart contain >= 2 goods?

### 7.2 Pass criterion -- two gates

**Gate 1: Cap-binding rate.** Across the sample at the canonical mid-tier (gold=200), the optimal cart's headline good must hit the source stock cap on **>= 20%** of (route, tick) pairs. This is the floor for the cap to be a real mechanic. If gate 1 fails (cap is non-binding most of the time), the cap is theatre -- refill rates need lowering. The slice cannot ship.

**Gate 2 (gated on gate 1): Multi-good rate when cap-bound.** *Among the (route, tick) pairs where gate 1 binds*, the optimal cart contains >= 2 distinct goods on **>= 60%** of them. This is the central slice-7 claim: when stock forces a fallback from the headline good, the player goes to a second good rather than a partial cart. If gate 2 fails (the player rationally takes a half-cart instead of mixing), the second-best good has negative profit on most edges -- a bias-spread tuning issue, not a slice-7 issue. Escalate to a separate slice (price-spread / bias retune); slice-7 ships the cap mechanic with a known-failed gate 2 only if Director ratifies that the cap mechanic alone is the slice's value.

The two gates are evaluated independently. Gate 1 is the *go/no-go* for the slice itself. Gate 2 is the *did the slice deliver the slice-6.13 promise* check.

### 7.3 Sweep parameters

- **refill_rate multiplier on (plentiful, neutral, scarce):** sweep `[(2.5, 0.5, 0.1), (5.0, 1.0, 0.2), (8.0, 1.5, 0.4), (10.0, 2.0, 0.5)]`. The (5.0, 1.0, 0.2) multiplier set is the §6.2 starting point; the others are the rough "too slow", "spec", "fast", "way too fast" bracket.
- **stock_cap multiplier on plentiful:** sweep `[2.0, 4.0, 6.0, 8.0]` (the §6.2 baseline is 4.0). Holds neutral=1.0 and scarce=0.25 fixed.
- **gold:** `[120, 200, 400]` (matches slice-6).
- **seeds:** `0..999`.
- **base values for cap and rate:** `(base_stock_cap=4, base_refill_rate=0.2)` -- not swept this slice; if the harness fails to find a PASS in the multiplier sweep, the secondary sweep runs over base values too.

### 7.4 Sanity baselines

The harness must include explicit pass-fail tests for two degenerate cases:

- **Refill = cap, always-full** (rate * warm-up >= cap on every node-good slot): the buy-out never bites. **This must FAIL gate 1** (cap-binding rate ~0%). If it passes gate 1, the harness logic is wrong.
- **Refill = 0, no refill ever** (rate = 0 on every slot, stock starts at cap and decays): gate 1 trivially passes (cap binds immediately and forever). Gate 2's behaviour here is the central diagnostic -- under no-refill, multi-good rates should approach 100% as the warmup proceeds (all stocks drain). If gate 2 fails even under no-refill, the bias-spread tuning is the culprit, not the cap mechanic.

These baselines are **not** ship candidates. They are sanity floors: the harness's ability to discriminate good tuning from bad depends on these passing/failing as expected. If they don't, the harness is broken before it's evaluated.

### 7.5 Output format

Mirror slice-6's format:

```
=== slice-7 production-caps measurement (refill=(plentiful=5.0, neutral=1.0, scarce=0.2),
    cap_mult=(plentiful=4.0, neutral=1.0, scarce=0.25), gold=200) ===
seeds=1000, edges_evaluated=N, ticks_sampled_per_edge=M

cap_binding rate: 34.2%   [gate 1 floor: >= 20%]   PASS
  (of 34.2% cap-bound, multi-good fraction: 71.8%)
gate 2 floor: >= 60%      PASS

sanity baselines:
  refill=cap-always-full: cap_binding=0.4% (expected ~0%, FAIL gate 1 as intended)
  refill=0-no-refill: cap_binding=99.7%, multi_good=98.1% (expected high, both as intended)

verdict: PASS at this multiplier set, gold=200.
```

The two-gate verdict is the load-bearing line. Engineer should print sanity baselines on every harness run -- if they ever flip from expected, the harness logic regressed.

### 7.6 Process gate (binding for the Engineer)

The Engineer must run the harness **before** committing the multiplier table. Ship sequence mirrors slice-6 §7.6:

1. Author multipliers per §6.2.
2. Run the harness; capture the verdict log on disk (`godot/tools/production_caps_verdict.txt` or similar -- Architect picks).
3. If gate 1 PASSes and gate 2 PASSes at gold=200: ship.
4. If gate 1 FAILS: refill is too fast. Reduce the (plentiful) rate multiplier. Re-run.
5. If gate 1 PASSes but gate 2 FAILS: cap is binding but the player doesn't fall back to a second good when bound. Hand back to Designer with the failing report attached -- the cap mechanic alone is the slice's value (Director call required to ratify shipping with a known-failed gate 2).

The harness is the source of truth for ship/no-ship on gate 1. Gate 2 outcomes feed Director-level scope decisions, not Engineer-level ship gating.

## 8. UI -- buy panel

ASCII only (CLAUDE.md project rule). Single-pixel cleanliness; no flashing, no animations, no audio.

### 8.1 The `[N left]` segment in the price row

Extend the existing price label format from:

```
Price: 12g (plentiful)
```

to:

```
Price: 12g (plentiful) [4 left]
```

- **Format string:** `"Price: %dg%s [%d left]"` where the second `%s` is the existing tag (` (plentiful)`, ` (scarce)`, or empty) and `%d` is `world.stock_for(node.id, good.id)`.
- **Position:** unchanged -- existing PriceLabel in the row HBox. Just longer text. The PriceLabel already has `custom_minimum_size = Vector2(96, 0)`; this may need to widen to accommodate `[12 left]` plus the (plentiful) tag at the longest. Architect picks the width (likely 144 or 160).

### 8.2 The "out of stock" disabled state

When `stock <= 0` and other gates pass:

- `buy_button.disabled = true`
- `buy_button.tooltip_text = "out of stock"` (single ASCII string, lowercase, no exclamation).
- The `[N left]` segment reads `[0 left]`.

When multiple disabled reasons stack (e.g., stock = 0 AND not affordable AND cart full):

- The tooltip names **all** binding reasons, in priority order: stock first (most informative), then cart, then gold. Format:
  - stock + cart: `"out of stock; need %d more cart space"`
  - stock + gold: `"out of stock; need %dg more"`
  - stock + cart + gold: `"out of stock; need %dg and %d more cart space"`
  - stock alone: `"out of stock"`
  - (cart-only and gold-only cases inherit the slice-6 messages unchanged)

The four-case tooltip from slice-6 §8.2 expands to an eight-case table. Engineer renders this verbatim from §3.4 pseudocode; no creative deviation. Architect ratifies the tooltip-builder's location (extension of the existing `_buy_tooltip` helper, or a new helper -- §11).

### 8.3 Label clearing -- the slice-6 lesson

The slice-6 disabled-button branches are: `force_disabled`, `node == null`, plus the predicate branches. Each disabled branch must explicitly clear the tooltip (slice-6 §8.4 / `node_panel.gd:148, 162`). **Slice-7 adds two new disabled branches** (stock=0 standalone, stock + other), and both must explicitly clear or set `tooltip_text` -- never rely on prior-frame state.

### 8.4 No "low stock" warning

When stock is at 1, the row reads `[1 left]` and the Buy button is enabled (1 unit fits any cart slot). **No colour, no asterisk, no "low stock!" annotation.** The integer is the warning. The slice-6 anti-goal ("no inventory-management as a system") extends to "no stock-management UI" -- the row is a passive readout.

### 8.5 No remote-stock readout

The player at Hillfarm cannot see Rivertown's stock from the buy panel. The map view does not annotate stock. Stock is local-knowledge-only; the player learns route patterns by visiting, not by reading a global stock UI. (This is the discriminating line between "kernel mechanic" and "inventory-management activity"; slice-7 holds it.)

### 8.6 ASCII verification

Strings introduced this slice:
- `"[%d left]"` -- ASCII brackets, integer, lowercase word. No special punctuation.
- `"out of stock"` -- ASCII letters and spaces. Single semicolon when chained with cart/gold tooltips.

No `->`, no em-dashes, no fancy quotes, no `...`. CLAUDE.md rule satisfied.

## 9. Edge cases and failure modes

- **Buying when stock = 0 (UI gates failed).** Defensive check in `try_buy` (§3.4) refunds gold, push_warning fires, return false. Save state remains consistent. Mirrors the slice-6 cargo-overflow defensive guard.
- **Empty inventory at out-of-stock node.** Player has 0 cargo, walks into a node where every stock is 0. All Buy buttons grey out with `"out of stock"` tooltip. Player can sell nothing (empty inventory) or travel. **Intended**: the player feels they need to leave to let the node refill.
- **Travel-while-empty.** Player has empty inventory, travels A -> B -> A in 6 ticks. During those 6 ticks, A's stocks refill by `6 * refill_rate` units per slot, capped at cap. The player returns to a partially-refilled A. **Intended**: travel ticks are when the world breathes.
- **Bandits + out-of-stock interaction.** Player loses 50% of their iron stack to bandits (slice-4). Iron stack drops from 6 to 3. The node where bandits hit (and the stocks at any node) are **not** affected -- bandit loss is trader-side only. Player arrives at the next node with a half-empty cart and decides whether to top up; if that next node has iron at 0, they can't replace the lost iron and continue with a partial. **Intended**: bandits hurt because cart-rebuild-from-stock is now a real cost, not just a gold cost.
- **Stock at exactly 1.** Buy succeeds; stock decrements to 0; row reads `[0 left]` post-buy; Buy button re-disables on next refresh. Single-unit consumption is the boundary case the slice ships to surface.
- **`stock < 0` somehow.** Defensive: `world.decrement_stock(...)` should `assert(node.stocks[good_id] > 0)` before decrementing, and the Trade verb's pre-check (§3.4) ensures it's never called on 0. If the assert fires, it's a bug.
- **Refill with `stock > cap` (cap reduced post-load).** The migration sets `stock = cap`, so this state is impossible at load. If a future build reduces a cap (e.g., retuning), the `if stock < cap` guard means refill stops, but the old over-cap stock persists. Acceptable -- player cannot exploit (they bought it under the old cap; reducing the cap mid-save is a build-config change, not an in-game event).
- **Refill rate = 0.** Stock decays from cap to 0 across buys; never refills. Player is forced to rotate. **Intended (slice-7's no-refill sanity baseline behaviour).**
- **Refill rate > cap.** Hypothetical: `rate = 5.0/tick`, cap = 4. The accumulator reaches 5.0 in one tick; we add `min(cap - stock, 5) = up to 4` units; accumulator drops to 5.0 - 4 = 1.0; on next tick we have 1.0 + 5.0 = 6.0; we add 0 units (stock at cap); accumulator resets to 0.0 per the §3.2 cap-saturation reset. **Behaviour is correct** but design-wise this is a bad authoring -- the rate is wasted on invisible refills. Engineer should `assert(rate < cap)` on world-gen post-derivation as a sanity rail.
- **`Game.goods` empty at refill time.** StockSystem walks `_world.nodes[i].stocks.keys()`, so the inner loop only visits goods that already exist on the node. Empty `Game.goods` means no buys can happen anyway (NodePanel pre-bootstrap path); refill still applies to whatever is on disk. No special handling needed.
- **B1 invariant harness regression.** The B1 predicates are P1-P6 per `save_invariant_checker.gd` -- mutex, travel validity, schema version, death consistency, non-negative state, history integrity. Slice-7 adds new state (`node.stocks`, `node.stock_caps`, `node.refill_rates`, `node.refill_accumulators`, `trader.cargo_capacity`); none of these are touched by P1-P6 directly. Engineer should add **two new B1 predicates**:
  - **P7-stock-non-negative:** `for each (node, good): node.stocks[good_id] >= 0 and node.stocks[good_id] <= node.stock_caps[good_id]`. Mirrors P5.
  - **P8-stock-keys-match-prices:** `for each node: set(node.stocks.keys()) == set(node.prices.keys()) == set(node.stock_caps.keys()) == set(node.refill_rates.keys())`. Catches partial-write failures during migration.
- **Save written under v5, loaded under v4 build.** Strict-reject on `schema_version != 4`; v5 saves are rejected by v4 code. **Acceptable** -- forward-compat for old builds is not a target.

## 10. Out of scope -- named, deferred to slice 7.x or beyond

Each item below was considered and left out of slice-7. None silently dropped.

- **Refill on arrival** (vs. per-tick). Picked: per-tick. The "refill on arrival" alternative would have nodes refill *only* when the player visits, producing burst-refills and a different UI (the player walks in and stock has just become available). Per-tick is simpler, more predictable, and aligns with the existing `tick_advanced` listener pattern.
- **Sell-side cap.** The brief specifies buy-side only. Sell does not affect node stock; selling doesn't fill local merchants' shelves. Adding a sell-side stock would invite a "sell saturation" mechanic (sell prices drop as you offload), which is one of slice-6 §13.3's three out-of-scope deepening levers. Deferred -- if and when, that's a separate slice.
- **Bandits respect stock.** The brief notes bandits don't interact with stock; this stays. (Variant: "bandits could top up a stock by depositing what they took elsewhere" -- not even close to in scope.)
- **Save-load tick alignment beyond schema.** The migration snaps stock to cap; we don't try to "replay" buy history to estimate what stocks should be. Players who upgrade get a free refill -- accepted cost.
- **Per-good stack rot / perishability.** Branch C-perish from the original brief. Not slice-7. Salt could rot above stack 30 in a future slice; not now.
- **Multi-leg commitment / route planning.** The third out-of-scope mechanic from slice-6 §13.3. Slice-7 introduces *temporal* route texture (nodes refill while you're away), but the player's commitment is still per-leg ("I will travel to B"); no system asks the player to commit to A->B->C up front. That is its own design.
- **Stock visibility from outside the node.** §8.5 -- explicit anti-goal. The player learns by visiting.
- **Trade-route automation / hireling traders / convoy ships.** Out -- this is "the kernel grew a metagame." Slice-7 is one mechanic; the metagame is its own slice (or its own decision to never build).
- **Variable starting stock.** §6.4 -- all worlds start at full cap.
- **Per-tag rate-curve (e.g., scarce refills slowly until stock = 0, then fast).** Linear refill only. Curves are a tuning surface that doesn't earn its weight at slice-7's scale.
- **Refill jitter / per-tick randomness on refill.** No. Refill is deterministic. The kernel pillar (`2026-04-29-deterministic-price-drift`) is "world is reproducible from seed and tick"; refill follows that contract.
- **TraderState death from "cannot afford to leave a node with 0 stock."** Slice-4 already handles "stranded with insufficient gold to travel out"; slice-7 doesn't add a new death type. A node with all stocks at 0 doesn't kill the player; they just leave with a half-cart.
- **Initial-cap-from-tick-0 vs initial-cap-from-tick-K warm-up.** Worlds start at full cap, not at "what the steady state would be if K ticks had passed." Steady state is the tick-K outcome of the buy-and-refill loop; we let the simulation reach it organically.

## 11. Open questions for Architect

- **`StockSystem` placement.** Mirror `PriceModel` -- a sibling Node under the same parent (`main.tscn`'s `$PriceModel` neighbour), with `setup(world: WorldState)` and a `tick_advanced` listener? Or fold the refill logic into `PriceModel` itself (since both walk every node every tick)? Designer leans **separate `StockSystem` Node**, mirroring `PriceModel` exactly. Reasoning: orthogonal mutations on disjoint state, separate test surface, separate setup wiring. PriceModel is 46 lines of focused work; doubling it would muddle. Architect ratifies.
- **`NodeState` field shape.** Three parallel dicts (`stocks`, `stock_caps`, `refill_rates`, `refill_accumulators`) keyed by good_id, OR one dict keyed by good_id holding a small record (Resource? Dictionary?) per slot. Designer leans **four parallel dicts** to match the existing per-node `prices`/`bias` pattern -- a record-per-good would be the only nested-record on `NodeState` and would force a new Resource subclass for the slot. Architect ratifies.
- **Cap and rate storage.** §4.2 derived caps and rates at world-gen time; but they are stored per-node-per-good in the save. Should they instead be **recomputed on load** from `Good.base_*` and node tags, leaving only `stocks` and `refill_accumulators` saved? Designer leans **store all four** -- the slice-6 weight precedent is that vocabulary fields ride the on-disk `.tres` rather than the save (because re-tuning a `.tres` should affect new worlds, not retroactively change existing saves), but slice-7 is harder: the cap and rate are *per-(node, good)*, derived from per-good base + per-node tags. If the multiplier table is retuned post-save, the old save's stock state is now inconsistent with the new caps (e.g., stock = 12 but new cap = 8). Storing the as-generated caps freezes the world's stock economy at gen time, which is what we want. **Recomputing on load** would force every retune to invalidate every save, which is harsher than the kernel implies. Architect ratifies the storage call; if Architect prefers recompute-on-load with a documented "retune invalidates saves" contract, that is also defensible.
- **Migration helper placement.** `_migrate_v4_to_v5` -- free function on `WorldState`, separate `SaveMigration` script-only class, or two static methods (one each on `WorldState` and `TraderState`)? Designer leans **two static methods** -- migration logic is per-shape, and a separate `SaveMigration` class would be premature abstraction at one migration. If we ever do a v5->v6, that's when the abstraction earns its weight. Architect ratifies.
- **`world.stock_for(node_id, good_id)` and `world.decrement_stock(node_id, good_id)`** as new accessors on `WorldState`. Designer leans yes, mirroring the existing `get_node_by_id(...)` accessor seam. Alternative: expose the dicts directly and let callers index. Designer's leaning is the encapsulation-y one; Architect ratifies.
- **B1 predicate additions.** P7 (stock non-negative + within cap) and P8 (key-set parity) per §9. Designer leans both must land in the same slice as the schema change so v5 saves are validated by B1 from day one. Architect picks the exact predicate file location and naming.
- **`assert(rate < cap)` on world-gen.** Sanity rail per §9 ("refill rate > cap"). Designer leans yes, post-derivation. Architect picks where the assert lives -- on `_author_stock` directly, or in a separate post-gen audit pass.
- **Tick-listener ordering.** §3.3 notes that PriceModel and StockSystem mutate disjoint state and should not need explicit ordering. Architect should confirm by inspection that no listener reads what another mutates. The `Game.tick_advanced` connect call order is currently insertion order in `main.gd`'s `_ready`; if ordering ever matters, surface it now.
- **Wire-format versioning of `refill_rates`.** Floats in the save dict. Godot's JSON write/read preserves floats; do we want to round to 4 decimal places on write to keep saves diff-clean? Designer leans no (raw float, leave the save format byte-for-byte deterministic). Architect ratifies.

## 12. Open questions for project owner

- `[needs playtesting]` All numbers in §6 (per-good base values and tag multipliers). The harness validates the slice's *mechanics work*; it does not validate the *feel* of "the world remembers me." Symptom-of-too-fast-refill: the player buys out a node and finds it full again on return -- cap is theatre. Symptom-of-too-slow-refill: the player feels punished for choosing a route and avoids "cleaned out" nodes the rest of the run -- punishment-flavoured kernel. Tuning windows in §6.2 -- ranges noted, ship values are §6's harness PASS.
- `[needs playtesting]` Tooltip clarity on stacked refusal reasons (out-of-stock + cart-full + gold-short). The tooltip can grow to 60+ chars; on web export with default font and small-window UI, this may wrap or clip. If players consistently miss the binding reason, demote stacked tooltips to "out of stock" (single-reason) and let the user discover the secondary refusal post-rotation. Slice-7.x.
- `[needs Director call]` If gate 2 fails in the harness despite gate 1 passing -- ship the cap mechanic alone? §7.6 escalates this. Designer's read: gate 1 alone delivers the temporal-availability kernel texture (the slice's load-bearing add); gate 2's promise (per-leg multi-good carts) was the slice-6 §13.3 hope. Shipping with gate 1 PASS / gate 2 FAIL is a *narrower-than-promised* slice that still delivers real value; Director ratifies.
- `[needs Director call]` Is "world has memory" a kernel pillar going forward, or a one-slice texture? If kernel, future slices will accumulate world-state mechanics (faction rep, ruler taxes, seasonal price shifts). If texture, slice-7 is the only slice that mutates `WorldState` from non-tick events. The decision shapes scope decisions for slice-8 onward.
- `[needs Director call]` Slice-7.x sequencing. Sell-side stock saturation (§10), bandit-respects-stock (§10), and per-leg perishability (§10) are three separate follow-ups. None are obviously next. Director picks which (if any) lands first when slice-7 ships.

## 13. Lessons placeholder

To be filled post-harness, mirroring `slice-6-weight-cargo-spec.md` §13. Sections expected:

- **13.1** -- structural finding from the harness sweep. Did gate 1 PASS at the §6 multipliers? Did gate 2? At what tier?
- **13.2** -- what the slice actually delivers vs. what the spec promised. (Slice-6's reframe lesson: route-dependent good selection vs. per-leg portfolio.) Slice-7's analogue: did the world-memory texture land, did the per-leg multi-good promise land, did one of them not land?
- **13.3** -- mechanics that would unlock the next deepening, if gate 2 failed. The three slice-6 §13.3 candidates (sell-side elasticity, multi-leg commitment, per-good rot) carry forward; slice-7 may add a fourth based on what the harness teaches.
- **13.4** -- process lessons. If the harness surprised us (gate 1 failed at the predicted multipliers; gate 2 over-promised; or sanity baselines did not behave as expected), document what the predictor missed.
- **13.5** -- what the harness was useful for, beyond the gate decision (e.g., catching pathological tunings, surfacing tag-meaning shifts, validating B1 predicate additions).

The harness is binding for the Engineer (§7.6); §13 is the post-mortem the Designer fills in after Engineer reports the verdict and Reviewer ships.

---

## Hand off to Architect

The Architect must ratify (or override with reasoning) the calls in §11 before the Engineer touches code. The four most load-bearing:

1. **`StockSystem` as a separate Node**, mirroring `PriceModel`. (vs. fold into `PriceModel`.)
2. **`NodeState` four-parallel-dicts shape.** (vs. record-per-slot.)
3. **Caps and rates stored on save**, frozen at world-gen. (vs. recompute on load.)
4. **Two static migration methods**, one each on `WorldState` and `TraderState`. (vs. separate `SaveMigration` class.)

The harness (§7) is binding for the Engineer: the multiplier table cannot be committed to disk until the harness gate 1 PASS verdict is on disk. Designer's per-good rationale (§6) is the *why*; the harness verdict is the *whether*. If the Engineer wants different numbers, they re-run the harness -- not negotiate the rationale.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies §11. Numbers in §6 are starting values backed by the harness (§7); finer tuning happens in playtest, not in spec.
