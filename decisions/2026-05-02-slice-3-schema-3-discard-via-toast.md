---
title: Schema 2 to 3: discard slice-2 saves via existing corruption-toast path
date: 2026-05-02
status: ratified
tags: [decision, slice-3, schema-management, pillar-1]
---

# Schema 2 to 3: discard slice-2 saves via existing corruption-toast path

## Decision
`WorldState.SCHEMA_VERSION` bumps from 2 to 3. Slice-2 saves are rejected by the existing strict-reject `from_dict` path; the corruption toast fires; a new world is generated. No migration code is written. No new file. The named trigger per [[2026-05-02-slice-2-no-schema-bump-trigger-named]] precedent is "regional bias and producer/consumer tags added to NodeState."

## Reasoning
Forward-filling `bias` to all-zero would produce a slice-3 build that runs but silently violates Pillar 1: the player would see prices with no observable regional structure (because bias is zero everywhere) and would learn nothing about the new system. Discarding saves and regenerating is the legible choice -- the player gets a build whose behaviour matches the design.

## Alternatives considered
- Forward-fill `bias` to zero -- rejected as silent Pillar 1 violation.
- Write a migrator that authors fresh bias for old saves -- rejected because the world-seed would no longer determine the world (different bias on different launch days).

## Confidence
High. Designer rooted it in Pillar 1; corruption-toast path was already implemented.

## Source
Designer spec §3.

## Related
- [[2026-05-02-slice-3-no-new-schema-migrator]]
- [[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]]
- [[2026-05-02-slice-2-no-schema-bump-trigger-named]]
- [[2026-05-02-from-dict-schema-version-belt-and-braces]]
