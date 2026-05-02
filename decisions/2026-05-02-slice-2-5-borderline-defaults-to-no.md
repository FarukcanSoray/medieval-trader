---
title: Borderline defaults to "n" in eyeball survey; reserved for genuinely contested calls
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, survey, judgement-rules]
---

# Borderline defaults to "n" in eyeball survey; reserved for genuinely contested calls

## Decision

For the slice-2.5 survey's `hub-y?` and `free-lunch suspect?` fields (and any future eyeball-driven inspection field of the same shape), the default is **n**. `borderline` is reserved for cases where the user would argue both sides for 30+ seconds.

`borderline` is a tail category, not a modal escape hatch.

## Reasoning

Critic flagged the failure mode: if `borderline` becomes the modal answer, the survey's "appears 2-4 times in 20" enforcement threshold becomes undefined (do borderlines count? half-count?). Without a tiebreak rule, every uncertain call drifts toward `borderline` and the data becomes ambiguous in a way the protocol cannot resolve.

The 30-second-argue rule forces clarity at the moment of judgement: if the user can't argue both sides for half a minute, it's not contested enough to qualify as borderline -- it's an `n` with low conviction.

This generalises beyond slice-2.5: any future eyeball-driven inspection pass (e.g. tuning passes for pricing, encounters, UI feel) inherits the same risk. The rule is a reusable primitive.

## Alternatives considered

- **Default to `y`** (more conservative; more rejections). Rejected; bias would push toward unnecessary enforcement, contrary to the slice-2.5 "accept entropy by default" posture.
- **No tiebreak rule** (let `borderline` mean what it means). Rejected per Critic's modal-answer failure mode.
- **Detailed notes required for every borderline case** (force structure on ambiguity). Rejected; raises per-seed cost, conflicts with the thin-protocol stance.

## Confidence

High. User explicitly accepted pre-commitment B (which includes this rule); Critic framed it as the cleanest tightening with no protocol overhead.

## Source

This session (2026-05-02 PM, slice-2.5 framing). Critic stress-test "Borderline as modal answer" section; user binding call B.

## Related

- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- the stance this rule enforces in practice.
- [[slice-2-5-survey-protocol]] -- where the rule is codified for slice-2.5.
