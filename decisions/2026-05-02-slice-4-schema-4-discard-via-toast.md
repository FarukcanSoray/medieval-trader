---
title: Schema 3 -> 4: discard slice-3 saves via existing corruption-toast path
date: 2026-05-02
status: ratified
tags: [decision, slice-4, schema-management]
---

# Schema 3 -> 4: discard slice-3 saves via existing corruption-toast path

## Decision
`WorldState.SCHEMA_VERSION` bumps from 3 to 4. Slice-3 saves are rejected by the existing strict-reject `from_dict` path; the corruption toast fires; a new world is generated. **No migration code is written. No new file.** Reuses [[2026-05-02-slice-3-schema-3-discard-via-toast]] precedent verbatim.

**Named trigger** (per `2026-05-02-slice-2-no-schema-bump-trigger-named`): "per-edge bandit-road tags added to EdgeState; per-leg encounter resolution added to TravelState; encounter history kind added to HistoryEntry."

## Reasoning
Forward-filling `is_bandit_road = false` on all edges of a slice-3 save would produce a slice-4 build that runs but has zero bandit roads — silently teaches the player nothing about the new system. Discard-and-regenerate is the legible choice.

The slice-3 precedent absorbs this with zero code changes to `SaveService` — strict-reject + toast already exists. One constant change in `world_state.gd` (`SCHEMA_VERSION = 4`) plus the new field-presence checks in `_edge_from_dict` (and analogous in `_travel_from_dict`).

## Alternatives considered
- **Forward-fill `is_bandit_road = false`** — rejected as silent Pillar 1 violation (no bandits in worlds the player thinks have them).
- **New `WorldStateMigrator.gd` file** — rejected; would carry zero migration logic. Slice-3 precedent established no-migrator path as the project default.

## Confidence
High. Direct application of established slice-3 pattern.

## Source
Designer spec §3; Architect ratification.

## Related
- [[2026-05-02-slice-3-schema-3-discard-via-toast]] — the precedent this extends
- [[2026-05-02-slice-3-no-new-schema-migrator]] — no-migrator-file pattern
- [[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]]
- [[2026-05-02-from-dict-schema-version-belt-and-braces]]
