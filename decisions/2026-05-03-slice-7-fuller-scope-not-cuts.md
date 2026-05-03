---
title: Slice 7 ships fuller scope; Critic's 7.0/7.1 split rejected
date: 2026-05-03
status: ratified
tags: [decision, slice-7, scope, owner-override]
---

# Slice 7 ships fuller scope; Critic's 7.0/7.1 split rejected

## Decision
Slice-7 ships caps on **every good at every node** with **character-tuned refill rates** (per-good, derived from `Good.base_*` values * tag multipliers). The Critic-proposed 7.0/7.1 split (caps on `(plentiful)`-only goods + flat refill in 7.0, fuller version in 7.1) is rejected. The "fuller" scope lands in one slice.

## Reasoning
The user holds full scope and uses slice-first sequencing instead of accepting Critic reductions. Splitting caps into a `(plentiful)`-only first pass would mean two schema bumps (one for caps-on-plentiful, one to extend to all goods) and two harness reframes, doubling integration cost for a sequencing benefit. The fuller authoring surface (per-good base values + four tag multipliers in `WorldRules`) keeps tuning visibility and preserves tag meaning -- `(plentiful)` and `(scarce)` graduate from labels to mechanical knobs in the same slice they begin to bite.

## Alternatives considered
- **Critic's 7.0/7.1 split** -- caps on `(plentiful)`-only goods with flat refill in 7.0; full per-good caps + character refill in 7.1. Rejected per project stance.
- **Even fuller scope** (per-node `.tres` authoring of caps and rates) -- rejected because it conflicts with the procgen-world decision; tag multipliers achieve the same felt experience without breaking determinism.

## Confidence
High. User explicitly chose "fuller version" after Critic surfaced the split; this is the standing project stance documented in `feedback_critic_stance` memory.

## Source
User reply mid-pipeline (2026-05-03): "no, I want 7 as fuller version."

## Related
- [[feedback_critic_stance]] -- the standing user stance that produced this override
- [[2026-04-29-no-cuts-slice-first]] -- prior project-level decision on this stance
- [[2026-05-03-slice-7-tag-multipliers-load-bearing]] -- the load-bearing design that "fuller" refers to
- [[2026-05-03-slice-7-schema-bump-coalesces-cargo-capacity]] -- one of the bumps avoided by not splitting
