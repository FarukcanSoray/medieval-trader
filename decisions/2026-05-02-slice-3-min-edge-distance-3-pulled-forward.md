---
title: `MIN_EDGE_DISTANCE` raised 2 to 3 (slice-3.x carryover pulled forward into slice-3)
date: 2026-05-02
status: ratified
tags: [decision, slice-3, topology, measurement-driven, free-lunch, carryover-closed]
---

# `MIN_EDGE_DISTANCE` raised 2 to 3 (slice-3.x carryover pulled forward into slice-3)

## Decision
`WorldGen.MIN_EDGE_DISTANCE` raised from 2 to 3. This consumes the slice-3.x carryover topology fix (originating chain: [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]]) and pulls it forward into slice-3.

The free-lunch chain is now **fully closed**: the empirical topology revisit landed in slice-3 itself, not in a deferred follow-up.

## Reasoning
Reviewer flagged that wool's bias predicate fails at `min_edge_distance == 2` (vol_term=5, max_spread=6, R approximately 0.083 < MIN_BIAS_RANGE 0.20). Engineer initially marked this as "spec-intended; seed-bump handles it." Reviewer pressure-tested and demanded measurement.

Headless measurement (`tools/measure_bias_aborts.gd`, 1000 seeds, fallback rect 468x664):
- At `MIN_EDGE_DISTANCE = 2`: **70.00% abort rate** (700/1000 seed-bump exhaustion). All 300 successes had `min_edge_distance == 3` exactly; zero successes at distance 2 (predicate fails) and zero at distance >=4 (placement geometry doesn't produce them).
- At `MIN_EDGE_DISTANCE = 3`: **0.00% abort rate** (1000/1000 successes, all no-bump).

The data was conclusive. The "spec-intended" defence collapsed -- the bump loop was not catching the failures, and the boot path was failing into the corruption-toast branch on a brand-new world.

## Alternatives considered
- **Keep `MIN_EDGE_DISTANCE = 2`, accept abort rate** -- rejected; 70% boot-path failure on a fresh install is shipping-broken.
- **Tighten goods (lower volatility or ceiling)** -- considered. Would push wool's volatility below the spec's recommended 5-15% range. Cost is silent (loses kernel signal) where raising `MIN_EDGE_DISTANCE` is cosmetic (very short raw distances now display 3 instead of 2).
- **Defer to slice-3.x** -- rejected; the deferral was the *originating* problem. Pulling the fix forward consumes the chain.

## Confidence
High. Decision is measurement-driven (1000-seed empirical run), and the cleanest viable change in shape (one constant; no formula change).

## Source
Reviewer's blocker (first review pass) -> Engineer wrote `tools/measure_bias_aborts.gd` -> measurement run from PowerShell -> Reviewer's verified Ship-it on the fix.

## Related
- [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]] -- chain origin, now closed
- [[2026-05-02-slice-3-free-lunch-option-a-edge-length-bound]] -- the pricing-side predicate this complements
- [[2026-05-02-measurement-before-tuning]] -- the meta-pattern this decision exemplifies
