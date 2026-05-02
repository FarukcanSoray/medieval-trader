---
title: `EncounterResolver` = new script-only file at `godot/travel/encounter_resolver.gd`
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, file-placement]
---

# `EncounterResolver` = new script-only file at `godot/travel/encounter_resolver.gd`

## Decision
Encounter logic (roll + outcome computation + cost-preview helper) lives in a new file at `godot/travel/encounter_resolver.gd` as `class_name EncounterResolver extends Object`, static-only methods. Two callers: `TravelController.request_travel` (for the roll) and `Main._on_travel_requested` (for the cost-preview bounds).

## Reasoning
Slice-3 precedent ([[2026-05-02-slice-3-author-bias-inline-in-world-gen]]) was "inline when there's one caller; split when there are independent callers." `EncounterResolver` has two callers in two files, so the premature-file-splitting smell does not apply.

Inlining on `TravelController` would force the controller to host both per-leg state AND the seed-derivation math (canonicalisation + hashing); spec §5.3 is real logic that doesn't belong wedged inside `request_travel`'s 20-line body.

`extends Object` (not `RefCounted`) matches the `WorldRules` sibling pattern — the script is a static-method holder, never instantiated.

## Alternatives considered
- **Inline on `TravelController`** — rejected; one of the callers (`Main._on_travel_requested`) is in a different file, breaking the inline justification.
- **Make it an autoload** — rejected; static-method module needs no global state.

## Confidence
High. Architect Call 1.

## Source
Architect handoff, Call 1.

## Related
- [[2026-05-02-slice-3-author-bias-inline-in-world-gen]] — the contrasting "inline" precedent
- [[2026-04-30-world-rules-shared-static-config]] — the static-method sibling pattern
