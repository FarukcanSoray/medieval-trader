---
title: Same-node arbitrage shadow is the permanent kernel-collision gate
date: 2026-05-05
status: ratified
slice: 8.2.1
tags: [decision, slice-8.2.1, kernel-collision, pillar-1, measurement-gate, permanent-gate]
---

# Same-node arbitrage shadow is the permanent kernel-collision gate

## Decision
At every (node, good) pair at steady state, the rule `max(0, sell_price - buy_price) <= cheapest_edge_travel_cost` for that world is now the **load-bearing pillar 1 (kernel collision) gate**. Any future tag-ratio change must be falsified against this metric before merge. Codified in `godot/tools/measure_demand_drift.gd` as the `same-node spread <= cheapest edge` pass criterion.

Cross-node spread is **reframed** from "primary pass criterion" to "pillar 2 texture metric only." It no longer carries kernel-collision weight.

## Reasoning
Slice-8.2 shipped with steady-state demand ratios (producer 0.30 / neutral 0.60 / consumer 0.85) that produced same-node arbitrage at high stock: at any node where stock was at or near cap, `buy_price = base` while `sell_price = (1 + ratio) * base`, giving free profit per unit with no travel. User identified this empirically in-play.

This is the same flaw class as slice-8.1's tick-0 same-node arb breach. Slice-8.1 had ratified an implicit rule -- "same-node spread sits inside the travel-cost shadow on short edges" -- but the rule lived only as Designer guidance, not as a falsifiable gate. Slice-8.2's tag-differentiation work raised the spread without re-checking that rule.

Director's verdict: "the absence of this gate in slice-8.2 is the actual root cause." Promoting the rule from guidance to a permanent measurement-tool gate ensures future tag-ratio changes cannot slip past the same way. The metric is per-(node, good) per-world (uses each world's own cheapest edge, not the global min), aggregated to a binary pass/fail across all 200 sweep seeds.

The reframing of cross-node spread is structural: with the same-node gate now enforcing pillar 1, cross-node spread is freed to be a pure pillar 2 (texture legibility) metric. This separation makes future tuning decisions tractable -- one metric per pillar.

## Alternatives considered
- **Add a spread guarantee on the formula (couple sell to buy at same node)** -- rejected as direction by Director; previously rejected in slice-8.1 as a band-aid that flattens texture. The texture pillar's "prices are the window into pool memory" property would be weakened by a same-node coupling.
- **Relax pillar 1 to "throughput-limited same-node arb"** -- rejected as premature; the drain-erodes-cap argument is real but unmeasured. Revisitable in a future slice if the numbers fix proves too tight.
- **Keep cross-node spread as the primary gate** -- the structural finding (slice-8.1's shadow rule) showed cross-node was never the pillar 1 metric; it was always pillar 2 texture.

## Confidence
High. Director's explicit verdict; Engineer codified the metric; pass criteria green at 0/200 worlds breaching after retune.

## Source
User empirical observation 2026-05-05 ("Still most of the products has cheaper buy than sell"); Director resolution call same day.

## Related
- [[2026-05-05-slice-8-1-asymmetric-initial-demand-fill-by-tag]] -- where the "spread inside travel-cost shadow" rule was first ratified (as guidance, not as a gate)
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar 2 framing that cross-node spread now serves alone
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula that creates the same-node spread when stock and demand decorrelate
- [[project-brief]] -- pillar 1 (kernel collision) this gate protects
- [[2026-05-05-slice-8-2-1-cross-node-floor-lowered]] -- companion decision; the cross-node floor is reframed to pillar 2 texture only
- [[2026-05-05-slice-8-2-1-consumer-drain-empirical-tuning]] -- the empirical tuning this gate disciplined
