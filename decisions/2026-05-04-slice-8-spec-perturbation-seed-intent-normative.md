---
title: Slice-8 spec perturbation seed combiner is intent-normative, not bit-exact
date: 2026-05-04
status: ratified
tags: [decision, slice-8, spec-discipline, determinism, hot-path]
---

# Slice-8 spec perturbation seed combiner is intent-normative, not bit-exact

## Decision
Slice-8 spec §5.4 is reframed: the perturbation seed combiner is **normative on intent and invariants, not on bit-exact output**. Any deterministic 64-bit mix over the five tuple components (`world_seed`, `tick`, `node_id`, `good_id`, side) that satisfies the listed invariants is conformant. The reference implementation lives in `PricingMath._perturbation` / `_mix64`.

The five load-bearing invariants any conformant combiner must preserve:

1. Seed includes `tick` (perturbation re-rolls every travel tick).
2. Seed includes a buy/sell namespace term (sides decorrelate).
3. Seed does NOT include any per-buy or per-sell counter (no re-roll on click).
4. Seed does NOT include pool fill (continuous, not discontinuous).
5. Combiner allocates **no per-call heap** -- no `RandomNumberGenerator.new()`, no Array literal, no String concatenation. **NEW today.**

Spec §5.1, §5.2, §5.4, and §13 were amended in this session to replace the literal `hash([world_seed, tick, node_id, good_id, "buy"])` references with `mix(world_seed, tick, node_id, good_id, SIDE_BUY)` pointer-shaped references plus the intent-normative paragraph in §5.4.

## Reasoning
The original spec §5.4 wording locked an implementation detail (the exact Array-based hash form). When the Engineer needed to swap the combiner for hot-path reasons (see `2026-05-04-slice-8-perturbation-seed-mix-supersedes-hash-array`), the spec text and the code disagreed.

Reframing the spec to be intent-normative resolves this without weakening the contract: the five invariants are what matter for determinism, decorrelation, legibility, and hot-path safety. The exact bit-output is not load-bearing -- gate 3 of the harness measures within-run replay determinism, which any pure-function combiner satisfies trivially.

Invariant 5 (no per-call heap) is new today, codifying the hot-path constraint discovered by the Reviewer's Blocker 1. Future combiner changes must preserve it.

## Alternatives considered
None discussed. The reframing was presented to the user as a consequence of choosing Option 1 in the three-way supersession trade-off and proceeded directly.

## Confidence
High. Direct consequence of an explicit user ratification; spec amendments are concrete (four sections updated in this session); the invariant list is identical to the original except for the new heap-allocation rail.

## Source
Spec update phase of the 2026-05-04 session, immediately following user's choice of Option 1 in the perturbation-seed supersession trade-off. See `docs/slice-8-pricing-v2-spec.md` §5.4 for the new paragraph.

## Related
- [[2026-05-04-slice-8-perturbation-seed-mix-supersedes-hash-array]] -- the implementation change that forced this spec reframe
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula whose seed-combiner reference these invariants now govern
- [[2026-05-04-slice-8-pricing-math-static-rng-cache]] -- the companion change that also helps satisfy invariant 5
