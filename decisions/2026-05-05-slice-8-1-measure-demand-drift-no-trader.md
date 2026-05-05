---
title: Measurement tool measure_demand_drift uses no-trader policy
date: 2026-05-05
status: ratified
slice: 8.1
tags: [decision, slice-8.1, measurement, tooling]
---

# Measurement tool measure_demand_drift uses no-trader policy

## Decision
Add `godot/tools/measure_demand_drift.gd` to gate the slice-8.2 redesign decision.

Shape:
- `extends SceneTree` with `func _initialize()` entry point (matches `measure_production_caps.gd`, NOT static `_run`)
- Sweeps 200 seeds, calls `WorldGen.generate(seed, goods, FALLBACK_RECT)`
- Pure decay+refill drift per tick: no trader, no buys, no sells
- Samples at ticks 0, 100, 500, 2000
- Per-(node, good) and aggregate spread metrics; first-seed dump for spot-check

## Reasoning
The slice-8.2 redesign decision hinges on whether pool symmetry re-emerges over time absent trader pressure. Adding a simulated trader policy (random walk or greedy arbitrage) would confound the intrinsic system signal with player-behavior assumptions and make the resulting numbers harder to interpret. Designer chose pure pool-dynamics measurement to keep that signal clean.

The tool's first run answered the open question affirmatively: under the current `DemandSystem`, all cells reach cap by ~tick 100 because the system rises toward cap unconditionally. This means slice-8.1 only protects tick 0 to ~tick 100; slice-8.2 must reshape `DemandSystem`. The data-gating Critic recommended is therefore satisfied affirmatively.

## Alternatives considered
- **Random-walk trader simulation** -- rejected: confounds pool dynamics with policy choice.
- **Greedy-arbitrage trader simulation** -- rejected as a separate-tool problem (exploit detection is a different question from pool re-symmetry); flagged as plausibly a slice-8.2 deliverable.

## Confidence
High. Designer's reasoning for no-trader was clear and load-bearing; user accepted; first run produced the expected signal cleanly.

## Source
Designer's slice-8.1 spec on 2026-05-05; first-run output during Engineer implementation.

## Related
- [[2026-05-04-slice-8-demand-multiplier-inverse-supply]] -- the demand system whose dynamics are measured
- [[2026-05-05-slice-8-1-asymmetric-initial-demand-fill-by-tag]] -- the fill change this tool validates
