---
date: 2026-05-02
type: session
tags: [session, slice-2-5, tuning-framing]
---

# Slice-2.5 framing: seed-survey inspection protocol

## Goal

Open slice-2.5 (the named tuning pass for procgen rejection criteria) and frame the seed-survey inspection protocol so the user can run it later. Run Director -> Critic -> user binding calls -> document decisions -> smoke test -- then pause before survey execution.

## Produced

- `docs/slice-2-5-survey-protocol.md` -- one-pager protocol for manual inspection of 20 seed boots. Five degeneracy definitions (hub-and-spoke, free-lunch, dominant routes, planarity; same-as-prior-seed deferred). Per-seed row structure (five fields). Cut conditions and out-of-scope list.
- `docs/slice-2-5-survey-results.md` -- empty 20-row tally table with impressions section; ready to populate as seeds run.
- `tools/survey.ps1` -- PowerShell launch helper. Deletes save, launches Godot with `--seed=$Seed`, tees stdout to `slice-2-5-survey.log`. Smoke-tested on seed 1.

## Decisions

- [[2026-05-02-slice-2-5-same-as-prior-seed-deferred]] -- deferred to slice-3+.
- [[2026-05-02-slice-2-5-hard-20-seed-cap]] -- no early stop, no continuation.
- [[2026-05-02-slice-2-5-borderline-defaults-to-no]] -- tiebreak for eyeball surveys.
- [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]] -- cross-slice owe-note.
- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- project posture for all tuning passes.

## Pipeline shape

Director frame -> Critic stress-test -> user binding calls (defer same-as-prior; accept all four Critic pre-commitments) -> decisions extracted and ratified. No Designer, Architect, Engineer, or Reviewer: slice-2.5 produces decisions from inspection, not code. One plain-language step-back delivered (pre-survey recap + binding-call framing) per standing memory rule.

## Open threads

- **Survey execution paused.** Seeds 2..20 still to run. Resume with `./tools/survey.ps1 N` for each seed. Time budget 45-75 min. Task #3 in slice-2.5 task list, pending.
- **Rejection thresholds ratification.** Task #4, depends on survey data. Director + Critic + user converge on hub/free-lunch/planarity verdicts post-survey.
- **Pricing slice owes topology-revisit** for free-lunch (preserved by [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]]).
- **Carryover from prior sessions:** web-export Begin Anew flicker, four corruption-regen branches untested, B1 deferred iters 1/4/5, runbook prose-refresh, `TRAVEL_COST_PER_DISTANCE` playtesting, travel confirm-modal Cancel button, Tier 7 deferred markers (from [[2026-05-02-cleanup-pass]]).

## Links

- [[2026-05-02-slice-2-procgen-pipeline]] -- slice-2 full pipeline that seeded this work.
- [[2026-05-02-slice-2-5-named-tuning-pass]] -- the charter decision from slice-2 close.
- [[CLAUDE]] -- project scope and workflow.

## Notes

First slice-2.5 session; precedent-setting for tuning-pass slice shape (Director-Critic-User-decisions, no engineering pipeline, paused mid-slice for hand-driven inspection).

The "accept entropy by default" decision is broader than slice-2.5 -- explicitly framed as a project posture for all future tuning passes.

This is the second time the project has used "name the carryover, archive through decisions" to prevent silent loss (first was slice-2.5 itself relative to slice-2, via [[2026-05-02-slice-2-5-named-tuning-pass]]).
