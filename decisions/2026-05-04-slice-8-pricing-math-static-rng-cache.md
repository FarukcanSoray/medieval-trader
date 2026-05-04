---
title: PricingMath caches a single static RandomNumberGenerator on the hot path
date: 2026-05-04
status: ratified
tags: [decision, slice-8, hot-path, performance, rng-pattern]
---

# PricingMath caches a single static RandomNumberGenerator on the hot path

## Decision
`PricingMath` declares a module-level `static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()` and reuses it across all `_perturbation` calls by reassigning `.seed` per call. Per-call `RandomNumberGenerator.new()` is forbidden in this helper.

```
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

static func _perturbation(...) -> float:
    var seed_value: int = _mix64(...)
    _rng.seed = seed_value
    return _rng.randf_range(-PERTURBATION_FRACTION, PERTURBATION_FRACTION)
```

Single-threaded by assumption -- this Godot project has no concurrent execution today. If threading is ever introduced, the cached static RNG becomes a data race; that is documented in the Engineer's carryover notes for the slice and is the responsibility of the slice that introduces concurrency.

## Reasoning
The Code Reviewer flagged Blocker 1: per-call `RandomNumberGenerator.new()` allocation on a hot path. PricingMath is invoked per visible row per paint event in `NodePanel`, on every buy/sell verb in `Trade`, by `DeathService.is_stranded`, and ~5M times in the slice-8 measurement harness. Heap-allocating an `Object`-derived RNG instance per call is the kind of GC pressure the Web export profile cares about.

Mutating `.seed` on a single shared instance is the documented `RandomNumberGenerator` reset path in Godot 4. The seed is recomputed deterministically per call from the (`world_seed`, `tick`, `node_id`, `good_id`, side) tuple via `_mix64`, so within-run determinism is preserved (gate 3 of the slice-8 harness passes 100/100 seeds round-trip).

This pattern may rise to a project-level convention if other hot-path helpers want stateless deterministic RNG -- the user explicitly flagged this as ambiguous between "slice-8-local" and "convention candidate." It is recorded here as slice-8-local with the door open for promotion.

## Alternatives considered
- **Per-call `RandomNumberGenerator.new()`** -- the original implementation, rejected by Reviewer Blocker 1.
- **Use a non-Godot deterministic RNG** (e.g. raw integer arithmetic returning a float) -- viable, but `RandomNumberGenerator.randf_range` is already the spec's contract for the perturbation distribution and reusing it preserves bit-compatibility with the formula.
- **Thread-local RNG cache.** Premature -- the project is single-threaded and adding thread-locals now would be cost without benefit. Documented as a forward concern.

## Confidence
Medium. The pattern is correct and surgical; what is uncertain is whether it generalises to a project convention. Filed at this level so future hot-path helpers can either reference it or supersede it.

## Source
Reviewer's Blocker 1 in the slice-8 review (per-call RNG allocation flagged as hot-path waste); Engineer's fix pass implementing the static cache; user ratified during the closeout.

## Related
- [[2026-05-04-slice-8-perturbation-seed-mix-supersedes-hash-array]] -- the companion fix for the same Blocker 1 (Array literal allocation)
- [[2026-05-04-slice-8-spec-perturbation-seed-intent-normative]] -- the spec invariant that codifies "no per-call heap"
- [[2026-05-04-slice-8-pricemodel-reshaped-stateless-query]] -- the structural decision that put PricingMath on the hot path in the first place
