---
title: Slice-5 day-2 PASS verdict at N=4 (0.0% abort, threshold 5.0%); slice-5 ships
date: 2026-05-03
status: ratified
tags: [decision, slice-5, measurement, ratification]
---

# Slice-5 day-2 PASS verdict at N=4 (0.0% abort, threshold 5.0%); slice-5 ships

## Decision
The headless `tools/measure_bias_aborts.gd` tool, extended for day-2 (`GOOD_PATHS` includes iron, `N_SWEEP = [2, 3, 4]`, `GATE_N = 4`), reports `abort_pct(N=4) = 0.0%` over 1000 seeds. The day-2 gate is `abort_pct <= 5.0%` per the binding day-1/day-2 split decision. Verdict: PASS. Slice-5 ships at N=4 goods (wool, cloth, salt, iron); iron is the load-bearing predicate good as designed.

The full sweep:

| N | abort_pct |
|---|---|
| 2 | 0.0% |
| 3 | 0.0% |
| 4 | 0.0% |

All 1000 seeds at N=4 succeed with zero seed-bumps. B1 invariant harness clean (P1-P6 all PASS). stderr clean of script errors after the cache-rebuild via `--import` earlier in the day.

## Reasoning
The gate is binding from spec §6 and the day-1/day-2 ratification: `abort_pct(GATE_N=4) <= MAX_ABORT_RATE=5.0%` ships, anything above stops the slice at N=3. Observed 0.0% crosses the threshold by 5.0 absolute percentage points -- well clear of the rule.

Per-good `allowed_range` histograms validate Designer's spec §7 prediction:

- **wool**: 1000/1000 in `[0.30, 0.40)` -- comfortable margin (~0.10+ over MIN_BIAS_RANGE).
- **cloth**: 1000/1000 in `[0.20, 0.30)` -- tight margin (~0.06+).
- **salt**: 1000/1000 in `[0.60, 0.80)` -- wide margin (~0.40+); predicate is never the binding constraint for salt.
- **iron**: 1000/1000 in `[0.20, 0.30)` -- spec §7 predicted "raw range 0.264, with 0.064 of margin" and the histogram landed exactly there. Iron is now the second load-bearing good (alongside cloth) for predicate failure if `MIN_EDGE_DISTANCE` ever drops below 3 in a future slice.

Zero aborts at N=4 means the predicate is satisfied on every seed in the test range, but the margin is real, not generous. That is the design intent -- the slice spans the role taxonomy without leaving budget headroom.

User confirmed in-editor playtest that iron renders with per-node prices, prices differ between nodes, and the slice-4-save forward-port path produces salt + iron rows on first load without a corruption-toast. The slice's own deliverables (4-good predicate validation, role taxonomy realization, forward-port migration) are confirmed.

## Alternatives considered
- **Stop at N=3** -- only available if `abort_pct(N=4) > 5.0%`. Not triggered; observed value is zero.
- **Re-run the measurement to confirm** -- ruled out by the determinism note in [[2026-05-03-slice-5-max-abort-rate-5pct]]: two runs with the same code produce byte-identical numbers. Re-rolling to dodge the rule is not permitted; re-rolling to confirm a passing rule wastes time.
- **Block slice closure on the save-persistence bugs surfaced during playtest** -- separately ratified as carryover; see [[2026-05-03-slice-5-save-bugs-deferred-to-5x]].

## Confidence
High. Measurement is deterministic; the gate is ratified; the verdict crosses the threshold by a wide margin; the supporting histograms match Designer's pre-measurement predictions.

## Source
Headless `measure_bias_aborts.gd` run on 2026-05-03 after the slice-5 day-2 Engineer pass shipped; verdict line: `slice-5 day-2 verdict: PASS  -> slice-5 ships at N=4; bias-predicate abort rate within budget.` User in-editor playtest confirmed iron renders, prices differ.

## Related
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- the binding day-1/day-2 gate threshold
- [[2026-05-03-slice-5-four-good-role-taxonomy]] -- the role spread iron completes
- [[2026-05-03-slice-5-histogram-split-success-abort]] -- the diagnostic format that produced the per-good histograms above
- [[2026-05-03-slice-5-forward-port-saves]] -- the migration path validated by the in-editor playtest
- [[2026-05-03-slice-5-save-bugs-deferred-to-5x]] -- structural save-persistence bugs surfaced during playtest, deferred
