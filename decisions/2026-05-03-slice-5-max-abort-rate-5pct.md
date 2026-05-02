---
title: Day-1/day-2 split gates on MAX_ABORT_RATE = 5.0% from headless measurement
date: 2026-05-03
status: ratified
tags: [decision, slice-5, measurement, tuning]
---

# Day-1/day-2 split gates on MAX_ABORT_RATE = 5.0% from headless measurement

## Decision
The slice-5 day-1 -> day-2 transition is gated on a measurement, not an opinion. Day-1 ships salt (catalogue N=3) plus an extension of `tools/measure_bias_aborts.gd` that sweeps N in {2, 3} (and {2, 3, 4} on day-2) over 1000 seeds and reports the per-N abort rate. If `abort_pct(GATE_N) <= 5.0%`, day-2 ships iron (catalogue N=4). Otherwise day-2 stops; the slice ships at N=3; slice-5.x owes a tuning revisit using the abort-side per-good `allowed_range` histogram.

`GATE_N = 3` on day-1 (the new-good predicate floor); retunes to `4` on day-2 (the final-ship gate).

The measurement is itself deterministic on the seed range (0..999): two runs of the tool with the same code produce identical numbers. A 0.1% threshold cross is the call -- no re-roll permitted to dodge the rule.

## Reasoning
The free-lunch predicate is a per-good math constraint that interacts as a *set*: every good must satisfy `(bias_range * base_price + 2 * volatility * ceiling_price) < shortest_edge * 3` simultaneously. Adding goods raises the simultaneous-failure surface multiplicatively. The question "does the predicate hold at N=4?" is rate-shaped and cannot be answered from desk -- this matches the measurement-before-tuning rule.

Designer reasoned the 5% threshold explicitly:
- **1% would be too tight.** Slice-3 measurement at `MIN_EDGE_DISTANCE = 3` reported 0% abort at N=2. Demanding 0% at N=4 (where the simultaneous-satisfaction surface is meaningfully larger) would force a tuning pass on at least one good for cosmetic safety, when 1-in-50 worlds rejecting their first seed and bumping 1-2 times is operationally invisible to the player.
- **10% would be too loose.** Players who serial-roll would feel "many seeds get rejected"; even with the seed-bump retry hiding this from gameplay, the abort tail (5 bumps exhausted -> `push_error`) becomes a non-trivial event count over a large user population.
- **5% lands at "1 in 20 first-seeds bumps once or twice; player never notices."** Abort tail at exhaustion: `0.05^5 = ~3e-7` -- effectively never.

The seed-bump loop already exists for placement starvation and slice-3 bias unsatisfiability; absorbing N=4 predicate failures at the same rate is no new operational concern.

## Alternatives considered
- **1.0% threshold** -- rejected as over-tight (forces cosmetic tuning, no operational benefit).
- **10.0% threshold** -- rejected as over-loose (palpable serial-roll friction; abort tail too thick).
- **Reasoning the predicate strain from desk math without measurement** -- ruled out by [[feedback_measurement_before_tuning]]; rate-shaped questions get tools, not arguments.

## Confidence
High. Designer ratified the threshold with explicit reasoning at spec §6; Architect's day-1 handoff binds the measurement to the gate; Reviewer cleared the verdict-line gate logic against the spec.

## Source
Designer spec `docs/slice-5-goods-expansion-spec.md` §6 (measurement protocol).

## Related
- [[2026-05-03-slice-5-histogram-split-success-abort]] -- the diagnostic data that feeds slice-5.x if the gate fails
- [[feedback_measurement_before_tuning]] -- the standing rule that gates rate-shaped questions on tools
- [[2026-05-02-slice-2-5-survey-automation-deferred]] -- prior precedent for the slice-2.5 tool that this extends
