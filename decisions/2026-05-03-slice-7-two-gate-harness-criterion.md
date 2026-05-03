---
title: Slice 7 harness splits into two independent gates; cap-binding and composition recruitment measured separately
date: 2026-05-03
status: ratified
tags: [decision, slice-7, harness, measurement]
---

# Slice 7 harness splits into two independent gates; cap-binding and composition recruitment measured separately

## Decision
The slice-7 harness splits the measurement criterion into two independent gates evaluated under the same seed sweep:

- **Gate 1 -- Cap-binding rate.** What fraction of (route, tick) pairs does the optimal cart's best good hit the cap? **Floor: >=20%.** If this fails, caps are theatre and refill rates need lowering.
- **Gate 2 -- Multi-good rate when cap-bound.** *Given* Gate 1 binds, how often does the optimal cart contain >=2 goods? **Floor: >=60%.** If this fails, second-best goods have negative profit on most edges -- a bias-spread tuning issue, escalated to a separate slice.

Gate 2 is conditional on Gate 1 (the multi-good rate is only meaningful when the cap binds).

## Reasoning
Slice-6's harness collapsed two distinct claims into a single multi-good rate: "is the cap binding?" and "when it binds, do mixes follow?" The collapse meant a FAIL didn't tell us *which* claim failed -- the harness couldn't distinguish "caps don't bite" from "caps bite but bias spreads are too thin." That conflation forced a Designer reframe of the slice's purpose mid-pipeline.

Slice-7 applies the slice-6 lesson early: split the criterion before the harness runs, so a FAIL says exactly what failed. Each gate measures a different design property and points to a different remediation surface. The slice can ship with Gate 1 PASS / Gate 2 FAIL because the two gates measure separable claims.

## Alternatives considered
- **Single multi-good rate** (slice-6 pattern) -- rejected per slice-6 lesson.
- **Three or more gates** (e.g., cap-binding rate, mix rate, mix-quality measure) -- rejected: more gates without clear remediation surfaces would conflate diagnosis again.
- **Gate 2 as unconditional** (multi-good rate regardless of cap-binding) -- rejected: would dilute the cap-binding signal with cases where the cart never filled in the first place.

## Confidence
High. The slice-6 lesson is documented and the pattern reused intentionally. Gate 1 PASSed at 98-100% in the actual run; Gate 2 FAILed cleanly at 27-54%. The split distinguished the two failure modes exactly as designed.

## Source
Designer spec §7.1-7.2; Critic preview during the cost pressure-test.

## Related
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the slice-6 lesson that justifies the split
- [[2026-05-03-slice-6-revised-harness-criterion]] -- slice-6's eventual fix, which informed slice-7's pre-emptive split
- [[2026-05-03-slice-7-gate-2-fail-escalates-separate-slice]] -- the ship-rule that depends on this split
- [[feedback_measurement_before_tuning]] -- the standing rule that justifies any harness criterion
