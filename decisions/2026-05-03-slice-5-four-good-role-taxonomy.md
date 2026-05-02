---
title: Four-good role taxonomy spans (price, volatility) 2x2; expensive-volatile corner excluded
date: 2026-05-03
status: ratified
tags: [decision, slice-5, design, taxonomy, predicate]
---

# Four-good role taxonomy spans (price, volatility) 2x2; expensive-volatile corner excluded

## Decision
The slice-5 catalogue is four goods occupying four corners of one (price, volatility) plane:

| Role | Good | base | floor | ceiling | volatility |
|---|---|---|---|---|---|
| Cheap, mid-volatile (existing) | wool | 12 | 5 | 25 | 0.10 |
| Mid-expensive, stable (existing) | cloth | 18 | 8 | 32 | 0.06 |
| Cheap, volatile (new, day-1) | salt | 7 | 3 | 14 | 0.13 |
| Expensive, stable (new, day-2) | iron | 22 | 14 | 32 | 0.05 |

The expensive-volatile corner (spice, silk, gemstones) is **explicitly not authored** in slice-5. It is unauthor-able under the slice-3 free-lunch predicate at the current `MIN_EDGE_DISTANCE = 3`: an expensive-volatile good (e.g., base=25, vol=0.12, ceiling=45) burns 10.8g of the 9g per-good budget on the volatility term alone, leaving negative headroom. The corner becomes a slice-6+ candidate only if a future slice raises `MIN_EDGE_DISTANCE` or `TRAVEL_COST_PER_DISTANCE`.

Numbers in the table are starting values; `[needs playtesting]` per spec §5.

## Reasoning
Two volatility tiers and two price tiers gives four goods that each answer a different "what kind of merchant am I being right now" question. With only one axis (e.g., four price tiers all at vol=0.10), the goods would feel like the same good at different scales -- which fails the legibility-per-good gate from [[2026-05-03-slice-5-goods-catalogue-expansion-scope]]. Volatility sets the role; price sets the scale. A player who learns "salt jitters, iron holds" has the entire mental model in one sentence.

The role spread is structurally predicate-aware. Iron is the load-bearing good for predicate failure: vol-term `2 * 0.05 * 32 = 3.20g`, leaving 5.80g of budget for bias, giving allowed_range `5.80 / 22 = 0.264` -- only 0.064 above `MIN_BIAS_RANGE = 0.20`. If `MIN_EDGE_DISTANCE` ever drops below 3 or iron's ceiling rises, iron is the first to fail. Salt is comfortable: vol-term `3.64g`, allowed_range capped at the global envelope `0.80`.

Per-good purpose in the kernel:
- **Wool** rewards mid-distance round-trip routes; bias and drift contribute equally.
- **Cloth** rewards long planned routes between (plentiful)/(scarce) nodes; structural bias dominates.
- **Salt** rewards short opportunistic trips timing drift swings; high volatility, low capital, fast turnover.
- **Iron** rewards capital-heavy routes between extreme-bias nodes; volatility is rounding noise; high capital, slow turnover.

## Alternatives considered
- **Spice / silk / gemstones (expensive, volatile fourth corner)** -- rejected; predicate-unauthor-able at current budget. Logged as slice-6+ candidate.
- **Six or more goods on day-1** -- Critic compressed to 4 (Branch B's natural shape); 6 is a slice-5.x extension once 4-good playtest confirms tag-and-role legibility.
- **A new mechanical axis (perishability or weight) instead of count expansion** -- Branch C, deferred.

## Confidence
High. Designer spec §4, §5, §7 all binding; Architect ratified no schema bump (catalogue is `.tres` authoring + per-good values); Reviewer cleared salt.tres values against spec §5 line-by-line.

## Source
Designer spec `docs/slice-5-goods-expansion-spec.md` §4 (role taxonomy table), §5 (authored values), §7 (predicate interaction math).

## Related
- [[2026-05-03-slice-5-goods-catalogue-expansion-scope]] -- the parent scope decision
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- the predicate-strain measurement gate
- [[2026-04-29-procgen-world-authored-vocabulary]] -- the hand-authored-vocabulary constraint
