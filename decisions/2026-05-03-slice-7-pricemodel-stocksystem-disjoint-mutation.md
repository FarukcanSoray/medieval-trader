---
title: PriceModel and StockSystem mutate disjoint NodeState fields; tick listener ordering unspecified by design
date: 2026-05-03
status: ratified
tags: [decision, slice-7, architecture, coupling]
---

# PriceModel and StockSystem mutate disjoint NodeState fields; tick listener ordering unspecified by design

## Decision
`PriceModel` and `StockSystem` both listen to `Game.tick_advanced` and mutate `NodeState` fields that do not overlap (`prices`/`bias` vs. `stocks`/`refill_accumulators`). The order in which they fire is **unspecified and not enforced**. The contract is *disjoint mutation*, not *ordered mutation*. `SaveService` is a reader on the same signal, not a participant.

## Reasoning
Enforcing an explicit order would couple the two listeners and raise the cost of adding a third listener (e.g., a future faction-rep system, taxes, depleted ore veins). Disjoint mutations let each listener evolve independently. The current single-threaded coroutine model prevents interleaving; if a future listener reads `node.stocks` mid-tick (e.g., an analytics bus, a per-tick HUD bind), the ordering question becomes load-bearing and surfaces *then*, not now.

Refill happens before or after price-drift -- both equivalent under the disjoint-mutation contract. Encounters mutate `trader.gold` and `trader.inventory`, never `node.*`, so they cannot race the refill. The tick's mutation graph is a forest, not a chain.

## Alternatives considered
- **Enforce explicit ordering** (e.g., PriceModel first, StockSystem second) -- rejected: couples listeners for no current benefit.
- **Single combined "WorldTick" system** that runs both pricing and stock logic -- rejected: would require restructuring `PriceModel`, doubling the test surface for slice-7's bug class.
- **Enforce ordering only at the connect-time level** (deterministic via signal connection order in `main.tscn`) -- rejected: silently fragile, since reorderings of `main.tscn` would break invisibly.

## Confidence
Medium. Architectural acceptance, not a debated alternative. Worth re-surfacing if a future listener reads stock state mid-tick.

## Source
Architect handoff §3 (tick ordering decision); ratified by acceptance.

## Related
- [[2026-04-29-signal-based-integration]] -- prior project-level decision on signal-driven inter-system communication
- [[2026-04-29-tick-on-player-travel]] -- the tick source this contract sits on top of
