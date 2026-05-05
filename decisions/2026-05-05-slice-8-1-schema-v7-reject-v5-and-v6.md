---
title: Schema bump v6 to v7, reject v5 and v6
date: 2026-05-05
status: ratified
slice: 8.1
tags: [decision, slice-8.1, schema, migration]
---

# Schema bump v6 to v7, reject v5 and v6

## Decision
`WorldState.SCHEMA_VERSION` bumped from 6 to 7. Both v5 and v6 saves are rejected on load (corruption-toast and regen via begin-anew). The `_migrate_v5_to_v6` helper at `world_state.gd:451-500` and its `_resolve_goods_for_migration` caller are deleted (no other callers).

Consistent with the v4-strict-rejected precedent.

## Reasoning
Architect identified during structural mapping that `SCHEMA_VERSION` was already 6 in shipped slice-8 code -- the slice-8.1 brief from Designer had assumed v5 -> v6, which was incorrect. More importantly, the existing `_migrate_v5_to_v6` writes `demand_pools[good.id] = cap` for every good (line 490), which is exactly the same-node arbitrage bug slice-8.1 is fixing. Migrating v6 saves to v7 with corrected fill values would require either re-deriving tags (already done at gen time) or accepting incorrect fills indefinitely.

Following the v4-strict-rejected precedent (`2026-05-04-slice-8-v4-saves-strict-rejected`) was the consistent choice: this project has already established that lenient migration is not the policy.

## Alternatives considered
- **v6 -> v7 migration patch that re-derives initial fill from existing tags** -- not deeply explored; the strict-reject precedent was the established pattern and adding migration code that would be deleted in the next slice anyway was poor return on engineering time.

## Confidence
High. Architect surfaced the existing-code mismatch with the brief; the precedent was clear; the migration helper being deletable confirmed there was no other consumer.

## Source
Architect's stop-the-line during slice-8.1 structural mapping, 2026-05-05.

## Related
- [[2026-05-04-slice-8-v4-saves-strict-rejected]] -- the strict-reject precedent extended here
- [[2026-05-04-slice-8-initial-demand-pool-fill-on-migration]] -- the v5->v6 migration approach this supersedes
