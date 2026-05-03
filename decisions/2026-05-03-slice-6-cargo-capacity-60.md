---
title: Slice-6.0 CARGO_CAPACITY = 60 derived from route-economy math
date: 2026-05-03
status: ratified
tags: [decision, slice-6, tuning]
---

# Slice-6.0 CARGO_CAPACITY = 60 derived from route-economy math

## Decision
`CARGO_CAPACITY = 60` (units). Derived from per-leg profit-spread analysis across the 3-node + slice-3 7-node procgen worlds. Single value; no per-trader variance this slice.

## Reasoning
Designer's route-economy math (spec §6) at cap=60, with weights (4,3,2,10) and 18g round-trip cost on a typical mid-game route:

- salt-only cart: nets +72g
- cloth-only cart: +82g
- wool-only cart: +57g
- iron-only cart: +30g
- mixed (4 iron + 20 salt): +74g

The four single-good returns are all positive AND all distinct -- four meaningfully different per-leg outcomes. The mixed example shows that the kernel still rewards careful allocation (74g beats wool, ties salt, loses to cloth and iron).

Boundary tests:
- **cap=40** -- starves iron's role (iron-only nets only +14g, often loss-making after travel cost). The role-taxonomy collapses: iron is no longer an option, the 4-good catalogue effectively becomes 3.
- **cap=100** -- flattens the knapsack. The cart is large enough to carry any affordable mix; the binding constraint moves entirely to gold, eliminating the "which good fits" tension the slice exists to introduce.
- **cap=60** -- sits at the balance: gold-cap binds early-game (forces trade-off), cargo-cap binds mid-game (forces "which good"), neither dominates entirely.

The harness sweep at [40, 48, 60, 72, 80] confirms 60 is inside the PASS region (40 and 48 also PASS the revised criterion at gold=200). The choice of 60 over 48 is feel-driven within the harness-valid region, per spec §6 ("Why 60, not 40 or 100").

## Alternatives considered
- **cap=40** -- rejected: collapses iron's role
- **cap=100** -- rejected: eliminates the cargo-decision the slice introduces
- **cap=48** -- not rejected, equally PASS-valid; chosen 60 for mid-game pacing feel

## Confidence
High on cap=60 being inside the harness PASS region; medium on the choice of 60 over 48 (feel-driven).

## Source
`docs/slice-6-weight-cargo-spec.md` §6 (route-economy math); harness sweep results in `godot/tools/cargo_divergence_verdict.txt`.

## Related
- [[2026-05-03-slice-6-cargo-cap-as-code-constant]] -- where the constant lives
- [[2026-05-03-slice-6-per-good-weights]] -- the weights this capacity is calibrated against
- [[feedback_measurement_before_tuning]] -- standing rule applied
