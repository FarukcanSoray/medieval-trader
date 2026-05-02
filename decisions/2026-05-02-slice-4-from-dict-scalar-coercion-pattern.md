---
title: `EncounterOutcome.from_dict` follows existing scalar-coercion pattern (no scalar type-checks)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, architecture, validation, pattern-precedent]
---

# `EncounterOutcome.from_dict` follows existing scalar-coercion pattern (no scalar type-checks)

## Decision
`EncounterOutcome.from_dict` strict-rejects on **missing keys** but does **not** type-check scalar fields. Scalars are coerced via `int()` / `String()` / `bool()`. Only structural containers (nested Resources, Dictionary, Array) are type-checked.

## Reasoning
This documents the **codebase-wide pattern** explicitly because Reviewer flagged the question.

Existing precedent ([[2026-04-29-strict-reject-from-dict]]) lists rejection conditions for top-level keys, schema_version values, and structural containers — scalar typing is **not** in that list. `WorldState._edge_from_dict`, `TraderState.from_dict`, `HistoryEntry`-related helpers all coerce scalars and only type-check containers.

JSON parsing returns floats for any number, so `is int` checks would always reject `gold_loss` on real reload. Coercion via `int()` is the necessary pattern; strict scalar-typing isn't compatible with JSON's number representation.

If stricter scalar checks are ever wanted (e.g., for API-style validation), the right fix is per-field `not (val is int or val is float)` patterns — and it's a **codebase-wide** change, not an `EncounterOutcome`-local one.

## Alternatives considered
- **Strict scalar type-checks in `EncounterOutcome.from_dict`** — rejected; would be inconsistent with the rest of the codebase and would reject valid JSON-roundtrip data (floats coerced from int writes).

## Confidence
High. Engineer-applied, Reviewer-ratified, precedent-cited.

## Source
Engineer Tier-A implementation flag; Reviewer Pass 1 verdict on Engineer flag #1.

## Related
- [[2026-04-29-strict-reject-from-dict]] — the contract this respects
- [[2026-05-02-from-dict-schema-version-belt-and-braces]] — the related belt-and-braces pattern
