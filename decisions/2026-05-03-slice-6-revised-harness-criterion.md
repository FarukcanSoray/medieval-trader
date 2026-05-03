---
title: Revised slice-6 harness criterion -- per-good band + multi-good floor + gold-cap sanity
date: 2026-05-03
status: ratified
tags: [decision, slice-6, harness, measurement, criterion]
---

# Revised slice-6 harness criterion -- per-good band + multi-good floor + gold-cap sanity

## Decision
The §7.2 PASS criterion for `measure_cargo_decision_divergence.gd` is replaced. Three clauses:

1. **Per-good band.** Per-good aggregate weight-share (mean across all routes, all seeds) inside [10%, 50%] at the gating tier (gold=200).
2. **Multi-good floor.** >= 10% of routes have multi-good optimal carts at gold=200. (Floor, not target -- relaxed from the original 60% gate.)
3. **Gold-cap sanity.** At the same (weights, cap), multi-good carts at gold=200 strictly > multi-good carts at gold=400. Confirms the gold-cap dimension is biting (rich players go single-good, gold-pressed players mix more).

`gold=120` reframed as a **starvation-regime diagnostic** -- printed for transparency but not gated.

## Reasoning
The original §7.2 criterion required >=60% of routes to have multi-good optimal carts. The first sweep returned 0/105 PASSes -- not a tuning failure but a structural finding (see [[2026-05-03-slice-6-knapsack-degeneracy-lesson]]). The criterion bundled two distinct claims:

- (a) "different routes prefer different goods" -- the macro-divergence claim. **Delivered** (per-good aggregate shares 24/14/45/17 all in [10%, 50%]).
- (b) "every leg is a portfolio decision" -- the per-leg portfolio claim. **Structurally unreachable** under integer knapsack with no diminishing returns / no per-node caps.

The revised criterion measures (a) plus pathology guards, drops (b):

- **Clause 1 (per-good band)** -- unchanged from the original; catches "salt eats everything" or "iron gets squeezed out" (both seen in (1,1,1,1) FAILs).
- **Clause 2 (multi-good floor at 10%)** -- relaxed from 60% gate to 10% floor. At 10%, the criterion still catches "every route is the same single good" pathology while accepting that single-good optimality at the route level is structural, not a bug.
- **Clause 3 (gold-cap sanity)** -- new. Confirms the relationship between gold-cap and capacity-cap is intact: when gold is plentiful (gold=400), the cart fills with the per-route winner (single-good); when gold is constrained (gold=200), partial cargos mix more. If gold=200 and gold=400 multi-good rates are equal or inverted, the gold dimension isn't biting and the slice isn't doing what it claims.

`gold=120` covers a "starvation regime" where the trader can barely afford anything; multi-good rates there can fall below 10% without indicating slice failure (the player's choices are constrained by what they can afford to buy at all, not by which good has the best route-fit). Diagnostic, not gated.

## Outcome
Under revised criterion, the chosen tuple (4,3,2,10) cap=60 gold=200 PASSes all three clauses (max share 44.6% (salt) <= 50%, min share 14.4% (cloth) >= 10%, multi-good 14.6% >= 10% floor, gold-cap sanity 14.6% > 0.0%). Across the 105-tuple sweep: 74 PASS, 31 FAIL. The 31 FAILs are mostly outlier weight assignments (e.g., (1,1,1,1) which fails clause 1 with salt at 64% mean share).

## Alternatives considered
- **Keep the original 60% multi-good gate** -- rejected: structurally unreachable, makes the criterion vacuous (always FAIL).
- **Drop measurement entirely** -- rejected: harness still discriminates good tuples from bad on macro-divergence; catches pathological weights.
- **Add even more clauses** -- rejected: over-fitting; three clauses cover macro-divergence, pathology guard, and gold-cap sanity, which exhaust what the slice's mechanic produces.

## Confidence
High. The criterion change is data-driven (the original failed 0/105; the revised passes the chosen tuple and discriminates pathological cases) and design-grounded (the reframe matches what the slice actually delivers per [[2026-05-03-slice-6-route-dependent-good-selection-reframe]]).

## Source
`docs/slice-6-weight-cargo-spec.md` §7.2 (revised binding criterion), §7.5 (revision history). `godot/tools/cargo_divergence_verdict.txt` (PASS verdict at chosen tuple under revised criterion).

## Related
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the structural finding that forced the revision
- [[2026-05-03-slice-6-route-dependent-good-selection-reframe]] -- the slice-purpose reframe that the revised criterion measures
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- prior measurement-criterion precedent (slice-5)
- [[feedback_measurement_before_tuning]] -- standing rule applied + reinforced
