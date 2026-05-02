# Medieval Trader -- Slice 4 (Encounters) Spec

> **Ratified frame (2026-05-02):** Director scoped slice-4 to prove travel cost is more than gold-per-distance -- route risk is itself a math problem. Bandits only; no weather, spoilage, or tolls (slice-5+). No choice UI inside encounters; the choice lives in route selection, telegraphed on edges. Critic ratified day-1 kernel (per-edge probability at world-gen, schema bump 3->4 via discard, departure-time roll, gold-loss outcome only, history-line readback) and day-2 in-slice (goods-loss variant, **visible expected-cost hint** -- Critic's Pillar-1 protection). Slice-4.x carries `slain` death cause, resolution modal, bandit-road minimum-count invariant.
>
> Determinism contract preserved: encounter authoring uses sub-seed `hash([effective_seed, "encounters"])` (sibling of `"bias"`, `"place"`, `"names"`); per-leg roll uses `hash([world_seed, tick, edge_a_id, edge_b_id, "encounter_roll"])` -- justified §5.3. Schema bump 3->4 named below per `2026-05-02-slice-2-no-schema-bump-trigger-named` precedent. Slice-3 saves discarded via existing corruption-toast path per `2026-05-02-slice-3-schema-3-discard-via-toast` precedent.

## 1. Pattern reference

This is **FTL's beacon-event roll** without the choice tree -- a per-leg trigger evaluated at departure, outcome resolved against a deterministic seed, no player input during resolution. The closest exact ancestor is *Pirates!*'s pirate-encounter check on the open sea: a flag on the route ("known pirate waters"), a roll on entry, an outcome that bites the wallet or the cargo. Slice-4 deviates from FTL in three places: (1) no choice modal -- the player decided when they picked the route; (2) the trigger is per-edge (a property of the route), not per-tile (a property of the world map); (3) outcomes are economic only -- no narrative branching, no follower mechanics, no ship damage proxies. From *Pirates!* we inherit the "telegraphed on the map" commitment but drop combat resolution entirely. The closest abstract ancestor in flavour is *Sunless Sea*'s peril-on-route mechanic, with all the storylet text removed and the cost surfaced as a number.

## 2. Core loop change

**Before slice-4:** the player reads spreads (slice-3 bias tags + slice-2 drift) and picks the highest-spread route reachable, paying a flat gold-per-distance cost. Travel cost is one number; route choice is one variable (which destination). The kernel is `spread > travel_cost`, with travel cost knowable in advance to the gold.

**After slice-4:** the same node-pair may be reachable by two routes -- a short-and-safe edge or a longer-but-also-bandit edge, or two edges where one is plain and one is tagged. The cost preview no longer reads `Cost: 12g`; it reads `Cost: 12g (+0..6g, bandit road, ~30%)`. The player now weighs **deterministic cost** against **expected cost** -- the spread must beat travel-cost-plus-expected-loss, not just travel-cost. Sometimes the cheaper-feeling route (bandit road, lower base distance) is the worse expected-value play. Sometimes it's still right because the spread is fat. The careful-merchant fantasy gains a probability axis without becoming gambling -- the numbers are visible, the math is doable, the dice are deterministic per leg.

## 3. Save format contract changes

Diff against `slice-3-pricing-spec.md` §3. **`schema_version` bumps 3 -> 4.**

**Trigger (named, per `2026-05-02-slice-2-no-schema-bump-trigger-named` precedent):** *"per-edge bandit-road tags added to EdgeState; per-leg encounter resolution added to TravelState; encounter history kind added to HistoryEntry."* Three semantic adds across three Resources, all required-on-load.

```
{
  "schema_version": 4,                                  // was 3
  "world_seed": <int>,
  "tick": <int>,
  "trader": {
    "gold": <int>,
    "age_ticks": <int>,
    "location_node_id": <string>,
    "travel": null | {
      "from_id": <string>,
      "to_id": <string>,
      "ticks_remaining": <int>,
      "cost_paid": <int>,
      "encounter": null | {                             // NEW: resolved-at-departure outcome
        "fired": <bool>,                                // true = encounter fires this leg
        "gold_loss": <int>,                             // 0 if not fired or no gold to lose
        "good_lost_id": <string>,                       // "" if not fired or no goods (day-2)
        "good_lost_qty": <int>,                         // 0 if not fired or no goods (day-2)
        "readback_consumed": <bool>                     // false until history-line shown
      }
    },
    "inventory": { "<good_id>": <int> }
  },
  "nodes": [ ... unchanged from schema 3 ... ],
  "edges": [
    { "a_id": <string>, "b_id": <string>, "distance": <int>,
      "is_bandit_road": <bool> }                        // NEW: gen-time tag, immutable
  ],
  "history": [
    { "tick": <int>,
      "kind": "buy"|"sell"|"travel"|"encounter",       // NEW kind: "encounter"
      "detail": <string>, "delta_gold": <int> }
  ],
  "dead": false,
  "death": null
}
```

**`from_dict` migration policy: discard.** Slice-3 saves are rejected via the existing strict-reject `from_dict` path; the corruption toast fires (`"Save discarded: schema upgraded. New world generated."`); a new world is generated. Reasoning is identical to slice-3->4's parent precedent: forward-filling `is_bandit_road = false` on every edge would silently violate Pillar 2 (the player learns the new system on a save where it has no teeth). New `_edge_from_dict` adds a single field-presence check (`"is_bandit_road"`); new `_travel_from_dict` (split out of inline travel parsing in TraderState's existing dict path -- Architect call to confirm placement) reads the optional `encounter` block; new `HistoryEntry.KINDS` includes `"encounter"`.

## 4. Inputs/outputs per system

Mirrors `slice-3-pricing-spec.md` §4. **Changed rows: Map (gen), Travel.** **New row: EncounterResolver.** Unchanged rows omitted (Goods catalogue, Price model, Aging, Save, Death, Death screen, Tags/legibility).

| System | Reads | Writes | Tick events |
|---|---|---|---|
| **Map (gen)** | `world_seed`, `goods[].volatility`, `MIN_EDGE_DISTANCE`, `TRAVEL_COST_PER_DISTANCE`, `BANDIT_ROAD_FRACTION` | `nodes` (incl. `bias`, `produces`, `consumes`), `edges` (incl. `is_bandit_road`) (once at world birth) | none after gen |
| **Travel** | `trader.location_node_id`, edge distance, edge `is_bandit_road`, `trader.gold` | `trader.travel` (incl. `encounter`), `trader.gold` (cost + encounter loss), `trader.location_node_id`, `trader.inventory` (day-2) | advances tick by 1 per step |
| **EncounterResolver** | `world_seed`, `world.tick`, edge `a_id`/`b_id`/`is_bandit_road`, `trader.gold`, `trader.inventory` (day-2), `BANDIT_ROAD_PROBABILITY`, gold-loss bounds, goods-loss fraction | nothing directly -- returns an `EncounterOutcome` value to TravelController, which writes it onto `trader.travel.encounter` | fires once at departure (`request_travel`); resolution applied at arrival tick |

**Unchanged:** Save just ferries the new fields through `to_dict`/`from_dict`. PriceModel does not read `is_bandit_road` -- bias stays the only price input. NodePanel does not render encounter info -- the bandit tag lives on the cost preview (TravelPanel/ConfirmDialog), not on the node panel.

## 5. Rules

### 5.1 Bandit-road tag generation -- ANSWER (open question 4)

**Pure-random per edge with a fixed fraction, no correlation to length / position / cost.** Authored at world-gen, sub-seed `hash([effective_seed, "encounters"])`, sibling of `"bias"`. No minimum-count invariant in slice-4 (a zero-bandit world is acceptable -- if playtest shows it feels hollow, slice-4.x carries an invariant; see §10).

```
func _author_encounters(effective_seed: int, edges: Array[EdgeState]) -> void:
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    rng.seed = hash([effective_seed, "encounters"])
    for edge: EdgeState in edges:
        edge.is_bandit_road = (rng.randf() < BANDIT_ROAD_FRACTION)
```

**Why pure random, not length-correlated:**
- *Pillar 1 (legibility) wins.* "Long edges are more dangerous" sounds intuitive but adds a second mental model -- the player would have to mentally compute `f(distance)` to predict risk. Pure random + visible tag means the tag IS the risk model: tagged = bandit, untagged = safe. One read, no inference.
- *Pillar 2 served the same.* The kernel needs *some* edges to be more expensive in expectation than their distance suggests; it does not need that expense to scale with distance. A 3-tick bandit road and a 5-tick bandit road both put the kernel under the same shape of pressure (expected cost > base cost), and the longer one already has a higher base cost from distance.
- *Determinism is trivial.* One RNG seeded once, one randf per edge, no per-edge state. Replays byte-for-byte across save/load (the `is_bandit_road` flag persists; the RNG isn't re-rolled).
- *Rejected: correlated with edge length.* Adds a tunable (the correlation coefficient) for zero kernel value. Defer indefinitely; not a slice-4.x candidate.
- *Rejected: correlated with distance from start.* Implies a "wilderness frontier" mental model the slice has no fiction to support. Pillar 1 violation by sneak.

**Output:** `edge.is_bandit_road: bool` populated for every edge. Default `false` if the field is unset (defensive; the generator should always set it).

**Determinism contract:** same `world_seed` -> same set of bandit roads, byte-identical. The bandit-road tag persists in the save; reloading a world does not re-roll it (it is gen-time data, not per-tick data).

### 5.2 Probability per edge -- ANSWER (open question 1)

**Flat constant for all `is_bandit_road == true` edges.** `BANDIT_ROAD_PROBABILITY` is a single number applied to every bandit-tagged edge regardless of length, position, or trader state.

**Why flat, not scaled:**
- *Pillar 1 directly.* The expected-cost hint (§5.5) is `Cost: <base> (+0..<max>g, bandit road, ~<P>%)`. If P varies per edge, the hint must compute and display a per-edge percentage, which means the player has to read a number that depends on edge length / distance / whatever input to predict expected loss. Flat P means the player learns ONE number ("bandit roads are 25%") and applies it everywhere.
- *Pillar 2 served the same.* Risk biting harder on long bandit edges is interesting in the abstract but operationally: long bandit edges already have high base cost (distance * TRAVEL_COST_PER_DISTANCE), so the absolute expected loss already scales. Doubling P on top of that is redundant pressure.
- *Critic's "tag without numbers" risk.* Flat P is the simplest mental model that makes the tag computable. Variable P means the tag carries hidden information.

**Starting value: `BANDIT_ROAD_PROBABILITY = 0.30`** (see §6).

### 5.3 Departure-time roll

Fires inside `TravelController.request_travel`, **after** `apply_gold_delta(-cost)` succeeds and **before** `_push_travel_history(to_id, cost)`. The encounter outcome is computed and stored on `trader.travel.encounter` immediately; the cost-paid history line is unchanged from slice-3 (it covers travel cost only, not encounter loss).

```
# Inside request_travel, after travel: TravelState is constructed and
# trader.travel = travel. Before _push_travel_history:
travel.encounter = EncounterResolver.roll(
    _world.world_seed, _world.tick, edge, _trader,
)

# EncounterResolver.roll(world_seed, tick, edge, trader) -> EncounterOutcome:
func roll(world_seed: int, tick: int, edge: EdgeState, trader: TraderState) -> EncounterOutcome:
    var outcome: EncounterOutcome = EncounterOutcome.new()  # all zeros
    outcome.fired = false
    if not edge.is_bandit_road:
        return outcome
    var rng: RandomNumberGenerator = RandomNumberGenerator.new()
    # Canonicalize edge identity: lex-min first so (a->b) and (b->a) hash equal.
    var lo: String = edge.a_id if edge.a_id < edge.b_id else edge.b_id
    var hi: String = edge.b_id if edge.a_id < edge.b_id else edge.a_id
    rng.seed = hash([world_seed, tick, lo, hi, "encounter_roll"])
    if rng.randf() >= BANDIT_ROAD_PROBABILITY:
        return outcome  # lucky leg, fired remains false
    outcome.fired = true
    # Gold-loss outcome (day-1).
    var loss_pct: float = rng.randf_range(BANDIT_GOLD_LOSS_MIN_FRACTION, BANDIT_GOLD_LOSS_MAX_FRACTION)
    var raw_loss: int = roundi(loss_pct * float(trader.gold))
    outcome.gold_loss = clampi(raw_loss, 0, BANDIT_GOLD_LOSS_HARD_CAP)
    # Goods-loss outcome (day-2). See §5.7.
    return outcome
```

**Hash namespace justification.** Sub-key `"encounter_roll"` (sibling of slice-3's `"bias"` namespace and the per-tick `[world_seed, tick, node_id, good_id]` price hash). Including `tick` makes the same edge re-rolled later in the run produce a different outcome -- this matters because the player can travel an edge multiple times in one run; otherwise the second crossing's outcome is locked to the first's. Including the canonicalized `(lo, hi)` makes direction symmetric -- crossing Hillfarm->Rivertown on tick 7 has the same fate as Rivertown->Hillfarm on tick 7, which matches the undirected nature of the edge. Excluding `trader.gold` is intentional -- the roll is a property of the world and the moment, not of the trader's wallet (whose contents would otherwise create a feedback loop where rich traders get unluckier).

**Re-roll on save/load is forbidden.** The outcome is computed at departure, written to `trader.travel.encounter`, and persisted. On reload mid-travel the resolved outcome is read from the save, not recomputed. Reasoning: the deterministic hash above *would* produce the same outcome on re-roll, but only if the save/load path preserves `(world_seed, tick_at_departure, edge_identity)` exactly. Persisting the resolved outcome makes the contract a single-source-of-truth ("the encounter is whatever the save says it is"), removing the entire class of bugs where a future change to the hash namespace silently changes a saved world's outcome.

### 5.4 Outcome distribution -- ANSWER (open question 2)

**Gold loss: clamped percentage of carried gold, with a hard cap.** Per leg, when fired:

```
loss_pct  = rng.randf_range(BANDIT_GOLD_LOSS_MIN_FRACTION, BANDIT_GOLD_LOSS_MAX_FRACTION)   # uniform float
raw_loss  = round(loss_pct * trader.gold)
gold_loss = clamp(raw_loss, 0, BANDIT_GOLD_LOSS_HARD_CAP)                    # int
```

**Why percentage-with-cap, not absolute range:**
- *Percentage scales with the player's wealth* -- a 20% loss bites a 50g trader and a 500g trader proportionally, so the encounter feels real at every wealth level. Absolute ranges (e.g., "5..15g lost") would be devastating early and trivial late.
- *Hard cap protects Pillar 3.* Without a cap, a 25% loss on a 2000g trader is 500g -- catastrophic enough to feel like a single roll killed them, which violates "death rare and earned." The cap (start: 30g) means the worst single bandit hit is bounded. A trader with 800g loses at most 30g per encounter, never 200g.
- *Critic's Pillar-1 demand: bounds visible.* The expected-cost hint (§5.5) reads `+0..<max>g`. The `<max>` displayed is `min(BANDIT_GOLD_LOSS_HARD_CAP, round(BANDIT_GOLD_LOSS_MAX_FRACTION * trader.gold))` -- the actual upper bound of what the player could lose this leg, computed from current gold. Visible. Computable.
- *Floor at zero* -- a 5% loss on 3 gold rounds to 0, and that's intended (encounter "fires" but does nothing material -- still gets a history line). See §8.

### 5.5 Expected-cost computation -- ANSWER (open question 3)

The cost-preview hint surfaces base cost, the loss range, the route tag, and the probability. ASCII only, in the existing ConfirmDialog text body:

**Plain edge:** `Travel Hillfarm -> Rivertown. Cost: 12g. Time: 4 ticks.`

**Bandit edge** (post-playtest amendment, two-line):
```
Travel Hillfarm -> Rivertown. Cost: 12g. Time: 4 ticks.
Bandit road: 30% chance to lose up to 6g.
```
> **Spec amendment 2026-05-02:** earlier draft used the compressed one-line `(+0..6g, bandit road, ~30%)` form. First playtest showed the numeric components were unparseable without labels. Replaced with two-line labelled format. See [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] amendment for the player-facing polish-pass owe-note.

Wording rules:
- `Cost: 12g` is the deterministic base cost; the player always pays this on confirm. The `(...)` is the *additional* expected variability.
- `+0..6g` is the loss range computed from current gold (`6g = min(BANDIT_GOLD_LOSS_HARD_CAP, roundi(BANDIT_GOLD_LOSS_MAX_FRACTION * trader.gold))`). On a 50g trader at `MAX_PCT = 0.20`, this reads `+0..10g`; on an 800g trader, `+0..30g` (the cap). The min is always 0 because the encounter may not fire AND because a fired encounter on near-zero gold rounds to 0.
- `bandit road` is the same lowercase-paren tag syntax slice-3 uses for `(plentiful)` / `(scarce)` (consistency by precedent: `2026-05-02-slice-3-hud-tags-plentiful-scarce`).
- `~30%` is `BANDIT_ROAD_PROBABILITY * 100` rounded to integer percent. The tilde signals approximation -- because P is a constant, the player can compute exact expected value if they want, but the hint reads as a quick legibility prompt rather than a precise wager.
- The `(...)` block is **not** present for non-bandit edges. The plain `Cost: 12g.` line is the slice-3 baseline, unchanged.

**Rejected alternatives:**
- `Cost: 12g (bandit road, expected +3g)` -- a single expected number hides the variance, which is exactly what makes a bandit road feel different from a flat surcharge. The player should see "you might lose nothing, you might lose six" not "average three." The latter encourages thinking of the encounter as a tax; the former preserves the gamble-vs-arbitrage tension.
- `Cost: 12g (bandit road)` (no numbers) -- Critic's flagged Pillar-1 risk. Tag without numbers is gambling, not arbitrage.
- Surfacing the seed / tick of the roll -- breaks the abstraction; the player isn't supposed to know they could re-derive the outcome.

### 5.6 Resolution timing -- ANSWER (open question 5)

**Roll fires at departure (already established §5.3); outcome is APPLIED at arrival** (the tick `ticks_remaining` reaches 0). The history line is written at the same arrival moment, immediately after the standard travel arrival writes `location_node_id`. The player sees the history-line readback on the next render after arrival -- same frame as the destination's prices appearing.

**Why arrival, not departure:**
- *Narrative arc, even without narrative.* Departure is "I commit to the road"; arrival is "I survived the road." Resolving at departure (showing the gold loss the moment you confirm) collapses the arc and makes travel feel like a tax, not a journey.
- *Travel mid-flight is empty time, but it shouldn't be empty stakes.* Knowing the encounter resolved while you watch `Travelling: 3 ticks remaining` undercuts the per-tick yield. Arrival-application means the per-tick yield carries genuine "what's waiting at the other side" weight.
- *Save mid-travel correctness.* The outcome IS resolved at departure (deterministic, persisted), but display-applied at arrival. Save during travel after departure: outcome already on `trader.travel.encounter`. Reload mid-travel: ticks tick down as before, arrival applies the outcome from save. No re-roll, no surprise.
- *Rejected: mid-travel application (some specific tick).* Adds a "when does it happen" knob with no kernel value; the player can't react during travel anyway (no choice UI by frame). Strictly cosmetic.

**Application sequence at arrival** (extends `TravelController.process_tick`'s existing arrival branch):

```
if _trader.travel.ticks_remaining <= 0:
    var encounter: EncounterOutcome = _trader.travel.encounter
    _trader.location_node_id = _trader.travel.to_id
    # Apply encounter BEFORE clearing travel, so the encounter readback can
    # reference travel.from_id / to_id in its history detail.
    if encounter != null and encounter.fired:
        _apply_encounter(encounter)   # gold delta + history push
    _trader.travel = null
```

`_apply_encounter` calls `apply_gold_delta(-encounter.gold_loss, ...)` (single path through the existing gold mutator -- Critic-mandated), then pushes a `kind: "encounter"` history entry. Day-2 also applies `apply_inventory_delta(good_lost_id, -good_lost_qty)`.

### 5.7 Goods-loss outcome (day-2) -- ANSWER (open question 7)

**Most-valuable-good-by-quantity-lost-fraction.** When the encounter fires AND the player has at least one good in inventory, additionally to the gold loss:

```
# After computing gold_loss, if trader has any goods:
if total_inventory_qty(trader) > 0:
    target_good: String = _highest_value_good(trader, world.nodes[from_id].prices)
    qty_lost: int = max(1, floor(BANDIT_GOODS_FRACTION * trader.inventory[target_good]))
    qty_lost = min(qty_lost, trader.inventory[target_good])  # cap by carried qty
    outcome.good_lost_id = target_good
    outcome.good_lost_qty = qty_lost
```

**Why most-valuable, not random or all-prorated:**
- *Pillar 1.* Most-valuable is computable -- the player can look at their inventory and the origin-node prices and predict which good is at risk. Random would require the player to mentally weight every good's loss probability. All-prorated (lose 20% of every good) is computable but tedious and scrubs the texture out of the loss.
- *Most-valuable creates a tradable risk.* A trader carrying 10 wool (cheap) plus 1 silk (expensive) thinks "the silk is the target"; a trader carrying 10 wool only thinks "wool is the target." That mental model is the kernel-side win -- the player learns "high-value cargo on bandit roads is double exposure."
- *Pillar 2 (cost felt).* Losing the most valuable good ensures the encounter has bite at every cargo composition. Random often hits the cheapest, which is a damp squib.
- *"Most-valuable" defined by origin-node sale price* (the price the player saw when they bought, captured at departure-roll time via the from_id lookup). This is the price the player would have realized if they hadn't been robbed -- the loss is in lost-arbitrage terms, which is the right mental model for a careful merchant.
- *Tie-break: lex-min good_id.* Determinism on identical-value cargoes.

**Display:** the cost preview does NOT enumerate goods loss in the hint -- the gold-loss range stays the headline. The history line on resolution names the lost good explicitly (§7).

### 5.8 Worked examples

Setup constants: `BANDIT_ROAD_FRACTION = 0.35`, `BANDIT_ROAD_PROBABILITY = 0.30`, `BANDIT_GOLD_LOSS_MIN_FRACTION = 0.05`, `BANDIT_GOLD_LOSS_MAX_FRACTION = 0.20`, `BANDIT_GOLD_LOSS_HARD_CAP = 30`, `TRAVEL_COST_PER_DISTANCE = 3`. Trader at Hillfarm, 200g, no cargo.

**Example (a) -- bandit-free run.** Player picks Hillfarm -> Oxmere, edge distance 4, `is_bandit_road = false`. ConfirmDialog reads `Travel Hillfarm -> Oxmere. Cost: 12g. Time: 4 ticks.` Confirm. -12g, four ticks pass, arrive at Oxmere with 188g. No history-line beyond the standard travel entry. Encounter system did nothing -- the kernel feels exactly like slice-3 here, and that's correct: not every leg interesting.

**Example (b) -- bandit road taken, encounter fires, gold loss.** Player picks Hillfarm -> Rivertown, edge distance 4, `is_bandit_road = true`. ConfirmDialog: `Travel Hillfarm -> Rivertown. Cost: 12g (+0..30g, bandit road, ~30%). Time: 4 ticks.` (`30g` is the hard cap, hit because `0.20 * 200 = 40 > 30`.) Confirm. -12g (now 188g), encounter rolls at departure: `randf() = 0.21 < 0.30` -> fires; `loss_pct = 0.13`; `raw_loss = round(0.13 * 188) = 24`; clamped to 24 (under cap). Outcome: `fired=true, gold_loss=24`. Stored on `trader.travel.encounter`, NOT yet applied. Four ticks tick down. On arrival: location set to Rivertown, encounter applied: -24g (now 164g), history-line `Hillfarm->Rivertown (bandit road, -24g)` with `delta_gold = -24` and `kind = "encounter"`. Player sees Rivertown prices AND the history line same frame.

**Example (c) -- bandit road taken, encounter does not fire.** Same setup, same edge. Departure roll: `randf() = 0.74 >= 0.30` -> does not fire. Outcome: `fired=false, gold_loss=0`. Travel proceeds normally; arrival is the standard travel arrival; **no encounter history line is written** (the standard travel entry from §5.3 is the only ledger row). The player learns implicitly via absence -- the bandit road sometimes pays off. This is the lucky-leg signal: silence.

**Example (d) -- day-2: bandit road, encounter fires, goods loss.** Same Hillfarm -> Rivertown bandit road, but trader carries 5 wool (Hillfarm price 8g each, total carried value 40g) and 2 cloth (Hillfarm price 22g each, total 44g). Encounter fires, `gold_loss = 24` as in (b). Most-valuable check: cloth's per-unit price (22g) > wool's (8g); even per-unit comparison says cloth. `qty_lost = max(1, floor(0.5 * 2)) = 1`. Outcome adds `good_lost_id = "cloth", good_lost_qty = 1`. On arrival: -24g, -1 cloth, history line `Hillfarm->Rivertown (bandit road, -24g, -1 cloth)`. Player loses the high-value cargo specifically -- the lesson "don't carry silk through bandit country" is built in.

## 6. Numbers (tuning ranges)

Mirrors `slice-3-pricing-spec.md` §6. New rows below the slice-3 rows.

| Knob | Starting value | Range | What it tunes / symptoms |
|---|---|---|---|
| (slice-3 knobs unchanged) | -- | -- | per slice-3 §6 |
| `BANDIT_ROAD_FRACTION` | **0.35** | 0.20-0.50 | Fraction of edges flagged as bandit roads at gen time. Low = often zero-bandit worlds (kernel collapses to slice-3); high = can't avoid bandit roads, removes the route-choice trade-off (Pillar 1 risk: no meaningful alternative). `[needs playtesting]` |
| `BANDIT_ROAD_PROBABILITY` | **0.30** | 0.15-0.45 | Probability a bandit-road leg fires per crossing. Low = bandit tag is cosmetic, kernel doesn't bite; high = bandit roads are de-facto closed. `[needs playtesting]` |
| `BANDIT_GOLD_LOSS_MIN_FRACTION` | **0.05** | 0.03-0.10 | Floor of percentage-of-gold loss when encounter fires. Below 0.03 the loss reads as zero on common gold values (50-100g); above 0.10 the floor merges with the ceiling and the variance disappears. |
| `BANDIT_GOLD_LOSS_MAX_FRACTION` | **0.20** | 0.15-0.30 | Ceiling of percentage-of-gold loss when encounter fires. Above 0.30 the worst-case bites Pillar 3 (death rare and earned -- a single fired encounter shouldn't approach a death). `[needs playtesting]` |
| `BANDIT_GOLD_LOSS_HARD_CAP` | **30** | 20-60 (gold) | Absolute cap on gold lost per encounter. Sized so a 200g trader's worst case (`0.20 * 200 = 40`) is capped to 30 -- a meaningful but recoverable hit. Cap should track median-trader-gold; revisit when slice-5 introduces wealth ceilings. `[needs playtesting]` |
| `BANDIT_GOODS_FRACTION` (day-2) | **0.50** | 0.25-0.75 | Fraction of the targeted good's stack that is lost. 0.5 with `max(1, floor(...))` means a 1-unit stack loses 1, a 4-unit stack loses 2, an 8-unit stack loses 4. Lower = encounter feels gentle on cargo; higher = high-value cargo runs become unviable on bandit roads. `[needs playtesting]` |

Schema-side determinism inputs (`hash([effective_seed, "encounters"])`, `hash([world_seed, tick, lo_id, hi_id, "encounter_roll"])`) are not knobs -- they are contracts.

## 7. Feedback (programmer-art budget)

ASCII only. No tweens, no colour, no audio. No new screens, no resolution modal (deferred to slice-4.x).

**ConfirmDialog** -- the slice's one new-text surface. Two formats based on `edge.is_bandit_road`:

```
# Plain edge (unchanged from slice-3):
Travel Hillfarm -> Rivertown. Cost: 12g. Time: 4 ticks.

# Bandit edge (new):
Travel Hillfarm -> Rivertown. Cost: 12g (+0..30g, bandit road, ~30%). Time: 4 ticks.
```

The bandit-edge `(...)` block is constructed by ConfirmDialog from inputs passed by Main -- Main computes `gold_loss_max = min(BANDIT_GOLD_LOSS_HARD_CAP, roundi(BANDIT_GOLD_LOSS_MAX_FRACTION * trader.gold))` and the probability percent, passes both to ConfirmDialog.prompt. Architect call: signature change on `prompt()` vs adding a separate `prompt_with_encounter()` -- Designer leans signature change (one entry point, optional fields), Architect ratifies (§9).

**HistoryEntry on encounter resolution** -- new kind `"encounter"`, written by `_apply_encounter` immediately after the gold deduction.

```
# Day-1 (gold loss only):
"detail": "Hillfarm->Rivertown (bandit road, -24g)"
"delta_gold": -24

# Day-2 (gold + goods loss):
"detail": "Hillfarm->Rivertown (bandit road, -24g, -1 cloth)"
"delta_gold": -24

# Day-1 fired-but-zero (rare, see §8):
"detail": "Hillfarm->Rivertown (bandit road, -0g)"
"delta_gold": 0
```

The travel-cost line is unchanged: `kind: "travel", detail: "Hillfarm->Rivertown", delta_gold: -12` is still pushed at departure. The encounter line is a separate entry, pushed at arrival when `fired == true`. **Two history entries per bandit-fired leg, one per non-fired leg.** Lucky bandit legs (fired = false) write zero encounter entries -- the absence is the signal.

**No travel-mid-flight surfacing.** The `Travelling: N ticks remaining` label is unchanged; it does not say "an encounter is brewing" or "you've been robbed but don't know it yet." The whole point of arrival-application (§5.6) is the surprise is preserved.

**No node-panel changes.** Encounters are an edge attribute, surfaced on the cost preview, not on the node panel. NodePanel rendering stays slice-3.

**No new sprite, no map-overlay tag.** The bandit road's tag lives in the cost preview; the player learns which edges are bandit by previewing them. (Architect / future polish: a map-overlay icon on bandit edges is in scope for slice-4.x or later UI polish; not slice-4 day-1 or day-2.)

## 8. Edge cases and failure modes

- **Encounter on a route with zero gold** (trader at 0g, traveling because they have a non-zero outbound bandit-edge cost would have been gated -- but a 0-distance / 0-cost edge cannot exist per `EdgeState.is_valid`). Realistic scenario: trader at 12g exactly, takes a 12g bandit edge, gold goes to 0 at departure. Encounter rolls, fires; `loss_pct * 0 = 0`; `gold_loss = 0`. Outcome stored as `fired=true, gold_loss=0`. On arrival: `apply_gold_delta(-0, ...)` is a no-op (returns true; gold_changed signal fires with delta 0 -- existing slice-2 behaviour). History line still written: `"Hillfarm->Rivertown (bandit road, -0g)"`. **Critically: this does NOT trigger death.** The death cause is `stranded` (gold=0 AND can't afford any outbound edge from the destination), evaluated by DeathService on the next gold mutation or location settle -- and by precedent `2026-04-29-slice-one-death-cause-bankruptcy`, the only death cause in the slice is `stranded`. **`slain` is deferred to slice-4.x (§10).** A fired-but-zero encounter is a moral defeat, not a literal one.
- **Encounter on a route with empty inventory (day-2 path).** `total_inventory_qty == 0` -> goods-loss block skipped. Gold loss applies normally. `outcome.good_lost_id = ""`, `outcome.good_lost_qty = 0`. History line omits the goods clause: `"Hillfarm->Rivertown (bandit road, -24g)"` (same as day-1). **Test:** spawn at Hillfarm with no cargo, take a bandit road, force fire via seed -- verify history line and no inventory mutation.
- **Save during travel after encounter resolved but before player sees readback.** The save captures `trader.travel.encounter` with `fired=true, gold_loss=24, readback_consumed=false`. On reload: ticks tick down from `ticks_remaining`, arrival applies the outcome from save (no re-roll), history line is pushed at arrival as if it just happened. Player sees the readback when they arrive -- which on a save-on-tick-1-of-4 is three more ticks of perceptible delay, exactly as it would have been without save. **The `readback_consumed` flag is not strictly required for slice-4 day-1** (history-line-only ships first; the modal that needs the flag is deferred). Designer recommends including the field in the save schema NOW so slice-4.x's modal doesn't trigger another schema bump for a single bool. Architect to ratify (§10).
- **Old slice-3 save loaded after schema bump.** `from_dict` returns null on `schema_version != 4`. Existing corruption-toast path fires: `"Save discarded: schema upgraded. New world generated."` New world generates on next boot. **Test:** load a slice-3 save on slice-4 build; expect toast.
- **Bandit-road tag absent on every edge (zero-bandit world).** Possible at low `BANDIT_ROAD_FRACTION` on small graphs. With FRACTION=0.35 and 9 edges (NODE_COUNT=7 with 6 MST + 2 extra + maybe 1 more), expected count is `9 * 0.35 = 3.15`; zero-bandit worlds are rare (probability `0.65^9 = ~2.1%`) but not impossible. **Slice-4 accepts this.** The world plays exactly like slice-3; the encounter system did its job by being legibly absent. If playtest shows zero-bandit worlds feel hollow (the slice's whole point is dormant), slice-4.x adds a minimum-count invariant (§10). **No assert; no seed bump.**
- **Deterministic re-roll across reload (must produce same outcome).** Already covered above: outcomes are persisted, not recomputed. The hash is deterministic but is not the source of truth on reload -- the save is. **Test:** seed a world, take a bandit road, save mid-travel, reload, complete travel; the gold lost on arrival must equal the gold lost in a no-save reference run from the same seed.
- **Encounter resolution touches `apply_gold_delta` while `dead == true`.** Cannot happen -- death is checked after every gold mutation, and the `apply_gold_delta` path's slice-1 contract refuses negative results. If a fired encounter would push gold below 0... wait, the encounter cannot push gold below 0 because `gold_loss = clampi(roundi(loss_pct * trader.gold), 0, HARD_CAP)`, and `loss_pct <= MAX_PCT < 1.0`, so `gold_loss < trader.gold` strictly (and trader.gold here is post-travel-cost -- the cost was deducted at departure and trader survived that gate). The only zero-result case is the §8 first item (trader at 0g pre-encounter); `gold_loss = 0`, `apply_gold_delta(0)` succeeds. **No new death path opens via slice-4.** Pillar 3 protected.
- **Bandit-road tag on a 1-edge graph (degenerate).** NODE_COUNT=2 hypothetical: only one edge, MST builds it, encounter rolls, may flag it. Player has to take it (only edge from spawn). No alternative route. **Unwinnable bandit pressure.** Acceptable per Pillar-1 reading: the player can SEE the tag, can SEE the expected cost, can choose to wait... except they can't wait (no wait verb in slice-spec). Edge case is moot at NODE_COUNT=7 (always >=2 outbound edges from any node by MST construction); flagged for future low-node-count modes.
- **Bandit-road bool deserializes as missing field.** `_edge_from_dict` returns null on missing `is_bandit_road` key. Strict-reject precedent: corruption toast, regen world. (Defensive against partial schema-3->4 hand-edits.)
- **`encounter` block on TravelState deserializes as malformed (e.g., `fired` missing, `gold_loss` non-int).** `_travel_from_dict` returns null on any required-field-missing or wrong-type. Same strict-reject path. The `encounter` block itself is OPTIONAL on the `travel` dict (a non-bandit-edge departure has `encounter = null`); a present encounter dict must be well-formed.
- **Schema-4 save with mid-development tuning changes** (e.g., `BANDIT_ROAD_PROBABILITY` raised from 0.30 to 0.45). Saves remain loadable; the world's *behaviour* on next encounter changes; the resolved outcome on a save-mid-travel does not change (it was committed to the save). Acceptable -- this is the standard tuning workflow. Bandit-road tags are also gen-time, so they don't change on tuning either. **The thing that DOES change behavior is `BANDIT_ROAD_FRACTION`**, but only on next world-gen; it doesn't re-tag a loaded world's edges. Saves are loadable; no migration.

## 9. Integration touch points

Updates `slice-3-pricing-spec.md` §9. New ownership lines below.

| Touch point | Systems involved | Owner |
|---|---|---|
| **Bandit-road tag authoring** | `WorldGen._author_encounters` (writes once at gen), `EncounterResolver` (reads at departure), `ConfirmDialog`/`Main` (reads for cost preview) | **`WorldGen`** authors. **`EdgeState.is_bandit_road`** owns the field. After gen, the tag is immutable -- no system mutates it. |
| **Encounter roll** | `TravelController.request_travel` (calls), `EncounterResolver.roll` (computes), `EncounterOutcome` (return value) | **`EncounterResolver`** (new module/static class -- Architect call on placement). Pure function: takes (world_seed, tick, edge, trader), returns outcome. No state. |
| **Encounter outcome storage** | `TravelController` (writes), `TravelState.encounter` (holds), `SaveService` (persists) | **`TravelState`** owns the `encounter: EncounterOutcome` field. Set once at departure, read once at arrival (apply), then cleared with the rest of `travel`. |
| **Encounter application** | `TravelController.process_tick` arrival branch | **`TravelController`** owns the apply call. Routes through `apply_gold_delta` (slice-1 contract preserved -- single path for all gold mutation) and `apply_inventory_delta` (day-2). Pushes the `kind: "encounter"` history entry. |
| **Cost-preview enrichment** | `Main._on_travel_requested` (computes hint inputs), `ConfirmDialog.prompt` (renders) | **`Main`** computes gold_loss_max and probability percent (it already has trader and edge in scope). **`ConfirmDialog.prompt`** is extended to take optional encounter-hint params. |
| **`BANDIT_*` constants** | `WorldGen`, `EncounterResolver`, `ConfirmDialog` (via Main), `_apply_encounter` | **`WorldRules`** (sibling of slice-3's `BIAS_*`, `MEAN_REVERT_RATE`). One source of truth. Architect to ratify the placement. |
| **History kind `"encounter"`** | `HistoryEntry.KINDS` (validation), `_apply_encounter` (writer), DeathScreen / ledger UI (reader, future) | **`HistoryEntry`** owns the kind list. Slice-4 adds `"encounter"` to `KINDS`. |

The slice-3 cross-system signals (`tick_advanced`, `gold_changed`, `state_dirty`, `died`) are unchanged. **No new signal in slice-4.** The encounter outcome flows synchronously through the existing `request_travel` -> `process_tick` -> `apply_gold_delta` chain; no async, no event bus addition.

## 10. Open questions

- `[needs playtesting]` All numbers in §6, especially `BANDIT_ROAD_FRACTION` x `BANDIT_ROAD_PROBABILITY` (the joint distribution is what the player feels as "how often does the encounter system fire on a typical run") and `BANDIT_GOLD_LOSS_HARD_CAP` (sized against expected median trader gold, which itself isn't measured yet).
- `[needs Architect call]` **`EncounterResolver` placement.** New file `godot/travel/encounter_resolver.gd` (script-only, static methods only -- mirrors `WorldRules` shape) OR inline static methods on `TravelController` OR new sibling node under `TravelController`? Designer leans: new script-only file, static, in `godot/travel/` (same folder as `travel_controller.gd`, `travel_state.gd`). Reasoning: pure function over inputs, no state, no node lifecycle needed; new file because the math is heavier than belongs inside `TravelController` and slice-4.x's modal will want to reference the same outcome type. Architect to ratify or push back.
- `[needs Architect call]` **`EncounterOutcome` Resource vs nested dict.** Designer leans Resource (`godot/travel/encounter_outcome.gd extends Resource`), `@export`'d fields: `fired: bool`, `gold_loss: int`, `good_lost_id: String`, `good_lost_qty: int`, `readback_consumed: bool`. Mirrors `TravelState` shape. Save serialization via dict in `to_dict`/`from_dict`, same as slice-1's pattern. Argument for nested dict: less ceremony for a 5-field struct. Argument for Resource: type safety, matches existing slice's resource discipline, easier to extend in slice-4.x.
- `[needs Architect call]` **`ConfirmDialog.prompt` signature change.** Add optional encounter-hint params (`gold_loss_max: int = 0, probability_pct: int = 0, is_bandit: bool = false`) OR add separate `prompt_with_encounter()` method. Designer leans single signature change with defaulted params -- one call site (Main), one entry point.
- `[needs Architect call]` **`readback_consumed` flag persistence.** Slice-4 day-1 ships history-line-only; the flag is unused. Including the field NOW means slice-4.x's modal lands without a schema bump. Excluding it means a clean schema-4 today and a schema-5 in slice-4.x. Designer leans **include now** -- the cost is one bool in the save, the savings is one schema bump. Architect to ratify.
- **Slice-4.x [encounter-death-cause] (logged carryover).** `slain` second death cause + death-cause-context plumbing. **Currently blocked by precedent [[2026-04-29-slice-one-death-cause-bankruptcy]] (one death cause: stranded, in the slice).** The slice-4.x decision must explicitly overturn that precedent's slice-scoped clause. Slice-4 day-1's gold-loss outcome cannot push gold below 0 (proven §8 last-but-one bullet), so `slain` is genuinely deferrable -- a fired encounter never directly kills the trader in slice-4. The slice-4.x death cause would model "left for dead" semantics: trader at very low gold gets robbed, can't afford onward travel from arrival node, becomes stranded -- but the *cause label* in the death record should be `slain` not `stranded` because the bandit hit was the proximate cause. Requires DeathService context plumbing (last-N-history-entries lookback, or an `attributed_cause` field on the encounter outcome). Defer to slice-4.x.
- **Slice-4.x [encounter resolution modal] (logged carryover).** History-line-only ships first; modal lands if playtest demands. The modal would: (1) pause the game on arrival when `encounter.fired && !encounter.readback_consumed`, (2) display "You were attacked on the road from Hillfarm. -24g.", (3) on dismiss, set `readback_consumed = true` and persist. The `readback_consumed` flag (above Architect call) gates this. **Defer.**
- **Slice-4.x [bandit-road min-count] (logged carryover).** Only if zero-bandit worlds feel hollow in playtest. Implementation would add `MIN_BANDIT_ROADS = 1` (or a fraction-of-edges floor); if `_author_encounters` produces fewer, force-flag the lex-min-id edges until the floor is met (or seed-bump). Ordering of forced-flag selection is the only design surface here. **Defer.**

---

## Hand off to Architect

The Architect must make three structural decisions before the Engineer touches code:

1. **`EncounterResolver` placement and shape.** New script-only file `godot/travel/encounter_resolver.gd` with static methods (Designer's lean -- mirrors `WorldRules`), or inline static methods on `TravelController`, or new sibling node? Bound up with the related call: should `EncounterOutcome` be a Resource (`godot/travel/encounter_outcome.gd`) for type-safe field access, or a nested dict? Designer leans: separate script-only `EncounterResolver`, separate Resource `EncounterOutcome`. Pick once, document.

2. **Cost-preview enrichment wiring.** Where does `gold_loss_max` get computed -- in `Main._on_travel_requested` (Designer's lean: Main already has trader + edge + cost in scope), or in a new helper on `EncounterResolver` (`expected_loss_bounds(trader, edge) -> {min: int, max: int}`)? And: `ConfirmDialog.prompt` signature extension with defaulted params, or separate `prompt_with_encounter` method? Designer leans extended signature (one call site, optional fields). Both should land together so the Engineer doesn't ship a half-wired preview.

3. **`BANDIT_*` constants and `readback_consumed` field.** Constants live in `WorldRules.gd` next to `BIAS_*` and `MEAN_REVERT_RATE` (Designer's lean: precedent already established in slice-3 §9). The `readback_consumed: bool` field on `EncounterOutcome` is included NOW (Designer's lean: pre-empts a slice-4.x schema bump for one bool) even though slice-4 day-1 ships history-line-only and never reads it. Architect ratifies both.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies the three calls above. Numbers in §6 are starting values; tuning happens in playtest, not in spec. Day-1 (gold-loss kernel + cost-preview tag) ships before day-2 (goods-loss + visible expected-cost hint extension); the Engineer should not bundle them.
