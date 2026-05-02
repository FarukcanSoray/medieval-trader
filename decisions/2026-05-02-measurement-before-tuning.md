---
title: Measurement-before-tuning -- when uncertainty is quantifiable, quantify it
date: 2026-05-02
status: ratified
tags: [decision, process, meta, quality-gate, measurement]
---

# Measurement-before-tuning -- when uncertainty is quantifiable, quantify it

## Decision
When a tuning-vs-correctness question reduces to optimism vs pessimism between agents, **pause the pipeline, write a headless measurement tool, run it against a meaningful sample size, and decide on the data**. Do not defer to "playtesting will tell us" or accept "spec-intended" claims that are not backed by numbers. The cost of an hour of measurement is small; the cost of shipping a broken boot path is large.

## Reasoning
This pattern emerged organically during slice-3. Engineer flagged a free-lunch predicate concern as "spec-intended; seed-bump handles it." Reviewer pressure-tested and called it a blocker. The question -- "is the abort rate tolerable?" -- was empirically answerable. User chose option (b) measurement over option (a) immediate fix or option (c) Monte Carlo paper analysis.

Engineer wrote `tools/measure_bias_aborts.gd` (1000 seeds, headless, runs in ~10 seconds). Result: **70% abort rate** -- catastrophically worse than either Engineer or Reviewer had estimated. The measurement converted a debate into a decision.

Re-measurement after the fix (`MIN_EDGE_DISTANCE = 3`): **0% abort rate**. Closed the loop empirically.

This is now the standing pattern for the project: when a Reviewer-vs-Engineer disagreement is data-shaped, write a measurement tool before patching.

## When this applies
- Tuning constants with system-wide implications (abort rates, retry rates, distribution shapes)
- "Will this rare event actually be rare?" questions
- Any place where a `[needs playtesting]` flag is being used to defer a question that could be answered headlessly in minutes

## When this does NOT apply
- Subjective questions (does it *feel* good?) -- those still need playtesting
- Questions about gameplay narrative (what does death mean?) -- design questions, not measurement questions
- Trivial fixes where the data is obvious from inspection (off-by-one bugs, etc.)

## Alternatives considered
- **Trust Engineer's optimism** -- would have shipped a 70% abort boot path
- **Trust Reviewer's pessimism without data** -- would have over-corrected without knowing how bad it actually was
- **Defer to slice-3.x with playtesting** -- the deferral was the *originating* problem the slice was meant to close

## Confidence
High. Pattern is concrete, was operationally tested in the same session, and is general enough to apply to future slices.

## Source
Engineer + Reviewer slice-3 pricing pass; measurement run from PowerShell; user explicitly invoked option (b) when given the choice.

## Related
- [[2026-05-02-slice-3-min-edge-distance-3-pulled-forward]] -- the decision this pattern produced
- [[2026-05-02-slice-2-5-survey-automation-deferred]] -- prior decision that *deferred* a similar measurement; this decision is the corrective for that pattern
