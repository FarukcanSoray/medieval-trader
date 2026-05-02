---
title: Free-lunch predicate is an edge-length-conditional bias bound, enforced at gen time
date: 2026-05-02
status: ratified
tags: [decision, slice-3, free-lunch, pricing-model, kernel]
---

# Free-lunch predicate is an edge-length-conditional bias bound, enforced at gen time

## Decision
The free-lunch predicate uses option (a) from Designer's three options: an **edge-length-conditional bias bound, enforced at world-gen time, per good**. The predicate is:

```
worst_case_spread(g) = (bias_max_g - bias_min_g) * g.base_price
                       + 2 * g.volatility * g.ceiling_price
worst_case_spread(g) < shortest_edge_distance * TRAVEL_COST_PER_DISTANCE
```

On unsatisfiable: soft-fail return from `_author_bias`; the existing `MAX_SEED_BUMPS` retry loop in `WorldGen.generate` catches it.

## Reasoning
The kernel is `arbitrage profit perpendicular to travel cost`. Free lunch breaks the perpendicular: profit becomes guaranteed regardless of cost. That is a Pillar 2 collapse; the slice cannot ship with it.

## Alternatives considered
- **(b) Push back to generator with `MIN_EDGE_DISTANCE` raise** -- rejected as scope creep into the generator; treats free-lunch as topology when it's actually pricing-coupling. (Note: ended up necessary anyway after measurement -- see [[2026-05-02-slice-3-min-edge-distance-3-pulled-forward]].)
- **(c) Accept short-edge free lunch globally** -- rejected as direct Pillar 1 violation.

## Confidence
High. Designer named all three options and chose with kernel-first reasoning.

## Source
Designer spec §5.5.

## Related
- [[2026-05-02-slice-3-free-lunch-in-price-model]]
- [[2026-05-02-slice-3-min-edge-distance-3-pulled-forward]] -- option (b) had to come back via measurement
- [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]]
