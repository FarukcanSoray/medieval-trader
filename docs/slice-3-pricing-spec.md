# Medieval Trader -- Slice 3 (Pricing) Spec

> **Ratified frame (2026-05-02):** Director scoped slice-3 to give prices identifiable structure the player can read. Critic ratified day-1 kernel (volatility, bias generation, drift re-centring, free-lunch predicate) and day-2 in-slice (producer/consumer tags, HUD labels). Slice-3.x carries the topology-revisit owed by `2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice`.
>
> Determinism contract from `2026-04-29-deterministic-price-drift` is preserved: every pricing input is reproducible from `world_seed` (and `tick`, for drift). Schema bump from 2 to 3 is allowed; trigger named below per `2026-05-02-slice-2-no-schema-bump-trigger-named` precedent.

## 1. Pattern reference

This is **Patrician III's regional production zones** with a **per-good volatility dial** lifted from *Port Royale 2*. Patrician's map gives each city a structural producer/consumer identity (Hamburg makes beer, Riga sells timber); prices oscillate around that identity, not around a global mean. Slice-3 deviates in three places: (1) we have no production chains -- bias is a pure price anchor, no inventory model behind it; (2) volatility is per-good identity (wool jitters, cloth holds steady), not per-city; (3) bias is authored at world-gen from `world_seed` only, not driven by simulated supply that the player could perturb (that's slice-3.x's job, deferred). The closest *exact* ancestor is X3's economy seed in spirit -- a deterministic, hand-shaped landscape -- but the math is Patrician.

## 2. Core loop change

**Before slice-3:** prices drift symmetrically around `base_price`. The player wandered until two nodes happened to be on opposite sides of the drift envelope, then ran a round trip. There was nothing to read in advance -- prices were noise. The careful-merchant pillar leaned on memory of recent ticks, not structural identity.

**After slice-3:** the player arrives at Hillfarm, sees `wool: 8g (source)` on the node panel and `cloth: 22g (sink)` at Rivertown, and knows -- before any tick passes -- that the wool->cloth round trip has structural pressure on it. Drift still adds the moment-to-moment "is the spread wide enough right now" question, but the player is no longer hunting for a spread; they're timing one they can already see. The kernel (arbitrage profit perpendicular to travel cost) gains a second axis: spread width is bias-driven (structural) plus drift-driven (transient). The player learns which routes exist by reading the map, not by sampling it.

## 3. Save format contract changes

Diff against `slice-spec.md` §3. **`schema_version` bumps 2 -> 3.**

**Trigger (named, per `2026-05-02-slice-2-no-schema-bump-trigger-named` precedent):** *"regional bias and producer/consumer tags added to NodeState."* Both clauses of the bump rule fire -- new required fields on an existing per-node Resource, plus semantic reinterpretation of `prices` (anchored to `base_price * (1 + bias)` instead of `base_price`).

```
{
  "schema_version": 3,                                  // was 2
  "world_seed": <int>,
  "tick": <int>,
  "trader": { ... unchanged ... },
  "nodes": [
    { "id": <string>, "name": <string>, "pos": [<float>, <float>],
      "prices": { "<good_id>": <int> },
      "bias":   { "<good_id>": <float> },               // NEW: per-good drift anchor multiplier
      "produces": [ "<good_id>", ... ],                 // NEW: tag list, day-2 in-slice
      "consumes": [ "<good_id>", ... ]                  // NEW: tag list, day-2 in-slice
    }
  ],
  "edges":   [ ... unchanged ... ],
  "history": [ ... unchanged ... ],
  "dead": false,
  "death": null
}
```

**`from_dict` migration policy: discard.** Slice-2 saves are rejected, the corruption toast fires, and a new world is generated. Reasoning: forward-filling `bias` to all-zero produces a flat-bias world that *runs* but silently violates Pillar 1 (no structural reads available -- the player learns the new system on a save where it has nothing to teach). The toast precedent (`2026-05-02-slice-2-followup-corruption-toast-all-load-branches`) already covers schema mismatch as one of the discard branches; this is the same code path. One-line user-visible message: `"Save discarded: schema upgraded. New world generated."` ASCII only.

## 4. Inputs/outputs per system

Mirrors `slice-spec.md` §4. **Changed rows: Map (gen), Price model.** **New row: Tags / legibility.** Unchanged rows omitted (Travel, Save, Aging, Death, Death screen, Goods catalogue identity columns).

| System | Reads | Writes | Tick events |
|---|---|---|---|
| **Map (gen)** | `world_seed`, `goods[].volatility`, `MIN_EDGE_DISTANCE`, `TRAVEL_COST_PER_DISTANCE` | `nodes` (incl. `bias`, `produces`, `consumes`), `edges` (once at world birth) | none after gen |
| **Price model** | `nodes[].prices`, `nodes[].bias`, `goods[].volatility`, `goods[].base_price`, `tick` | `nodes[].prices` | on every tick |
| **Tags / legibility** (NodePanel only) | `nodes[].produces`, `nodes[].consumes`, `goods[].display_name` | nothing | renders on `tick_advanced` and `state_dirty` (existing subscriber pattern) |

**Unchanged:** Travel reads `nodes[].bias` for nothing -- travel cost stays edge-distance-only. Bias does not feed travel cost. Save just ferries the new fields through `to_dict`/`from_dict`.

## 5. Rules

### 5.1 Volatility per good

New field on `Good`: `volatility: float`, range `0.0`-`1.0`, default unset (asserts on load). Replaces `PriceModel.DRIFT_FRACTION` as the per-tick drift envelope. The constant remains as a fallback only for the asserts in tests; production code reads `good.volatility`.

### 5.2 Bias representation -- ANSWER (your call from Director's question 1)

**Bias is a multiplicative anchor on `base_price`.** Per node, per good: `bias[good_id]: float` in the range `[bias_min, bias_max]` (see §6). The drift formula's anchor (the value drift walks toward) is `base_price * (1 + bias)`. Example: wool's `base_price = 12`, Hillfarm's `bias["wool"] = -0.30` -> Hillfarm's anchor is `12 * 0.70 = 8.4`, rounded to `8` for display. The price drifts around 8, not around 12.

**Why multiplicative, not additive or anchor-walk:**
- **Multiplicative scales with good identity.** A `bias = -0.3` on a 12g good means `-3.6g`; on a 100g good (future slice) it means `-30g`. Additive offsets would either be tiny on cheap goods or implausible on expensive ones, and would need a per-good range. Multiplicative is one knob that travels.
- **Integer-math is preserved at the boundary.** Bias is float internally (during gen and during drift-anchor computation); `prices[good_id]` stays `int` everywhere it's read or written. Rounding happens once, at the point where the drifted float becomes the new int price (see §5.4). The save format stores `bias` as float and `prices` as int -- consistent with slice-spec §3's "ints only, no floats" intent for prices.
- **Floor/ceiling behaviour stays clean.** `floor_price` and `ceiling_price` (per `2026-04-29-rename-floor-ceiling-price`) are absolute caps on the *output* int. The anchor can be near the floor (low-bias source node) without the math becoming brittle -- the clamp catches the tail of the distribution, not the centre.
- **Drift-target-anchor (rejected):** moves the system from "price walks around a moving fixed point" to "price chases a target." Adds a smoothing parameter (how fast does it chase?), which is a third tunable on top of volatility and bias. Not earned by the slice. Rejected.

### 5.3 Bias generation algorithm

`WorldGen.generate()` runs one new authoring pass after node placement and edge construction, before `_seed_prices`. Pseudocode:

```
func _author_bias(effective_seed: int, nodes: NodeState[], edges: EdgeState[],
                  goods: Good[], travel_cost_per_distance: int) -> void:
    rng.seed = hash([effective_seed, "bias"])
    var min_edge_distance: int = _shortest_edge_distance(edges)  // computed; not const
    var max_spread_gold: int = min_edge_distance * travel_cost_per_distance
    // Free-lunch predicate (see §5.5): worst-case spread < min_edge * cost.
    // For each good, the worst-case bias spread is (bias_max - bias_min) * base_price.
    // We choose per-good (bias_min_g, bias_max_g) so that
    //     (bias_max_g - bias_min_g) * base_price + 2 * volatility * ceiling_price
    //     < max_spread_gold
    // (the +2*volatility*ceiling term covers worst-case drift on top of bias.)
    // If the inequality cannot be satisfied with bias_max_g - bias_min_g >= MIN_BIAS_RANGE,
    //     ASSERT and let the seed-bump retry loop in WorldGen pick it up.
    for good in goods:
        var allowed_range: float = _solve_bias_range(good, max_spread_gold)
        if allowed_range < MIN_BIAS_RANGE:
            assert(false, "bias: free-lunch unsatisfiable; seed bump")
        for node in nodes:
            node.bias[good.id] = rng.randf_range(-allowed_range/2, +allowed_range/2)
    // Day-2: producer/consumer tags derived from bias extremes (see §5.6).
```

**Inputs:** RNG seeded on `hash([effective_seed, "bias"])` -- new sub-seed namespace, sibling of `"place"`, `"names"`. The list of nodes (post-placement), the list of goods, the existing `edges` (for shortest-distance lookup), and `TravelController.TRAVEL_COST_PER_DISTANCE` as a constant input (currently `3` per `travel_controller.gd` references; needs to be exposed -- see §9).

**Output:** `node.bias: Dictionary[String, float]` populated for every (node, good) pair. Empty bias dict at any node is invalid; assert.

**Constraint:** the free-lunch predicate (§5.5) holds across all edges by construction. Determinism: same seed -> same bias dict, byte-for-byte.

### 5.4 Updated drift formula

Rewrites `slice-spec.md` §5's price drift formula:

```
anchor       = round(good.base_price * (1.0 + node.bias[good_id]))
delta        = round(rng.randf_range(-good.volatility, +good.volatility) * anchor)
mean_revert  = round((anchor - old_price) * MEAN_REVERT_RATE)
new_price    = clamp(old_price + delta + mean_revert,
                     good.floor_price,
                     good.ceiling_price)
where rng.seed = hash([world_seed, tick, node_id, good_id])  // unchanged
```

Three changes against the slice-2 formula:
- `anchor` replaces `old_price` as the centring quantity inside `volatility * X`. Drift magnitude scales with the *biased* anchor, not the current price -- this prevents biased-low nodes from amplifying their volatility upward into the unbiased band.
- Mean-reversion term (`MEAN_REVERT_RATE`, default `0.10`) pulls the price toward the anchor each tick. Without it, a sequence of same-sign volatility samples can walk a node's price all the way to the floor or ceiling and pin it there. With it, the structural identity is recovered over a few ticks. **This is the structural fix the slice's whole point depends on.**
- `floor_price` / `ceiling_price` clamp is unchanged -- they are absolute caps, not bias-relative. A node biased low never exceeds the global ceiling; a node biased high never undercuts the global floor.

The `hash([world_seed, tick, node_id, good_id])` seed is preserved verbatim per `2026-04-29-deterministic-price-drift`. No salts, no namespacing -- existing slice-2.5 surveys with replayed seeds will produce different prices (because the drift function changed), but the determinism contract holds going forward.

### 5.5 Free-lunch predicate -- ANSWER (your call from Director's question 2)

**Choice: (a) edge-length-conditional bound, enforced at gen-time per good, with assert + seed-bump on failure.**

Reasoning, kernel-first:
- **(b) push-back to generator (`MIN_EDGE_DISTANCE` raise).** Real, but indirect. It treats free-lunch as a topology problem when it's actually a coupling problem (price * distance vs cost). A `MIN_EDGE_DISTANCE = 3` would solve current free-lunch but constrain future maps unnecessarily, and the carryover decision specifically owes a *topology revisit with live pricing in hand* -- that's slice-3.x's job, not slice-3's.
- **(c) accept short-edge free lunch globally.** Violates Pillar 1 directly. If the player learns there's a one-edge round trip that always wins, the kernel collapses on that edge. Not negotiable.
- **(a) edge-length-conditional bound.** Lives in pricing (Director's frame: "Free-lunch lives in price model (bias bounds), not in generator"). Generator stays free to produce whatever topology it wants; pricing constrains itself to the topology. The cost is a per-good bias range that may be tighter on dense maps than on sparse ones, which is a *feature* (the player's spread budget scales with how spread-out the map is).

**Predicate (per good `g`, must hold at gen time):**

```
worst_case_spread(g) = (bias_max_g - bias_min_g) * g.base_price
                       + 2 * g.volatility * g.ceiling_price
worst_case_spread(g) < shortest_edge_distance * TRAVEL_COST_PER_DISTANCE
```

> **Implementation note (2026-05-02):** `_solve_bias_range` returns the maximum `R` such that `R * base_price + 2 * volatility * ceiling_price <= max_spread_gold` (the headroom math `headroom / base_price` is boundary-inclusive). This admits R values where `worst_case_spread = max_spread_gold` exactly, not strictly less. In practice float arithmetic makes exact equality unlikely; the asymmetry is intentional (boundary-inclusive on the floor: `headroom <= 0.0 -> 0.0`; boundary-inclusive on the ceiling: equality accepted). If a future tuning pass finds an exact-equality edge case in playtest, tighten with an explicit epsilon.

The volatility term covers the case where two nodes are biased at opposite extremes *and* drift to opposite extremes simultaneously -- the worst case the determinism math can produce. The shortest edge in the map is the binding constraint; if it passes, all longer edges pass with margin. With `MIN_EDGE_DISTANCE = 2` (current) and `TRAVEL_COST_PER_DISTANCE = 3`, the budget per good is `< 6 gold` of worst-case spread. Numbers in §6 are sized to this.

**Failure mode:** if `_solve_bias_range` cannot find a range satisfying the predicate with `>= MIN_BIAS_RANGE` (so bias has *some* signal), `assert(false)` fires and the seed-bump retry loop in `WorldGen.generate` catches it (existing pattern -- see `world_gen.gd:33` MAX_SEED_BUMPS). Five bumps exhausted -> `push_error` and abort, same as connectivity failure today.

### 5.6 Producer/consumer tag generation (day-2 in-slice)

**Tags are a player-readable label of bias, not a separate driver.** `produces` / `consumes` are derived from the authored bias values; they don't drive bias and they don't appear in any pricing math. They exist only for the HUD.

Generation rule, per node, per good:

```
bias_value = node.bias[good_id]
if bias_value <= -PRODUCER_THRESHOLD:    node.produces.append(good_id)
if bias_value >= +CONSUMER_THRESHOLD:    node.consumes.append(good_id)
// PRODUCER_THRESHOLD == CONSUMER_THRESHOLD == 0.5 * (allowed_range_for_good / 2.0)
// (i.e. bottom/top half of the per-good bias range, where bias is drawn from
// [-allowed_range/2, +allowed_range/2]; threshold of 0.25 * allowed_range)
```

> **Spec correction (2026-05-02):** earlier draft read `0.5 * allowed_range_for_good` (without the `/2.0`). Bias is drawn from `[-allowed_range/2, +allowed_range/2]`, so the literal `0.5 * allowed_range` would be the *minimum possible* bias and would tag essentially zero nodes. Correct value is half of the half-range (`0.25 * allowed_range`). Implementation in `world_gen.gd:_author_bias` matches the corrected pseudocode.

A node can produce one good and consume another. A node can be neither (mid-band bias on every good). A node cannot both produce and consume the same good (the rule's mutual-exclusive by construction; assert on it for safety).

### 5.7 Worked arbitrage example (replaces slice-spec §5's example)

Setup:
- Good: wool. `base_price = 12`, `floor_price = 5`, `ceiling_price = 25`, `volatility = 0.10` (10%, midpoint of slice-spec's 5%-15% band).
- Hillfarm: `bias["wool"] = -0.30` (producer; tag `wool source`). Anchor = `12 * 0.70 = 8.4` -> 8.
- Rivertown: `bias["wool"] = +0.30` (consumer; tag `wool sink`). Anchor = `12 * 1.30 = 15.6` -> 16.
- Edge distance = 4. Travel cost = `4 * 3 = 12`.

**Profitable case (mid-band drift, both directions favourable):**
- Tick 0: Hillfarm wool = 8, Rivertown wool = 16. Spread = 8.
- Buy 10 wool at Hillfarm: -80g. Travel to Rivertown: -12g. Sell at 16: +160g. Travel back: -12g. Net **+56g over 8 ticks**.

**Marginal case (drift compresses spread mid-trip):**
- Tick 0: Hillfarm 8, Rivertown 16. Buy 10 at Hillfarm: -80g. Travel.
- Tick 4 (arrival at Rivertown): drift sample drove Rivertown to 13 (within `volatility * anchor = 0.10 * 16 = 1.6`, plus mean-reversion pull, so 13 is plausible after 4 ticks of bad samples). Sell at 13: +130g. Travel back: -12g. Net **+26g**. Still profitable but visibly thinner -- the kernel bites.

**Unprofitable case (worst-case timing):**
- Tick 0: Hillfarm 9 (drifted up), Rivertown 14 (drifted down). Player misreads, commits anyway.
- Buy 10 at Hillfarm: -90g. Travel: -12g. Sell at 13: +130g. Travel back: -12g. Net **+16g over 8 ticks**, or **2g/tick** -- below the wage of just sitting (wait, the player can't sit; they're losing time and gold every tick they're not arbitraging).

**Free-lunch check (the predicate's binding case):**
- Suppose the same wool numbers but on the shortest edge (distance = 2, travel cost = 6).
- Worst-case spread per the predicate: `(0.30 - (-0.30)) * 12 + 2 * 0.10 * 25 = 7.2 + 5.0 = 12.2`. **Predicate: 12.2 < 6? No.** This setup violates free-lunch on a distance-2 edge.
- Resolution at gen time: `_solve_bias_range` would tighten wool's bias range to `~0.0` (no signal) on a graph where the shortest edge is 2 and travel cost is 3. `MIN_BIAS_RANGE` (say `0.20`) would not be met; assert fires; seed bump.
- This is *exactly* the carryover from `2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice` showing up. The slice-3 design **catches it at gen time** rather than letting it surface at play time.

## 6. Numbers (tuning ranges)

Mirrors `slice-spec.md` §6. New rows below the existing slice-2 rows.

| Knob | Starting value | Range | What it tunes / symptoms |
|---|---|---|---|
| (slice-2 knobs unchanged) | -- | -- | per slice-spec §6 |
| `volatility` (wool) | **0.10** | 0.05-0.15 | High = drift dominates structural reads (kernel feels gambling-like, Pillar 1 risk); low = node identity calcifies, drift becomes irrelevant. `[needs playtesting]` |
| `volatility` (cloth) | **0.06** | 0.03-0.10 | Cloth is the steadier good (slice's good-identity contrast). High = pair becomes too symmetric; low = cloth becomes a one-route trade with no timing. `[needs playtesting]` |
| `bias_min`, `bias_max` (per-good envelope before predicate trim) | **-0.40 / +0.40** | -0.50 to +0.50 | Outer bound on author's intent; predicate tightens per-good as needed. Higher = more dramatic regional identity but more free-lunch failures (more seed bumps). `[needs playtesting]` |
| `MIN_BIAS_RANGE` | **0.20** | 0.10-0.30 | Floor on per-good range after predicate trim. Below this we'd be authoring a flat-bias good (no structural read) -- assert and seed-bump instead. |
| `MEAN_REVERT_RATE` | **0.10** | 0.05-0.20 | High = price snaps back to anchor fast (drift becomes cosmetic); low = drift can pin price at the floor/ceiling for many ticks (structural read becomes unreliable). `[needs playtesting]` |
| `PRODUCER_THRESHOLD` / `CONSUMER_THRESHOLD` | **0.5** (of per-good range) | 0.4-0.7 | Fraction of authored bias range that earns a tag. Lower = more tags (some on near-mid nodes -- noise); higher = fewer tags (some real producers go unlabelled). `[needs playtesting]` |
| `TRAVEL_COST_PER_DISTANCE` (referenced from `travel_controller.gd`) | **3** | unchanged | Slice-2 value. Kept; bias predicate is sized against it. If this changes, predicate budget changes. |
| `MIN_EDGE_DISTANCE` | **2** (unchanged from `world_gen.gd:16`) | unchanged | Slice-2.5 value. Slice-3 does **not** raise this -- the carryover topology-revisit may, in slice-3.x, but slice-3 itself uses (a) above. |

`bias_min` / `bias_max` are float; predicate-trimmed ranges are computed at gen time, not stored.

## 7. Feedback (programmer-art budget)

ASCII only. No tweens, no colour, no audio.

**Node panel** -- the slice's one new UI surface. Existing layout: shows current node name + good prices. New rendering, per good, per node:

```
Hillfarm
  wool   8g   (source)
  cloth 19g

Rivertown
  wool  16g   (sink)
  cloth 18g
```

Tag syntax: `(source)` or `(sink)`. ASCII parens, lowercase, single word. **Not** `(wool +)` (cryptic) or `[wool source]` (square brackets read as UI controls). **Not** `wool: 8g (-3)` -- the bias number does **not** surface in the UI. Players read the tag, not the multiplier. Reasoning: the tag is the entire abstraction -- exposing the bias value invites the player to compute `base_price * (1 + bias)` themselves, which is one inferential step the slice doesn't earn. If playtesting shows the tag isn't legible enough, escalate to numbers in slice-3.x.

**No tag** -- a node with neither produces nor consumes for a given good shows just `wool 12g` with no parens. This is normal; not every node is interesting in every good.

**Travel, buy, sell:** unchanged from slice-2. Modal text identical. Greyed buttons identical. No bias-aware UI on the travel side.

**Bias does not animate.** `produces` and `consumes` are immutable post-gen; the tag rendering is one read on `_ready` of NodePanel and re-renders only because the surrounding panel re-renders on tick. No special invalidation logic.

## 8. Edge cases and failure modes

- **Bias generator cannot satisfy free-lunch.** `_solve_bias_range` returns `< MIN_BIAS_RANGE` for some good. **Assert; seed bump.** `WorldGen` already has a 5-bump retry loop (`MAX_SEED_BUMPS`); add bias-failure as a third trigger alongside placement starvation. After 5 bumps exhausted, `push_error` and abort -- same terminal behaviour as connectivity failure. **Test:** force a topology where `shortest_edge = 2`, `travel_cost = 3`, `wool.volatility = 0.10`, `wool.ceiling_price = 25`; predicate budget is 6; volatility-only term alone is 5; bias range squeezes to `< 0.10`; assert; bump.

> **Spec correction (2026-05-02):** earlier draft asserted "expect bump succeeds within 1-2 attempts on a 7-node random graph." Headless measurement (`tools/measure_bias_aborts.gd`, 1000 seeds, fallback rect 468x664) **disproved this**: at `MIN_EDGE_DISTANCE = 2` the abort rate was **70%** (700/1000 seeds exhausted all 5 bumps). Both wool and cloth fail simultaneously on distance-2 edges, and the bump loop does not recover often enough. **Resolution:** `MIN_EDGE_DISTANCE` raised from 2 to 3 (see [[2026-05-02-slice-3-min-edge-distance-3-pulled-forward]]). Re-measurement at floor=3: **0% abort rate**.
- **Old (slice-2) save loaded after schema bump.** `from_dict` returns null on `schema_version != 3`. SaveService corruption-toast path fires. Toast text: `"Save discarded: schema upgraded. New world generated."` New world generates on next boot. **Test:** load slice-2.5 survey saves on slice-3 build; expect toast on every one.
- **Node with neither `produces` nor `consumes`.** Valid. Mid-band bias on every good is a real and intended outcome. NodePanel renders without parens. **No assert.**
- **Two nodes biased identically for a good (kernel collapse risk).** Possible by RNG accident. Spread on that pair is drift-only, same as slice-2. The graph as a whole still has structural pressure on *other* edges, so the kernel doesn't collapse globally. **Let it ride** -- no rejection logic. The slice's whole-map worst-case is `worst_case_spread(g)`; pairwise minimums are not bounded above zero. (If playtest shows two-node-flat-bias hurts on small graphs, slice-3.x revisits.)
- **Schema-3 save with slice-3 numerics changed mid-development.** Volatility, bias bounds, mean-revert rate are tuning knobs, not schema. Saves remain loadable; the world's *behaviour* changes on next tick. Acceptable -- this is the standard tuning workflow.
- **`bias` dict missing a good listed in `Game.goods`.** Save/world is corrupt (a slice-3 save should always have bias for every good). `from_dict` rejects -> toast -> regen. Same code path as schema mismatch.
- **Web-export-specific (HTML5).** None new. Bias is gen-time data, no per-tick allocations beyond slice-2 (RNG-per-draw pattern preserved). IndexedDB flush still covers the schema-3 save. **No new web-export concern.**
- **Empty `goods` array at gen time.** Existing slice-2 contract: `WorldGen.generate` is called with the loaded goods list. Empty list -> zero work in `_author_bias`, zero work in `_seed_prices`, world generates without prices. Slice-2 doesn't assert on this and slice-3 doesn't either; it's a developer-config error and an empty goods list will surface as an immediate buy/sell UI break. **Not in slice scope to harden.**
- **`good.volatility` unset (0.0).** Asserts on load via the goods loader (`Game._load_goods` -- existing seam). A volatility-zero good would have zero spread budget; predicate would still pass trivially but the good would behave like a fixed price. Author error; assert is enough.
- **History entries from before the bump.** Slice-2 saves are discarded entirely, so this never happens. No partial-load path.

## 9. Integration touch points

Updates `slice-spec.md` §9. New ownership lines below; existing ownership unchanged.

| Touch point | Systems involved | Owner |
|---|---|---|
| **Bias authoring** | `WorldGen` (writes once at gen), `PriceModel` (reads each tick), `NodePanel` (reads on render via tags) | **`WorldGen`** authors. **`NodeState`** owns the field. After gen, bias is immutable -- no system mutates it. |
| **Volatility per good** | `Good` (data), `PriceModel` (consumer), `WorldGen._author_bias` (consumer for predicate) | **`Good`** owns. Hand-authored on `.tres`. PriceModel and WorldGen are pure readers. |
| **Free-lunch predicate** | `WorldGen._author_bias` (enforces at gen time), nothing at runtime | **`WorldGen`**. Predicate is gen-time only; PriceModel does not re-check it. If the predicate held at gen, drift cannot violate it (math). |
| **Tag rendering** | `NodePanel` (consumer), `NodeState.produces`, `NodeState.consumes` | **`NodePanel`**. Tags are derived data on the resource; rendering is the panel's job. No tag invalidation logic -- tags are immutable post-gen. |
| **`TRAVEL_COST_PER_DISTANCE` exposure to WorldGen** | `TravelController` (defines), `WorldGen` (reads at gen for predicate) | **Architect call** -- this is currently a private constant in `travel_controller.gd`. Must be lifted to a shared location (e.g. `WorldRules.gd` -- already referenced from `travel_controller.gd:20, 33, 71, 76`). One source of truth, two consumers. |

The four cross-system signals from slice-2 (`tick_advanced`, `gold_changed`, `state_dirty`, `died`) are unchanged. No new signals. Bias does not trigger any signal -- it's gen-time + read-only thereafter.

## 10. Open questions

- `[needs playtesting]` All numbers in §6, especially `volatility_wool`/`volatility_cloth` ratio, `MEAN_REVERT_RATE`, and the `0.5`-of-range tag threshold. The bias-vs-volatility split is the slice's main tuning surface and cannot be set from desk -- it's the kernel's spread budget and how it allocates between structural and transient.
- `[needs Architect call]` Where does `_author_bias` live? Inline method on `WorldGen` (precedent: `_seed_prices`, `_assign_names` are all inline) or a new `bias_authoring.gd` script-only? Argument for inline: bias generation is one pipeline step alongside placement and price seeding, and `WorldGen` is already the authoring boundary. Argument for separate: bias has more math than placement (predicate solver, per-good range), and slice-3.x may want to swap algorithms. **Designer leans inline; Architect to ratify or push back.**
- `[needs Architect call]` Schema migration: lives in `WorldState.from_dict` (current shape) or a separate `WorldStateMigrator.gd`? Slice-3 discards rather than migrates, so the call is "just reject on schema_version != 3 and let the existing toast path handle it" -- which is the current `from_dict` shape with one constant changed. **Designer leans current `from_dict`, no new file.** Architect to ratify.
- `[needs Architect call]` `TRAVEL_COST_PER_DISTANCE` lift to `WorldRules.gd`. Already partially there per `travel_controller.gd` references; confirm the constant lives next to `edge_cost` and `TICK_DURATION_SECONDS` in `WorldRules`.
- **Slice-3.x topology revisit (logged carryover, originating chain: `2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice`).** Slice-3 picks (a) edge-length-conditional bias bounds. After slice-3 plays end-to-end with live pricing, revisit slice-2.5 survey seeds and decide: (i) does the per-good bias range under (a) feel tight enough to sometimes flatten goods on dense maps -- if yes, reconsider (b) raising `MIN_EDGE_DISTANCE`; (ii) does the seed-bump retry rate climb above acceptable on random graphs -- if yes, ditto. **This is slice-3.x's owed work, not slice-3's.** Decision Scribe should re-link the carryover to slice-3.x once slice-3 closes.

---

## Hand off to Architect

The Architect must make three structural decisions before the Engineer touches code:

1. **`_author_bias` placement.** Inline in `world_gen.gd` (Designer's lean -- consistent with `_seed_prices` / `_assign_names`) or new `godot/game/bias_authoring.gd` script-only? The math is heavier than other gen steps but still gen-time only. Pick once, document.
2. **Schema-3 migration shape.** Designer's call is "discard on `schema_version != 3` via existing `from_dict` null-return + corruption-toast path." Architect ratifies that `from_dict`'s current strict-reject shape absorbs the new schema with just a `SCHEMA_VERSION = 3` bump and added `_node_from_dict` field-presence checks for `bias` / `produces` / `consumes`. No new migrator file. If Architect disagrees, name the file.
3. **`TRAVEL_COST_PER_DISTANCE` location.** Currently a private constant inside `travel_controller.gd`; needs to be a `WorldRules` constant readable by `WorldGen._author_bias`. Trivial mechanically -- but a placement call the Architect should make explicitly so the Engineer doesn't reach across feature folders or duplicate the value.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies the three calls above. Numbers in §6 are starting values; tuning happens in playtest, not in spec.
