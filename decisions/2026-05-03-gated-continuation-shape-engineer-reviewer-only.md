---
title: Gated-continuation slices use Engineer→Reviewer pipeline only (skip Director/Critic/Designer/Architect)
date: 2026-05-03
status: ratified
tags: [decision, workflow, process, pipeline]
---

# Gated-continuation slices use Engineer→Reviewer pipeline only (skip Director/Critic/Designer/Architect)

## Decision
When a slice was fully pipelined in a prior session (Director, Critic, Designer, Architect, Engineer, Reviewer all touched it) AND a later day of that slice is "fully named" (specs and decisions ratified, work mechanically prescribed), the pipeline shape for that day is **Engineer -> Reviewer only**. The four upstream roles are skipped.

Concretely: this applies to multi-day slices with explicit gates (e.g., slice-5's day-1 / day-2 split, where day-2 work is conditional on day-1 measurement passing). Day-2 inherits the slice's prior pipeline output; running the full pipeline again would re-traverse settled ground.

Trigger conditions (all must hold):

1. The slice itself has been fully pipelined in a prior session.
2. The current day's work is named in a binding spec or session note (file paths, function signatures, parameter values, all explicit).
3. No new design surface is exposed by the day's work (no new mechanics, no new pillars-of-fit questions, no new structural calls).
4. The prior pipeline's decisions are still binding (no contradicting evidence has emerged since).

If any condition fails -- e.g., playtest of the prior day reveals a new design question, or measurement comes back ambiguous -- escalate to the missing role(s). The shape is not a free pass; it is the shape when there is genuinely nothing for the upstream roles to add.

## Reasoning
The full pipeline (Director -> Critic -> Designer -> Architect -> Engineer -> Reviewer) is project standing rule for new features (CLAUDE.md, "Every feature goes through Director and Critic before Designer touches it"). It is not standing rule for *executing already-ratified work*. Forcing Director/Critic/Designer/Architect to rubber-stamp settled decisions adds churn without value: each round costs context and time, and re-opening settled questions risks decision-thrash where someone's late-arriving Critic-shaped instinct undoes a prior ratification.

The slice-5 case made this concrete: day-1 ratified four decisions binding for both days (catalogue scope, role taxonomy, abort threshold, forward-port path). Day-1's session note explicitly listed day-2 as "fully named" with iron's exact parameter values, the preload append point, and the measurement extension targets. Running Director on "should we add iron?" would have pretended day-1 hadn't already answered that.

The carryover-check-protocol memory ([[feedback_carryover_check_protocol]]) is the adjacent rule: re-read the doc that governs an open task and surface its exit ramp as a co-equal option. This decision codifies the exit ramp's shape -- when the governing doc says "fully named," the exit ramp is Engineer -> Reviewer.

The slice-first stance ([[feedback_critic_stance]]) reinforces the call: the user holds full scope and uses slicing as the sequencing mechanism. Once a slice has been ratified, executing its named subsections is sequencing, not new design.

## Alternatives considered
- **Re-run the full pipeline on every slice-day** -- the conservative default, ratified for new features. Rejected for gated-continuation days because the upstream roles would have nothing to add when the slice's spec is binding and the day is named. Adds churn without correctness benefit.
- **Engineer-only (skip even Reviewer)** -- rejected. Reviewer is the last load-bearing guard for type-strictness, ASCII rule, naming, scope creep, anti-pattern catches. Even mechanical work benefits from one independent read; the pattern that lands here is "minimal pipeline" not "no pipeline."
- **Designer + Engineer + Reviewer** -- rejected. If Designer's spec is binding from the prior session, re-running Designer on already-named work is the same churn-without-value problem; if it isn't binding, the slice wasn't actually fully pipelined and the trigger condition fails.

## Confidence
Medium. The shape worked cleanly for slice-5 day-2 -- one Engineer pass, one cosmetic follow-up, one Reviewer Ship-it, measurement passed at the gate. But this is the first time the shape has been applied; subsequent slices may surface edge cases the trigger conditions don't cover (e.g., a multi-day slice where day-N reveals a measurement result that retroactively invalidates a day-(N-1) decision -- which role re-opens it?). Revisit if the shape produces a "we should have had Designer back in" failure mode.

## Source
This session (slice-5 day-2 close, 2026-05-03). Pipeline shape was framed as two options early in the session; user chose option A (governed execution). The shape was not pre-named in any prior decision or memory; this is the first explicit codification.

## Related
- [[feedback_carryover_check_protocol]] -- the adjacent rule (memory) about checking governing protocols before promoting carryover
- [[feedback_critic_stance]] -- the user's standing pattern of holding scope and sequencing via slices
- [[2026-05-03-slice-5-day-1-day-2-split]] -- the day-1/day-2 split that produced the first gated-continuation case
- [[2026-04-29-no-cuts-slice-first]] -- the broader stance this decision sits inside
