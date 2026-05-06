---
title: Schema v7 -> v8 strict-reject extends slice-8.1 precedent
date: 2026-05-05
status: ratified
slice: 8.2
tags: [decision, slice-8.2, save-schema, persistence]
---

# Schema v7 -> v8 strict-reject extends slice-8.1 precedent

## Decision
`WorldState.SCHEMA_VERSION` bumped 7 -> 8. v7 saves are rejected on load (no migration path; corruption-toast/regen takes over). New `NodeState` fields persisted: `demand_drain_rates: Dictionary[String, float]`, `demand_drain_accumulators: Dictionary[String, float]`, `sell_seed_counter: int`.

## Reasoning
Slice-8.2 introduces persistence requirements that v7 saves cannot satisfy: per-(node, good) drain rates authored at world-gen, drain accumulators carrying float remainders across ticks, and a per-node sell counter that drives deterministic conservation RNG. No v7 save contains these fields, so a migration path would require synthetic initialization with no ground truth — which would also drop the player into a "demand-flat" world that 8.2 immediately invalidates anyway.

Following the strict-reject precedent established in slice-8.1 ([[2026-05-05-slice-8-1-schema-v7-reject-v5-and-v6]]). The project's no-story / no-characters brief means saves are not narrative artifacts; the regen cost is one-time and aligns with the design.

## Alternatives considered
- **Synthetic initialization of missing v7 fields (e.g., uniform drain rate)** -- rejected; produces a save state inconsistent with the new mechanism's gen-time authoring, and the resulting world would still need to "settle" into 8.2's steady states from an arbitrary seed point.
- **Soft migration with a one-time rebuild** -- not formally weighed; the strict-reject precedent made the call.

## Confidence
High. Architect's structural decision; consistent with prior schema versioning decisions; no objection from Engineer or Reviewer.

## Source
Architect's handoff document `docs/slice-8-2-architect-handoff.md` (2026-05-05); precedent [[2026-05-05-slice-8-1-schema-v7-reject-v5-and-v6]].

## Related
- [[2026-05-05-slice-8-1-schema-v7-reject-v5-and-v6]] -- the strict-reject precedent this extends
- [[2026-05-05-slice-8-2-drain-conservation-composed]] -- the mechanism whose persistence drives this bump
- [[2026-05-05-slice-8-2-conservation-rng-per-node-counter]] -- introduces the `sell_seed_counter` field
