---
title: Travel cost deducted once at departure
date: 2026-04-29
status: ratified
tags: [decision, design, travel-mechanics]
---

# Travel cost deducted once at departure

## Decision
Gold is deducted from the player **once at departure**, not per tick during travel. This is a design rule, not a tuning number.

## Reasoning
Matches "travel costs bite" without ambiguity. Per-tick deduction would create edge cases in state recovery (mid-travel bankruptcy, partial-tick saves). One deduction is cleaner on save/load and produces a clear UX: at travel confirm, if `gold < travel_cost`, the button is disabled.

## Alternatives considered
Per-tick deduction during travel. Rejected for the reasons above.

## Confidence
High. Explicit Designer rule.

## Source
`docs/slice-spec.md` §5 — "Travel state machine. Gold is deducted **once at departure**, not per tick."

## Related
- [[slice-spec]] — captured there
- [[project-brief]] — reinforces Pillar 2 (travel costs bite)
- [[2026-04-29-tick-on-player-travel]] — pairs with this; travel is the tick-advancing action
- [[2026-04-29-slice-one-death-cause-bankruptcy]] — bankruptcy check happens at travel-confirm
