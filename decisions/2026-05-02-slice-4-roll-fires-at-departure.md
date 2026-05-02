---
title: Encounter roll fires at departure, applies at arrival (not per-tick)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, encounters]
---

# Encounter roll fires at departure, applies at arrival (not per-tick)

## Decision
The bandit encounter roll is evaluated **once at departure** in `TravelController.request_travel`, after gold-deduction and before history push. The outcome is persisted on `TravelState.encounter` and **applied at arrival** in `process_tick`'s arrival branch.

## Reasoning
Per-tick rolls would couple encounter logic tightly to `TravelController`, multiply the determinism surface (one hash per tick), and complicate save-during-travel (mid-roll states would need persistence). Departure model reuses the existing "one gold deduction at departure" frame and keeps the coupling to a single seam. Apply-at-arrival preserves the journey's narrative arc — the player learns the outcome on arrival, after the trip happened.

## Alternatives considered
- **Per-tick roll** — rejected for complexity and tight coupling.
- **Apply at departure (immediately)** — rejected; loses the journey-arc framing and would surface the loss before the travel modal closes.

## Confidence
High. Director-ratified, Architect-confirmed.

## Source
Director scoping pass; Designer spec §5.3.

## Related
- [[slice-4-encounters-spec]] §5.3
- [[2026-05-02-slice-4-encounter-roll-seed]]
