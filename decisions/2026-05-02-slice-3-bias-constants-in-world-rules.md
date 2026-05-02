---
title: Bias bounds and MEAN_REVERT_RATE live in `WorldRules` (kernel-knob family)
date: 2026-05-02
status: ratified
tags: [decision, slice-3, architecture, configuration]
---

# Bias bounds and MEAN_REVERT_RATE live in `WorldRules` (kernel-knob family)

## Decision
The following constants live in `godot/shared/world_rules.gd`, alongside existing `TRAVEL_COST_PER_DISTANCE` and `TICK_DURATION_SECONDS`:

- `MEAN_REVERT_RATE: float = 0.10`
- `BIAS_MIN: float = -0.40`
- `BIAS_MAX: float = 0.40`
- `MIN_BIAS_RANGE: float = 0.20`
- `PRODUCER_THRESHOLD_FRACTION: float = 0.5`
- `CONSUMER_THRESHOLD_FRACTION: float = 0.5`

## Reasoning
Architect noted these are kernel-tuning knobs in the same family as `TRAVEL_COST_PER_DISTANCE` -- cross-system tuning facts that pricing reads. Keeping `MEAN_REVERT_RATE` on `PriceModel` would lock it to one consumer, but `WorldGen._author_bias` reads bias bounds at gen time (so they have at least two consumers immediately). `WorldRules` is the right home; the precedent is [[2026-04-30-world-rules-shared-static-config]].

## Alternatives considered
- Keep constants local to their consumers (`PriceModel`, `WorldGen`) -- rejected because they cross system boundaries.

## Confidence
High. Consistent with existing precedent; clear ownership.

## Source
Architect handoff §3.

## Related
- [[2026-04-30-world-rules-shared-static-config]]
- [[2026-05-02-slice-3-mean-reversion-added]]
