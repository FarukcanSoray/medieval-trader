# Medieval Trader -- Slice 8 (Pricing v2: Two-Sided Pool Curve) Spec

> **Ratified frame (2026-05-04):** Director scoped slice-8 to replace the slice-3
> random-walk-around-bias-anchor pricing with a two-sided pool curve. Each
> (node, good) carries a **supply pool** (units the player can buy from) and a
> **demand pool** (units of unmet local demand the player can sell into). Prices
> are pure functions of pool fill state plus a deterministic ±5% perturbation.
> Critic stress-tested and locked the 9-item scope under one slice. Branch:
> cargo retune deferred to slice-8.5; sell-side stock saturation and per-good
> rot remain out of scope from slice-7's named-deferrals list.
>
> **New pillar (replaces slice-7's "world has memory of trader actions"):**
> *"The world's economic state is the game's primary texture. Stock and demand
> at every node remember what happened, and prices are the player's window into
> that memory."* The slice-7 pillar is subsumed -- world memory was the
> precondition; slice-8 is what makes that memory legible at the price label.
>
> **Schema bump v5 -> v6 trigger (named, per `2026-05-02-slice-2-no-schema-bump-trigger-named` precedent):** *"per-(node, good) demand pool state added to NodeState; semantic reinterpretation of `prices` (now derived from pool state, no longer drift state)."* Both clauses fire -- new required dicts on `NodeState`, plus the live save's `prices` dict either becomes ignored on load or is dropped from the schema entirely (Architect's structural call -- §3).
>
> **Sacred (do not relitigate):** produces/consumes tags as concept; floor/ceiling clamps; the measurement-harness habit; pull-driven price-from-state determinism contract (`2026-04-29-deterministic-price-drift`); slice-7's "world has memory" semantics. **Negotiable in playtest:** target multipliers, decay rates, the 5x supply-cap bump's exact factor, perturbation magnitude.

## 1. Pattern reference

This is **Patrician III's town demand pools** crossed with **Capitalism Lab's elastic-demand curves**. Patrician's cities had per-good demand reservoirs that the player drained by selling and that recovered by population consumption; prices were a function of how full the reservoir was relative to its target. Capitalism's price elasticity formula -- `price = base * (target / current)` family -- gave a clean inverse-fill response that scales naturally across goods of different base prices. Slice-8 is the union: Patrician's *two-pool* shape (separate buy-from and sell-into reservoirs) with Capitalism's *target-relative* price curve. We deviate in three places: (1) no production chain backs the supply pool -- it's a pure stockpile authored by tag, exactly as slice-7 already does; (2) demand pool is symmetric to supply pool (same shape, inverse target table), not a separate population-consumption simulation; (3) we add ±5% deterministic perturbation on top so two visits at the same pool state aren't byte-identical -- the perturbation is the legibility of "the world is alive," not a randomization of the read. Closest exact ancestor for the *two-sided* part is OTC trading desks: bid/ask spread driven by inventory imbalance.

## 2. Core loop change

**Before slice-8 (current state):** the player walks into Hillfarm and sees `wool 12g (plentiful)`. The price drifted there from a per-(node, good) bias anchor under a random-walk plus mean-reversion (slice-3 §5.4). Buying drains slice-7's supply pool but does **not** affect the price. Selling 30 wool at Rivertown gets the same `wool 18g` price whether the player is the first trader of the session or the tenth. The price is a **read of structural identity** (bias) plus **transient noise** (volatility); it is not a read of *what the player just did*. Trader actions mutate stock memory but not price memory.

**After slice-8:** the player walks into Hillfarm. Wool's supply pool is at 80/80 (full -- no one has bought today). Buy price = `12 * (1 + (80 - 80)/80) = 12g`. Times 1.03 perturbation = `12g`. The player buys 60 wool (slice-6 cargo cap); supply pool drops to 20/80. Buy price now = `12 * (1 + (80 - 20)/80) = 21g`. Times 0.97 perturbation = `20g`. **The price at Hillfarm just rose because the player bought.** They travel to Rivertown. Rivertown's wool demand pool is at 18/20 (mostly unmet -- locals want wool, no one has been). Sell price = `12 * (1 + (18 - 0)/20) = 22g` times 1.04 = `23g`. They sell 60 wool; demand pool drops to 0/20 (saturated -- no more demand). Sell price collapses: `12 * (1 + 0/20) = 12g`. Returning to Rivertown the next tick is a wasted leg until demand pool decays back upward toward target. **The world's economic state is the texture the player reads at every visit.**

The kernel is unchanged -- arbitrage profit perpendicular to travel cost -- but spread is now **pool-driven**, not drift-driven. The player who reads `wool 21g (plentiful) [20 left]` knows three things at once: stock is low (slice-7 memory), prices have moved because of recent activity (slice-8 memory), and the (plentiful) tag still tells them this is a producer node where the supply pool is *authored* deep but currently *drained*. Re-visiting too soon is no longer just a stock punishment; it is also a **price punishment** -- the supply pool hasn't refilled enough to bring the buy price back down. Rotating routes is now structurally rewarded by the price itself.

## 3. Save format diff (v5 -> v6)

**Schema bump trigger (named):** *"per-(node, good) demand pool state added to NodeState; semantic reinterpretation of `prices` (now derived from pool state, no longer drift state)."* Both clauses of `2026-05-02-slice-2-followup-schema-bump-semantic-reinterpretation` fire.

### 3.1 New fields on `NodeState`

Adds three parallel dicts mirroring slice-7's supply-pool shape:

```
@export var demand_pools: Dictionary[String, int]              // NEW: current unmet demand
@export var demand_caps: Dictionary[String, int]               // NEW: max demand pool (= demand target)
@export var demand_decay_accumulators: Dictionary[String, float]  // NEW: fractional decay carry between ticks
```

**Naming rationale:** `demand_pools` parallels slice-7's `stocks`; `demand_caps` parallels `stock_caps` and serves dual duty as both the cap and the decay target (decay drives toward cap, just as supply refill does). `demand_decay_accumulators` parallels `refill_accumulators`. **No new `demand_decay_rates` dict** -- decay rate is derived at world-gen from `Good.base_demand_decay_rate * tag_multiplier` (mirrors slice-7's `refill_rates` derivation), and per the `2026-05-03-slice-7-caps-rates-frozen-at-gen-time` precedent, the derived rate must be persisted. So actually four new dicts:

```
@export var demand_pools: Dictionary[String, int]
@export var demand_caps: Dictionary[String, int]
@export var demand_decay_rates: Dictionary[String, float]
@export var demand_decay_accumulators: Dictionary[String, float]
```

This keeps perfect symmetry with the existing four supply dicts (`stocks`, `stock_caps`, `refill_rates`, `refill_accumulators`).

### 3.2 Renaming `stock_caps` to `supply_caps` -- DEFERRED

Naming asymmetry will exist on `NodeState`: `stock_caps` (slice-7 name) on the supply side, `demand_caps` (new) on the demand side. **Deferring the rename to a slice-8.x cleanup**. Reasoning: a rename would touch every file that reads slice-7's stock dicts (`world_state.gd`, `world_gen.gd`, `node_state.gd`, `node_panel.gd`, `trade.gd`, the migration helper, the harness) for zero behaviour change. Architect may rename if it is genuinely cheap; otherwise the asymmetry is documentation cost only.

### 3.3 `prices` field disposition -- ARCHITECT CALL

Two options for the existing `NodeState.prices: Dictionary[String, int]`:

- **(a) Drop entirely.** Price is pull-driven -- a pure function of pool state, perturbation seed, and `Good.base_price`. No need to store. Save shrinks. `from_dict` ignores any `prices` key in v5 saves; v6 saves omit the key entirely.
- **(b) Keep as a per-tick cache.** Recompute on every tick advance and on every buy/sell. Save still carries it. UI reads `node.prices` directly without going through a price helper.

**Designer leans (a) drop.** Reasoning: pool state is already authoritative; storing prices is redundant state that introduces a new save-vs-runtime drift class (price stored, then formula tuned, save loads with stale prices). Architect ratifies in §9.

### 3.4 `to_dict` / `from_dict` changes

`NodeState.to_dict` gains the four `demand_*` dicts. If §3.3(a) is picked, drops `prices`. Wire format:

```
{
    "id": ...,
    "name": ...,
    "pos": [...],
    "bias": {...},                    // unchanged (slice-3 -- still drives produces/consumes derivation)
    "produces": [...],                // unchanged
    "consumes": [...],                // unchanged
    "stocks": {...},                  // slice-7 (supply pool current)
    "stock_caps": {...},              // slice-7 (supply pool target)
    "refill_rates": {...},            // slice-7
    "refill_accumulators": {...},     // slice-7
    "demand_pools": {"wool": 18, "cloth": 0, ...},                 // NEW
    "demand_caps": {"wool": 20, "cloth": 5, ...},                  // NEW
    "demand_decay_rates": {"wool": 0.2, "cloth": 0.04, ...},       // NEW
    "demand_decay_accumulators": {"wool": 0.0, "cloth": 0.6, ...}, // NEW
    // "prices": dropped per §3.3(a). v5 saves carrying this key are accepted with the key ignored.
}
```

### 3.5 Schema bump

`WorldState.SCHEMA_VERSION` advances 5 -> 6. `from_dict` migration policy mirrors slice-7: accept v5 or v6, route v5 through `_migrate_v5_to_v6`, reject anything else.

### 3.6 Migration spec, v5 -> v6

Per node in the loaded v5 dict:

1. Read `produces` and `consumes` (already present from slice-3).
2. For each good in the live `Game.goods` catalogue (mirror slice-7 §5.4):
   - Compute `demand_cap = roundi(good.base_demand_cap * demand_target_multiplier(node, good))` per §5.7's table.
   - Compute `demand_decay_rate = good.base_demand_decay_rate * decay_rate_multiplier(node, good)` per §5.7's table.
   - Set `demand_caps[good.id] = cap`, `demand_decay_rates[good.id] = rate`, `demand_decay_accumulators[good.id] = 0.0`.
   - Set `demand_pools[good.id]` per the **initial demand fill state decision (§11 open question 1)**.
3. If §3.3(a) picked: drop `prices` key (silently -- v5 saves carrying it pass through).
4. Bump `schema_version` to 6.

Migration is one-way (v6 saves cannot load on v5 builds -- mirrors slice-7 §5.4 precedent). No RNG, no procgen retry: pure dict rewrite.

### 3.7 Determinism check

Pull-driven prices mean save -> load -> save is byte-identical iff (a) pool dicts round-trip exactly through JSON (already true for slice-7's int/float dicts), and (b) the perturbation seed is purely a function of `(world_seed, tick, node_id, good_id, side)` -- no per-session salt. The `prices` field's removal **strengthens** the determinism contract: there is no longer a stored-but-derivable field that could drift between save and load. See §5.4 for the seed.

## 4. Inputs / outputs per system

| System | Reads | Writes | Tick events |
|---|---|---|---|
| **WorldGen** (gen-time only) | `world_seed`, `goods[]`, node tags | `node.demand_pools`, `node.demand_caps`, `node.demand_decay_rates`, `node.demand_decay_accumulators` (initial fill = caps, accumulators = 0) | none after gen |
| **PriceModel** (becomes pull-helper) | `node.stocks`, `node.stock_caps`, `node.demand_pools`, `node.demand_caps`, `good.base_price`, `good.floor_price`, `good.ceiling_price`, `world.world_seed`, `world.tick` | **nothing** -- pure function | **none** -- no longer subscribes to `tick_advanced` |
| **StockSystem** (slice-7) | `node.stocks`, `node.stock_caps`, `node.refill_rates` | `node.stocks`, `node.refill_accumulators` | on every tick (refill) |
| **DemandSystem** (NEW) | `node.demand_pools`, `node.demand_caps`, `node.demand_decay_rates` | `node.demand_pools`, `node.demand_decay_accumulators` | on every tick (decay toward cap) |
| **Trade.try_buy** | `world.stock_for(...)`, **`PriceModel.buy_price_for(...)`** (pull) | `node.stocks` (decrement -- slice-7), `trader.gold`, `trader.inventory` | none (buys do not advance tick) |
| **Trade.try_sell** | **`PriceModel.sell_price_for(...)`** (pull) | `node.demand_pools` (decrement -- NEW), `trader.gold`, `trader.inventory` | none |
| **NodePanel** | **`PriceModel.buy_price_for(...)`**, **`PriceModel.sell_price_for(...)`**, `node.stocks`, `node.stock_caps`, `node.demand_pools`, `node.demand_caps` | nothing | re-renders on `tick_advanced`, `gold_changed`, `state_dirty` |

### 4.1 Price recompute trigger -- DECISION: pull-driven

**Price is computed on every read, not stored, not pushed.** Specifically:

- `PriceModel.buy_price_for(world, node, good, side="buy")` is a static-or-instance function returning an `int`. It reads pool state, applies the curve, applies the perturbation (seeded on `(world_seed, tick, node_id, good_id, "buy")`), clamps, and returns.
- `PriceModel.sell_price_for(...)` is the symmetric helper for the demand side.
- **No tick subscription on PriceModel.** PriceModel ceases to be a state mutator; it becomes a query helper. The slice-7 `2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation` decision is partially superseded -- PriceModel and StockSystem no longer mutate disjoint state because PriceModel no longer mutates state. The disjoint contract still applies between StockSystem and DemandSystem (which mutate parallel pool dicts).

**Why pull, not push:**

- *Determinism wins.* Stored prices are a class of bug ("save loaded with stale price after tuning change"). Pulled prices have no save state to drift.
- *Save shrinks.* Drops the `prices` dict (§3.3(a)). Per-(node, good) ints disappear from the save schema.
- *Pool state is the source of truth.* The whole slice's claim is "prices are the player's window into pool state." Materializing prices into a separate dict creates two windows; pull-driven keeps one.
- *No tick-listener ordering question.* Slice-7 had to ratify that PriceModel and StockSystem mutate disjoint state. Slice-8 dissolves the question -- StockSystem and DemandSystem mutate disjoint pools, PriceModel reads both.
- *Buy/sell apply current price atomically.* Today, `Trade.try_buy` reads `node.prices[good_id]` and applies. Under pull, it reads `PriceModel.buy_price_for(...)`. Same shape; price is "current at the moment of the verb." This is also the moment the supply pool is about to mutate -- the price the player pays is the price *before* their decrement, never after. (Identical to current slice-3 behaviour, where price drift happens on tick boundaries, not on buy.)

**The one cost of pull:** the perturbation seed must include `world.tick`, so prices change on tick boundaries (visibly), not on buys. Buying does NOT change the perturbation -- only the underlying pool fill, which the curve reads. From the player's perspective: prices change visibly on travel ticks (perturbation re-rolls) and visibly on buys (pool drains). Symmetric to slice-7's stock readout.

## 5. Rules

### 5.1 Buy price formula

```
buy_curve         = base_price * (1.0 + (stock_cap - stock) / stock_cap)
buy_perturbation  = randf_range(-PERTURBATION_FRACTION, +PERTURBATION_FRACTION)
                    where rng.seed = mix(world_seed, tick, node_id, good_id, SIDE_BUY)  // see §5.4
buy_price_raw     = buy_curve * (1.0 + buy_perturbation)
buy_price         = clampi(roundi(buy_price_raw), good.floor_price, good.ceiling_price)
```

**Worked example.** Wool: `base_price=12, floor_price=5, ceiling_price=25`. Hillfarm wool slot: `stock_cap=80` (plentiful, with 5x bump per §5.8), `stock=20` (drained).
- `buy_curve = 12 * (1 + (80-20)/80) = 12 * 1.75 = 21.0`
- Perturbation sample (deterministic): say -0.04. `buy_price_raw = 21.0 * 0.96 = 20.16`.
- `buy_price = clampi(20, 5, 25) = 20g`.

When `stock = stock_cap` (full): `buy_curve = 12 * (1 + 0/80) = 12`. Times perturbation, gives ~12g. **Pool full = base price.**
When `stock = 0` (empty): `buy_curve = 12 * (1 + 80/80) = 24`. Times perturbation, gives ~24g, clamped to ceiling 25g. **Pool empty = max buy price.**
When `stock > stock_cap` (impossible under slice-7's `mini(cap, ...)` clamp): formula yields `buy_curve < base_price`, but the §6 clamp on stock prevents this.

### 5.2 Sell price formula (symmetric)

```
sell_curve        = base_price * (1.0 + demand_pool / demand_cap)
sell_perturbation = randf_range(-PERTURBATION_FRACTION, +PERTURBATION_FRACTION)
                    where rng.seed = mix(world_seed, tick, node_id, good_id, SIDE_SELL)  // see §5.4
sell_price_raw    = sell_curve * (1.0 + sell_perturbation)
sell_price        = clampi(roundi(sell_price_raw), good.floor_price, good.ceiling_price)
```

**Symmetry note.** Buy curve scales with **emptiness** of supply pool (numerator `stock_cap - stock`). Sell curve scales with **fullness** of demand pool (numerator `demand_pool`). Both produce `base_price` at neutral pool state and `2 * base_price` at extreme. The asymmetric numerators are deliberate -- they reflect the kernel meaning: buying drains supply (raises buy price), selling drains demand (lowers sell price).

**Worked example.** Wool: `base_price=12`. Rivertown wool demand: `demand_cap=20` (consumer node, high target), `demand_pool=18` (mostly unmet -- locals hungry).
- `sell_curve = 12 * (1 + 18/20) = 12 * 1.9 = 22.8`
- Perturbation sample: say +0.03. `sell_price_raw = 22.8 * 1.03 = 23.484`.
- `sell_price = clampi(23, 5, 25) = 23g`.

When `demand_pool = 0` (saturated -- locals fully supplied): `sell_curve = 12 * 1 = 12g`. **Demand drained = base price (no premium).**
When `demand_pool = demand_cap`: `sell_curve = 12 * 2 = 24g`, clamped to ceiling. **Demand full = max sell price.**

### 5.3 Bias's role -- RETIRED FROM PRICE FORMULA, KEPT AS TAG-DERIVATION SEED

Slice-3 made bias a multiplicative anchor (`base_price * (1 + bias)`) feeding the drift formula. Slice-3 made tags a label of bias (`2026-05-02-slice-3-tags-as-label-not-driver`). Slice-7 amended that to make tags load-bearing for stock economics (`2026-05-03-slice-7-tag-multipliers-load-bearing`).

**Slice-8 retires bias from the price formula but keeps it as the tag-derivation seed.** Specifically:

- `node.bias` field stays on `NodeState`. `WorldGen._author_bias` still runs, still seeds the tag derivation, still produces `produces` / `consumes` lists.
- `node.bias[good_id]` is **no longer read by any pricing code**. The slice-3 `_drift_node_prices` function and `MEAN_REVERT_RATE` constant are removed.
- Pool targets and decay rates are derived from **tags** (which are derived from bias), not bias directly. The slice-7 derivation pattern extends: `produces` -> high supply cap, low demand cap; `consumes` -> low supply cap, high demand cap.

**Why keep bias rather than derive tags from a new mechanism:** bias is the slice-3 free-lunch predicate's load-bearing input -- `_solve_bias_range` enforces predicate satisfiability per good. Removing bias would force a re-derivation of the predicate from scratch on a new vocabulary. Keeping bias as the tag seed is the cheapest path -- the predicate's math just changes (§5.6) while the bias-to-tag derivation stays intact.

**Why retire bias from price:** under pools, price is determined by *current pool fill*, not by *structural anchor*. The (plentiful) producer node has a *high supply cap and high refill rate* (slice-7) and *low demand cap* (new) -- those are the structural anchors now. Layering a multiplicative bias on top of base_price would add a third anchoring input, and the math would lose its symmetry with `(target - current) / target`.

**This amends `2026-05-02-slice-3-bias-multiplicative-anchor` and supersedes `2026-05-02-slice-3-mean-reversion-added` (mean-reversion has no role under pull-driven prices).** Decision Scribe should ratify the supersession when slice-8 lands. The bias-as-tag-seed contract preserves slice-3's free-lunch determinism; it only changes the downstream consumption.

### 5.4 Stochastic perturbation seeding

Perturbation seed shape -- a deterministic mix of five tuple components into a single 64-bit RNG seed:

```
buy_seed  = mix64(world_seed, tick, node_id.hash(), good_id.hash(), SIDE_MIX_BUY)
sell_seed = mix64(world_seed, tick, node_id.hash(), good_id.hash(), SIDE_MIX_SELL)
```

The combiner is **normative on intent, not on bit-exact output.** Any deterministic 64-bit mix that satisfies the invariants below is conformant; the implementation lives in `PricingMath._perturbation` / `_mix64` (slice-8 chose a splitmix64-style xorshift-multiply finaliser to avoid per-call Array literal allocation, supersession-ed from the original `hash([...])` form mid-slice -- see DS note `slice-8-perturbation-seed-mix-supersedes-hash-array`). `SIDE_MIX_BUY` and `SIDE_MIX_SELL` are distinct high-entropy 64-bit constants that namespace the buy and sell sides.

**Critical invariants (load-bearing -- any conformant mix must preserve all of these):**
- Seed includes `tick`. Perturbation re-rolls every travel tick (consistent with slice-3's per-tick drift cadence -- the player's on-screen experience of "prices change over time" survives).
- Seed includes a buy-vs-sell namespace term. Buy and sell perturbations decorrelate; without the namespace, both sides would jiggle in lockstep and the spread (sell - buy) at any pool-neutral state would be artificially stable.
- Seed does **NOT** include any per-buy or per-sell counter. Buying does not re-roll the perturbation. The price seen on the buy click is the price computed for the current (tick, node, good, side) tuple; clicking again before tick advance reads the same perturbation.
- Seed does **NOT** include pool fill values. Pool state already enters via the curve; including it in the seed would create a discontinuous perturbation that re-rolls per buy, defeating the legibility of "the perturbation is the world breathing."
- The combiner allocates **no per-call heap** -- no `RandomNumberGenerator.new()`, no Array literal, no String concatenation. PricingMath is on the hot path (NodePanel paint, Trade verbs, harness inner loop ~5M iterations).

**Application.** Perturbation is `rng.randf_range(-PERTURBATION_FRACTION, +PERTURBATION_FRACTION)` and applied multiplicatively to the curve output (`curve * (1 + perturbation)`), not additively. Multiplicative scales with good identity (a 3% jiggle on wool's 12g is 0.36g; on iron's 22g is 0.66g). Clamp happens after perturbation so a perturbed-up max hits the ceiling, not a perturbed-up base then re-perturbed.

`PERTURBATION_FRACTION = 0.05` (the locked ±5% from Director).

### 5.5 Supply refill (mostly inherits slice-7)

Inherits slice-7 §3.2 verbatim: `if stock < cap: accumulator += rate; stock += int(accumulator); accumulator -= int(accumulator); saturate at cap`. **One change:** the cap multipliers in `WorldRules.STOCK_CAP_MULT_*` are bumped 5x per §5.8, which changes the absolute cap values but not the refill mechanic. Per-tick refill rate constants (`REFILL_MULT_PLENTIFUL=5.0`, `REFILL_MULT_SCARCE=0.2`) are **unchanged from slice-7** -- the §6 harness PASS values stand. Refill happens on every travel tick; non-travel ticks don't exist (slice-7 §3.3).

### 5.6 Demand decay (NEW -- symmetric to refill)

Each (node, good) pair carries `demand_pools[good_id]: int`, `demand_caps[good_id]: int`, `demand_decay_rates[good_id]: float`, and `demand_decay_accumulators[good_id]: float`. The demand pool **decays toward cap** -- when the pool is below cap (player has sold and saturated some demand), the pool refills toward cap over time. This is symmetric to supply refill but with the meaning inverted: the demand pool grows when the player is away, just as supply does, because in both cases "the world recovers from trader pressure during travel ticks."

```
if demand_pool < demand_cap:
    demand_decay_accumulators[good_id] += demand_decay_rates[good_id]
    var whole_units: int = int(demand_decay_accumulators[good_id])
    if whole_units > 0:
        demand_pools[good_id] = mini(demand_cap, demand_pool + whole_units)
        demand_decay_accumulators[good_id] -= whole_units
else:
    demand_decay_accumulators[good_id] = 0.0  # steady-state reset, mirrors slice-7 §3.2
```

**Critical: decay direction.** "Decay" here is a misnomer in the colloquial sense -- the pool *grows* toward cap. The naming follows the kernel logic: demand decays toward its target (steady-state demand) when nothing is depressing it. A saturated demand pool (just sold into) decays back upward to its authored target as the local population's wants reassert themselves. Variable name retained because `demand_decay_rates` parallels `refill_rates` symmetrically -- both are "rate at which pool moves toward target per tick."

**Why decay must exist (Critic's Slice-8 item 4):** without it, one over-eager trader permanently saturates a town and the world ratchets stuck. A sell-only town's demand pool drains to zero across a single full-cargo sell and never recovers; the player learns the town is "done" and stops visiting; the kernel narrows. Decay is the symmetric world-breathes-during-travel mechanic that keeps the route economy renewable.

**Decay rate per tag (§6 table):** producer nodes have *low* decay rate on the goods they produce (locals don't want more wool when they make wool -- demand recovers slowly). Consumer nodes have *high* decay rate on the goods they consume (locals always want more salt -- demand recovers fast). Neutral is the baseline. This produces the felt experience: a consumer town's sell prices recover faster than a producer town's, making consumer routes more sustainable than producer routes for the *return* leg of an A->B->A loop.

**Decay only on travel ticks** -- mirrors slice-7 supply refill exactly. Non-travel ticks don't exist; player who never travels never sees demand recover.

### 5.7 Demand-side multiplier table (NEW)

Authored on `WorldRules` as new constants, mirroring slice-7's STOCK_CAP_MULT and REFILL_MULT pairs:

```
DEMAND_CAP_MULT_PRODUCER  = 0.25   // good in node.produces -> low demand for what they make
DEMAND_CAP_MULT_NEUTRAL   = 1.0
DEMAND_CAP_MULT_CONSUMER  = 4.0    // good in node.consumes -> high demand for what they use up

DEMAND_DECAY_MULT_PRODUCER = 0.2   // demand recovers slowly (town doesn't crave its own export)
DEMAND_DECAY_MULT_NEUTRAL  = 1.0
DEMAND_DECAY_MULT_CONSUMER = 5.0   // demand recovers fast (town keeps wanting its imports)
```

**Inverse-of-supply structure.** Producer (`good in node.produces`) has supply_cap_mult=4.0, demand_cap_mult=0.25 -- deep supply pool, shallow demand pool. Consumer (`good in node.consumes`) has supply_cap_mult=0.25, demand_cap_mult=4.0 -- shallow supply, deep demand. The numbers mirror exactly. Refill multipliers do the same: producer node refills its own supply fast (5.0) and recovers its demand slowly (0.2); consumer node refills its supply slowly (0.2) and recovers demand fast (5.0).

**Why this is the right shape:** the player walks into a producer node, sees `wool 8g (plentiful) [80 left]` (low buy price, deep stock) and `cloth 22g (scarce) [1 left]` (high sell price for cloth -- but only 1 unit's worth of demand). Walking into a consumer node flips it: `wool 22g (plentiful for selling) [...]` and `cloth 8g (low buy)`. The (plentiful)/(scarce) tag drives a coherent four-way decision matrix: buy-or-not, sell-or-not, both at every good. **The slice's information-density requirement (§7) flows from this symmetry.**

**Authored on `Good.tres`:**

```
@export var base_demand_cap: int = 4              // baseline demand pool target, range 1..100
@export var base_demand_decay_rate: float = 0.2   // baseline demand decay rate, range 0.01..10.0
```

Mirrors slice-7's `base_stock_cap` / `base_refill_rate` exactly. The four base values together form the per-good identity surface; tag multipliers do the per-(node, good) differentiation.

### 5.8 Supply cap 5x bump

Slice-7's `STOCK_CAP_MULT_PLENTIFUL=4.0`, `STOCK_CAP_MULT_NEUTRAL=1.0`, `STOCK_CAP_MULT_SCARCE=0.25` produced caps of 16/4/1 at `base_stock_cap=4`. Director's "realistic stockpile" bump is 5x:

```
STOCK_CAP_MULT_PLENTIFUL = 20.0    // was 4.0  -- 80 cap at base_stock_cap=4
STOCK_CAP_MULT_NEUTRAL   = 5.0     // was 1.0  -- 20 cap
STOCK_CAP_MULT_SCARCE    = 1.25    // was 0.25 -- 5 cap (rounded, see §6)
```

**Refill rates unchanged.** This means a producer node's supply pool now takes 5x as long to refill from empty (cap=80, rate=1.0/tick = 80 ticks). Cleaning out a producer node leaves it visibly drained for many travel legs, even with frequent rotation. Combined with the new pool-driven price curve, the felt experience: drained producers stay expensive for ten-plus legs, not just one.

**Why this matters for the curve.** The price curve produces values ∈ `[base_price, 2*base_price]` regardless of cap size. What cap size controls is the **rate of price change per buy**. With cap=16 (slice-7), buying 4 wool moves the curve numerator from 0 to 4, so price moves by `base * 4/16 = 25% of base`. With cap=80 (slice-8), buying 4 wool moves the curve by `base * 4/80 = 5% of base` -- **per-buy price movement is now within the perturbation envelope**, so individual buys don't visibly jiggle the price. Only large drains do. This is the texture: "the world remembers cumulative trader pressure, not individual transactions." The 5x bump makes the curve **player-readable**, not a per-click oscilloscope.

### 5.9 `_solve_bias_range` -- updated free-lunch predicate

The slice-3 predicate was: `(bias_max - bias_min) * base_price + 2 * volatility * ceiling_price < shortest_edge * cost`. Under pools, neither term still applies -- bias doesn't enter prices, and volatility (slice-3 random-walk magnitude) is replaced by `PERTURBATION_FRACTION`.

**New predicate, per good `g`:**

```
worst_case_buy_price  = min(g.ceiling_price, roundi(2 * g.base_price * (1 + PERTURBATION_FRACTION)))
worst_case_sell_price = max(g.floor_price,   roundi(g.base_price * (1 - PERTURBATION_FRACTION) * 1.0))   // demand_pool=0 case
worst_case_spread     = worst_case_buy_price - worst_case_sell_price

best_case_buy_price   = max(g.floor_price,   roundi(g.base_price * (1 - PERTURBATION_FRACTION) * 1.0))   // stock=cap case
best_case_sell_price  = min(g.ceiling_price, roundi(2 * g.base_price * (1 + PERTURBATION_FRACTION)))
max_profitable_spread = best_case_sell_price - best_case_buy_price
```

The interesting predicate is **two-sided**:

**(P1) No-free-lunch (the slice-3 carryover, kernel pillar 1):** `worst_case_spread > shortest_edge * TRAVEL_COST_PER_DISTANCE` is *acceptable* -- a single overpriced-buy + underpriced-sell round trip should LOSE money. **Predicate: a fully-saturated supply pool at one node + a fully-drained demand pool at another node + worst perturbation -> the trip is unprofitable.** Stated mathematically: `worst_case_buy_price - worst_case_sell_price + shortest_edge * cost > 0` -- wait, let me re-state. The loss case is: buy at the highest possible buy price (drained supply, ~2*base) and sell at the lowest possible sell price (drained demand, ~base), pay travel. Net per unit: `sell - buy - cost_per_unit_of_weight` -- if this is ever guaranteed *positive*, free-lunch holds. The predicate must ensure it can be *negative*: `worst_case_sell_price - worst_case_buy_price < shortest_edge * cost / unit_weight`. Worst case for the player: buy ~2*base, sell ~base, lose `base + travel`. **Predicate P1: `roundi(g.base_price) <= shortest_edge * TRAVEL_COST_PER_DISTANCE` is satisfied trivially for any base_price <= shortest_edge*3** (under current TRAVEL_COST_PER_DISTANCE=3 and MIN_EDGE_DISTANCE=3 = 9 gold), which is true for wool (12 -- wait, fails) ... let me re-derive in §5.10.

Actually, under pools, the **shape** of the no-free-lunch question changes. With slice-3 random-walk, the worst-case spread was bounded by bias range * base_price. With pools, the worst-case spread is bounded by `~base_price` (between ~2*base and ~base on the wrong direction). Whether that constitutes a free lunch on the shortest edge is a different question, derived in §5.10.

**(P2) Profit-must-exist (NEW -- the kernel-must-have-game predicate):** at the *best* pool state on the *shortest profitable* edge, the player must be able to make profit, or the game has no kernel. Stated: `max_profitable_spread > shortest_edge * TRAVEL_COST_PER_DISTANCE * unit_weight_of_lightest_good`. With wool's base=12, weight=4, shortest_edge=3: `max_profitable_spread = 25 - 5 = 20`; `travel_cost_per_unit_weight = 3 * 3 / 4 = 2.25`; spread > cost: PASS. P2 is comfortably satisfied at current numbers but worth gen-time-asserting for future tunings.

### 5.10 Free-lunch predicate -- derivation

The slice-3 predicate was satisfiable only by tightening bias ranges. Under pools, **bias no longer enters the predicate**. The new predicate is *static* per (good, edge_length) -- determined entirely by `base_price`, `floor_price`, `ceiling_price`, `PERTURBATION_FRACTION`, and `TRAVEL_COST_PER_DISTANCE`.

**P1 (no-free-lunch, derived):** the player must NOT be guaranteed profit on the shortest edge under any pool state. A profit-guaranteed loop would be one where `min(sell_price) - max(buy_price) > shortest_edge * cost`. With pools:
- `min(sell_price)` at the destination = `base_price * 1.0 * (1 - PERTURBATION_FRACTION)` -- demand pool drained, worst perturbation. For wool: `12 * 0.95 = 11.4 -> 11`.
- `max(buy_price)` at the source = `base_price * 2.0 * (1 + PERTURBATION_FRACTION)` clamped to ceiling. For wool: `12 * 2 * 1.05 = 25.2 -> 25` (ceiling).
- Spread in the *unfavourable* direction: `11 - 25 = -14`. Player buying at max and selling at min loses 14g/unit before travel. **No free lunch.**

Even the *best-case-at-source-vs-worst-case-at-destination* must be checkable. The relevant predicate fires only when sell_min > buy_max -- which under the curve cannot happen, since both prices sit in `[base*0.95, base*2.05]` clamped. P1 is **structurally satisfied by the curve shape itself** for any base_price > 0 and PERTURBATION_FRACTION < 0.5. **No gen-time assert needed.**

**P2 (profit-must-exist):** at the best pool state, the player must be able to profit. Spread `max_sell - min_buy = 2*base*(1+P) - base*1*(1-P)` clamped to ceiling-floor. For wool: `25 - 5 = 20g`. Travel cost on shortest edge: `MIN_EDGE_DISTANCE * TRAVEL_COST_PER_DISTANCE = 3 * 3 = 9g`. Per-unit profit at best pool state, lightest good: `20 / 4 weight = 5g/weight` vs `9/4 = 2.25g/weight cost`. **PASS by margin of ~2x.**

**Predicate to assert at gen-time, per good:**

```
max_spread = (2 * base_price * (1 + PERTURBATION_FRACTION)) - (base_price * 1.0 * (1 - PERTURBATION_FRACTION))
max_spread = base_price * (1 + 3 * PERTURBATION_FRACTION)              // simplify
required   = MIN_EDGE_DISTANCE * TRAVEL_COST_PER_DISTANCE
assert(max_spread > required, "free-lunch P2: good %s cannot turn profit on shortest edge" % good.id)
```

For wool (`base=12`, P=0.05): `max_spread = 12 * 1.15 = 13.8`. Required: 9. **PASS.**
For salt (`base=7`, P=0.05): `max_spread = 7 * 1.15 = 8.05`. Required: 9. **FAIL.**
For iron (`base=22`, P=0.05): `max_spread = 22 * 1.15 = 25.3`. Required: 9. **PASS.**

**Salt is below the predicate threshold.** This means the cheapest good cannot, even at best pool state, recover its travel cost on a single unit. The shipping decision for salt is then: (a) salt is cheap-and-bulky (weight=2, so per-weight profit is `8.05 / 2 = 4.0` vs cost `9 / 2 = 4.5` -- still below); or (b) salt's `base_price` needs to rise; or (c) salt is intentionally a fill-the-cargo good, never primary cargo. **Designer's call:** option (c) is acceptable as long as P2 is asserted with a *per-weight* form, not a per-unit form -- the kernel question is "does the cheapest weight unit ever turn profit," not "does each good in isolation."

**Refined P2 (per-weight):**

```
max_spread_per_weight = (base_price * (1 + 3 * PERTURBATION_FRACTION)) / good.weight
required_per_weight   = (MIN_EDGE_DISTANCE * TRAVEL_COST_PER_DISTANCE) / good.weight   // unit-weight travel cost
assert(max_spread_per_weight > required_per_weight, ...)
```

Both terms divide by `weight`, so they cancel: P2 simplifies to the per-unit form, and salt fails again. **The honest answer is: salt's base_price=7 is below P2's threshold under TRAVEL_COST=3, MIN_EDGE_DISTANCE=3.** This was already true under slice-3 -- the harness for slice-7 assumed salt was profitable on enough routes to matter (and it is, when bias raises Hillfarm's salt price toward 4 and Rivertown's toward 12 -- spread of 8, exceeds travel of 9 only barely on the longest edges). Slice-8's pool-driven prices give salt a max spread of 8 at *best pool state* before travel; on shortest edges, salt is structurally unprofitable.

**Designer's call:** P2 is **diagnostic, not blocking.** If a good fails P2, log a warning at gen-time: `"good '%s' cannot turn profit on shortest edge under pool curve; will only be profitable on longer edges"`. Do not abort gen. The harness (§10) measures profitable-edge fraction per good and surfaces if any good is profitable on zero edges across the seed sweep -- *that* is the blocking condition.

Salt's tuning is then a slice-8.x or slice-8.5 question. **For slice-8, salt's base_price stays at 7**; the harness will report what fraction of routes have profitable salt arbitrage. If that fraction is near-zero, slice-8.5 retunes salt's base or the cargo cap; if the fraction is non-trivial (salt is profitable on long edges), salt remains a long-edge good with no bias retune needed.

## 6. Numbers (tuning ranges)

| Knob | Starting value | Range | What it tunes / symptoms |
|---|---|---|---|
| (slice-1 through slice-7 knobs unchanged) | -- | -- | per their respective specs |
| `PERTURBATION_FRACTION` | **0.05** (locked by Director) | 0.02-0.10 | High = price reads as noisy, structural pool fill harder to read; low = pool-fill-state and price are nearly 1:1 (no "world breathing" feel). |
| `STOCK_CAP_MULT_PLENTIFUL` | **20.0** (was 4.0) | 12.0-30.0 | The 5x bump. Higher = drained producers stay drained for more legs; lower = supply refills back to neutral price quickly, cap stops biting. `[needs playtesting]` |
| `STOCK_CAP_MULT_NEUTRAL` | **5.0** (was 1.0) | 3.0-8.0 | Neutral cap defines per-buy curve sensitivity at non-tagged slots. Same 5x scaling as plentiful. |
| `STOCK_CAP_MULT_SCARCE` | **1.25** (was 0.25) | 1.0-2.0 | Scarce cap stays near 1 unit (the cheapest "scarcity bites" floor). Higher = scarce stops feeling scarce; lower = round-down hits 1 unit for all goods, scarce becomes uniform. |
| `DEMAND_CAP_MULT_PRODUCER` | **0.25** | 0.1-0.5 | Producer's sell-side: how many units of own-product the locals want. Low = selling wool at a wool-producer is hopeless (intended); high = producer becomes a sell target too (kernel collapses). `[needs playtesting]` |
| `DEMAND_CAP_MULT_NEUTRAL` | **1.0** | -- | Anchor; varies the absolute pool size but not its shape. Tied to `Good.base_demand_cap`. |
| `DEMAND_CAP_MULT_CONSUMER` | **4.0** | 2.0-8.0 | Consumer's sell-side: how big the demand reservoir is. High = sell trips can dump full cargo without saturating; low = a single full cargo saturates demand for many legs (intended scarcity). `[needs playtesting]` |
| `DEMAND_DECAY_MULT_PRODUCER` | **0.2** | 0.05-0.5 | Producer's demand recovery rate. Low = producer's sell window stays narrow (intended); high = producer becomes always-sellable (kernel collapse on producer routes). |
| `DEMAND_DECAY_MULT_NEUTRAL` | **1.0** | -- | Anchor. |
| `DEMAND_DECAY_MULT_CONSUMER` | **5.0** | 3.0-8.0 | Consumer's demand recovery. High = consumer routes stay sustainable (intended -- the player's main route ladder); low = consumer saturates and stays saturated (kernel narrows). `[needs playtesting]` |
| `Good.base_demand_cap` (per-good) | **4** | 1-20 | Mirrors `base_stock_cap`. Authored uniformly across goods at slice-8 ratification; per-good asymmetry is a slice-8.x retune. |
| `Good.base_demand_decay_rate` (per-good) | **0.2** | 0.05-1.0 | Mirrors `base_refill_rate`. Same uniform-authoring stance. |

**Removed knobs (slice-3 retirement):**
- `MEAN_REVERT_RATE` -- no longer applicable; pull-driven prices have no drift state to revert.
- `BIAS_MIN`, `BIAS_MAX`, `MIN_BIAS_RANGE` -- still used by `_author_bias` for the tag-derivation seed (§5.3), but **not** by the price formula. Keep on `WorldRules`; their values are unchanged.
- `Good.volatility` -- still required as `> 0.0` by `_author_bias` (per slice-3 assert), but not read by pricing. Keep on `Good.tres`; their values are unchanged.

**Why so many knobs marked `[needs playtesting]`:** every demand-side multiplier is new and unmeasured; the harness (§10) is the desk-tuning tool but the *feel* of "consumer routes are sustainable, producer routes are bursty" is a play-time judgement.

## 7. Feedback (UI)

The pillar gate fails without a node-panel rework. The player must be able to read **buy price, sell price, supply fill, demand fill** simultaneously per good per node, and they must read it without studying.

ASCII-only (CLAUDE.md project rule -- web export font has no Unicode coverage). No animation. No colour gradients beyond simple text-color choices.

### 7.1 Information density requirement

Each good row in `NodePanel` must surface:

1. Good name (slice-1 onward).
2. **Buy price** -- as the player would pay it now.
3. **Sell price** -- as the player would receive now.
4. **Supply fill** -- visual indicator of `stocks[good_id] / stock_caps[good_id]` ∈ [0, 1].
5. **Demand fill** -- visual indicator of `demand_pools[good_id] / demand_caps[good_id]` ∈ [0, 1].
6. Owned qty (slice-1 onward).
7. Buy / Sell action buttons (slice-1 onward).
8. (Plentiful) / (Scarce) tag (slice-3 onward).

That is 5 numerical reads per row plus 1 tag plus 2 buttons. Slice-7's row format `wool 12g (plentiful) x0 [4 left]` carries 4 reads; slice-8 adds 2 (sell price, demand fill).

### 7.2 Visual conventions (Designer-specced; Architect picks layout)

- **Supply fill: ASCII bar.** `[####...]` style, fixed width (Designer suggests 5 or 6 chars). `####.` shows 4/5 fill. The `[N left]` integer from slice-7 stays alongside or replaces the bar -- Architect picks; bar is the at-a-glance read, integer is the precise read. Both are useful.
- **Demand fill: ASCII bar, distinct shape.** Designer suggests `<###..>` or similar to visually distinguish from supply. ASCII brackets only -- no Unicode block characters (web export coverage).
- **Buy price colored relative to base.** If `buy_price > base_price * 1.2`: dim red (drained supply, expensive). If `buy_price < base_price * 0.9`: green (well-stocked, cheap). Otherwise: default text color. Color is supplemental; the integer is authoritative.
- **Sell price colored relative to base.** Symmetric: `sell_price > base * 1.2` -> green (hungry market, sell here). `sell_price < base * 0.9` -> dim red (saturated, don't sell here). Otherwise: default.
- **The (plentiful) / (scarce) tag stays as a separate prefix.** It conveys *structural identity*; the bars convey *current state*. The two are different reads and should not be conflated.
- **Buy/Sell buttons disable independently.** Buy disabled iff (cargo full OR stock=0 OR can't afford). Sell disabled iff (own=0 OR demand_pool=0). The pool-zero-disable for sell is **NEW** -- under slice-3 selling at any price was always allowed if the player had stock; under slice-8, a saturated demand pool should refuse the sale (price would clamp to floor anyway, but disabling is more honest than "selling at floor"). **Designer call: disable sell when demand_pool == 0.** Architect ratifies. Tooltip on sell-disabled-from-demand: `"local market saturated"`.

### 7.3 Suggested row layout (informational, not binding)

```
Hillfarm                Cart: 0/60
  wool   B 8g (plentiful) S 7g  [#####]<#....>  x0  [Buy] [Sell]
  cloth  B 13g           S 11g [###..]<##...>  x0  [Buy] [Sell]
  salt   B 4g (plentiful) S 7g  [####.]<#....>  x0  [Buy] [Sell]
  iron   B 22g (scarce)  S 24g [#....]<####.>  x0  [Buy] [Sell]
```

Where `B` = buy price, `S` = sell price, `[####.]` = supply fill bar (5/5 = full), `<#....>` = demand fill bar. Architect picks the exact format and column widths -- the requirement is **information density per row sufficient to make a 4-way decision (buy/sell/skip/wait) at a glance**. If Architect's preferred layout is two-line per good or a separate sell column, fine.

### 7.4 What does NOT change in UI

- Slice-7's `[N left]` integer can stay or be replaced by the bar; bar + integer is acceptable redundancy. Architect picks.
- Map view does NOT show pool state for remote nodes (slice-7 §8.5 anti-goal preserved -- "no remote-stock readout"). The map is local-knowledge-only.
- Travel modal does not show price information at the destination (slice-7 §8.5).
- No "best route" indicator. No "this is profitable" highlight. The player computes the trade themselves; the panel exposes the inputs.

### 7.5 ASCII verification

New strings:
- `B %dg`, `S %dg` -- ASCII letter prefix, integer, lowercase unit. No Unicode.
- `[####.]`, `<###..>` -- ASCII brackets, hash, period. No Unicode block chars.
- `"local market saturated"` -- ASCII letters and spaces.
- Color tokens are theme-driven, not strings (no Unicode in theme names).

## 8. Edge cases and failure modes

- **Supply pool at 0.** Buy disabled (slice-7 `[0 left]` + tooltip). Buy price formula yields `2 * base_price * (1 + perturbation)` clamped to ceiling -- the price displayed is the max, but the button is disabled. Player reads "I cannot buy here, and even if I could, it would be expensive."
- **Supply pool at cap (full).** Buy enabled. Buy price = `base_price * (1 + 0/cap) * (1 + perturbation) = base_price ± 5%`. The "neutral" read.
- **Demand pool at 0 (saturated).** Sell disabled (NEW -- §7.2). Sell price formula yields `base_price * (1 + 0/cap) * (1 + perturbation) = base_price ± 5%`. The displayed price is the floor of the sell range -- low but not below `Good.floor_price`. Player reads "I cannot sell here; market is full."
- **Demand pool at cap (full -- max unmet demand).** Sell enabled. Sell price = `2 * base_price * (1 + perturbation)` clamped to ceiling. The "best sell" read.
- **Pool somehow at 2x cap (impossible under §5 clamps, but hypothetical).** Curve yields `base * (1 + 1) = 2*base` -- the same as `cap` -- so pool > cap doesn't blow up the price; clamp catches it. Defensive: WorldGen and decay/refill code asserts `pool <= cap` post-mutation.
- **Pool at -1 (impossible).** Same as pool=0 in the formula (clamp at 0 in the read helper). Decrement code in `Trade.try_buy` and `Trade.try_sell` already guards against decrementing past 0 (slice-7 pattern).
- **Price floor hit during sell into saturated demand.** With base=7 (salt) and demand_pool=0, `sell_price_curve = 7 * 1 = 7`. Perturbation ±5% gives `[6.65, 7.35]` -> clamped to `[6, 7]` after roundi. `floor_price=3` (from existing `salt.tres`); never binds. **Floor only binds for goods authored with `floor_price > base * (1 - PERTURBATION_FRACTION)`.** None of the current goods author this way, so the floor is effectively decorative under slice-8. Floor is kept on `Good.tres` as a defensive rail; it would bind if a future good had volatility-shaped scarcity asymmetry. **No assert; documented edge case.**
- **Price ceiling hit on drained supply with high perturbation.** With base=22 (iron), drained supply, +5% perturbation: `22 * 2 * 1.05 = 46.2 -> clampi to 25 (ceiling)`. Player sees `25g` which is the ceiling, not the formula output. **This is the binding case; the curve is "soft" at the ceiling.** Designer's read: this is the intended "iron is expensive when scarce, but not unboundedly expensive" texture. Ceilings should bind on at least some configurations to keep prices legible.
- **Decay during travel ticks.** Demand decay runs only on travel ticks (§5.6, mirrors slice-7 supply refill). Player who never travels: pools never recover. Player travelling A->B->A in 6 ticks: B's demand pool decays by `6 * decay_rate` units toward cap during the round trip. This is the symmetric "world breathes during travel" texture.
- **Determinism replay across save/load.** Pull-driven prices: save->load->save is byte-identical iff (a) pool state round-trips through JSON exactly (already true), (b) the `tick` value round-trips (true), (c) the perturbation seed function is a pure deterministic mix of (world_seed, tick, node_id, good_id, side) per §5.4 with no hidden state. Save format drops `prices` (§3.3(a)) so there is no stored-but-derivable field to drift. The B1 invariant harness must be extended to verify this -- §10.4.
- **Player buys into a node with `stock=0` and `demand_pool=cap` (mismatched pools).** Possible under heavy player activity: someone bought everything, but the demand pool hasn't been touched. Buy disabled (stock=0). Sell at max sell price. **This is the intended "I drained supply, now I have nothing to buy with -- but I CAN sell here at top dollar" texture.** Read: the pools are independent; a node can be a great sell target even when supply is exhausted.
- **Two players saving and loading on the same world (single-player, but conceptually).** Not applicable -- this is a single-player offline game. Saved state is the player's only state.
- **Web-export-specific (HTML5).** Pull-driven prices add zero new heap allocations per tick (no per-tick price recompute). UI re-renders on tick_advanced, gold_changed, state_dirty just as today; the cost is the per-row formula evaluation (cheap -- 7 nodes * 4 goods * 2 sides = 56 formula evals per refresh). No new web-export concern.
- **Stranded predicate re-validation (Critic item 8).** `DeathService.is_stranded` checks whether the player can afford to travel out of the current node. Under slice-8, the buy price varies with supply pool; the stranded check should use the **current buy price** (computed by `PriceModel.buy_price_for(...)`), not a stored value. The check shape doesn't change; the price helper does. Verify: stranded means "no edge out is affordable at current gold AND no good in the current node yields enough sell value to cover the cheapest edge." Sell-side under slice-8 uses `PriceModel.sell_price_for(...)`; same shape as the existing computation, swapped helper. **No new failure mode; verify in code review.**
- **Determinism replay invariant check (Critic item 9).** Existing B1 predicates P1-P8 run against post-mutation state; slice-8 needs to verify that `node.prices` (if removed per §3.3(a)) is no longer asserted on. Mechanically: any P-predicate referencing `node.prices` either breaks under v6 saves (where prices is absent) or is rewritten to call `PriceModel.buy_price_for(...)` to derive the current price for the assertion. Designer's call: **rewrite, don't break.** Existing P5 (non-negative state) covers prices via the implicit int-non-negative check; under v6 the check becomes "computed buy_price >= floor_price", which is true by construction of `clampi`. No new B1 predicate needed for prices; existing checks remain valid (vacuously, in pull-driven mode).
- **Save written under v6, loaded under v5 build.** v5's strict-reject on `schema_version != 5` rejects v6 saves. Mirrors slice-7. **Acceptable** -- forward-compat to old builds is not a target.

## 9. Integration touch points (vs slice-7)

| Touch point | Systems involved | Owner | Change vs slice-7 |
|---|---|---|---|
| **Demand pool authoring** | `WorldGen` (gen-time write), `DemandSystem` (per-tick decay), `Trade.try_sell` (decrement) | **`WorldGen`** authors via `_author_demand` (mirrors `_author_stock`); **`NodeState`** owns the four parallel dicts; **`DemandSystem`** mutates per tick; **`Trade`** mutates on sell. | NEW. |
| **Demand pool decay** | `DemandSystem` (NEW Node) | **`DemandSystem`** | NEW Node, mirrors `StockSystem`'s shape. Listens to `Game.tick_advanced`. |
| **Pull-driven price** | `PriceModel` (becomes query helper), `Trade.try_buy`, `Trade.try_sell`, `NodePanel`, `DeathService.is_stranded`, B1 predicates | **`PriceModel`** owns the formulas. Callers query through it; no mutator role. | CHANGED. PriceModel was a per-tick mutator; now it is a stateless helper. |
| **Supply pool** (slice-7) | unchanged | `StockSystem`, `WorldGen`, `Trade.try_buy` | UNCHANGED -- pools are slice-7 mechanic with new cap multipliers (5x bump). |
| **Tag derivation** | `WorldGen._author_bias` -- writes `bias`, derives `produces`/`consumes` | `WorldGen` | UNCHANGED. Bias retires from price formula but stays as tag-derivation seed (§5.3). |
| **Save migration v5 -> v6** | `WorldState._migrate_v5_to_v6` (NEW static helper, mirrors `_migrate_v4_to_v5`) | **`WorldState`** | NEW. |
| **B1 predicates** | `save_invariant_checker.gd` -- existing P1-P8 plus possible P9 (demand pool non-negative + within cap, mirrors P7 supply); P10 (demand_pools.keys() == demand_caps.keys() == prices keys, mirrors P8) | Architect call -- mirror slice-7's P7/P8 additions. | NEW PREDICATES. |
| **Removed: PriceModel tick subscription** | `PriceModel._on_tick_advanced`, `PriceModel._drift_node_prices` | -- | REMOVED. PriceModel no longer subscribes to `Game.tick_advanced`. The tick-listener registration in `main.gd` drops one entry. |
| **Removed: `node.prices` field (§3.3(a) if Architect picks)** | NodeState, WorldState.to_dict/from_dict, NodePanel | -- | REMOVED (Architect call). Replaced by pull through `PriceModel`. |

The four cross-system signals (`tick_advanced`, `gold_changed`, `state_dirty`, `died`) are unchanged. **One new tick-listener** (`DemandSystem._on_tick_advanced`) joins the existing two (`StockSystem._on_tick_advanced`, `SaveService._on_tick_advanced`). Listener ordering is still unspecified per `2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation` -- StockSystem and DemandSystem mutate orthogonal pool dicts. PriceModel reads both but no longer writes either; if PriceModel reads mid-tick (e.g., a HUD pull during the tick window), it gets either the pre-tick or post-tick state depending on when in the listener chain it fires -- fine, since both are valid pool states.

## 10. Acceptance criteria / harness gate

The slice-7 harness measured cap-binding rate and multi-good fraction. Slice-8 needs different gates because the slice's claim is different: not "stock cap forces multi-good carts," but "pool curve produces meaningful, readable price spreads that reward route rotation."

### 10.1 Tool

New file: `godot/tools/measure_pricing_v2.gd`. Mirrors `measure_production_caps.gd`'s structure (seed sweep, per-block stats, gate predicate, ASCII output).

### 10.2 What it measures

Per (DEMAND_DECAY_MULT triple, DEMAND_CAP_MULT triple, seed):

1. Generate world.
2. **Warm-up phase (K=20 ticks):** simulate per-tick optimal trade (every directed edge, optimal cart) to drive pools away from initial-full state. K=20 is the slice-7 default; slice-8 may need higher because demand pools need to drain too.
3. **Measurement phase (M=8 ticks):** for each tick, for each directed edge `(from, to)`:
   - For each good: compute `buy_price_at_from`, `sell_price_at_to`, and the optimal cart spreading them.
   - Record pool fill bracket for both supply and demand pools at both nodes (drained / mid / saturated; "mid" = 20-80% of cap).
   - Record price-spread per profitable route per good: `sell_price - buy_price` and `(sell_price - buy_price) / base_price`.

### 10.3 Pass criterion -- two gates

**Gate 1 (curve-sweeping): Pools must be in motion, not pinned.**

```
gate_1_pass <=> at the gating-gold tier (gold=200):
   >= 40% of (route, tick, direction, good) tuples have either supply_pool_fill OR demand_pool_fill in the middle 60% of capacity (i.e., ∈ [0.20*cap, 0.80*cap])
```

Justification: the curve produces meaningful prices only when pools breathe. If 90% of (route, tick) pairs have both pools pinned at 0 or cap, the curve is producing only the corner cases (max price or min price) and the perturbation is doing all the work. Gate 1 floor of 40% is calibrated against slice-7's 20% cap-binding floor -- demand pool adds a second binding axis, so the bar rises proportionally.

If gate 1 fails: pools are pinned. Diagnostic: are they pinned at full (decay too fast / cap too low / supply refill too high relative to play) or pinned at empty (decay too slow / supply refill too slow / cap too high)? The harness output should histogram `(supply_at_drained, supply_at_mid, supply_at_saturated)` and same for demand.

**Gate 2 (price-gradient): Spread must exceed perturbation noise on profitable routes.**

```
gate_2_pass <=> at the gating-gold tier:
   >= 30% of (route, tick) pairs that have profit > 0 show |buy_price_at_source - sell_price_at_destination| >= 2 * PERTURBATION_FRACTION * base_price = 0.10 * base_price
```

Justification: perturbation is ±5% of curve output. Two perturbations stack to 10% of base in worst case. If the spread on a profitable route is less than 10% of base, the player is making a profit that's within noise -- they cannot read whether their next trip will profit. Gate 2 ensures the curve's structural spread (driven by pool fill differentials) dominates the perturbation noise on profitable routes.

If gate 2 fails: pool fill differentials between source and destination are too small. Diagnostic: histogram `(supply_at_source - supply_at_dest)` and `(demand_at_dest - demand_at_source)` -- the curve relies on these differentials; if both are near zero, decay rates have equilibrated supply and demand across nodes, and the player's only profit signal is perturbation. Tuning lever: lower `DEMAND_DECAY_MULT_PRODUCER` and raise `DEMAND_DECAY_MULT_CONSUMER` to amplify the asymmetry.

The two gates are independent. Gate 1 is the slice-level go/no-go; gate 2 is the "did the curve deliver the slice's promised legibility" check, mirroring the slice-7 gate-1/gate-2 structure exactly. **Slice-7 escalation precedent (`2026-05-03-slice-7-gate-2-fail-escalates-separate-slice`):** if gate 1 PASS and gate 2 FAIL, ship the slice with a known-failed gate 2 only with Director ratification.

### 10.4 Determinism gate (Critic item 9 -- NEW)

A third gate, deterministic but binary:

```
gate_3_pass <=> for 100 random seeds in [0, 999]:
   generate world; warm up K ticks; save_dict_1 = world.to_dict()
   load world from save_dict_1; save_dict_2 = world.to_dict()
   assert save_dict_1 == save_dict_2 (byte-identical)
   for each (node, good): assert PriceModel.buy_price_for(world1, node, good) == PriceModel.buy_price_for(world2, node, good)
```

**Pull-driven prices put determinism load on the harness, not just the pool dicts.** Gate 3 ensures the perturbation seed function is stable across save/load. If gate 3 fails on any seed, slice cannot ship -- this is the kernel determinism contract (`2026-04-29-deterministic-price-drift`).

### 10.5 Sanity baselines (mirror slice-7 §7.4)

- **Pools frozen at cap** (decay = 0, refill = 0, stocks at cap, demand at cap): every read produces base_price ± perturbation. Gate 1 should FAIL hard (no pool motion). Gate 2 should FAIL hard (spreads ~ perturbation noise). Sanity: the harness can detect the no-motion case.
- **Pools drained instantly each tick** (decay = 999, refill = 0, mass-buy in warm-up): pools stuck at 0 / cap. Gate 1 should FAIL hard (pinned at corners, not mid-band). Sanity: the harness can distinguish "pools pinned at corner" from "pools pinned at neutral."
- **Existing slice-7 multipliers** (no 5x bump, slice-7 caps): gate 1 likely fails because per-buy curve sensitivity is too high (slice-8 §5.8 reasoning); harness output documents this as the *reason* for the 5x bump.

### 10.6 Sweep parameters

- `DEMAND_DECAY_MULT_PRODUCER`: sweep `[0.1, 0.2, 0.4, 0.8]`.
- `DEMAND_DECAY_MULT_CONSUMER`: sweep `[3.0, 5.0, 8.0, 12.0]`.
- `DEMAND_CAP_MULT_PRODUCER`: sweep `[0.1, 0.25, 0.5]`.
- `DEMAND_CAP_MULT_CONSUMER`: sweep `[2.0, 4.0, 8.0]`.
- `STOCK_CAP_MULT_PLENTIFUL`: sweep `[12.0, 20.0, 30.0]` (the 5x bump, ±50%).
- `gold`: `[120, 200, 400]` -- gating tier 200, mirrors slice-6/7.
- `seeds`: `0..199` (200; matches slice-7's harness seed budget).

Total block count: 4 * 4 * 3 * 3 * 3 * 3 = 1296 blocks. **Too large.** Restrict to the ratification-candidate corner: hold `STOCK_CAP_MULT_PLENTIFUL=20.0` (locked at this slice), sweep only the four demand multipliers + gold. That gives 4 * 4 * 3 * 3 * 3 = 432 blocks -- still ~10-30 minutes wall-clock. Engineer's call on whether to further restrict to `DEMAND_CAP_MULT_PRODUCER=0.25` and `DEMAND_CAP_MULT_CONSUMER=4.0` fixed and sweep only the two decay multipliers (=4*4*3 = 48 blocks).

### 10.7 Output format

```
=== slice-8 pricing-v2 measurement (decay=(producer=0.2, consumer=5.0), demand_cap=(producer=0.25, consumer=4.0), gold=200) ===
seeds=200, warmup=20, measurement_ticks=8

gate 1 (pools breathe):       42.3%   [floor: >= 40%]   PASS
gate 2 (spread > 2*perturb):  31.1%   [floor: >= 30%]   PASS
gate 3 (determinism replay):  100/100 seeds              PASS

verdict: PASS at this multiplier set, gold=200.

pool fill histogram:
  supply: drained 18%, mid 47%, saturated 35%
  demand: drained 22%, mid 41%, saturated 37%

spread histogram (% of base_price, profitable routes only):
  < 5%   : 12%
  5-10%  : 28%
  10-20% : 38%
  > 20%  : 22%
```

The histograms are diagnostics for failed runs; on PASS they document the run's character.

### 10.8 Process gate (binding for Engineer)

1. Author multipliers per §5.7 / §6.
2. Run the harness; capture verdict log on disk (`godot/tools/pricing_v2_verdict.txt` -- Architect picks).
3. If gate 1 + gate 2 + gate 3 all PASS at gold=200: ship.
4. If gate 3 FAIL: determinism is broken. **Hard stop.** Re-derive perturbation seed; do not negotiate.
5. If gate 1 FAIL: pools are pinned. Tune decay rates (raise consumer decay, lower producer decay) and re-run.
6. If gate 1 PASS, gate 2 FAIL: pool differentials are too symmetric. Hand back to Designer with the histogram attached -- the curve mechanic alone is the slice's value (Director call required).

Harness is source of truth for ship/no-ship on gates 1 and 3. Gate 2 outcomes feed Director-level scope decisions.

## 11. Open questions

### 11.1 For Director

- **(1) Initial demand-pool fill state on v5 -> v6 migration.** When an existing slice-7 save loads under slice-8 code, what value does `demand_pools[good_id]` get?
  - **(a) Saturated (= 0).** Maps to "demand has been fully met -- player saved their world after buying out everywhere; selling now will be at floor prices everywhere." First-session-after-update feel: "selling is impossible everywhere; I have to wait for demand to recover." Punishing but informative.
  - **(b) Target (= demand_cap).** Maps to "demand is at full unmet level -- selling now will be at high prices everywhere." First-session feel: "everywhere will pay top dollar; great, let me dump my cargo." Pleasant but hides the slice's mechanic (no demand-state texture on the upgrade boundary).
  - **(c) Empty (= 0)** -- same as (a), different framing. Identical mechanically.
  - **(d) Mid (= demand_cap / 2).** Neutral start; sell prices are at base ± perturbation everywhere. First-session feel: "neutral; sell prices vary modestly; pool state will diverge as I trade." The blandest read but the most honest: the world-state hasn't been touched by demand activity yet.
  - **Designer leans (b) target.** Reasoning: the v5 -> v6 boundary is the player's first contact with the demand pool; loading them into a saturated state means they have to wait many travel ticks before any sell is at meaningful price, which feels like the upgrade *broke* selling. Loading at target gives them an immediate sense of "demand is real and varies by node tag" via differing sell prices across producer/consumer nodes (different `demand_cap`s). Trade-off: the player gets one free leg of "everywhere is at peak sell price" before pool state catches up to their actions. The slice-7 supply migration set stocks=cap (full) for the same reason -- fresh-feeling-but-mechanically-honest.
  - **Director's call.** The decision shapes the upgrade UX significantly.

- **(2) Harness gate ratification.** §10's gate 1 (40% pool-mid-band fraction), gate 2 (30% spread > 2*perturbation), gate 3 (100% determinism replay). These are Designer's read of "what does the curve need to produce to count as legible." Director ratifies whether these floors are (a) too generous (slice ships under-tuned), (b) too strict (slice can't ship), or (c) miscalibrated (different metrics needed).

- **(3) Bias retirement scope.** §5.3 retires bias from the price formula but keeps it as the tag-derivation seed. Director should ratify: is bias's role *future-narrowed* to "only tag-derivation" -- meaning future slices can refactor it out entirely once tag derivation has a different seed -- or is bias still considered "the structural-identity number, just unused in pricing right now"? The first framing makes bias a deprecation target; the second keeps it as design-vocabulary.

- **(4) Salt's profitability under pools (§5.10).** Salt fails the per-unit P2 predicate at base_price=7. Slice-8 ships salt as "long-edge-only good." If the harness reports zero profitable salt routes across all seeds, this becomes a slice-8.5 question: retune salt's base or accept salt is a fill-cargo good. **Surface to Director only if harness reports zero profitable salt routes**; otherwise, salt's role as "occasional long-edge filler" is fine.

### 11.2 For Designer to flag (carryover-shaped)

- **(5) Sell-side stranded predicate.** Slice-7 §10 deferred "sell-side cap" to a future slice. Slice-8 introduces a sell-side cap implicitly (demand pool 0 = cannot sell). If `DeathService.is_stranded` finds the player at a node with all goods at `demand_pool=0` AND insufficient gold to travel out, is that a stranded death? Designer's read: yes, mirrors the existing stranded predicate exactly (the player cannot afford to leave AND cannot raise gold by selling). The check shape doesn't change; it just consults pool-driven sell prices instead of stored prices. **Verify in code review.**

### 11.3 For Architect

- **(6) `prices` field disposition (§3.3).** Drop entirely (Designer leans this) vs keep as per-tick cache. Affects save schema, NodePanel access pattern, and B1 predicates referencing prices.
- **(7) `DemandSystem` placement.** Mirror `StockSystem` exactly (separate Node under main.tscn, `setup(world)` + tick listener). Designer leans yes -- the symmetry makes the structure obvious. If Architect prefers folding both pool systems into one `PoolSystem`, that's defensible too; Designer's lean is "split for evolvability, like StockSystem and PriceModel were split at slice-7."
- **(8) `PriceModel` reshape to query helper.** PriceModel becomes stateless (no `_world` field, no tick listener). Helpers `buy_price_for(world, node, good_id)` and `sell_price_for(world, node, good_id)` become static methods (or instance methods on a no-state Node). Designer leans static methods on the existing PriceModel script for minimal disruption to call sites; Architect picks.
- **(9) Migration helper placement.** `_migrate_v5_to_v6` static method on `WorldState`, mirroring `_migrate_v4_to_v5`. Mechanically identical. Architect ratifies.
- **(10) Demand-cap and demand-decay-rate freezing.** Per `2026-05-03-slice-7-caps-rates-frozen-at-gen-time`, both should be persisted (not recomputed on load). Designer leans yes; Architect ratifies.

### 11.4 For Decision Scribe (post-ratification)

- **(11) Supersession of slice-3 decisions.** Slice-8 supersedes `2026-05-02-slice-3-mean-reversion-added` (mean-reversion has no role under pools). Slice-8 amends `2026-05-02-slice-3-bias-multiplicative-anchor` (bias is no longer a price-formula input; bias remains as tag-derivation seed). Slice-8 amends `2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation` (PriceModel no longer mutates state, so the disjoint-mutation contract no longer applies to PriceModel; it now applies to StockSystem and DemandSystem). DS should write supersession / amendment notes when slice-8 ratifies.
- **(12) New decisions to log at slice-8 close.** "Pull-driven prices" (the trigger for §3.3(a)). "Demand-pool symmetry to supply-pool" (the §5.7 multiplier inversion). "5x supply cap bump" (the §5.8 retune). "Bias retires from price formula, kept as tag seed" (the §5.3 amendment). Each gets its own decision file under the standard naming scheme.

## 12. Lessons placeholder

To be filled post-harness, mirroring `slice-7-production-caps-spec.md` §13. Sections expected:

- **12.1** -- structural finding from the harness sweep. Did gate 1 PASS at the §6 multipliers? Gate 2? Gate 3? Where in the demand-decay sweep did pools start to pin?
- **12.2** -- what the slice actually delivers vs. what the spec promised. Did "the world's economic state is the game's primary texture" land in the player's read of the new node panel? (This is a UX question, validated post-implementation by play-feel, not by the harness.)
- **12.3** -- the salt question. Did the harness report salt as profitable on >0 routes? On what fraction? If zero, slice-8.5 retunes; if non-trivial, salt's long-edge role is validated.
- **12.4** -- mechanics that would unlock the next deepening. Per-good rot (slice-7 §10 carryover); multi-leg commitment (slice-7 §10 carryover); price elasticity beyond the linear curve (slice-8.x candidate). Cargo retune (slice-8.5 -- a known follow-on per Critic).
- **12.5** -- process lessons. Did pull-driven prices simplify or complicate? Did the determinism gate catch a bug the obvious tests missed? Did the migration's initial-demand-fill choice produce the expected upgrade UX?

The harness is binding for the Engineer (§10.8); §12 is the post-mortem after Engineer reports the verdict and Reviewer ships.

---

## Hand off to Architect

Architect must ratify (or override with reasoning) the calls in §11 before Engineer touches code. The five most load-bearing:

1. **`prices` field disposition (§3.3 / §9 row).** Drop entirely (Designer's lean) vs keep as per-tick cache. Affects save schema, NodePanel access shape, B1 predicates.
2. **`DemandSystem` as separate Node, mirroring `StockSystem`.** Vs fold supply+demand into one `PoolSystem`.
3. **`PriceModel` reshape to stateless query helper.** Static methods vs instance methods on existing Node. Drops tick subscription either way.
4. **`NodeState` field shape for demand pools.** Four parallel dicts (Designer's lean -- mirrors slice-7 supply shape) vs record-per-good Resource.
5. **Migration helper `_migrate_v5_to_v6` static on WorldState.** Mirrors `_migrate_v4_to_v5`. Trivial; ratify by inspection.

The harness (§10) is binding for Engineer: the multiplier table and the perturbation magnitude cannot be committed to disk until gate 1 + gate 2 + gate 3 PASS verdict is on disk. Designer's per-multiplier rationale (§5.7, §6) is the *why*; the harness verdict is the *whether*.

Designer is unblocked. Spec is binding for Engineer once Architect ratifies §11.6-§11.10. Numbers in §6 are starting values backed by the §10 harness; finer tuning happens in playtest. Director ratification of §11.1 (initial demand fill state) and §11.2 (gate floors) lands before the harness run, not after -- both feed into the migration code and the gate predicates respectively.
