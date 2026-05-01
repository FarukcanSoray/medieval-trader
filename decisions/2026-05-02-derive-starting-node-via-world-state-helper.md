---
title: Derive starting node via WorldState.get_starting_node_id; no hardcoded literals
date: 2026-05-02
status: ratified
tags: [decision, save-system, slice-2, derivation]
---

# Derive starting node via WorldState.get_starting_node_id; no hardcoded literals

## Decision

`WorldState.get_starting_node_id() -> String` is the single source of truth for "where does the trader start a fresh world." It walks `edges` once to compute degree per node, picks max-degree, breaks ties by lexicographic-min `id`. Returns `""` if `nodes.is_empty()` (defensive).

**`SaveService._generate_fresh()` calls this helper** to set `trader.location_node_id`. The slice-1 hardcoded `t.location_node_id = "hillfarm"` literal is removed.

**`WorldGen.generate()` also calls this helper** (after assembling the WorldState) to log the starting node id in the per-generation log line. The slice-2 first-pass duplicate `_pick_starting_node_index` was deleted in the fix loop; only `WorldState.get_starting_node_id` implements the predicate.

## Reasoning

The slice-1 hardcoded literal was a bug-shaped seam: any change to the slice-1 node ids (which slice-2 makes — node ids are now `node_0`...`node_6`, not `hillfarm`/`rivertown`/`thornhold`) would silently set `location_node_id` to a non-existent node and produce undefined behaviour on first travel.

Derivation has three properties the literal lacked:

1. **Survives id changes.** The predicate is over graph shape, not over specific strings.
2. **Survives count changes.** Works at 3 nodes, 7 nodes, or 100 nodes.
3. **Pure function over state.** No state to keep in sync, no migration needed; works on slice-1 saves loaded into slice-2 just as well as on fresh slice-2 worlds.

The "highest-degree, ties to lowest id" rule was Designer-ratified for tonal reasons (player starts at the trading hub) and for pillar-2 protection (avoid stranded-corner starts).

## Alternatives considered

- **Keep the hardcoded literal `"hillfarm"`.** Rejected. Breaks under slice-2 ids; un-fixable without a migration.
- **Store `starting_node_id: String` as a new field on `WorldState`.** Rejected. Adds a required field on a per-world Resource — would force a `schema_version` bump per the trigger rule (see [[2026-05-02-slice-2-no-schema-bump-trigger-named]]).
- **Two implementations of the predicate (one in `WorldGen` for the index, one in `WorldState` for the id).** Rejected in fix loop. Two implementations of the same predicate drift; consolidation cleaner.

## Confidence

High. Architect identified the bug; Engineer implemented the helper; Reviewer flagged the duplication; fix loop consolidated.

## Source

This session (2026-05-02 PM). Architect §9 schema sanity check found the literal; Reviewer non-blocker #3 surfaced the duplication; Engineer fix loop resolved.

## Related

- [[2026-05-02-slice-2-no-schema-bump-trigger-named]]
- [[2026-04-29-stranded-includes-empty-inventory]]
- [[2026-04-30-stranded-predicate-v2-affordability-checks]]
- [[2026-04-30-world-state-get-node-by-id-helper]]
