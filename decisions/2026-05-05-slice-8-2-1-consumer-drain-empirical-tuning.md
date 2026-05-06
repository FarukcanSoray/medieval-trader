---
title: Consumer drain mult empirically tuned to 11.5 over analytical 10.0
date: 2026-05-05
status: ratified
slice: 8.2.1
tags: [decision, slice-8.2.1, calibration, empirical-tuning, kernel-collision]
---

# Consumer drain mult empirically tuned to 11.5 over analytical 10.0

## Decision
`DEMAND_DRAIN_MULT_CONSUMER = 11.5` in `world_rules.gd` (effective steady-state ratio ~0.43). This is **empirical**, not analytical. Director's recommended value was 10.0 (analytical target ratio 0.50); first headless run with 10.0 breached the same-node arbitrage shadow in 93/200 worlds. Tuning to 11.5 lands iron's same-node max at exactly 9 gold (= cheapest edge cost), with 0/200 worlds breaching.

Principle codified: **when a constant lands near a binding constraint, trust empirical landing over analytical target.**

## Reasoning
Director's framing for slice-8.2.1 set consumer ratio target = 0.50, "at slice-8.1's line, top of the shadow." Steady-state equation `pool*/cap = decay/drain` with `DEMAND_DECAY_MULT_CONSUMER = 5.0` yields `drain_mult = 5.0/0.50 = 10.0` analytically.

Engineer's first headless run with `DEMAND_DRAIN_MULT_CONSUMER = 10.0` produced same-node arbitrage in iron of 10 gold (slightly above the 9-gold cheapest edge) and breached the kernel-collision shadow in 93/200 worlds. The analytical math was correct; the failure mode was that the analytical target sat *exactly at* the binding constraint, which gave perturbation, integer quantization, and per-world variance enough room to push real spreads above the line.

Engineer empirically swept drain_mult upward and landed 11.5 as the smallest value that produces 0/200 breaches with iron same-node max sitting exactly at the 9-gold ceiling. The new effective ratio is ~0.43 (= 5.0/11.5).

The principle generalizes: future tag-ratio decisions should treat the analytical target as a **starting point**, not the shipped value, when the target sits near a hard constraint. The empirical sweep with the headless tool is the load-bearing falsification step, not the math.

## Alternatives considered
- **Stick with analytical 10.0 and accept the 93/200 breach** -- rejected; the same-node shadow gate is now load-bearing pillar 1, breaches must be 0.
- **Tighten the cheapest edge cost (raise travel cost)** -- rejected; broader balance change, out of slice-8.2.1 scope.
- **Lower iron's `base_price`** -- rejected; goods-balance change, out of slice-8.2.1 scope.

## Confidence
High. Empirical sweep over 200 seeds confirms 0 breaches at 11.5; the gap between analytical target (10.0) and empirical safe value (11.5) is the load-bearing data point.

## Source
Engineer's headless tuning loop during slice-8.2.1 retune (2026-05-05).

## Related
- [[2026-05-05-slice-8-2-1-same-node-shadow-permanent-gate]] -- the gate that disciplined this tuning
- [[2026-05-05-slice-8-2-drain-conservation-composed]] -- the drain mechanism the constant parameterizes
- [[2026-05-05-slice-8-1-measure-demand-drift-no-trader]] -- the headless tool extended for this empirical sweep
