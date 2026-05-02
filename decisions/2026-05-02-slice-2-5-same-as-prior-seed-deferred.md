---
title: Same-as-prior-seed survey field deferred from slice-2.5 to slice-3+ play
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, survey, deferral, starting-node]
---

# Same-as-prior-seed survey field deferred from slice-2.5 to slice-3+ play

## Decision

The "same-as-prior-seed" field is removed from the slice-2.5 inspection row. Starting-node sameness -- the question of whether the highest-degree starting policy produces same-feeling openings across seeds -- will be evaluated in slice-3+ against actual gameplay feel, not via silent-boot eyeballing.

The slice-2.5 per-seed row is therefore 5 fields, not 6: `seed`, `nodes/edges`, `min/max edge dist`, `hub-y?`, `free-lunch suspect?`, plus a `notes` column.

## Reasoning

Critic identified the field as Hidden-Expensive: holding a mental cache of 2-3 prior worlds while evaluating seed N inflates per-seed judgement time and degrades by seed 8 when comparisons drift to "some earlier world that felt like this." Most likely field to silently corrupt the survey.

User chose option A2 (defer entirely) over A1 (narrow to immediately-prior seed only) on the framing argument that starting-node sameness is fundamentally a play-feel question that 20 silent boots cannot authentically answer.

## Alternatives considered

- **A1: Narrow scope** -- compare current seed only to immediately-prior seed. Cheaper than full 2-3 history, keeps the question live in slice-2.5. Rejected because the underlying signal is play-feel, not visual layout.
- **Keep the field as-is** with full 2-3 seed comparison. Rejected per Critic's Hidden-Expensive flag.
- **Add stricter scaffolding** (notes-per-comparison, longer log) to make the field robust. Rejected; protocol is meant to stay thin.

## Confidence

High. Explicit user binding call (A2) after parent agent framed the trade-off; Critic's Hidden-Expensive analysis was direct.

## Source

This session (2026-05-02 PM, slice-2.5 framing). Critic stress-test "Same-as-prior-seed field" section; user binding call A2.

## Related

- [[2026-05-02-slice-2-5-named-tuning-pass]] -- the charter listing starting-node policy review as an open thread.
- [[slice-2-5-survey-protocol]] -- protocol that implements this deferral.
