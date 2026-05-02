---
title: Bias-abort measurement histograms split into success and abort populations
date: 2026-05-03
status: ratified
tags: [decision, slice-5, measurement, tooling, reviewer-overturn]
---

# Bias-abort measurement histograms split into success and abort populations

## Decision
The per-good `allowed_range` histogram in `tools/measure_bias_aborts.gd` captures both success and abort populations as separate histograms (`per_good_histogram_success` and `per_good_histogram_abort`), one sample per requested seed per good. Successes sample the post-bump winning topology; aborts sample the *exhausted* topology at `seed_value + WorldGen.MAX_SEED_BUMPS - 1`. A new public static `WorldGen.compute_topology_min_edge_distance(effective_seed: int, map_rect: Rect2) -> int` reproduces the placement+edge half of `generate` without authoring bias or seeding prices, supporting the abort-side sample.

The placement-starvation case (helper returns `-1`) skips the abort histogram for that seed and is documented as an informative gap (rare under `MIN_EDGE_DISTANCE = 3`).

## Reasoning
The Engineer's first pass sampled successes only, reasoning "the data of interest is for worlds that did succeed, how much margin remained?" Reviewer overturned this as structurally incorrect: every good in a successful seed has `allowed_range >= MIN_BIAS_RANGE` by construction (because `_author_bias` returns false the moment any good's range drops below that threshold), so the `[0.0, MIN_BIAS_RANGE)` bucket is always empty for successes. The diagnostic question spec §7 binds the histogram to is "if the slice fails the gate, which good drove the aborts?" A success-only sample is structurally incapable of answering that, because the failing good is exactly the one whose distribution gets clipped out of the success sample.

A success-only histogram on a FAIL day-2 outcome would print clean-looking numbers above the threshold while the diagnostic signal -- which good fell into the predicate-fail zone, and how often -- would be invisible. Shipping the tool that way would burn the measurement at the exact moment slice-5.x would need it.

The new `compute_topology_min_edge_distance` helper was chosen over alternatives:
- **Duplicate placement+MST+edges code into the tool** -- rejected; recipe for silent drift between gen-time and measurement-time formulas.
- **Out-parameter on `generate`** -- rejected; pollutes the gameplay hot path's signature with measurement scaffolding.

The helper isolates the cost: production callers see a one-line public addition; the tool gets exact production behavior for free. Reviewer ratified as "measurement-tool affordance, not a gameplay path."

## Alternatives considered
- **Success-only histogram** -- Engineer's initial implementation; Reviewer's blocking issue overturned it as structurally incapable of answering the diagnostic question.
- **Single combined histogram (no split)** -- not explicitly named, but the split preserves the success-side margin distribution as useful tuning context alongside the load-bearing abort diagnostic.
- **Reverse-walk the bump loop** to recover signal from seeds where the *last* bump placement-starved but earlier bumps failed for predicate reasons -- deferred; current placement-starvation skip is acceptable for slice-5 day-1, fix is named for slice-5.x if histogram comes back ambiguous.

## Confidence
High. Reviewer's structural argument is non-overrideable (success-only sampling is mathematically incapable of populating the load-bearing bucket). Engineer round 2 implemented the split; Reviewer round 2 verified correctness and ratified the public-API addition.

## Source
Reviewer round 1 (blocking ruling on success-only sampling); Engineer round 2 (split implementation + helper); Reviewer round 2 (Ship-it verdict on the split).

## Related
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- the gate the histogram diagnoses on failure
- [[2026-05-02-slice-2-5-survey-automation-deferred]] -- prior precedent for the headless measurement tool family
- [[feedback_measurement_before_tuning]] -- the standing rule that puts diagnostic tools at the center of rate-shaped questions
