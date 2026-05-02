---
title: "Store-only-when-it-bites": no `fired` field; null on TravelState.encounter means no encounter
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, design]
---

# "Store-only-when-it-bites": no `fired` field; null on TravelState.encounter means no encounter

## Decision
`EncounterOutcome` has **no `fired: bool` field**. `EncounterResolver.try_resolve` returns `null` when the encounter does not fire. `TravelController.request_travel` sets `travel.encounter = outcome` only when the outcome is non-null; otherwise `travel.encounter` stays `null`.

`null` on `TravelState.encounter` means "no encounter to apply this leg" — covering BOTH:
- The edge is not bandit-tagged.
- The edge IS bandit-tagged but the roll missed.

These two cases are intentionally indistinguishable in storage.

## Reasoning
Two cases collapsed into one representation: simpler save schema (no extra bool to serialise/validate), simpler `_apply_encounter` guard (`if encounter != null`), simpler downstream slice-4.x readback logic. The information distinction (was it a bandit road that didn't fire, vs not a bandit road at all?) is recoverable from `EdgeState.is_bandit_road` if ever needed — and the history-line pattern ([[2026-05-02-slice-4-history-encounter-kind]]) carries the "lucky bandit leg" signal via row-count asymmetry.

## Alternatives considered
- **Explicit `fired: bool` on every `EncounterOutcome`** — rejected; doubles the storage footprint of the null case for no semantic gain.
- **Three-state encounter field** (`null` / `pending` / `resolved`) — rejected; adds states the slice doesn't need.

## Confidence
High. Architect refinement that reduced spec complexity at the seam.

## Source
Architect handoff §2 (the `EncounterOutcome.fired` field elimination).

## Related
- [[2026-05-02-slice-4-encounter-outcome-resource]]
- [[2026-05-02-slice-4-history-encounter-kind]] — the "absence-as-signal" pattern this enables
