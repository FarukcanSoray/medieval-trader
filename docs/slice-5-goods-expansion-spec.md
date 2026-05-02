# Medieval Trader -- Slice 5 (Goods Catalogue Expansion) Spec

> **Ratified frame (2026-05-03):** Director scoped slice-5 to expand the goods catalogue from 2 to 4 goods so the player has more **cargo composition** decisions per leg, with the constraint that legibility per good must hold (each good's identity holdable in the player's head -- "the volatile cheap one," "the steady expensive one"). Critic compressed Branches A (count expansion) and B (named personality roles) into one slice. Branch C (mechanical axes -- perishability, weight, regional bias) is **out of slice**: weight goes to slice-5.x; perishability is slice-6+. Day-1 ships 3 goods + a measurement extension; day-2 ratifies the 4th good only if the measurement passes.
>
> **No new mechanics.** No new fields on `Good`. No new schema bump. No new signals. Slice-5 is a per-good `.tres` authoring pass plus a measurement-tool extension and one new entry in the goods directory. The "more buttons that say the same thing" outcome would be a Critic-flag failure; the slice's job is to prove the existing rules produce **distinguishable identities** at N=4.
>
> Anti-goal carried forward (Director, repeat for the Engineer): **no crafting, no good-pair transformation, no production claims.** Goods exist independently. Slice-3's `produces` / `consumes` tags are price-anchor labels, not production claims. Naming "iron" or "grain" is fine; naming "iron + tools" or "grain + bread" crosses the line. None of the four good names below imply a transformation pair.

## 1. Pattern reference

This is **Patrician III's commodity catalogue** at the smallest size that still spans the design space -- four goods chosen as deliberate role archetypes, not as a sample of "more stuff." The closest exact ancestor is *Port Royale 2*'s starter trade pairs (grain/cloth/sugar/tobacco) where each good's `(base_price, volatility, regional bias amplitude)` triple lands in a different quadrant of "cheap vs. expensive" x "stable vs. volatile." Slice-5 deviates from PR2 in three places: (1) we have only the *price* axis to span (no perishability, no weight, no regional bias amplitude per good -- those are deferred mechanical axes); (2) the four goods land in four corners of one (price, volatility) plane -- not a richer space; (3) selection is hand-authored under a hard predicate constraint (slice-3's free-lunch math), not freely tunable. The promise from the project brief -- *"a small fixed catalogue of goods (hand-authored, not procgen) -- likely 6-12 items with stable identities so the player can build mental models"* -- gets its first concrete realisation here at the catalogue's lower bound.

## 2. Core loop change

**Before slice-5:** the player carries wool or cloth or both. Cargo composition is a one-bit decision (which of two), and at any given moment the spread on one good is usually wider than the other -- so cargo composition collapses to "carry the one with the better spread today." Volatility differences (wool 0.10 vs. cloth 0.06) exist but the player has no comparison set rich enough to read them; "wool jitters" is a fact without a contrast.

**After slice-5:** the player walks into a node and reads four price rows. Two are the kernel-trained pair (wool, cloth -- familiar shape, predictable spread budget). The third is **cheap-and-jumpy** -- a price that moved 2g since last visit, on a base of 7. The fourth is **expensive-and-steady** -- a 22g number that hasn't budged but whose `(plentiful)` tag is a structural promise of profit if you can afford the inventory cost. The cargo composition decision becomes real: do you fill the cart with the volatile-cheap good and time the spread, or sink your gold into the steady-expensive good for a reliable (slimmer per-unit but larger absolute) margin? Both are valid; both are different routes. The careful-merchant fantasy gains a **portfolio axis** -- mastery now includes "which of the four roles does this leg's economics favour?" without adding a new rule.

The kernel is unchanged: arbitrage profit perpendicular to travel cost. What changes is the **vocabulary the player uses to read the kernel**. Four roles is the minimum count where role identity is forced into legibility (with two, every good is "the other one"; with four, the player must name the role to track it).

## 3. Day-1 / day-2 split

**Day-1 (ships first, gates day-2):**
1. Author one new good as a `.tres` file (the cheap-volatile role -- **salt**). Total catalogue: wool, cloth, salt -> N=3.
2. Extend `tools/measure_bias_aborts.gd` to sweep N in {2, 3, 4} goods and log the abort rate per N. (Today's tool measures at N=2 only with hardcoded wool+cloth.)
3. Run the sweep on 1000 seeds per N. Capture the abort rate at each N to the log.
4. **Decision gate:** if N=4 abort rate is `< MAX_ABORT_RATE` (see §6, default `5%`), proceed to day-2 with the second new good. Otherwise stop at N=3 and log a slice-5.x carryover for tag-threshold revisit / `MIN_EDGE_DISTANCE` revisit.

**Day-2 (ships only if day-1 measurement passes):**
1. Author the second new good as a `.tres` file (the expensive-stable role -- **iron**). Total catalogue: wool, cloth, salt, iron -> N=4.
2. Re-run the measurement at the final live values; abort rate must hold.
3. Update HUD if and only if the rendering at N=4 demonstrably breaks (see §8 -- the prediction is it doesn't).

**Why this split, not just "ship 4 goods":** the free-lunch predicate (slice-3 §5.5) is a per-good math constraint, but it interacts as a *set* -- a generated world must satisfy the predicate for **every** good simultaneously, and `_author_bias` returns false if **any** good's allowed range falls below `MIN_BIAS_RANGE`. Adding goods raises the simultaneous-failure surface multiplicatively (each new good is another way to abort). The measurement-before-tuning rule (`feedback_measurement_before_tuning.md`) says: when a question is rate-shaped, write a tool and decide on data. This is exactly that -- the question "does the predicate hold at N=4?" cannot be answered from desk; it has to be measured.

The split also limits day-1 risk: if N=3 itself raises the abort rate above tolerance (unlikely on inspection, but possible), we know before authoring iron and the slice can stop at 3 with a clean owed-note rather than mid-flight retreat from 4.

## 4. The role taxonomy

Four goods, spanning two axes: **cheap vs. expensive** (base_price) and **stable vs. volatile** (volatility). Each quadrant gets one good; each good gets one identity sentence the player can recall after one round trip.

| Role | Good | base_price | floor_price | ceiling_price | volatility | One-line identity |
|---|---|---|---|---|---|---|
| **Cheap, mid-volatile** (existing) | wool | 12 | 5 | 25 | 0.10 | "The kernel-trainer -- familiar shape, every world has a wool route." |
| **Mid-expensive, stable** (existing) | cloth | 18 | 8 | 32 | 0.06 | "The bread-and-butter -- prices read like a menu, structural profit lives here." |
| **Cheap, volatile** (new, day-1) | salt | 7 | 3 | 14 | 0.13 | "The impulse buy -- jitters every tick, drift dominates the structural read." |
| **Expensive, stable** (new, day-2) | iron | 22 | 14 | 32 | 0.05 | "The capital play -- prices barely move, but the bias spread alone is fat enough to live on." |

**Per-role purpose in the kernel** (which kind of route each rewards):

- **Wool** rewards mid-distance round-trip routes where both bias and drift contribute roughly equally to the spread. Travel cost ~30-50% of typical spread. The kernel's "is the spread wide enough right now" question lives here.
- **Cloth** rewards long, planned routes between a `(plentiful)` and `(scarce)` node. Drift adds little; the structural bias does almost all the spread work. Reward is the *predictability* -- if you can afford the inventory, the route pays.
- **Salt** rewards short-distance, opportunistic round trips where the player times the drift sample. Bias contribution is small per unit (low base, low absolute bias gold value); drift swings often outweigh bias. Reward is "I caught it at the bottom and sold at the top within 8 ticks." High volatility, low capital required, fast turnover.
- **Iron** rewards capital-heavy routes between extreme-bias nodes. Volatility is rounding noise; the spread is whatever the structural bias delivered, full stop. Reward is the absolute gold per unit (a single iron round trip can replace four salt round trips). High capital required, slow turnover, low risk-of-misread.

**Why this shape, not other shapes:**

- *Two volatility tiers, two price tiers* gives four goods that each answer a different "what kind of player am I being right now" question. With only one axis (e.g., four price tiers all at vol=0.10), the goods would feel like the same good at different scales -- which fails the legibility-per-good gate.
- *Volatility sets the role, price sets the scale*. A player who learns "salt jitters, iron holds" has the entire mental model in one sentence. Adding more axes (perishability, weight, regional bias amplitude) would muddy this -- and Branch C is exactly what Critic deferred.
- *No good is dominant.* At equilibrium, all four routes pay roughly the same gold-per-tick on a competent run; the choice is *which kind of attention* the player wants to allocate (timing for salt, capital for iron, etc.). If playtest shows one good dominates, the value to retune first is the dominant good's volatility (toward the role boundary). `[needs playtesting]`

**Important constraint -- the free-lunch predicate eats the "expensive volatile" corner.** A naive "complete the four corners" design would pick `(expensive, volatile)` as the dramatic luxury good (spice, silk). The slice-3 predicate `(bias_range * base_price + 2 * volatility * ceiling_price) < shortest_edge * 3` makes that corner unauthor-able at our budget: with `shortest_edge >= 3` and `TRAVEL_COST_PER_DISTANCE = 3`, the budget is 9g; an expensive-volatile good (e.g., base=25, vol=0.12, ceiling=45) burns 10.8g in volatility alone, leaving negative headroom. Iron deliberately occupies `(expensive, stable)` instead -- it fits the predicate and gives the role taxonomy a real fourth corner without inviting `_author_bias` to abort on every seed. The expensive-volatile role is **not designed in slice-5**; it surfaces only if a future slice raises `MIN_EDGE_DISTANCE` or otherwise expands the budget. (Logged as slice-6+ candidate in §11.)

## 5. Authored names and per-good values

Four `.tres` instances at `godot/goods/`. Names are medieval-canonical, ASCII-only, and stand alone (no transformation-pair implications). Iron is "iron bars" as a traded commodity (the player buys finished bars, not ore); salt is "salt" as in raw trade salt blocks. Neither name implies a production chain.

- `godot/goods/wool.tres` -- **unchanged** (`id: "wool"`, `display_name: "Wool"`, `base_price: 12`, `floor_price: 5`, `ceiling_price: 25`, `volatility: 0.10`).
- `godot/goods/cloth.tres` -- **unchanged** (`id: "cloth"`, `display_name: "Cloth"`, `base_price: 18`, `floor_price: 8`, `ceiling_price: 32`, `volatility: 0.06`).
- `godot/goods/salt.tres` -- **NEW (day-1)**:
  - `id: "salt"`
  - `display_name: "Salt"`
  - `base_price: 7`
  - `floor_price: 3`
  - `ceiling_price: 14`
  - `volatility: 0.13`
- `godot/goods/iron.tres` -- **NEW (day-2)**:
  - `id: "iron"`
  - `display_name: "Iron"`
  - `base_price: 22`
  - `floor_price: 14`
  - `ceiling_price: 32`
  - `volatility: 0.05`

Naming check against the Critic's flagged anti-patterns: "iron + tools" (banned), "grain + bread" (banned), "hides + leather" (banned). None of the four authored goods imply any of these pairs. Iron stands alone as a traded ingot/bar commodity (medieval canon, no in-game smithing). Salt stands alone as a trade commodity (no in-game cooking/preserving system). Wool and cloth coexist already, with the (intentional) shared etymology that Director resolved in slice-1 as acceptable because slice-3's `produces` / `consumes` are price-anchor labels, not production claims (carryover honored).

ASCII verification: all four `display_name` values are pure ASCII per CLAUDE.md project rule. No diacritics, no quotes, no special punctuation.

## 6. Day-1 measurement protocol

The decision gate between day-1 and day-2 is a measurement, not an opinion. The headless tool is the source of truth.

**Tool extension:** `tools/measure_bias_aborts.gd` (the existing slice-3 tool, currently in `godot/tools/`) is extended to sweep N in {2, 3, 4} rather than the current hardcoded N=2.

**Required changes:**

1. Replace the hardcoded `_load_goods()` body with a parameter-driven loader: `_load_goods(n: int) -> Array[Good]` that returns the first N entries of the canonical good list `[wool, cloth, salt, iron]` (in that order -- adding goods extends the array, never reorders, so day-1's N=3 measurement uses the same wool+cloth that already shipped).
2. Wrap the existing seed loop in an outer N-loop. For each N in {2, 3, 4}, run all 1000 seeds and tally:
   - `success_no_bump` (count and percent)
   - `success_with_bump` (count, percent, distribution by bump count)
   - `aborts` (count, percent) -- the load-bearing number
   - `min_edge_distance` distribution (already tracked)
3. Print one report block per N, with a final summary line listing the abort percent at each N side-by-side: `abort rates: N=2: X.X%, N=3: Y.Y%, N=4: Z.Z%`.
4. Add a verdict line per N using the existing thresholds; the slice-5 verdict additionally compares against `MAX_ABORT_RATE` (below).

**`MAX_ABORT_RATE` -- ratified at 5%.** This is the abort-rate ceiling at N=4 that triggers "ship 4 goods on day-2." Above 5%, the slice stops at N=3 and the surface-level cause (predicate too tight, `MIN_EDGE_DISTANCE` too low for N=4, or one good's volatility-times-ceiling crowding the budget) is logged as a slice-5.x carryover. Critic suggested `~5%`; Designer ratifies the same.

Reasoning for 5% (not 1%, not 10%):

- *1% would be too tight.* The slice-3 measurement at `MIN_EDGE_DISTANCE = 3` reported 0% abort at N=2. Demanding 0% at N=4 (where the simultaneous-satisfaction surface is meaningfully larger) would force a tuning pass on at least one good for cosmetic safety, when 1-in-50 worlds rejecting their first seed and bumping 1-2 times is operationally invisible to the player.
- *10% would be too loose.* At 10%, players who serial-roll would feel "many seeds get rejected"; even if the seed-bump retry hides this from gameplay, the abort tail (5 bumps exhausted -> `push_error`) becomes a non-trivial event count over a large user population. 5% leaves the abort tail well below 0.1% (since exhaustion requires 5 consecutive failures, a 5% per-attempt rate gives `0.05^5 = ~3e-7` exhaustion rate -- effectively never).
- *5% lands at a reasonable "1 in 20 first-seeds bumps once or twice, the player never notices."* The seed-bump loop already exists for placement starvation and slice-3 bias unsatisfiability; absorbing N=4 predicate failures at the same rate is no new operational concern.

**Decision rule (binding):**

- N=4 abort rate `<= 5%` -> day-2 authors `iron.tres`, ships at N=4.
- N=4 abort rate `> 5%` -> day-2 stops, slice ships at N=3, slice-5.x owes a tuning revisit. Log the failing good's allowed_range distribution (extension of existing tool output) so slice-5.x has data on which good is the load-bearing failure.

**Determinism note:** the measurement is itself deterministic on the seed range (0..999) -- two runs of the tool with the same code produce identical numbers. If the abort percent crosses the 5% threshold by 0.1%, that's the call -- no re-roll of the measurement is permitted to dodge the rule.

## 7. Free-lunch predicate interaction

The Critic flagged this and they're right: the predicate `(bias_range * base_price + 2 * volatility * ceiling_price) < shortest_edge * 3` has two terms that dominate in opposite regimes, and the role spread must be predicate-aware.

**Volatility-times-ceiling dominates expensive-volatile goods.** A good with `ceiling_price = 32` and `volatility = 0.10` burns `2 * 0.10 * 32 = 6.4g` of the per-good budget on the volatility term alone, leaving `9 - 6.4 = 2.6g` for the bias contribution. Divided by `base_price = 22`, that's an allowed_range of `0.118` -- below `MIN_BIAS_RANGE = 0.20`. Predicate fails; seed bumps.

**Bias-range-times-base dominates cheap-stable goods.** A good with `base_price = 7` and `volatility = 0.04` burns `2 * 0.04 * 14 = 1.12g` on volatility, leaving `9 - 1.12 = 7.88g` for bias. Divided by `base_price = 7`, that's an allowed_range of `1.126`, capped by `BIAS_MAX - BIAS_MIN = 0.80`. The predicate is trivially satisfied; the bias range is constrained by the global envelope, not by the budget.

**The role spread for slice-5 is deliberately predicate-aware:**

- **Salt (cheap-volatile):** vol-term `2 * 0.13 * 14 = 3.64g`, headroom `5.36g`, raw range `5.36 / 7 = 0.766`, capped at envelope `0.80`. Comfortable; predicate is never the binding constraint for salt.
- **Iron (expensive-stable):** vol-term `2 * 0.05 * 32 = 3.20g`, headroom `5.80g`, raw range `5.80 / 22 = 0.264`. Above `MIN_BIAS_RANGE = 0.20`, with 0.064 of margin. **Iron is the load-bearing good for predicate failure**: if `MIN_EDGE_DISTANCE` ever drops below 3 (slice-5.x weight-cap deferral and the measurement may hint at this), iron is the first to fail. The day-1 measurement specifically validates this margin holds.
- **Wool, cloth (existing):** raw ranges 0.33 and 0.286 respectively (computed in slice-3). Comfortable.

**Tool implication.** The measurement extension MUST log the per-good `allowed_range` distribution at N=4, not just the abort count. If the slice ships at N=3 due to the gate, the iron-allowed_range distribution from the failing N=4 sweep is the data slice-5.x needs to decide what to retune. (Implementation: track `min(allowed_range)` per good per seed in a histogram; print buckets at end-of-run.)

**What this rules out for slice-5+:** an "expensive-volatile" luxury good (the natural fourth corner -- spice, silk, gemstones) cannot be authored under the current predicate at our shortest-edge floor. This is the slice-5+ tension the role taxonomy explicitly trades away. Future slices that raise `MIN_EDGE_DISTANCE` or `TRAVEL_COST_PER_DISTANCE` open the corner; slice-5 does not.

## 8. HUD / legibility impact

Slice-3 `NodePanel` already iterates `Game.goods` to render one row per good per node -- there is no hardcoded 2-good assumption. Adding entries to `Game.goods` produces 4 rows automatically (`godot/ui/hud/node_panel.gd:55`, the `for good: Good in Game.goods` loop). No code change required for the row count itself.

**Legibility audit at N=4:**

- **Vertical row count.** NodePanel renders one node at a time. 4 rows of `Name | Price | Owned | Buy | Sell` is well within the panel's existing vertical budget (slice-3 ratified the layout at 2 rows + a title; 2 more rows fit without scrolling on 720p web export viewport). **No change.**
- **Tag rendering.** The `(plentiful)` / `(scarce)` tags append per-row per slice-3 §7. With 4 goods, a single node may show up to 4 tags -- e.g., `wool 8g (plentiful)`, `salt 4g (scarce)`, etc. The visual density rises but each tag is local to its row; the player's parse is still per-row, not gestalt. **No change.**
- **TravelPanel preview density.** The travel-panel cost preview (slice-4 §7) does not enumerate goods; it shows base cost + bandit hint only. No N-dependence. **No change.**
- **ConfirmDialog.** Same -- no goods enumeration. **No change.**

**Tracking burden.** The Critic raised this as the legibility concern: at 4 goods x N nodes, the player tracks `4 * N` price cells mentally. Slice-3's `(plentiful)` / `(scarce)` tags exist precisely to externalize this -- the player reads tags, not numbers. The tag legibility budget scales with goods count, not with node count: at any single node, the player skims 4 rows for tags. That's a legibility-per-row check, not a legibility-per-node-set check.

**Slice-5 verdict: no HUD changes needed.** Defer all HUD-density work to slice-5.x **only if** playtest at N=4 surfaces concrete legibility breaks. Predictions: (a) the tag column at N=4 will sometimes be sparse (a node with tags on only 1 of 4 goods reads cleanly); (b) the price-row block at N=4 stays under 8 lines in the panel including title and padding; (c) the `Owned: x0` rows for goods the player isn't carrying may feel noisy and, if so, slice-5.x adds a "hide zero-stack rows" toggle. Don't over-engineer in slice-5.

**One tiny non-change worth naming.** `_build_rows()` rebuilds the row dictionary lazily once Game.goods is available; it does not handle Game.goods *changing* after first build. Slice-5 doesn't introduce a code path that mutates Game.goods at runtime (goods are loaded once at boot per slice-3), so no fix needed. If slice-6+ ever introduces dynamic goods (procgen catalogues, regional sub-catalogues), the rebuild path becomes load-bearing -- explicit owe-note for slice-6+ design.

## 9. Bandit goods-loss interaction

Slice-4's `BANDIT_GOODS_FRACTION = 0.50` was tuned at N=2. With N=4, the qualitative feel of "1-of-N stacks hit" changes:

- At N=2, a fired bandit encounter on a player carrying a mixed cargo loses 50% of one of two stacks. The "the high-value good is the target" lesson is unambiguous (only two candidates).
- At N=4, the same encounter still loses 50% of *one* stack -- but the player tracks four candidates. The lesson is the same (most-valuable-by-origin-price), but the *texture* shifts from "I knew which one would get hit" (binary obviousness) toward "I had to think about which one was at risk" (mild deduction).

This is *good* for the kernel -- the cargo composition decision becomes a real risk-allocation decision rather than a binary -- but the constant `0.50` may want to retune for absolute loss feel. With salt (cheap, often carried in volume) being the "most-valuable" target on a no-iron-no-cloth leg, a 50% salt-stack hit might feel trivial (lose 5g of value); on an iron-heavy leg, a 50% iron-stack hit is meaningful even with ceiling cap (lose 16g of value).

**Slice-5 decision: defer retune to slice-5.x. Confirm Critic's placement.** Reasoning:

- The constant doesn't break at N=4; it just operates at a different scale of player attention. Retuning it pre-playtest is desk-tuning the wrong thing. The right time to revisit is after N=4 has been played and the "felt loss" data exists.
- Slice-5's day-1 / day-2 split already gates on a measurement; adding a second measurement-shaped decision (bandit-loss-feel) would expand scope.
- The constant is in `WorldRules` as `BANDIT_GOODS_LOSS_FRACTION` (note: code uses `_LOSS_` -- spec called it `BANDIT_GOODS_FRACTION`; same constant). Retuning is a one-line change, no schema implications. Cheap to revisit.

**Slice-5.x carryover (logged in §11):** `BANDIT_GOODS_LOSS_FRACTION` retune after N=4 playtest. Specifically: (a) does a salt-only cargo loss feel like a tax or a pinch? (b) does an iron-only cargo loss feel proportionate or over-bite given the cap? (c) does a mixed-cargo loss correctly target the iron without ambiguity?

**No change to `EncounterResolver` in slice-5.** The "most-valuable-by-origin-price, 50% of stack, lex-min tie-break" rule at `godot/travel/encounter_resolver.gd:46-63` is N-independent; it iterates `trader_inventory.keys()` and selects max. Adding two new good IDs to the dictionary doesn't change the algorithm.

## 10. Schema / save format

**No schema bump in slice-5.** The catalogue is `.tres` authoring. The save format already stores `prices` and `inventory` as `Dictionary[String, int]` keyed on good id (slice-spec §3, slice-3 §3, slice-4 §3) -- adding good IDs `"salt"` and `"iron"` to the dictionaries is a value-level change, not a schema change. `schema_version` stays at 4.

**Confirmation:** the `inventory: Dictionary[String, int]` shape on `TraderState` (architecture §4.1) holds for 4 goods unchanged. New inventory dicts on world-gen will have entries for all 4 goods (or rather, will start empty and accrete keys via `apply_inventory_delta` as the player buys -- existing slice-1 behavior, N-independent).

**Existing saves on slice-5 build:** slice-4 saves have `inventory` dicts containing only `"wool"` and `"cloth"` keys; on load, slice-5 code reads those dicts unchanged. The player's old wool and cloth stacks are preserved; salt and iron stacks default to absent (read as 0 via `trader.inventory.get(good_id, 0)` -- existing pattern in `node_panel.gd:104`). The world's `nodes[].prices` dicts likewise lack salt/iron entries. **This is a real edge case** -- see §12.

**Slice-5 saves on a future slice-5-stop-at-3 build:** if day-1 measurement fails and the slice ships at N=3, the catalogue is `[wool, cloth, salt]`. A slice-5 day-2 save (with iron) loaded onto a stop-at-3 build would contain an iron-keyed inventory the build can't render. Nothing in the load path enforces a goods-list match. **Acceptable** -- the slice will not ship in a "day-2 then revert to N=3" sequence; either day-2 ships with iron and stays, or day-2 doesn't ship at all. No new save-validation logic needed.

**`from_dict` field-presence check:** unchanged. Slice-5 adds no new fields; only new keys in existing dicts.

## 11. Open questions

- `[needs playtesting]` All numbers in §5 (per-good `base_price` / `floor_price` / `ceiling_price` / `volatility`). The four-corner role spread is structural, but the exact numbers within each corner are tuning surface. Symptom-of-too-low-volatility for salt: drift swings under 1g per tick, role collapses to "cheap stable" and overlaps cloth's identity. Symptom-of-too-low-base for iron: capital play feels like wool with extra steps, role collapses to "expensive stable" without affordance friction.
- `[needs Architect call]` `Game._load_goods()` (or equivalent goods-loader) likely hardcodes the wool/cloth `.tres` paths today. Adding salt and iron requires either two more `load("res://goods/<id>.tres")` lines or a directory scan. Designer leans **explicit paths** (no scan -- predictable, one source of truth, immune to stray `.tres` files). Architect ratifies.
- `[needs slice-5.x -- tag-threshold revisit]` (Critic-flagged). At N=4, the bias-tag distribution per node may produce nodes with all-tags or no-tags more often than the slice-3 design intended. `PRODUCER_THRESHOLD_FRACTION = 0.5` was tuned on N=2 worlds. The tool extension in §6 should also log per-node `produces.size() + consumes.size()` distribution; if many nodes carry 0 tags or 4 tags, retune the threshold in slice-5.x.
- `[needs slice-5.x -- BANDIT_GOODS_LOSS_FRACTION retune]` (Critic-flagged). See §9. After N=4 playtest, decide whether 0.50 still feels right; specifically whether salt/iron extremes change the texture.
- `[needs slice-5.x -- weight-cap follow-up]` (Critic-flagged Branch C-weight). Weight / cargo capacity is the next mechanical axis after slice-5. Not in slice-5. Slice-5.x design surface: per-good `weight: int` field on `Good`, total cargo capacity on `TraderState`, buy gating against capacity. This pre-supposes `Good` schema gains a field, which is the explicit slice-5 boundary -- don't preempt it here.
- `[needs slice-6+]` Expensive-volatile role corner (the spice/silk/gemstone good). Currently unauthor-able under predicate at `MIN_EDGE_DISTANCE = 3`. Slice-6+ candidate IF a future slice raises the shortest-edge floor (e.g., for travel-time pacing reasons) or otherwise expands the per-good free-lunch budget. Not a slice-5.x candidate -- it requires a structural change, not a tuning pass.
- `[needs slice-6+]` Perishability (Branch C-perish). Per-good decay-while-traveling rule. Director-flagged as new-rule-per-good (violates "mastery transfers as procedural reasoning"); explicitly out of slice-5; slice-6+ candidate that requires its own pillar-fit pass.

## 12. Edge cases

- **Player buys all 4 goods to overflow gold.** Inventory is `Dictionary[String, int]`; no per-good cap, no total cap (slice-5 has no weight system). The player can hold any non-negative integer of any good. Existing `apply_inventory_delta` semantics (slice-architecture §4.1) handle this -- no new edge case introduced by 4 vs. 2 goods. Buying is gated only by gold (existing slice-1 rule). The "overflow" case is gameplay-valid: if the player has 1000g and buys salt at 4g, they end with 250 salt and 0g, then have to sell or travel-with-cost back. Slice-5 introduces no new failure mode here.
- **Empty inventory at bandit roll with 4 stacks possible.** Existing `EncounterResolver.try_resolve` (`encounter_resolver.gd:44-47`) skips the goods-loss block when `trader_inventory.is_empty()`. With 4 goods, "empty inventory" still means "no key has positive qty"; the iteration on line 47 short-circuits cleanly. The check is `not trader_inventory.is_empty()` -- which is **true when any key exists**, even if all qtys are 0. The inner loop on line 48-52 already filters `qty > 0`, so a dict like `{"wool": 0, "cloth": 0, "salt": 0, "iron": 0}` falls through with `target_good_id == ""` and the goods-loss block is skipped. **No change needed.** Mild defensive-code note for the Engineer: the slice-4 implementation correctly handles the all-zeros case via the inner filter; that semantics holds at N=4.
- **Free-lunch abort on goods 3 or 4 -- what's the fallback?** Per slice-3 §5.5 and `world_gen.gd:50`, `_author_bias` returns false on first-good failure; the seed-bump retry kicks in. With 4 goods, *any* of the four can be the failing good on a given seed -- the loop short-circuits on the first failure. After 5 bumps exhausted, `push_error` and abort -- existing terminal behavior. **No new code path.** The day-1 measurement directly validates this is rare at N=4; if measurement fails the gate, the slice stops at N=3.
- **Slice-4 save loaded on slice-5 build (existing wool/cloth-only saves).** `inventory` and `nodes[].prices` dicts contain only wool and cloth keys. On load:
  - **NodePanel** rendering: iterates `Game.goods` (now 4 entries); reads `node.prices.get(good.id, 0)` per slice-3 -- missing keys default to 0, so salt/iron rows render as `Price: 0g (no tag)`. Buy button is disabled (price <= 0 predicate, `node_panel.gd:127`). Sell button is disabled (owned == 0). **Cosmetically odd** -- the player sees 4 rows where 2 are dead.
  - **Resolution: forward-port the save by re-seeding salt/iron prices and bias on first load.** Designer leans: at load time, if the world was generated at a lower N than current `Game.goods.size()`, run a one-shot price-and-bias-seed pass for the new goods (mirrors `WorldGen._author_bias` and `_seed_prices` for the new-good subset). This avoids a schema bump (the dicts gain keys, not fields) and avoids the cosmetic dead-row state.
  - **Alternative: reject the save (corruption-toast path), regen world.** Simpler, consistent with prior schema bumps. Architect call to ratify, with Designer's lean toward forward-port given that no schema actually changed.
  - **Architect call needed before Engineer codes this.** See §11 first slice-5.x carryover entry isn't this -- this one is a slice-5 day-1/day-2 implementation question, not a future-slice question. Naming it here so it's not buried.
- **Day-1 ships, then Engineer accidentally adds iron before measurement passes.** Process failure. The day-1 / day-2 split is enforced by review, not by code. The Engineer should not author `iron.tres` until the measurement log is on disk and the abort percent is recorded as `< 5%`. (Implementation note: keep `iron.tres` out of the goods folder until day-2 begins; mere presence of the file would not load it -- only the explicit `_load_goods()` paths matter -- but absence is the cleanest signal.)
- **Measurement tool extension introduces a regression in N=2 numbers.** The tool's existing N=2 numbers (slice-3 measurement) must reproduce byte-identical when the extension runs N=2 as the first iteration of the sweep. **Test:** run extended tool, capture N=2 verdict line, compare to slice-3-era log. If they differ, the extension introduced a regression in seed handling; fix before measuring N=3 / N=4. (This is a defensive-test instruction, not an expected failure.)
- **Iron's `floor_price = 14` against typical drift.** Iron's vol term `2 * 0.05 * 32 = 3.20g` means per-tick drift envelope is around 3g. Mean-reversion (`MEAN_REVERT_RATE = 0.10`) pulls the price toward the biased anchor each tick. Floor at 14 sits exactly at the edge of the lowest plausible biased anchor (`base * (1 + bias_min)` = `22 * 0.60` = `13.2`, rounded to 13 -- but `bias_min` for iron is the predicate-trimmed range, not the envelope, so actual lowest anchor is `22 * (1 - 0.264/2)` = `22 * 0.868` = `19.1`, rounded to `19`). The floor is well below the lowest anchor, so it should rarely clamp -- which is the intent (clamping should be a rare safety, not a common occurrence). **No change.**
- **All four goods at the same node simultaneously in the deepest `(scarce)` tag.** Possible by RNG. The node renders four `(scarce)` tags. Cosmetically dense but legible. No mechanical issue; tags don't drive math beyond rendering.
- **The new `salt` good's volatility (0.13) lands above wool's (0.10).** Confirmed intentional. Wool is "mid-volatile, mid-cheap" -- the kernel-trainer; salt is "high-volatile, cheap" -- the impulse buy. The volatility ordering (wool < salt) is part of the role spread; it's why salt's spread feels jumpier than wool's at a glance. If the playtest observation is "salt and wool feel the same," that's a tuning failure (consider raising salt to 0.16 or lowering wool to 0.08).

## 13. Anti-goal watch carried forward (Engineer reads this)

Director's rule, repeated verbatim for the Engineer to read:

> **No crafting, no good-pair transformation.** "Cloth made from wool" framing crosses the line. Goods exist independently; slice-3's `produces` / `consumes` tags are price-anchor labels, not production claims.

**Engineer-side translation:**

- The four `Good.tres` files are *unrelated* by mechanic. There is no code path that transforms one good into another. There is no "iron + X = Y" rule. There is no "harvest grain from village" verb. There is no "bake bread at city" verb. There is one mechanic: `apply_inventory_delta(good_id, qty)`, which adds or removes units of one specific good in one place. That mechanic is N-independent and unchanged.
- If you find yourself writing code that reads from one good's stack and writes to another's, **stop**. That is crafting. It is out of scope. Hand back to Designer for a pillar check.
- The `produces` / `consumes` tag arrays on `NodeState` are price-anchor labels -- they map to the bias-extreme classification (slice-3 §5.6). They do **not** mean the node *produces* the good. A node tagged `wool (plentiful)` does not generate wool over time, does not refuse to buy wool, does not have a wool stockpile. It just has a low bias for wool's price, which the player reads as "cheap to buy here."
- ASCII rule (CLAUDE.md): all four good display names are pure ASCII. New strings introduced by the slice (none currently) MUST follow the same rule -- no `--`, no `->`, no fancy quotes, no ellipses except `...`.

---

## Hand off to Architect

The Architect must make two structural calls before the Engineer touches code:

1. **Forward-port behavior on slice-4 saves loaded onto slice-5 builds.** Re-seed prices and bias for the newly-introduced goods on first load (Designer's lean -- avoids the cosmetic dead-row state on existing saves), or reject the save via corruption-toast (simpler, consistent with prior schema bumps). The schema is unchanged either way; the call is "graceful migration of an existing dict" vs. "regenerate world." Pick once, document.

2. **Goods-loader path explicitness.** `Game._load_goods()` (or equivalent) lists the four `.tres` paths explicitly (Designer's lean), or scans `godot/goods/*.tres`. Explicit paths give one source of truth and immunity to stray files; scanning is one-line-of-code-cheaper but couples loading to filesystem state. Architect ratifies.

The day-1 / day-2 split is binding for the Engineer: salt ships first, iron ships only if `tools/measure_bias_aborts.gd` (extended per §6) reports `abort_pct(N=4) <= 5.0`. The Engineer should not author `iron.tres` until that measurement is on disk.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies the two calls above. Numbers in §5 are starting values; tuning happens in playtest, not in spec.
