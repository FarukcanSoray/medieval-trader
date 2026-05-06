---
title: decrement_demand_cap_permanent is a separate WorldState mutator
date: 2026-05-05
status: ratified
slice: 8.2
tags: [decision, slice-8.2, architecture, world-state]
---

# decrement_demand_cap_permanent is a separate WorldState mutator

## Decision
Permanent demand-cap erosion (the conservation effect) is a separate `WorldState` mutator: `decrement_demand_cap_permanent(node_id: String, good_id: String, amount: int) -> void`. It is NOT folded into the existing `decrement_demand` call.

`Trade.try_sell` calls both in sequence on a successful sell:
1. `decrement_demand` -- per-tick consumption (existing).
2. `decrement_demand_cap_permanent` (probabilistic, gated by `CONSERVATION_FRACTION` roll).

## Reasoning
Per-tick consumption and permanent structural erosion are **semantically different operations** that happen to share a (node, good) addressing scheme. Architect ruled they should remain distinct verbs in the WorldState API:

- **Call sites stay honest** about which operation they're triggering. A future caller wanting only consumption (no erosion) doesn't have to thread an `also_erode: bool` flag.
- **Headless tools can exercise each in isolation.** The trader-free measurement tool exercises drain+decay against `demand_pools` without touching `demand_caps`; a future tool could measure erosion-only effects without simulating consumption.
- **Diff legibility**: a future change to either operation lives in one named function, not behind a branch in a multi-purpose mutator.

## Alternatives considered
- **Fold conservation into `decrement_demand` (extend with optional erosion param)** -- rejected; obscures the two semantic operations and couples tool behavior. Designer's spec explicitly leaned toward separation; Architect ratified.

## Confidence
High. Architect's resolution; Engineer implemented as specified; no Reviewer pushback.

## Source
Architect handoff `docs/slice-8-2-architect-handoff.md` Call 2 (2026-05-05).

## Related
- [[2026-05-05-slice-8-2-drain-conservation-composed]] -- the mechanism that calls this mutator
- [[2026-05-05-slice-8-2-conservation-rng-per-node-counter]] -- the RNG that gates the call
