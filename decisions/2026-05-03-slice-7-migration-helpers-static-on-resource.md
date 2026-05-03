---
title: Migration helpers live as static methods on owning Resource; no SaveMigrations module yet
date: 2026-05-03
status: ratified
tags: [decision, slice-7, architecture, schema]
---

# Migration helpers live as static methods on owning Resource; no SaveMigrations module yet

## Decision
The v4->v5 migration logic lives as static methods on the Resource types it migrates:

- `WorldState._migrate_v4_to_v5(d: Dictionary) -> Dictionary`
- `TraderState._migrate_v4_to_v5(d: Dictionary) -> Dictionary`

There is no separate `SaveMigrations` module. `WorldState.from_dict` and `TraderState.from_dict` each handle the accept-or-migrate branch internally. `SaveService.load_or_init` is unchanged -- migration is a `from_dict` concern, not a load-orchestration concern.

`TraderState.from_dict` does not currently consult `schema_version` (the schema field lives only on `WorldState`); the trader-side migration triggers off **field absence** -- if `cargo_capacity` is absent, default to `WorldRules.CARGO_CAPACITY`. This avoids adding a `schema_version` field to `TraderState` (which would itself be a schema bump).

## Reasoning
One migration does not earn a separate abstraction. Slice-2 set the precedent that strict-rejects on schema mismatch (`world_state.gd:139`); slice-7 introduces the *first* real migration. Promoting to a `SaveMigrations` script-only class on a single migration would be premature abstraction. The abstraction earns its weight on the **second** migration (v5->v6), where cross-resource versioning becomes a real coordination problem.

## Alternatives considered
- **Single `SaveMigrations` script-only class with all migrations** -- rejected per "one migration does not earn an abstraction" argument; promote on the second migration.
- **Migration logic inline inside `from_dict`** (no static helper) -- rejected because a named static method is more testable and more readable than an inline branch with growing complexity.
- **Add `schema_version` to `TraderState`** so its migration follows the same shape as `WorldState`'s -- rejected because it would itself be a schema bump for a one-field migration.

## Confidence
High. Architect call; ratified by acceptance.

## Source
Architect handoff §4 (schema migration ownership).

## Related
- [[2026-04-29-strict-reject-from-dict]] -- the prior strict-reject precedent
- [[2026-05-03-slice-7-schema-bump-coalesces-cargo-capacity]] -- the migration this rule structures
