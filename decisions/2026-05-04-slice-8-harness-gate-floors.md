---
title: Slice-8 harness gate floors ratified at 40% / 30% / 100%
date: 2026-05-04
status: ratified
tags: [decision, slice-8, harness, scope, ship-gate]
---

# Slice-8 harness gate floors ratified at 40% / 30% / 100%

## Decision
Slice-8's harness has three ship/no-ship gates:

- **Gate 1 (pool-motion):** >=40% of (route, tick, direction) tuples have either supply-pool or demand-pool fill in the middle 60% of capacity at gating-gold. Measures: pools actually move during play; they are not pinned at one end.
- **Gate 2 (spread-vs-noise):** >=30% of profitable routes show buy-price-at-source and sell-price-at-destination differ by >=2x the +/-5% perturbation. Measures: spread is bigger than noise; the player can read the gradient.
- **Gate 3 (determinism replay):** 100% of save->load->save round-trips byte-identical. Non-negotiable kernel determinism contract.

## Reasoning
Gate 1 at 40% is calibrated against slice-7's 20% cap-binding floor. Slice-8 has two binding axes (supply pool + demand pool); the gate fires if either is mid-band, so the bar correctly rises proportionally. 40% on a ">=1 of 2 axes" gate is roughly equivalent in stringency to 20% on slice-7's 1-axis gate. Raising to 50% would risk failing the slice on tuning that is actually legible in play; lowering to 30% would let pinned-corner worlds ship.

Gate 2 at 30% is the legibility gate proper. 30% of profitable routes showing readable spread is a low bar by design: not every profitable route needs to be readable above noise (the kernel collision means some edges are knife-edge profitable; that is the texture), but enough routes need clear gradient that the player learns to trust their read. 50% would force the world to over-stratify and flatten the kernel.

Gate 3 at 100% is the determinism contract, not legibility. Anything below 100% means the save format is broken.

The gates are go/no-go for shipping, not targets for tuning. Tighter floors do not produce better legibility; they produce more harness re-runs. The §10.8 escape valve (gate 1 PASS + gate 2 FAIL escalates to Director with histogram) is the right check on under-tuned ship; tighter floors should not substitute for it.

§12 lessons must record whether gate 2 actually predicted play-felt legibility -- the harness is desk-tuning; play-feel is the real judge. If gate 2 PASSES at 31% but the panel reads as illegible in playtest, the floor was wrong (too low), and that is data for slice-8.x retune, not a slice-8 ship blocker.

## Alternatives considered
- **Stricter floors (50% / 50%)** -- rejected: legibility is not a numerical property; tighter gates produce re-runs, not better play-feel.
- **Looser gate 2 (20%)** -- rejected: would let slice ship under-tuned with a flat-feeling spread.

## Confidence
High. Director Q2 ratified the 40%/30%/100% floors with explicit reasoning.

## Source
Director Q2 ratification (2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` §10, §10.8.

## Related
- [[2026-05-03-slice-7-two-gate-harness-criterion]] -- the slice-7 two-gate predicate pattern this extends to three gates
- [[2026-05-03-slice-7-gate-2-fail-escalates-separate-slice]] -- the escalation precedent
- [[2026-04-29-deterministic-price-drift]] -- the kernel determinism contract that gate 3 enforces
