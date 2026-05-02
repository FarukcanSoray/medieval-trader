---
title: `EncounterOutcome` is a Resource (not a nested Dictionary)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, schema]
---

# `EncounterOutcome` is a Resource (not a nested Dictionary)

## Decision
`EncounterOutcome` is a `Resource` subclass at `godot/travel/encounter_outcome.gd` with five typed exported fields (`kind`, `gold_loss`, `goods_loss_id`, `goods_loss_qty`, `readback_consumed`). Persisted on `TravelState.encounter` (nullable). JSON ferry methods `to_dict()` / `from_dict()` with strict-reject on missing keys.

## Reasoning
Persistence already nests `TravelState: Resource` inside `TraderState: Resource` (slice-1 pattern). Adding `encounter: EncounterOutcome` continues the established pattern — typed handle for the Engineer, clean `from_dict` strict-reject contract for the loader.

A nested `Dictionary[String, Variant]` would defeat strict-reject (every read becomes `String(d.get(...))` with no type guarantee) and force every consumer to redo type coercion. Slice-1's strict-reject contract demands typed sub-resources for sub-blocks.

## Alternatives considered
- **Nested Dictionary on `TravelState`** — rejected; defeats strict-reject and type safety.
- **Inline fields on `TravelState`** — rejected; the nullable structure (no encounter vs encounter fired) is cleaner with a sub-Resource than with multiple nullable fields.

## Confidence
High. Architect Call 2.

## Source
Architect handoff, Call 2.

## Related
- [[2026-05-02-slice-4-store-only-when-it-bites]] — the null-semantics that complement this Resource shape
- [[2026-04-29-strict-reject-from-dict]] — the contract this enables
