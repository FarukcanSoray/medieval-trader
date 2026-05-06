---
title: Conservation RNG seed plumbed via per-NodeState sell_seed_counter
date: 2026-05-05
status: ratified
slice: 8.2
tags: [decision, slice-8.2, determinism, rng, persistence]
---

# Conservation RNG seed plumbed via per-NodeState sell_seed_counter

## Decision
Each `NodeState` carries a `sell_seed_counter: int` field. On each successful sell, conservation RNG seed = `hash([world_seed, tick, node_id, good_id, sell_seed_counter, "conservation"])`. The counter increments **after** hashing, so two sells in the same tick at the same node produce different coin-flips. The counter persists across save/load.

## Reasoning
Conservation fires probabilistically (`CONSERVATION_FRACTION = 0.10`) on every successful sell. Without disambiguation, two sells in the same tick at the same (node, good) would seed identically and produce the same coin-flip, breaking save-replay determinism if those sells are split across a save/load boundary.

Architect evaluated three alternatives. Per-NodeState counter chosen because:
- **Persists deterministically** across save/load (other options either lose state or couple to scheduler that's not save-aware).
- **Lives at the node scope** where conservation actually mutates state (no spurious coupling to TraderState).
- **Minimal external surface**: only `Trade.try_sell` reads/increments the counter; no other system touches it.

Save footprint: ~1 int per node, negligible compared to existing dicts.

## Alternatives considered
- **Per-trader counter on TraderState** -- rejected; couples Trade verb to TraderState, which it currently does not need.
- **In-tick local counter on DemandSystem (resets each tick)** -- rejected; not save-persistent. Two sells in tick T would re-seed identically after a save/load between them.
- **Implicit seed from sell-quantity-so-far (computed from `cap_original - cap_current`)** -- rejected; couples seed to a state field that's mutated by conservation itself, fragile.

## Confidence
High. Architect's resolution; Engineer implemented faithfully; Reviewer confirmed the counter increments after hashing, persists in `to_dict`/`from_dict`.

## Source
Architect handoff `docs/slice-8-2-architect-handoff.md` Call 1 (2026-05-05).

## Related
- [[2026-05-04-slice-8-pricing-math-static-rng-cache]] -- precedent for deterministic RNG seeding via tuple hash
- [[2026-05-04-slice-8-perturbation-seed-mix-supersedes-hash-array]] -- related seed-shape decision for pricing
- [[2026-05-05-slice-8-2-drain-conservation-composed]] -- the mechanism this RNG drives
- [[2026-05-05-slice-8-2-schema-v8-strict-reject]] -- the schema bump this field is part of
