---
title: Harness Gate 2 failure escalates to a separate bias-spread slice; does not block slice 7
date: 2026-05-03
status: ratified
tags: [decision, slice-7, harness, process, ship-rule]
---

# Harness Gate 2 failure escalates to a separate bias-spread slice; does not block slice 7

## Decision
When the slice-7 harness's Gate 2 (multi-good rate when cap-bound >= 60%) fails while Gate 1 (cap-binding rate >= 20%) passes, the failure does **not** block slice-7 from shipping. Instead it escalates to a separate follow-up slice for bias-spread tuning. The cap mechanic alone (Gate 1) delivers the slice's load-bearing texture (world memory + temporal availability); the multi-good-when-cap-bound promise (Gate 2) is separable.

## Reasoning
Gate 1 PASS proves caps are a real binding constraint -- the slice's load-bearing claim ("the world has memory") lands. Gate 2 FAIL means the second-best good doesn't get recruited often enough when caps bind: even with the winner empty, the player's gold is better held than spent on second-best because the bias-spread between best and second-best on most edges is too thin to make second-best profitable. This is a *price-spread tuning issue*, not a caps issue. Fixing it inside slice-7 would conflate two different problems and risk shipping a slice with the wrong knob being tuned. Splitting it into a separate slice keeps the cap mechanic and the bias-spread tuning as independently measurable design surfaces.

The actual harness verdict (committed at `26a9da8`): Gate 1 PASS at 98-100% across all swept tuples; Gate 2 FAIL at 27-54% range. The pattern is consistent and structural, not noise.

## Alternatives considered
- **Block ship until Gate 2 passes** -- rejected. The cap mechanic ships even when Gate 2 fails, because Gate 1 is the slice's primary deliverable.
- **Tune bias spreads inside slice-7 to lift Gate 2** -- rejected. That's a different design problem; in-slice tuning would risk paving over the diagnostic.
- **Drop the Gate 2 criterion** -- rejected. Gate 2 stays as a measurement that flags when bias spreads are too thin; it just doesn't gate ship.

## Confidence
High. User explicitly pre-ratified before the harness ran: "escalate to a separate slice."

## Source
User reply during Designer step (slice-7 pipeline, 2026-05-03): "escalate to a separate slice. memory should be a part of the game's identity."

## Related
- [[2026-05-03-slice-7-two-gate-harness-criterion]] -- the criterion structure that makes this escalation possible
- [[2026-05-03-slice-7-world-has-memory-pillar]] -- the load-bearing claim Gate 1 PASS validates
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the structural lesson that Gate 2 was designed to test
