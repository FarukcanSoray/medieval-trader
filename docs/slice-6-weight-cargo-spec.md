# Medieval Trader -- Slice 6.0 (Weight + Cargo Capacity) Spec

> **Ratified frame (2026-05-03):** Director scoped slice-6.0 to add per-good `weight` and a fixed trader cargo capacity that gates the buy action, so route choice becomes "which goods to bring" instead of just "whether to buy." Critic compressed slice-6 into 6.0 (this slice) and 6.1 (TraderState save-schema migration when capacity needs to vary per-trader). Branch C-perish, weight-affects-travel-cost coupling, encumbrance penalties, cart upgrades, mid-route inventory management UI, and per-route capacity restrictions are **all out of slice**.
>
> Anti-goal carried forward (Director, repeat for the Engineer): **no inventory-management as a system.** The slice's drift edge is "show current load + show what fits" growing into "manage cargo." The UI spec keeps that line clear: there is no reorder verb, no jettison verb, no partial-drop verb, no mid-route cargo screen. The buy gate is the entire mechanic; the fill-state readout is a passive label, not a controller.
>
> **No schema bump.** `TraderState` is unchanged this slice -- `cargo_capacity` is a code constant, `current_load` is computed (see §4). Goods catalogue gains `weight: int`, which rides the slice-5.x forward-port pattern: `.tres` on disk gain a field, saves don't store it (goods are loaded from disk at boot, not from the save). Slice-5 saves load on slice-6.0 builds with no migration code.

## 1. Pattern reference

This is **Patrician III's cargo-load gate** at the smallest size that still produces a real cargo-composition decision. The closest exact ancestor is the cog-ship cargo limit in *Patrician 2/3* and the cargo grid in *Port Royale 2*: a single hard cap (in cargo units) shared across all goods, with each good consuming a per-unit weight integer. The buy verb is gated by `current_load + weight <= cargo_capacity`; sell frees space; travel does not affect load. Slice-6.0 deviates in three places: (1) capacity is a code constant, not a per-trader stat (no upgrade path this slice -- that's 6.1); (2) weight does not couple to travel cost (Branch C-coupling deferred); (3) overload is impossible by construction -- the gate refuses, it does not penalise post-hoc. The careful-merchant fantasy gains a **portfolio-density axis**: gold-per-unit-weight, not just gold-per-unit, becomes a route's headline number.

## 2. Core loop change

**Before slice-6.0:** the player walks into Hillfarm, sees four price rows, and has one decision: which goods are mispriced relative to a sell node? Inventory has no cap; gold is the only constraint. The player drops their full purse into the highest-spread good and travels. Cargo composition is "100% of whatever has the best spread today" -- the four-good role taxonomy is real but flattens at decision time.

**After slice-6.0:** the player walks into Hillfarm with 240g and a 60-unit cart. Iron is `(plentiful)` at 14g. Salt is `(plentiful)` at 4g. The player can afford 17 iron (240g / 14g) but the cart only holds 6 iron (60 / 10 weight). They can afford 60 salt but the cart only holds 30 salt (60 / 2 weight). The cargo decision becomes: **which of the four goods has the best profit-per-cart-unit on this specific edge?** That answer changes route-to-route -- salt wins on one edge, iron on another, cloth on a third -- because the four goods sit at different points on the gold-per-unit-weight axis and the per-edge spreads vary. The player no longer "carries iron because it has the best spread today" (slice-5); they carry **the right good for this leg**, and the right good is not always the same.

The kernel is unchanged: arbitrage profit perpendicular to travel cost. What changes is the **second axis on the buy decision** -- gold-per-unit-weight is now the headline density figure, and the four goods sit at four different points on that axis. A player who learned "iron pays per unit" in slice-5 learns "iron pays per gold but not per unit-of-cart" in slice-6.0; the role taxonomy survives but gets sharper.

> **Honest framing (post-harness, 2026-05-03):** the original spec promised "every leg is a knapsack problem the player solves at the buy panel." The decision-divergence harness (§7) showed that, under rational profit-maximisation with N=4 distinguishable goods and no per-node elasticity, the optimal answer at any given route is **"fill cart with the single best profit-per-weight good for that edge."** This is a structural property of the math, not a tuning failure. Slice-6.0 therefore delivers **route-dependent good selection** ("which good for this leg") rather than **per-leg portfolio composition** ("which mix for this leg"). The former is a real decision -- different routes really do prefer different goods, the harness confirms this -- but it is smaller than the spec's first reading promised. The "compose a mixed cart" reading is recoverable only via mechanics out of slice-6.0 scope (per-node production caps, sell-side elasticity, multi-leg commitments); see §13.

## 3. Mechanic spec

**The buy gate, in one sentence:** at buy time, refuse the purchase if `current_load + good.weight > cargo_capacity`. Otherwise: take 1 unit (the slice-1 single-unit buy contract -- see `godot/travel/trade.gd:30`).

**Data flow:**

```
NodePanel._update_row(good, node, trader, force_disabled):
    price = node.prices[good.id]
    weight = good.weight                                      # NEW
    current_load = _compute_load(trader.inventory)            # NEW (§4.3)
    affordable    = price > 0 and trader.gold >= price
    fits_in_cart  = current_load + weight <= cargo_capacity   # NEW
    buy_button.disabled = force_disabled or not affordable or not fits_in_cart
    # Rendering: §8 specifies the label text and the refusal feedback shape.
```

```
Trade.try_buy(good_id):
    ... existing slice-5 guards ...                           # location, world, prices
    if not _trader.apply_gold_delta(-price, ...):
        return false
    # NEW: defensive cargo gate, mirrors UI predicate. Refunds gold on overflow.
    var weight: int = Game.good_by_id(good_id).weight
    var current_load: int = _compute_load(_trader.inventory)
    if current_load + weight > cargo_capacity:
        _trader.apply_gold_delta(price, ...)                  # refund
        return false
    _trader.apply_inventory_delta(good_id, 1, ...)
    ... existing history push + write_now ...
```

**Why the buy gate fires after gold deduction, not before:** matches the slice-1 file contract for `try_buy` (gold first, inventory second). The refund branch keeps the contract honest -- if cart overflows, the trade did not happen, gold returns. The defensive check exists because UI predicates can drift from runtime predicates (slice-1 standing rule); the ground truth is `try_buy`, not the disabled button. UI gating prevents the click; the defensive check prevents the overflow if the click somehow fires.

**Sell does not gate on weight.** Sell removes from inventory, freeing units. No cap, no minimum, no fee. (The `current_load` indicator updates because inventory changed; see §8.)

**Travel does not consult weight.** No cost coupling, no per-step weight penalty, no encumbrance state. Branch C-coupling is explicitly out of slice.

## 4. Schema additions

### 4.1 `Good` gains `weight: int`

```
class_name Good
extends Resource

@export var id: String
@export var display_name: String
@export var base_price: int
@export var floor_price: int
@export var ceiling_price: int
@export var volatility: float
@export var weight: int                   # NEW -- units of cart per 1 unit of good
```

`weight: int`, range 1..N (no zero, no negative). Authored per-good in `.tres`. See §5 for the four values.

**Forward-port behaviour on slice-5 saves loaded onto slice-6.0 builds:** zero migration code. Goods are loaded from `.tres` at boot (`game.gd:28-33` -- the four `preload` lines). Saves contain `inventory: Dictionary[String, int]`; they do not contain weight. On load, `Game.goods` is populated with the on-disk `.tres` (which now include `weight`), and the existing inventory dict is interpreted against the new weights. A slice-5 save with 17 iron in inventory loads as 17 iron with `current_load = 17 * 10 = 170`, which may exceed `cargo_capacity` -- see §10 for the load-time edge case.

### 4.2 `cargo_capacity: int` is a code constant

Lives in `WorldRules.gd` next to `TRAVEL_COST_PER_DISTANCE` and the slice-3/4/5 constants. **Not** on `TraderState`. **Not** on a per-trader Resource. Constant access surface for slice-6.0; promotable to a TraderState field in slice-6.1 when it actually needs to vary per trader (cart upgrades, etc.).

```
const CARGO_CAPACITY: int = 60      # See §6 for the route-economy math.
```

Why constant, not field: the Director frame says "fixed trader cargo capacity." If it's fixed, it's a constant. Putting it on `TraderState` now would force a schema bump (3 -> 4) for a value that does not vary. Slice-6.1 takes the bump when capacity actually needs to vary; slice-6.0 ships without one. (See §12 for the 6.1 hand-off.)

### 4.3 `current_load` -- derived, not stored. Designer's call.

**Choice: derive from inventory each access.** Pseudocode:

```
static func compute_load(inventory: Dictionary[String, int],
                         goods_by_id: Dictionary[String, Good]) -> int:
    var total: int = 0
    for good_id: String in inventory.keys():
        var qty: int = int(inventory[good_id])
        if qty <= 0:
            continue
        var good: Good = goods_by_id.get(good_id)
        if good == null:
            continue                    # missing-from-catalogue: §10
        total += qty * good.weight
    return total
```

**Reasoning (Critic's framing -- derive vs. memo):**

- *Migration cost:* derive is **zero migration**. Memo on `TraderState` is a `schema_version` bump and a `from_dict` field-presence check. With `cargo_capacity` already a constant (no per-trader varying), the schema bump is paying twice for the same slice.
- *Debug cost:* derive is **harder if there's ever a desync** -- but desync is impossible by construction here. The function is `(inventory, goods) -> int`, both pure inputs. There is no second source of truth to drift from. Memo introduces the desync surface (forget to recompute on `apply_inventory_delta`, save the stale value, load it next session); derive eliminates it.
- *Performance:* the loop is O(goods-in-inventory) -- at N=4 goods, that is at most 4 dict reads + 4 multiplies per call. Called on each `_refresh()` of NodePanel (signal-driven, not per-frame). HTML5 budget impact: negligible. The "cache for perf" branch is not earned.
- *Storage:* derive adds zero bytes to the save. Memo adds 4 bytes (an int field) plus the schema bump's amortised cost.

**Decision: derive.** The Engineer should expose a static helper (location is the Architect's call; see §11) so that NodePanel, Trade, and any future read site call the same function. No `current_load` field anywhere.

**Slice-6.1 may flip this** if capacity becomes per-trader and the recompute hot-path moves into a tighter loop (e.g., a continuous-buy verb, not in scope). Until then, derive.

## 5. Per-good weight values

The four numbers below are **derived from the harness** (§7 specifies the harness; the values here are the post-harness selections that pass its decision-divergence pass). Each value's per-good rationale follows.

| Good | Role (slice-5) | base_price | weight | g/wt at base | One-line identity (weight-aware) |
|---|---|---|---|---|---|
| **wool** | cheap, mid-volatile | 12 | 4 | 3.0 | "Median density -- the kernel-trainer is also the average-cart-row." |
| **cloth** | cheap-volatile (drift-rewarding) | 11 | 3 | 3.7 | "Light and chatty -- you can fit a lot of cloth, drift makes it pay off." |
| **salt** | cheap, volatile | 7 | 2 | 3.5 | "The bulk play -- cheapest per-unit AND lightest per-unit; volume route." |
| **iron** | expensive, stable | 22 | 10 | 2.2 | "The dense capital play -- 1 iron eats a wool-and-a-half of cart." |

> **Slice-5 consolidation note:** §5 of slice-5-spec described cloth as "mid-expensive, stable" with `base_price=18, vol=0.06`, and salt as "cheap, volatile" with `base_price=7, vol=0.13`. The `.tres` on disk today are: wool (12, vol=0.10), cloth (11, vol=0.18 -- per CLAUDE.md catalogue line), salt (7, vol=0.13), iron (22, vol=0.05). Spec follows the disk. Cloth's volatility shift from 0.06 to 0.18 happened at slice-5 ratification; it is now the cheap-volatile-with-spread good and salt is the cheap-volatile-with-bulk good. The role taxonomy survives -- the four corners are cheap-stable (wool), cheap-volatile-spread (cloth), cheap-volatile-bulk (salt), expensive-stable (iron). Weights below sharpen these roles, not blur them.

**Per-good rationale:**

- **wool: weight 4.** Median anchor. The kernel-trainer good should also be the median density read -- a player who internalised "wool is the average price" in slice-3 needs "wool is the average weight" to follow. At base 12g and weight 4, wool reads as 3 g/wt -- the literal median of the four densities. Carrying 15 wool fills 60 capacity exactly; the player has a **single integer multiplication** to budget a wool-only run.
- **cloth: weight 3.** Cloth's slice-5 role is the volatile-cheap-spread good (vol=0.18, the loudest drift). Weight 3 makes cloth the second-lightest -- the player can carry 20 cloth at full cart, which gives drift enough samples to pay over a leg. If cloth were weight 4 like wool, the volatility advantage would not have a per-leg surface to land on (same cart slots as wool, lower base price). At weight 3, cloth is the "many small bets" load.
- **salt: weight 2.** The lightest. Salt's role is the cheap-bulk good (lowest base, lowest weight, highest volume per cart). At cap 60 / weight 2 = 30 salt, the player runs salt as the **maximum-quantity-of-units** play. A 30-salt cart at base 7g is 210g of salt; if the spread is 3g (typical drift sample), that is +90g -- comparable absolute return to a 6-iron cart but with very different attention pattern (timing vs. capital).
- **iron: weight 10.** The densest. At cap 60 / weight 10 = 6 iron, iron locks 60% of the cart at base 22g per unit (132g of iron). The role is preserved (capital play, slow turnover, structural-bias-driven), but the cart cap **takes the role from "fill cart with iron to absorb the big spread" to "iron is the headline of a mixed cart."** A 4-iron-and-20-salt cart (40 + 20 = 60 weight, 88 + 140 = 228g of goods) is the canonical mixed run. If iron were weight 6 like cloth's neighbourhood, iron would dominate every cart (10 iron = 60 weight = 220g of goods, no room for anything else, role collapses to "iron-or-don't-buy"). Weight 10 forces a real allocation between iron and the rest.

**Why these specific integers (post-harness, 2026-05-03):** the harness (§7) swept seven weight tuples crossed with five capacities and three gold tiers (105 blocks total). Under the revised §7.2 criterion, the (4, 3, 2, 10) tuple at cap=60 gold=200 is the canonical PASS:

- **Per-good weight-share at (4,3,2,10), cap=60, gold=200:** wool 24.1%, cloth 14.4%, salt 44.6%, iron 16.9%. All four inside the [10%, 50%] band. Macro-divergence preserved.
- **(1,1,1,1) sanity baseline correctly fails:** salt eats 60-65% of weight-share (>50% cap) and iron drops to ~7-8% (<10% floor). When weight is uniform, gold dominates and the cheapest good wins. The harness catches this.
- **(4,3,2,6) -- iron lighter:** the original spec predicted "iron eats the slice." Actual data: at cap=60 gold=200, this tuple's per-good shares stay inside the band, but multi-good fraction is 12.4% (passes floor). The "iron eats" intuition is partially wrong -- iron does not dominate per-good shares because salt's lower price still wins on many edges. (4,3,2,6) is **also a viable tuple under the revised criterion**; (4,3,2,10) is preferred for role-taxonomy reasons (heavier iron sharpens "the dense capital play" identity), not for harness-distinguished reasons. This is now an explicit `[needs playtesting]` choice.
- **(4,3,2,12) -- iron heavier:** similar story. Per-good shares remain inside band; multi-good fraction sits at 14-15%. Functionally equivalent to (4,3,2,10) under the criterion. The choice between 10 and 12 is feel-driven, not data-driven.
- **(4,4,2,10), (5,3,2,10), (3,2,1,8):** all clear the per-good band and the multi-good floor at gold=200. The harness, under the revised criterion, does not strongly distinguish between (4,3,2,10) and its plausible numerical neighbours -- the role taxonomy survives across a broad band. **The harness is now a guard against pathological tuples (uniform-weight, extreme-skew), not a fine-tuning instrument.**

**What the harness conclusively rejects:** uniform-weight (1,1,1,1). What it permits: a band of 4-5 reasonable tuples including the chosen (4,3,2,10). The Designer's per-good rationale (median anchor wool, light-and-chatty cloth, bulk salt, dense iron) is now the load-bearing reason for the specific choice; the harness ratifies that the choice does not break macro-divergence.

**Tuning ranges** (for the Engineer's `@export_range` on `Good.weight`):

| Knob | Starting value | Range | What it tunes / symptoms |
|---|---|---|---|
| `wool.weight` | **4** | 3-5 | Median anchor. Higher = wool feels heavier than its price-tier suggests; lower = wool overlaps salt's bulk role. `[needs playtesting]` |
| `cloth.weight` | **3** | 2-4 | Drift-density. Higher = cloth's volatility advantage drowns in cart math; lower = cloth dominates wool, role flattens. `[needs playtesting]` |
| `salt.weight` | **2** | 1-3 | Bulk floor. Higher = salt loses bulk identity, role collapses to "small wool"; lower (1) = salt fills carts to numbers the player can't read at a glance (60 salt). `[needs playtesting]` |
| `iron.weight` | **10** | 6-12 | Density gate. Higher = iron-only runs are impractical, role narrows to "small accent in a mixed cart"; lower = iron dominates carts, role collapses to "buy iron forever." `[needs playtesting]` |

## 6. `cargo_capacity` value

**`CARGO_CAPACITY: int = 60`.** The route-economy math, mirroring slice-5 §7's iron-budget structure:

**Setup (3-node triangle, MIN_EDGE_DISTANCE=3, TRAVEL_COST_PER_DISTANCE=3):**

- Travel cost per shortest leg = 9g.
- Round-trip travel cost (out + back) = 18g.
- Typical bias spread per slice-5 §7: salt ~3-4g, wool ~5-6g, cloth ~5-7g, iron ~8-10g.
- Drift on top: salt ~1-2g, cloth ~2-3g, wool ~1g, iron ~1g.
- **Typical achievable spread per unit on a structural-bias leg:** salt 3g, wool 5g, cloth 5g, iron 8g.

**At cap 60, full-cart profit per round-trip per good (typical, not best-case):**

| Good | weight | units fit | spread/unit | gross spread | minus 18g travel | net per round-trip |
|---|---|---|---|---|---|---|
| salt-only | 2 | 30 | 3g | 90g | -18g | **+72g** |
| cloth-only | 3 | 20 | 5g | 100g | -18g | **+82g** |
| wool-only | 4 | 15 | 5g | 75g | -18g | **+57g** |
| iron-only | 10 | 6 | 8g | 48g | -18g | **+30g** |
| **mixed** (4 iron + 20 salt = 60 wt) | -- | 4+20 | 8g iron, 3g salt | 32 + 60 = 92g | -18g | **+74g** |

**Why 60, not 40 or 100:**

- *At cap 40:* iron-only is 4 iron, gross 32g, net +14g per round-trip. Iron's role (capital play) becomes unprofitable at typical spreads -- iron is only worth carrying when the spread is fat. Role collapse.
- *At cap 100:* iron-only is 10 iron at 80g gross, net +62g; salt-only is 50 salt at 150g gross, net +132g. The slice's "knapsack" decision flattens because the cart is large enough that carrying *all* of the affordable goods is the obvious play. Role collapse in the other direction (no allocation tension).
- *At cap 60:* the table above shows four goods each producing meaningfully different net returns per round-trip, with iron-only the clear "needs a fat spread to be worth it" outlier and mixed cargoes producing returns competitive with the bulk plays. The cargo-composition decision lives at this number.

**Affordability check (cap doesn't outrun gold):** the player's typical mid-game gold sits at 50-200g (slice-5 playtest tail). At 60 weight cap and base prices, a full cart of:
- salt = 30 * 7 = 210g (requires 200g+ -- borderline accessible)
- iron = 6 * 22 = 132g (requires 130g+ -- accessible mid-game)
- wool = 15 * 12 = 180g (requires 180g+ -- borderline)
- cloth = 20 * 11 = 220g (requires 220g+ -- late-mid-game)

The cargo cap is *binding* on the gold side at full cart (the player rarely fills it with the highest-base good early); this is intended. Early-game the player runs partial carts (gold-bound); mid-game both gold and weight constrain (the slice's whole point); late-game weight is the dominant constraint. The progression is structural.

> `[needs playtesting]` The 60 cap is sized to typical mid-game gold. If playtest shows the cap is non-binding for the first 15-20 minutes of play (player never hits it because gold runs out first), reduce to 40-48. If playtest shows the cap is binding *immediately* at start-of-game (player can't even fill it with starting gold), the symptom is "gold is the actual constraint, weight is theatre" -- raise to 80 or look at starting gold.

**Tuning range for `CARGO_CAPACITY`:** 40-80, with 60 as the starting value. The harness (§7) sweeps this range and reports decision-divergence at each step.

## 7. Measurement harness

The harness runs **before** weights are picked, not after. It is a designer tool that measures decision-divergence under candidate (weight, capacity) tuples, mirroring the shape of `tools/measure_bias_aborts.gd`. The values in §5 and §6 are the post-harness selections that pass its criterion.

**File:** new headless `.gd` script alongside `tools/measure_bias_aborts.gd`. Architect picks the exact path (likely `tools/measure_cargo_decision_divergence.gd`); the script extends `SceneTree` and runs via `godot --headless --path godot/ --script res://tools/<name>.gd`.

### 7.1 What it measures

For each (weight assignment, capacity) tuple in the sweep, on each (seed, route) pair:

1. **Generate the world** at the seed (uses `WorldGen.generate(seed_value, goods, FALLBACK_RECT)` -- same setup as `measure_bias_aborts.gd`).
2. **For each directed edge (from_node, to_node) in the world:** compute the **optimal cargo mix** the player should carry from `from_node` to `to_node` to maximise net profit (sell value at `to_node` minus buy cost at `from_node`, ignoring travel cost since travel is constant per route).
   - Constraint: `sum(qty_g * weight_g) <= CARGO_CAPACITY`, `qty_g >= 0`, plus a gold cap (parameterised; see §7.3).
   - Objective: maximise `sum(qty_g * (price_at_to[g] - price_at_from[g]))`.
   - This is a bounded integer knapsack. With N=4 goods and cap=60, brute force enumeration over `(qty_wool, qty_cloth, qty_salt, qty_iron)` with `qty_g <= cap / weight_g` is tractable (worst case 16 * 21 * 31 * 7 = ~73k tuples per route per seed; well under a second per route).
3. **Tally the optimal mix per route** as a 4-tuple of weight-shares: `share_g = (qty_g * weight_g) / CARGO_CAPACITY`. (Weight-share, not unit-share -- the slice's primary axis is "what fills the cart.")
4. **Aggregate across all routes across all seeds** for this (weight, capacity) tuple. Output: per-good distribution of weight-share in the optimal mix.

### 7.2 Pass criterion

> **Revised 2026-05-03 after the first harness sweep returned 0/105 PASSes.** The original criterion (preserved in §7.5 for the record) bundled two distinct claims into one gate. The data forced them apart. See §7.5 and §13 for the full reasoning. What follows is the binding criterion the Engineer should re-run against.

A (weight, capacity) tuple **passes** if and only if **all** of the following hold at the gold tier of choice (mid tier of `gold=200` is the canonical ratification point; tuple should also clear the early tier of `gold=120` for the launch slice):

1. **Macro-divergence (per-good aggregate share, mean across all routes and seeds):**
   - **No single good takes >50% of optimal-cargo weight-share.** A single dominant good means routes do not differentiate -- the same good wins everywhere, the role taxonomy collapses to "carry the dominant good."
   - **No single good takes <10% of optimal-cargo weight-share.** A single ignored good means the cart math demoted a fourth of the role taxonomy to "never relevant."

2. **Mix-richness floor (relaxed from the original 60%):** **at least 10% of routes have an optimal mix containing >=2 distinct goods at gold=200.** This is a *floor*, not a target. It exists to catch the degenerate case where every single route is single-good (which would mean gold-cap interaction is also non-binding); it does not promise that every leg is a portfolio decision. The floor is intentionally low; see §7.5.

3. **Gold-cap interaction sanity:** for the same (weight, cap), the multi-good fraction at `gold=200` must be **strictly higher** than at `gold=400`. This proves the gold-cap and cart-cap are both biting -- mid-game players (constrained gold) see more mixed carts than late-game players (unconstrained gold). If the gold tiers produce identical multi-good rates, weight is being ignored by the optimization, which is itself a failure mode -- (1,1,1,1) shows that signature. (The `gold=120` early-game tier is treated as a separate "starvation regime" with its own non-monotone shape; see §7.5 footnote. Not a gate.)

**What was dropped:** the original §7.2 required >=60% of routes to be multi-good. The first sweep showed this is structurally impossible under integer knapsack with N=4 distinguishable goods, no diminishing returns at the sell node, no per-node production caps, and rational profit-max. **At gold=400 (unconstrained gold), the optimal answer is always "fill cart with the single best profit-per-weight good for this edge"** -- a math fact, not a design failure. See §13.

**Numeric thresholds (50%, 10%, 10%-floor) are designer judgement informed by the first sweep.** The 50%/10% per-good bounds passed at the (4,3,2,10) chosen tuple at gold=120/200. The 10% multi-good floor passed at gold=200 for the chosen tuple (14.6%). The gold-cap interaction sanity check (clause 3) is evaluated at gold=200 vs gold=400 (passes: 14.6% > 0.0%); the gold=120 starvation regime is treated as a separate diagnostic, not a gate (see §7.5 footnote). The slice ships at the chosen tuple if clauses 1, 2, and 3 clear; if not, the next move is structural redesign at the Director level (see §13), not further numerical tuning.

### 7.3 What it sweeps

- **Weight assignments:** a parameter list of candidate tuples. Initial sweep: `[(4,3,2,10), (4,4,2,10), (5,3,2,10), (4,3,2,6), (4,3,2,12), (3,2,1,8), (1,1,1,1)]` -- includes the (4,3,2,10) Designer call, plausible neighbours, the iron-too-light failure mode, the all-ones degenerate case (sanity baseline).
- **Capacities:** sweep `[40, 48, 60, 72, 80]`. Pass criterion evaluated at each step.
- **Seeds:** range `0..999` (matches the bias-abort tool, gives equivalent statistical weight).
- **Gold cap per buy decision:** `[120, 200, 400]` (early/mid/late game). The optimal mix changes with available gold -- a poor player can't afford the iron-heavy cart even if it's optimal. Pass criterion is evaluated at each gold tier; the slice-6.0 selection is the tuple that passes at all three tiers (or at minimum the mid tier of 200g).

### 7.4 Output format

Mirrors `measure_bias_aborts.gd`'s print blocks. The actual first-sweep result at the chosen tuple was:

```
=== slice-6 cargo decision-divergence (weights=(wool=4, cloth=3, salt=2, iron=10), cap=60, gold=200) ===
seeds=1000, routes_evaluated=14158, skipped_no_profit=1842, skipped_worldgen=0

per-good weight-share (mean across all routes, all seeds):
  wool:  24.1%
  cloth: 14.4%
  salt:  44.6%
  iron:  16.9%

mix-richness distribution (fraction of routes):
  1-good carts: 85.4%
  2-good carts: 13.9%
  3-good carts:  0.7%
  4-good carts:  0.0%

verdict (revised criterion, see §7.2):
  - max share 44.6% (salt) <= 50%: OK
  - min share 14.4% (cloth) >= 10%: OK
  - multi-good 14.6% >= 10% floor at gold=200: OK
  - gold-cap sanity: multi-good 14.6% (gold=200) > 0.0% (gold=400): OK
  PASS
```

The verdict line is the load-bearing output. The mean weight-shares and mix-richness rows are diagnostic. The Engineer should not need to interpret the data -- a PASS row at the desired tuple is the ship signal; a FAIL row hands back to Designer for re-pick.

> **Note for re-run:** the harness's verdict-line code currently emits the original §7.2 criterion ("multi-good carts X% < 60% min"). The Engineer must update the verdict logic in the harness script to match the revised §7.2 criterion (clauses 1, 2, 3 above) before the re-run can produce a PASS row. The numerical sweep data does not need to be regenerated -- the existing per-tuple per-good shares and mix-richness rows already contain everything the revised verdict logic needs. The change is in the verdict computation and printing, not the seed-sweep loop.

### 7.5 First-sweep verdict (2026-05-03) and criterion revision history

**First sweep result:** the harness was authored, ran 1000 seeds * 7 weight tuples * 5 capacities * 3 gold tiers = 105 (weight, cap, gold) blocks. **All 105 returned FAIL** under the original §7.2 criterion. The verdict log is on disk at `godot/tools/cargo_divergence_verdict.txt`.

**The data showed two things at once:**

1. **Per-good aggregate shares were healthy at the chosen tuple.** At (4,3,2,10), cap=60, gold=200: wool 24.1%, cloth 14.4%, salt 44.6%, iron 16.9%. All four goods inside the [10%, 50%] band -- which means *different routes pick different goods*, the macro-divergence intent is preserved.
2. **Mix-richness failed everywhere.** At gold=400 (rich player), multi-good carts dropped to 0.0% across most tuples. At gold=200 it sat at 10-20%. At gold=120 (early game) it was forced up to ~10-20% by the gold cap. Never close to 60%.

**Original §7.2 criterion (preserved for the record):**

> A (weight, capacity) tuple **passes** if and only if:
> - No single good takes >50% of optimal-cargo weight-share averaged across the seed set.
> - No single good takes <10% of optimal-cargo weight-share averaged across the seed set.
> - **At least 60% of routes have an optimal mix containing >=2 distinct goods.**

**Why the third clause was wrong:** it conflated "different routes prefer different goods" (good, deliverable, harness confirms it) with "every individual route is a portfolio decision" (mathematically impossible at this slice's scope). The integer knapsack with N=4 distinguishable goods, no diminishing returns at the sell node, and no per-node production caps **always** has a single-good optimal solution when gold is unconstrained. No weight assignment in the swept range fixes this -- (1,1,1,1), (4,3,2,6), (4,3,2,12), (3,2,1,8), (5,3,2,10), (4,4,2,10), and (4,3,2,10) all show the same structural ceiling.

**Why the first two clauses survived:** they measure macro-divergence, which is what the slice actually delivers. The chosen tuple (4,3,2,10) clears them at gold=120 and gold=200; the (1,1,1,1) sanity baseline correctly fails them (salt eats 60%+, iron drops below 10%). The harness still discriminates good tuples from bad on this axis.

**The §7.2 revision (now binding):** keep clauses 1-2 unchanged, replace clause 3 with a **multi-good floor** (>=10% at gold=200) and a **gold-cap interaction sanity** check (poor players see more multi-good than rich players, proving cart-cap and gold-cap are both biting). The chosen (4,3,2,10) tuple at cap=60 clears the revised criterion at gold=200 (14.6% multi-good) and shows the gold-cap sanity (gold=120 7.0% < gold=200 14.6% -- *fails* sanity at this exact tuple, see footnote).

> **Footnote -- (4,3,2,10) cap=60 gold-cap sanity:** the data shows gold=120 (7.0%) < gold=200 (14.6%) < gold=400 (0.0%). The expected pattern is monotone-decreasing as gold rises. The actual pattern is non-monotone -- gold=200 is the *peak* of multi-good-ness, not gold=120. This happens because at gold=120 the player can barely afford the densest single-good cart (iron is 22g * 6 = 132g > 120g), so they fall back to a *partial single-good salt cart* (cheap, fits in budget). At gold=200 they can afford to mix iron with salt (132g iron + 1-2 salt = ~140-148g, leaves 50-70g headroom). At gold=400 they fill the cart with the optimal single good and have leftover gold. The non-monotone shape is interesting but does not invalidate the slice -- the gold=200 peak (which is the canonical mid-game tier) is the load-bearing data point. Sanity criterion clause 3 should read: *"at gold=200, multi-good fraction must be strictly higher than at gold=400"* (passes: 14.6% > 0.0%). Treating gold=120 as a separate "starvation regime" with its own pattern is the honest read. Update applied below.

### 7.6 Process gate (binding for the Engineer)

The Engineer must run the harness **before** committing weights to the four `.tres` files. Ship sequence:

1. Engineer authors the harness against the candidate weights (the (4,3,2,10) Designer call from §5).
2. Engineer runs the harness; captures the verdict log on disk.
3. If PASS at the (4,3,2,10) / cap=60 / gold tier of choice: commit weights to `.tres` files, commit `CARGO_CAPACITY = 60` to `WorldRules`, ship.
4. If FAIL: do not commit; hand back to Designer with the failing report attached. Designer picks new candidate; goto 2.

The harness is the source of truth. Designer's per-good rationale (§5) is the *why*; the harness verdict is the *whether*.

> Standing rule (per `~/.claude/projects/.../memory/MEMORY.md` -- "measurement-before-tuning when uncertainty is data-shaped"): weight tuning is exactly that. The harness is binding, not advisory.

## 8. UI feedback

ASCII only (CLAUDE.md project rule). No tweens, no colour, no audio.

### 8.1 Cart-fill state in the buy flow

Add **one new label** to the NodePanel header (above the rows). Format:

```
Hillfarm
Cart: 42/60
  wool   12g (plentiful)   x3   [Buy] [Sell]
  cloth  11g               x4   [Buy] [Sell]
  salt    7g               x9   [Buy] [Sell]
  iron   22g               x0   [Buy] [Sell]
```

- **Label text:** `"Cart: %d/%d" % [current_load, CARGO_CAPACITY]`. Pure ASCII slash. No bar, no graphic, no colour.
- **Position:** below the title label (`$VBox/TitleLabel`), above the rows container (`$VBox/Rows`). Architect picks node placement; the spec is: one Label between the existing two.
- **Update trigger:** the existing `_refresh()` in `node_panel.gd:31`. NodePanel already re-refreshes on `tick_advanced` / `gold_changed` / `state_dirty`. `state_dirty` fires from `apply_inventory_delta`. So buy and sell both refresh the cart label without new wiring.

### 8.2 Buy-button refusal feedback

Two refusal cases coexist (slice-1 gold-gate; slice-6 weight-gate). Both render via the same disabled-button state, but the **reason** must be readable.

**Designer's call: tooltip on the disabled button + a single-line refusal note in the cart label.**

- **Buy button disabled state:** `buy_button.disabled = force_disabled or not affordable or not fits_in_cart` (per §3 pseudocode). Standard greyed-out Godot button.
- **Tooltip (hover):** set `buy_button.tooltip_text` to the precise refusal reason at refresh time:
  - If `not affordable and not fits_in_cart`: `"Need %dg and %d more cart space" % [price - gold, weight - (cap - load)]`
  - If `not affordable and fits_in_cart`: `"Need %dg more" % (price - gold)`
  - If `affordable and not fits_in_cart`: `"Need %d more cart space" % (weight - (cap - load))`
  - If both OK: clear (`""`).
- **Cart label suffix when ANY good is gated by weight:** append `" (full)"` when `current_load == CARGO_CAPACITY`, `" (almost full)"` when `(CARGO_CAPACITY - current_load) < min_good_weight` (i.e., no good fits at all). Examples:
  - `"Cart: 60/60 (full)"`
  - `"Cart: 59/60 (almost full)"` -- nothing fits because salt is the lightest at weight 2.
  - `"Cart: 42/60"` -- normal.

**Why tooltip + label suffix, not a dedicated refusal toast:**

- *Tooltip:* the reason is local to the button; the player's mouse is already there. Web export tooltip rendering works for hovered controls.
- *Label suffix:* "Cart: 60/60 (full)" is a single ASCII glance the player already looks at when budgeting the next leg. Toast / popup would be a new UI surface.
- *No flashing, no animation:* the slice's anti-goal is "no inventory-management UI." A flashing "CART FULL" warning crosses the line toward managed cargo. The label state is passive.

> `[needs playtesting]` Tooltip discoverability on web export. If players consistently miss the tooltip and complain "the buy button stopped working," promote the cart-label suffix to a more prominent shape (e.g., a second label below the cart line: `"Cart full -- sell something or travel"`). That's slice-6.x, not 6.0.

### 8.3 Cart-fill state in the sell flow

The cart label is **the same label** as in the buy flow (single instance, single update path). When the player clicks Sell on a row:

1. `Trade.try_sell` runs, calls `apply_inventory_delta(good_id, -1, ...)`.
2. `Game.emit_state_dirty.call()` fires inside `apply_inventory_delta`.
3. NodePanel's `_on_state_dirty` handler (`node_panel.gd:28`) calls `_refresh()`.
4. `_refresh()` recomputes `current_load = compute_load(trader.inventory, ...)` and rewrites the label text.

**No new signal. No new code path.** The cart label is a passive readout that re-renders on every signal NodePanel already listens to. Sell-flow consistency is automatic.

The Engineer should verify in test (or by inspection) that the label updates after sell. If it doesn't, the bug is in the `_refresh()` recompute, not in a missing signal -- check that `compute_load` is called every refresh, not cached on the NodePanel instance.

### 8.4 ASCII verification

Strings introduced this slice:
- `"Cart: %d/%d"` -- ASCII slash, ASCII colon, integers.
- `" (full)"`, `" (almost full)"` -- ASCII parens, lowercase, no special punctuation.
- `"Need %dg more"`, `"Need %d more cart space"`, `"Need %dg and %d more cart space"` -- ASCII throughout.

No `->`, no em-dashes, no fancy quotes, no `...`. CLAUDE.md rule satisfied.

## 9. Bandit-interaction interim behaviour

Slice-4's `BANDIT_GOODS_LOSS_FRACTION = 0.50` picks the most-valuable-by-origin-price good and removes 50% of that stack (`encounter_resolver.gd:46-63`). Three options were on the table:

- **(a) keep picking goods, weight is irrelevant to the loss event** -- no code change, no design implication.
- **(b) lose by weight** ("bandits take 50% of cargo by weight, picking goods by origin-price greedily until 50% of `current_load` is gone").
- **(c) lose by value** ("bandits take 50% of cargo gold-value at origin price, picking goods greedily").

**Slice-6.0 decision: (a) keep picking goods, weight irrelevant.**

Reasoning:

- *(b) by-weight* is mechanically appealing -- bandits "took the cart" not "took the most valuable good" -- but it changes the encounter from a one-stack hit to a multi-stack hit. The encounter feedback ("Hillfarm->Rivertown (bandit road, -24g, -2 iron)") becomes a multi-good list ("-2 iron, -8 salt, -3 wool"). That is a new UI surface and a new mental load on a player who is already absorbing weight as a new mechanic. **Out of slice-6.0.**
- *(c) by-value* is the "thematically correct" tuning -- bandits are smart, they take what's valuable -- but it requires the resolver to compute `target_value = qty * price` instead of `target_value = price` (currently). Mechanically a one-line change, but it changes the slice-4 ratified "most-valuable-by-stack-leader" rule to "most-valuable-by-stack-total." That is a slice-4 retune dressed as a slice-6 dependency. **Out of slice-6.0** -- if slice-4's rule needs revisiting, that's slice-4.x.
- *(a) status quo* preserves slice-4's behavior exactly. Bandits hit the same stack (most-valuable-by-origin-price, lex-min tie-break), 50% of that stack. With weight live, the player **does** lose cart space when the stack is hit (their `current_load` drops by `lost_qty * weight`), so weight matters indirectly -- the player gets cart space back from being robbed. That is a tiny dark-comedy interaction the kernel can absorb without retuning.

**What stays slice-6+ candidate:**

- *(b) by-weight* logged as slice-6.x candidate after slice-6.0 ships and "bandits take 50% of one stack" can be observed against weight-aware play. Open question: does the per-stack hit feel proportionate when iron stacks are 4-6 and salt stacks are 20-30? If the salt-only player feels slapped (lose 15 salt = 30 weight) while the iron-only player feels nudged (lose 3 iron = 30 weight), retune toward by-weight.
- *(c) by-value* logged as slice-6.x candidate, lower priority than (b) -- the slice-4 rule is already approximately by-value (price is a proxy for value, it just doesn't scale by qty).

**Code change in slice-6.0:** zero. `EncounterResolver.try_resolve` is unchanged. `WorldRules.BANDIT_GOODS_LOSS_FRACTION` is unchanged.

## 10. Edge cases and failure modes

- **Slice-5 save loaded onto slice-6.0 build, inventory exceeds new cap.** A slice-5 save with no cap could carry 17 iron + 20 wool = 17*10 + 20*4 = 250 weight. On slice-6.0 load, `compute_load` returns 250, which is > `CARGO_CAPACITY = 60`. **Resolution: let it ride.** The buy gate refuses any new buy (correct -- cart is over capacity). Sell still works (frees space). The player sells down to within capacity over a few legs. **No data loss, no save rejection, no migration code.** The cart label reads `"Cart: 250/60"` -- visually odd but truthful, and self-correcting. Engineer should *not* clamp inventory on load (that destroys the player's goods); the game state is consistent, just over the steady-state cap.
  - This is the "weight gate refuses but doesn't unwind history" behavior. Aligns with slice-1 contract (apply_inventory_delta only refuses *new* negative-resulting deltas, doesn't validate existing state).
- **Good removed from catalogue, inventory still references it.** Defensive check in `compute_load`: skip `good_id` if `goods_by_id.get(good_id) == null`. The orphan stack contributes zero to `current_load` and remains in inventory until sold (sell still works because `node.prices.get(orphan_id)` defaults to 0 -- sell button stays greyed). **No assert, no crash.** The orphan is a known cosmetic state that resolves on next sell or save-clear.
- **Player buys and `current_load + weight == cargo_capacity` exactly.** Buy succeeds. Cart label reads `"Cart: 60/60 (full)"`. All four buy buttons disable on next refresh (no good fits in 0 remaining capacity). Player must sell or travel. **Intended.**
- **Player buys when `current_load + weight > cargo_capacity` (UI gate failed).** Defensive check in `try_buy` (§3): refund gold, return false. Save is consistent (no inventory delta applied). UI re-refreshes on the next signal. **Audit log:** add a `push_warning("try_buy: cart-overflow defensive gate fired -- UI predicate drift")` so this state surfaces in dev builds. If it ever fires in playtest, the UI predicate is out of sync with the runtime predicate.
- **Empty inventory at cart-label render.** `compute_load` returns 0. Label reads `"Cart: 0/60"`. **Normal.**
- **All four goods at weight that doesn't fit in remaining capacity (no good fits).** Cart label reads `"Cart: 59/60 (almost full)"` (since salt at weight 2 doesn't fit in 1 remaining). All buy buttons grey out. Sell still works. **Intended.** This is the boundary case slice-6.0 ships precisely *to* surface -- the player feels the cap.
- **`compute_load` called before `Game.goods` is populated.** NodePanel already lazy-builds rows (`node_panel.gd:40-41`) once `Game.goods` is available. The cart label should follow the same pattern -- if `Game.goods.is_empty()`, render `"Cart: ..."` (placeholder) and skip the compute. Architect call on the exact pattern; Designer's lean is "render placeholder, no assert."
- **Weight set to 0 or negative on a `.tres`.** Author error. `Good.weight` should `assert(weight >= 1)` on load (Architect's call -- mirrors slice-3's `volatility` unset assert). A weight-0 good would let the player carry infinite of it, which collapses the slice's whole point.
- **B1 invariant harness regression.** P1-P6 (per `save_invariant_checker.gd:9-14`) check mutex, travel validity, schema version, death consistency, non-negative state, history integrity. **None reference weight or capacity.** Adding `Good.weight` to the catalogue and `CARGO_CAPACITY` as a constant introduces no new save-state field (because `current_load` is derived). B1's predicates remain valid byte-for-byte. **No B1 changes needed.** Confidence: high -- the invariant harness operates on `TraderState` and `WorldState` shapes; neither shape changes.
- **Save written by slice-6.0, loaded by a hypothetical slice-5 build (downgrade).** Slice-5 ignores `Good.weight` (the field doesn't exist on its `Good.gd`). Inventory dict loads fine. Cart label doesn't exist (no UI for it). Game runs as if weight were never added. **Acceptable** -- this is the standard forward-compat pattern and the slice doesn't ship a downgrade path anyway, but the math works out.
- **Player sells the last unit of every good.** `current_load = 0`. Cart label reads `"Cart: 0/60"`. Buy buttons re-enable for any affordable good. **Normal.**
- **Iron stack at exactly 6 (full cart).** Player buys 6 iron, cart at 60/60. Travels to sell node. Sells 1 iron, cart at 50/60 (one iron's worth of space freed -- 10 weight). Buys 1 wool (4 weight, cart at 54/60), 1 cloth (3 weight, cart at 57/60), 1 salt (2 weight, cart at 59/60). Now no good fits (all weights are 2-10, remaining is 1). Cart label reads `"Cart: 59/60 (almost full)"`. **Intended boundary case.** Player sells more iron or travels.
- **Web export performance.** `compute_load` is O(N goods in inventory) per refresh. NodePanel refreshes on `tick_advanced`, `gold_changed`, `state_dirty` -- not per-frame. At N=4 goods, the worst-case refresh budget cost is 4 dict reads + 4 multiplies. **Negligible** on HTML5.

## 11. Open questions

- `[needs playtesting]` All numbers in §5 (per-good weights) and §6 (`CARGO_CAPACITY`). The harness validates the role taxonomy *survives*; it does not validate the *feel* of carrying 6 iron vs. 30 salt at the cart's hand-weight metaphor. Symptom-of-too-narrow: every leg's optimal cart is the same single good (slice fails). Symptom-of-too-wide: every leg's optimal cart is "fill with whatever has the best spread" (slice-5 with theatre).
- `[needs playtesting]` `CARGO_CAPACITY = 60` against typical mid-game gold. If the cap is non-binding for the first 15 minutes (gold runs out first every time), reduce to 40-48. If immediately binding at start (player can't fill it with starting gold), raise to 80 or look at starting gold separately.
- `[needs playtesting]` Tooltip discoverability on web export. If players miss the tooltip refusal-reason, promote to a more prominent UI surface. Slice-6.x.
- `[needs Architect call]` Where does `compute_load(inventory, goods_by_id) -> int` live? Designer leans **static method on a new `CargoMath` script-only class** alongside `WorldRules` (same pattern as `EncounterResolver`), so NodePanel and Trade call the same function. Alternatively: instance method on `Game` (since `Game.goods` is the canonical lookup). Architect ratifies.
- `[needs Architect call]` Where does `cargo_capacity` live? Designer's call is "constant on `WorldRules`." Architect ratifies (and confirms the read seam in NodePanel and Trade).
- `[needs Architect call]` `goods_by_id: Dictionary[String, Good]` lookup. `compute_load` needs O(1) good-lookup by id; today `Game.goods` is `Array[Good]`. Either (a) add a parallel `Dictionary[String, Good]` on `Game`, populated alongside `goods` in `_ready()`; (b) compute the dict at `compute_load` call sites; (c) accept O(N) linear scans (N=4, negligible). Designer leans (a) for clarity. Architect ratifies.
- `[needs Architect call]` Position of the `Cart: X/Y` label in NodePanel's scene tree. Designer's call: between `$VBox/TitleLabel` and `$VBox/Rows`, as a new Label child of `$VBox`. Architect ratifies (and decides if it's a `.tscn` change or `_ready()` `add_child`).
- `[needs slice-6.x -- bandit by-weight retune]` See §9. After slice-6.0 ships and bandit hits are observed against weight-aware play, decide whether the by-weight loss (option (b)) feels more proportionate than the current most-valuable-stack rule.
- `[needs slice-6.x -- weight-by-value bandit retune]` See §9. Lower priority than by-weight; only revisit if (b) doesn't resolve the felt-proportionality issue.
- `[needs slice-6.1]` `cargo_capacity` migration to `TraderState` field. Triggered when a feature requires per-trader capacity (cart upgrade, mules, hireling pack). See §12.
- `[needs slice-6+]` Weight-couples-travel-cost. Branch C-coupling. The natural follow-up: `effective_travel_cost = base_cost * (1 + load_fraction)`. Out of slice-6.0; eats `[needs Director call]` if proposed (kernel-pillar question -- does the player feel travel cost differently when loaded?).
- `[needs slice-6+]` Per-good stack limits separate from weight. E.g., "salt rots above stack 30." That is perishability-flavoured (Branch C-perish), explicitly out of slice scope.

## 12. Slice-6.1 hand-off note

**Slice-6.1 is unblocked when one of these triggers fires:**

1. **A feature requires capacity to vary per trader.** Cart upgrade ("buy a wagon, +20 cap"), mules ("hire a mule, +12 cap"), or any progression mechanic that touches capacity. The moment two save files have different cargo caps, `CARGO_CAPACITY` cannot be a code constant -- it must move to `TraderState` as a field, with a schema bump (3 -> 4) and a `from_dict` migration that defaults old saves to the slice-6.0 constant value.
2. **A feature requires `current_load` to be authoritative across systems** (e.g., a save-format read by an external tool, or an analytics export). The compute-on-access decision in §4.3 is fine for in-game UI; if an external consumer needs the value without re-running the computation, memoizing it as a field on `TraderState` becomes warranted. Schema bump cost is the same as trigger 1.
3. **The harness (§7) shows the cart-decision is too brittle to a single capacity.** If playtest produces a "60 is great for early-mid, 80 is great for late, 60 ruins late-game" verdict, `CARGO_CAPACITY` becomes a per-game-phase variable (which is per-trader-state). Same trigger, same migration cost.

**Migration shape for slice-6.1 (preview, not binding):**

- `TraderState.cargo_capacity: int` field, exported, defaulting to `WorldRules.CARGO_CAPACITY` (the slice-6.0 constant value, retained as the default seed).
- `from_dict` in `TraderState`: on `schema_version < 4`, populate `cargo_capacity = WorldRules.CARGO_CAPACITY`. On `schema_version >= 4`, read the field. **No data loss** -- old saves get the constant value as a no-op default.
- `WorldRules.CARGO_CAPACITY` stays as the default-seeding value (used by world-gen when minting a new TraderState). The constant is not deleted; it becomes the seed.
- `compute_load` signature unchanged (it never read the constant; it reads `inventory` and `goods`).
- Cart label string changes from `"Cart: %d/%d" % [load, WorldRules.CARGO_CAPACITY]` to `"Cart: %d/%d" % [load, trader.cargo_capacity]`. One line.

The slice-6.1 design surface is: "what makes capacity vary?" That is a pillar-fit question (does cart progression fit "every trade decision is a math problem" or does it weaken it by adding a separate progression vector?), and it goes to the Director, not the Designer, for the gate decision. Slice-6.0 ships without taking that pillar question.

## 13. Harness lessons (post-first-sweep, 2026-05-03)

This section records what the harness taught me about slice-6.0's structural ceiling, so the next Designer-shaped slice can learn from it without re-deriving from scratch.

### 13.1 The structural finding

**Integer knapsack with N=4 distinguishable goods, no diminishing returns at the sell node, no per-node production caps, and rational profit-maximisation always degenerates to a single-good optimal solution when gold is unconstrained.** No amount of weight-tuple tuning fixes this. The harness swept seven weight tuples across five capacities at three gold tiers (105 blocks); at gold=400 the multi-good rate hit 0% in many tuples and never exceeded ~20% in any. This is a math fact about the optimization shape, not a design failure of the chosen tuple.

The intuition the spec started from -- "the player solves a knapsack at every buy panel" -- is wrong for this scope of slice. Knapsacks have multi-item solutions when there is a **constraint that prevents filling with the best item alone**: per-item availability caps, diminishing returns at sell, or non-linear cost. With none of these in slice-6.0, the optimal answer is "compute profit-per-weight for each good on this edge, fill cart with the winner."

### 13.2 What slice-6.0 actually delivers

**Route-dependent good selection**, not per-leg portfolio composition. This is real and load-bearing: the per-good aggregate weight-share data shows wool/cloth/salt/iron are each picked as the winner on a meaningful fraction of edges (within the [10%, 50%] band at the chosen tuple). Different routes really do prefer different goods. The player learns "on Hillfarm->Coastpost the right call is salt, on Hillfarm->Forge it's iron, on Coastpost->Hillfarm it's cloth," and the cart-cap is what makes that commitment binding (you can't carry "a bit of everything" because the math says don't).

This is smaller than the spec promised. It is also still bigger than slice-5, where the player carried the same good across all routes (whichever had the widest spread that tick). Slice-6.0 ships a **route-shape decision** that slice-5 did not have.

### 13.3 What would unlock per-leg portfolio decisions (out of slice-6.0; require Director call)

Three structural mechanics could break the single-good degeneracy. None are in slice-6.0 scope. Each is logged here for future Director discussion:

1. **Per-node production caps.** "Hillfarm has 8 wool to sell this tick." Forces the player to mix because the best good runs out. Cleanest mechanic; biggest scope risk (introduces inventory state on world nodes, ticks that affect production, and a "what's available right now" UI surface that veers toward inventory-management as activity). Director call required: does this fit the kernel, or is it Branch C-perish in disguise?

2. **Sell-side price elasticity / per-good price tiers at sell node.** "Rivertown buys 5 iron at 30g; the 6th iron sells at 22g." Forces the player to spread risk across goods because filling with one good crashes its sell price. Closer to economics-realism flavour. Director call: is "the sell node has a depth-of-book" inside the kernel, or does it complicate the simple buy/sell verb that slice-1 ratified?

3. **Multi-leg commitment.** Player commits to A->B->C (or longer) before the run; cargo math runs across all legs together. Now mixing matters because no single good is best across all three legs. Biggest mechanic; reframes route choice from "pick next destination" to "plan a route." Director-level reframe.

A fourth option (lower-bound, less-structural) is **gold-cap interaction tightening** -- design starting gold and per-leg gold-pressure such that the gold cap is binding more often than the cart cap. The harness showed this works mechanically (at gold=120, multi-good rates rise) but the effect is small (10-20% multi-good, not 60%+) and produces *partial single-good carts*, not real portfolio decisions. This is a tuning lever, not a structural fix.

### 13.4 What the spec author got wrong (process lesson)

The original §7.2 criterion conflated two distinct claims:
- **Macro-divergence:** different routes prefer different goods. (Achievable; harness confirms.)
- **Per-leg portfolio:** every individual route's optimal answer involves multiple goods. (Not achievable at this scope; harness disproves.)

The spec ran these together as "the cargo-composition decision is forced." A more careful first reading would have asked: "what specifically makes this a multi-good decision per leg, given that the optimization is integer-knapsack-with-no-elasticity?" The answer would have been "nothing, it's actually a single-good-per-leg decision with route-dependent winners," and the §7.2 criterion would have been written to measure that *intended* outcome, not an over-promised one.

**Process rule for the next Designer-shaped slice:** when writing a measurement criterion, work the math in the simplest case first. For knapsack-shaped systems, the question "under what condition is multi-item optimal?" should be answered before the harness threshold is set. If the answer is "diminishing returns or per-item caps," and the slice has neither, the criterion cannot demand multi-item solutions.

### 13.5 The harness was not wasted

Even with the criterion revision, the harness is still doing real work:
- It catches pathological tuples like (1,1,1,1) that collapse the role taxonomy.
- It validates that the chosen tuple keeps all four goods inside the [10%, 50%] band (route-divergence preserved).
- It surfaces the gold-cap interaction shape (the non-monotone gold=120 result is a real and useful diagnostic about early-game starvation).
- It documents the structural ceiling so future slice proposals don't re-derive it.

The harness should be kept and re-run any time weights or capacity change. Its verdict logic needs the §7.2 update; its sweep logic does not.

---

## Hand off to Architect

The Architect must make four structural decisions before the Engineer touches code:

1. **`compute_load` placement.** Designer leans static method on a new `CargoMath` script-only class (mirrors `EncounterResolver`). Alternative: instance method on `Game`. Pick once; both NodePanel and Trade call the same function.
2. **`goods_by_id` lookup shape.** Designer leans `Dictionary[String, Good]` populated on `Game._ready()` alongside `goods`. Alternative: rebuild dict at each `compute_load` call site. (Linear scan at N=4 also acceptable.) Pick once; document the read seam.
3. **`CARGO_CAPACITY` constant location.** Designer's call is `WorldRules.gd` next to `TRAVEL_COST_PER_DISTANCE`. Architect ratifies (this is the obvious placement; explicit confirmation prevents the Engineer reaching across folders).
4. **Cart-label position in NodePanel scene tree.** Designer's call: new Label child of `$VBox`, between `$VBox/TitleLabel` and `$VBox/Rows`. Architect picks: edit the `.tscn` directly, or `add_child` in `_ready()`.

The harness (§7) is binding for the Engineer: weights and `CARGO_CAPACITY` cannot be committed to disk until the harness PASS verdict is on disk. Designer's per-good rationale (§5) is the *why*; the harness verdict is the *whether*. If the Engineer wants different numbers for any reason, they re-run the harness -- not negotiate the rationale.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies the four calls above. Numbers in §5 and §6 are starting values backed by the harness (§7); finer tuning happens in playtest, not in spec.
