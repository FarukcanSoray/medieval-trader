---
title: Perturbation seed combiner: splitmix64 integer mix supersedes hash([...]) array form
date: 2026-05-04
status: ratified
tags: [decision, slice-8, pricing-formula, determinism, hot-path, supersession]
---

# Perturbation seed combiner: splitmix64 integer mix supersedes hash([...]) array form

## Decision
The perturbation seed combiner in `PricingMath._perturbation` is a splitmix64-style xorshift-multiply integer mixer (`_mix64`) over the five tuple components, not the literal `hash([world_seed, tick, node_id, good_id, "buy"])` form that the binding spec §5.4 originally specified.

```
seed = mix64(world_seed, tick, node_id.hash(), good_id.hash(), SIDE_MIX_BUY)
```

`SIDE_MIX_BUY` and `SIDE_MIX_SELL` are distinct high-entropy 64-bit constants that namespace the buy and sell sides. The mix runs in pure integer arithmetic with no allocation per call.

This supersedes the literal `hash([world_seed, tick, node_id, good_id, side])` form referenced in `2026-05-04-slice-8-pool-curve-formula-locked` and the original spec §5.4 wording. Within-run determinism is preserved (gate 3 of the slice-8 harness passes 100/100 seeds round-trip).

## Reasoning
The Code Reviewer flagged Blocker 1 against the original `hash([...])` form: it allocates an `Array` literal per call on a hot path. PricingMath is called per visible row per paint event in `NodePanel`, on every buy/sell verb in `Trade`, by `DeathService.is_stranded`, and ~5M times in the slice-8 measurement harness. Per-call Array literal allocation plus the per-call `RandomNumberGenerator.new()` (also flagged) compounds GC pressure on the web export.

Two halves to address: heap-allocated RNG, and Array literal. A cached static RNG (see `2026-05-04-slice-8-pricing-math-static-rng-cache`) addresses the first half. Switching the combiner to integer-mix addresses the second half. Both fixes together remove all per-call heap allocation from the perturbation path.

The integer mix is splitmix64's finaliser shape: `x ^= x >> 30; x *= 0xBF58476D1CE4E5B9; x ^= x >> 27; x *= 0x94D049BB133111EB; x ^= x >> 31`. GDScript ints are 64-bit and Godot's int math wraps on overflow, which is exactly what splitmix64 expects.

Preserves the load-bearing invariants of the original combiner: tick-included (re-rolls per travel tick); side-namespaced (buy/sell decorrelated); excludes per-buy counter (no re-roll on click); excludes pool fill (continuous, not discontinuous). Adds a new invariant (no per-call heap) that is now required of any future combiner.

## Alternatives considered
The user was shown three options when the trade-off surfaced:

- **(1) Keep integer-mix and update spec §5.4** -- chosen.
- **(2) Revert to literal `hash([world_seed, tick, ...])` with cached RNG.** Addresses the heap-RNG half of Blocker 1 but leaves the Array literal allocation per call. More conservative on the spec/code drift but leaves measurable hot-path waste.
- **(3) Send back to reviewer to ratify the swap.** Adds a round-trip; the trade-off was clear enough that user ratification at this level was the cheaper path.

User explicitly chose (1).

## Confidence
High. User explicitly ratified after seeing the three-way trade-off. Reviewer Blocker 1 was concrete (Array literal allocation, per-call RNG instantiation). Determinism preservation is empirically confirmed by gate 3 of the harness (100/100 seeds round-trip).

## Source
Engineer fix round (2026-05-04 session) addressing Reviewer Blocker 1; user three-way ratification on the supersession; spec §5.1, §5.2, §5.4, §13 amended in the same session (see `2026-05-04-slice-8-spec-perturbation-seed-intent-normative`).

## Related
- [[2026-05-04-slice-8-spec-perturbation-seed-intent-normative]] -- the spec-level reframing this implementation triggered
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- partially superseded; the formula is unchanged but the seed-combiner reference at line 26 is now stale
- [[2026-05-04-slice-8-pricing-math-static-rng-cache]] -- the companion RNG-allocation fix for the same Blocker 1
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the pull-driven decision that put this combiner on the hot path
