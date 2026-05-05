---
title: Asymmetric initial demand pool fill by node tag
date: 2026-05-05
status: ratified
slice: 8.1
tags: [decision, slice-8.1, initial-state, arbitrage-fix]
---

# Asymmetric initial demand pool fill by node tag

## Decision
Demand pools fill asymmetrically at world gen (tick 0) based on node role:

- Producer (good in `node.produces`): initial `demand_pool = 0` (sell-dead for own good, intentional feature)
- Consumer (good in `node.consumes`): initial `demand_pool = cap`
- Neutral (neither): initial `demand_pool = floor(cap * 0.5)`

New `WorldRules` constants:
- `DEMAND_INITIAL_FILL_MULT_PRODUCER = 0.0`
- `DEMAND_INITIAL_FILL_MULT_NEUTRAL = 0.5`
- `DEMAND_INITIAL_FILL_MULT_CONSUMER = 1.0`

These are kept separate from `DEMAND_CAP_MULT_*` because they shape gen-time start state, not pool size.

## Reasoning
Slice-8 shipped with stock=cap AND demand=cap on every node at tick 0. Under the symmetric two-sided pool curves, this gave buy=base and sell=2*base at the same node, making free profit at any node with no travel. Director ruled this a hard kernel-collision breach (CLAUDE.md: "neither pillar works alone"; the kernel is the collision between travel cost and arbitrage profit, and same-node arbitrage decouples profit from travel entirely).

Asymmetric initial fill breaks the symmetry without touching the locked formula. The neutral 0.5 value is load-bearing: at 0, most goods become sell-dead everywhere and the trade graph collapses; above 0.5, same-node arbitrage reappears at neutral nodes. At 0.5 the within-node spread sits inside the travel-cost shadow on short edges, preserving the kernel collision.

## Alternatives considered
- **Symmetric fill (status quo from slice-8)** -- rejected, breaches kernel collision.
- **Spread guarantee (reshape sell curve to force sell < buy)** -- rejected by Director as a band-aid that papers over the symptom and weakens the texture pillar by flattening sell prices uniformly.
- **Neutral = 0** -- rejected, collapses the trade graph.
- **Neutral > 0.5** -- rejected, reintroduces same-node arbitrage at neutral nodes.

## Confidence
High. Director endorsed direction A; Designer specced the load-bearing 0.5 with reasoning; user confirmed both producer-sell-dead and the neutral=0.5 ship-and-measure approach.

## Source
Director verdict, Designer spec, and user confirmation during the slice-8.1 pipeline run on 2026-05-05.

## Related
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the symmetric curves this asymmetric fill compensates for
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this preserves
- [[2026-05-04-slice-8-demand-multiplier-inverse-supply]] -- multiplier philosophy this extends
- [[2026-05-04-slice-8-initial-demand-pool-fill-on-migration]] -- superseded by this decision
