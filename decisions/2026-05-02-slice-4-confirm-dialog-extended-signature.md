---
title: `ConfirmDialog.prompt` extended with defaulted params (not a separate method)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, ui]
---

# `ConfirmDialog.prompt` extended with defaulted params (not a separate method)

## Decision
`ConfirmDialog.prompt` signature extended in-place:
```
func prompt(from_name: String, to_name: String, cost: int, ticks: int,
            encounter_label: String = "",
            encounter_loss_max: int = 0,
            encounter_probability_pct: int = 0) -> void
```
Body branches on `encounter_label != ""` to select between the slice-3 string and the encounter-extended string. Existing call sites (no encounter) get the slice-3 output verbatim.

## Reasoning
One render path with one branch is clearer than two near-duplicate methods (`prompt` + `prompt_with_encounter`). Architect dropped `encounter_loss_min` (always 0 per spec; the format string hard-codes `+0..`) and renamed `probability` to `encounter_probability_pct` to make units explicit at the boundary (avoiding `0.30` vs `30` confusion at the call site).

Back-compat: callers with a plain edge pass the four positional args and get the unchanged dialog. Bandit-edge callers pass the three additional defaults populated.

## Alternatives considered
- **New `prompt_with_encounter` method** — rejected; near-duplicate body, two places to maintain the format string.
- **Pass an `EncounterOutcome` directly** — rejected; the dialog only needs the loss-max and probability, not the full outcome (the outcome is already rolled at this point but the dialog shouldn't see it before the player commits).

## Confidence
High. Architect Call 3.

## Source
Architect handoff, Call 3.

## Related
- [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] — the format this signature renders
