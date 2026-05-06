---
title: Cross-node legibility floor lowered 0.40 -> 0.25 (structural ceiling)
date: 2026-05-05
status: ratified
slice: 8.2.1
tags: [decision, slice-8.2.1, measurement-gate, pillar-2, calibration-anchor]
---

# Cross-node legibility floor lowered 0.40 -> 0.25 (structural ceiling)

## Decision
The cross-node legibility pass-criterion floor in `measure_demand_drift.gd` is lowered from **`>= 0.40`** to **`>= 0.25`**. This is a measurement-gate floor, not a generation target.

Spec doc `docs/slice-8-2-demand-reshape-spec.md` §9 updated to reflect the new floor and the structural reasoning.

## Reasoning
After slice-8.2.1's retune to shadow-respecting ratios (producer 0.0 / neutral target 0.20 / consumer effective ~0.43), the empirical cross-node spread mean landed at 0.32 -- failing the original 0.40 floor.

The structural finding: **0.40 is mathematically unreachable** under the kernel-collision shadow with the current goods catalogue. Iron's `base_price = 22` and the cheapest edge travel cost = 9 means consumer ratio cannot exceed `9/22 ~= 0.41`. With consumer's ratio capped at ~0.41 and producer at 0.0, the cross-node mean of all (node, good) pairs cannot exceed ~0.41 either; the mean will sit well below it because most pairs are not consumer cells.

The 0.40 floor was set in slice-8.2's spec when consumer ratio was 0.85 (producing cross-node spread of 0.55 by construction). At that ratio, 0.40 was a defensible "design must not drift below this" floor. After slice-8.2.1 enforces the shadow, 0.40 can never be hit no matter how good the design.

The 0.25 floor is the **empirical floor under shadow-respecting ratios** -- still above Critic's original 0.20 hedged starting point, still discriminates a half-broken design, but no longer mathematically unreachable.

This floor is now explicitly a **pillar 2 (texture) metric only**, decoupled from kernel-collision concerns (which are now enforced by [[2026-05-05-slice-8-2-1-same-node-shadow-permanent-gate]]).

## Alternatives considered
- **Lower iron's `base_price`** -- deferred. Goods-balance change; could ripple through the catalogue and other slice-balanced numbers. Out of slice-8.2.1 scope.
- **Raise `MIN_EDGE_DISTANCE` or `TRAVEL_COST_PER_DISTANCE` to widen the kernel shadow** -- deferred. Affects playtest balance globally; risky without broader equilibrium study.
- **Keep the 0.40 floor and ship with FAIL** -- rejected; harness output should ship clean.

## Confidence
High. Empirical measurement (200 seeds) + structural derivation (`9/22 ~= 0.41` ceiling) both confirm 0.40 unreachable; Engineer flagged the gap; Director ratified the lower floor as same-slice numbers fix.

## Source
Engineer's headless run during slice-8.2.1 retune (2026-05-05); Director's same-day ratification.

## Related
- [[2026-05-05-slice-8-2-1-same-node-shadow-permanent-gate]] -- kernel-collision gate that now carries pillar 1 weight, freeing this floor to serve pillar 2 alone
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar 2 metric this floor measures
- [[2026-05-05-slice-8-2-1-consumer-drain-empirical-tuning]] -- the retune that surfaced this structural ceiling
