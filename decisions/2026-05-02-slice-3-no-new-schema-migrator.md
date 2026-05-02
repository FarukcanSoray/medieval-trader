---
title: No new schema migrator file; reuse existing `from_dict` strict-reject path
date: 2026-05-02
status: ratified
tags: [decision, slice-3, schema-management, architecture]
---

# No new schema migrator file; reuse existing `from_dict` strict-reject path

## Decision
No new `WorldStateMigrator.gd` (or similar) file is created for slice-3. The existing `WorldState.from_dict` strict-reject path handles the schema 2 to 3 transition by returning null on `schema_version != 3`; `SaveService` catches the null, sets the corruption-notice flag, and regenerates.

## Reasoning
Slice-3 discards rather than migrates (see [[2026-05-02-slice-3-schema-3-discard-via-toast]]). A migrator file would carry zero migration logic -- it would be a name without a body. The existing strict-reject + corruption-toast path handles the transition with zero code changes to `SaveService`.

## Alternatives considered
- Create `WorldStateMigrator.gd` for forward-compatibility -- rejected; YAGNI applies, and any future migration that needs more than discard can introduce the file then.

## Confidence
High. Architect ratified by inspection of the existing path.

## Source
Architect handoff §1 (Call B).

## Related
- [[2026-05-02-slice-3-schema-3-discard-via-toast]]
- [[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]]
- [[2026-04-29-strict-reject-from-dict]]
