---
title: B1 ships zero schema bump; monotonic-tick verification deferred to B2
date: 2026-05-01
status: ratified
tags: [decision, save-system, schema, b1, b2-deferral]
---

# B1 ships zero schema bump; monotonic-tick verification deferred to B2

## Decision

B1's harness does not bump `schema_version` from 1. Two specific candidates that would have required a bump are explicitly deferred:

- **`last_validated_tick`** persisted across boots (which would catch the backward-rolling-tick failure mode #7-full): deferred to B2.
- **Structured `from_id`/`to_id` fields on history entries** (which would simplify P6 history referential integrity): rejected. P6 instead parses arrow-form strings (`"hillfarm→rivertown"`) out of the existing `history[].detail` field.

B1 covers eleven of twelve failure modes via the harness/runbook split; mode #7's backward-rolling-tick variant rides to B2 alongside other determinism work.

## Reasoning

Director's call: a schema bump in slice 1 normalizes schema bumps, and slice-spec §8's "discard and regenerate on schema mismatch" posture depends on the slice not doing migrations. Bumping schema for a single non-gameplay key inside the *first* invariant slice is exactly the accretion the slice-first stance exists to prevent.

Backward-rolling-tick across boots requires browser-storage anomalies (IndexedDB transaction reorder, quota eviction) that aren't the failure pattern B1 was scoped to prove. Deferring to B2 lets one schema bump pay for multiple modes (monotonic-tick + whatever B2 surfaces about FIFO ordering and quota) instead of accreting bumps one-at-a-time.

P6's arrow-string parsing is brittle but acceptable: exactly one writer (`TravelController._push_travel_history`) authors the `detail` format, so the parser's coupling has a single owner. If a future slice adds new `history` kinds with different `detail` shapes, the parser updates with them.

## Alternatives considered

- **Add `last_validated_tick` to save schema**: rejected per Director on slice-first / no-migrations grounds.
- **Add `from_id`/`to_id` fields to history entries**: rejected. Schema-clean alternative (parsing) exists and the writer is single-source.
- **Defer P6 entirely (no history referential integrity)**: rejected. Mode #8 (history-state mismatch) is a real corruption surface; parsing closes it without a bump.

## Confidence

High. Director's ruling was definitive on the schema-bump question; the parsing alternative was a clean structural workaround.

## Source

- Director's second ruling (monotonic-tick deferral).
- Architect's revision (P6 parsing approach in lieu of schema bump).

## Related

- [[2026-04-30-tier7-deferred-followups]] — same "small things deferred" archive pattern
- [[2026-05-01-save-invariant-checker-harness-no-autoload]] — P6 lives in this harness
- [[slice-spec]] — §3 save schema (untouched), §8 schema-mismatch posture (depends on no migrations)
