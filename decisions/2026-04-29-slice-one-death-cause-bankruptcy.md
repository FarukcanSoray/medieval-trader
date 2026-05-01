---
title: One death cause in the slice — bankruptcy
date: 2026-04-29
status: ratified
tags: [decision, slice, death-mechanics]
---

# One death cause in the slice — bankruptcy

## Decision
The slice has one death cause: **bankruptcy**, defined as "stranded with insufficient gold to travel anywhere." Other death causes (violent encounter, starvation, old age) are deferred. They remain in full project scope.

## Reasoning
The slice's job is to test the kernel and the integration plumbing of the death pipeline (gold-change → death-trigger → death-screen → save). One purely state-driven death cause is sufficient for that, and bankruptcy is the simplest: it's a check on `trader.gold` after every gold mutation, no encounter system required, no aging-clock model required.

Old age was the alternative for "purely state-driven, no subsystem dependencies" but requires a lifespan model and the slice doesn't need it to test the death-screen pipeline.

## Alternatives considered
- Multiple causes (bankruptcy + old age + violent encounter). Rejected — too much surface for the slice; encounter is deferred regardless.
- Old age as the slice's single cause. Rejected — needs lifespan tuning; bankruptcy is more directly tied to the kernel.

## Confidence
High. Designer's explicit slice scope; user ratified via slice spec approval.

## Source
`docs/slice-spec.md` ratifications header and §5 (death trigger rule).

## Related
- [[slice-spec]] — captured in the ratifications header and §5
- [[2026-04-29-death-rare-and-earned]] — full-project death cadence (this slice cause must satisfy it)
- [[2026-04-29-travel-cost-at-departure]] — bankruptcy check is at travel-confirm
- [[2026-04-29-slice-zero-encounters]] — pairs with this; violent-encounter death is also deferred
