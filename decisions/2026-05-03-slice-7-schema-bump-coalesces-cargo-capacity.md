---
title: Schema bump v4 to v5 coalesces stock state and cargo_capacity field
date: 2026-05-03
status: ratified
tags: [decision, slice-7, schema, save-format]
---

# Schema bump v4 to v5 coalesces stock state and cargo_capacity field

## Decision
The slice-7 schema bump (`SCHEMA_VERSION: 4 -> 5`) lands two field groups in one migration: per-(node, good) stock state (four new dicts on `NodeState`: `stocks`, `stock_caps`, `refill_rates`, `refill_accumulators`) **and** the deferred `TraderState.cargo_capacity` field originally queued for slice-6.1. Old saves migrate by setting all stocks to cap (full) and `cargo_capacity` to `WorldRules.CARGO_CAPACITY` (60).

## Reasoning
The slice-6.1 carryover -- adding `cargo_capacity` to `TraderState` once per-trader capacity needed to vary -- already required a schema bump someday. Slice-7's bump for stock state is unavoidable. Coalescing both into v5 avoids a future v5->v6 bump for `cargo_capacity` alone. "Two birds, one schema bump." The migration helpers (one per Resource: `WorldState._migrate_v4_to_v5` and `TraderState._migrate_v4_to_v5`) are independent; coalescing is purely an opportunistic save-format bundling, not a coupling.

## Alternatives considered
- **Land stock state in v5; defer cargo_capacity to a future v5->v6** -- rejected because `cargo_capacity` was already a known carryover and adding it now is essentially free.
- **Promote a `SaveMigrations` module ahead of demand** -- rejected because one migration does not earn a separate abstraction (see `2026-05-03-slice-7-migration-helpers-static-on-resource`).

## Confidence
High. Critic surfaced the opportunity; user confirmed with "yes."

## Source
Critic report (slice-7 pipeline, 2026-05-03); user reply ("yes" to coalesce).

## Related
- [[2026-05-03-slice-6-cargo-cap-as-code-constant]] -- the slice that deferred `cargo_capacity` to slice-6.1
- [[2026-05-03-slice-7-migration-helpers-static-on-resource]] -- where the migration code lives
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- what gets persisted in the bumped save
