---
title: `EncounterOutcome.readback_consumed` pre-empted in slice-4 schema (avoids slice-4.x bump)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, schema-management, forward-compat]
---

# `EncounterOutcome.readback_consumed` pre-empted in slice-4 schema (avoids slice-4.x bump)

## Decision
`EncounterOutcome` carries a `readback_consumed: bool` field (default `false`) in slice-4 day-1 even though no day-1 code reads or writes it. Persisted in `to_dict`/`from_dict`.

## Reasoning
Slice-4.x's "encounter resolution modal" carryover ([[2026-05-02-slice-4-encounter-resolution-modal-deferred]] — to be logged when slice-4.x is named) needs exactly this bool to track whether the modal was acknowledged. Pre-empting the field in slice-4 schema 4 avoids a second discard-toast for the user when the modal lands. Schema-bump cost is identical whether the field ships now or in a follow-up bump; user pain (a second forced save discard) is not.

This is the same pattern slice-3 used implicitly (most fields were future-proofed) but flagged explicitly here because the field is dead until slice-4.x.

## Alternatives considered
- **YAGNI — defer the field to slice-4.x** — rejected; one bool now vs another full discard-toast cycle later. The field has no runtime cost; the user pain of a second migration does.

## Confidence
High. Architect-confirmed; one bool serialised per save.

## Source
Designer spec §3, §10; Architect Call 4 (pre-empt confirmed).

## Related
- [[2026-05-02-slice-4-schema-4-discard-via-toast]] — the bump this field rides on
- [[2026-05-02-slice-4-history-encounter-kind]] — the readback the modal would consume
