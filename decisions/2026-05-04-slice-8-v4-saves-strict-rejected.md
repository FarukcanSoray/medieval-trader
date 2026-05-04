---
title: v4 saves strict-rejected under slice-8 (one-version-back tolerance)
date: 2026-05-04
status: ratified
tags: [decision, slice-8, save-format, migration, schema]
---

# v4 saves strict-rejected under slice-8 (one-version-back tolerance)

## Decision
Slice-8's `WorldState.from_dict` accepts schema versions 5 (via `_migrate_v5_to_v6`) and 6 (directly). All other versions, including v4, are rejected at load time and routed to the existing corruption-toast / new-world-generated path.

This applies the one-version-back tolerance precedent: slice-7 was the build that tolerated v4 saves (via `_migrate_v4_to_v5`); slice-8 closes that window.

## Reasoning
Maintaining migration paths for arbitrary back-versions accumulates engineering cost without a use case in a single-player solo project where saves are not shared. The one-version-back rule trades long-tail migration coverage for code simplicity and forward-derived determinism: every accepted save can be exactly characterised by its current-or-previous schema, with no compounded migrations.

A user on a v4 save who skipped slice-7 entirely is the only affected case; on slice-8 boot, that save is rejected via the existing toast path, a fresh world is generated, and the slice-7 features (production caps) implicitly initialise alongside slice-8's demand pools. No data loss in practice for the project's solo-player context.

## Alternatives considered
- **Maintain `_migrate_v4_to_v6` (compounded migration)** -- rejected: doubles migration code complexity without a use case.
- **Reject anything below v6 (zero-version-back)** -- rejected: existing slice-7 saves should still load on slice-8 day one.

## Confidence
Medium. Architect applied the precedent without a Director Q-round explicitly ratifying it. The precedent is established (slice-7's policy was one-version-back) but slice-8 is the first instance of cycling that window forward; if you later want to keep a v4 path, the alternative paths above are the levers.

## Source
Architect (spec §3.5 implicit, §9 table, 2026-05-04 session).

## Related
- [[2026-05-03-slice-7-migration-helpers-static-on-resource]] -- the slice-7 migration shape; this decision continues that pattern
- [[2026-05-02-slice-3-schema-3-discard-via-toast]] -- the corruption-toast precedent invoked here for v4 saves
