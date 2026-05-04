---
title: DemandSystem placed as separate Node sibling to StockSystem
date: 2026-05-04
status: ratified
tags: [decision, slice-8, structure, demand-system, scene-tree]
---

# DemandSystem placed as separate Node sibling to StockSystem

## Decision
`DemandSystem` is implemented as a separate Node placed under `Main`, symmetric to `StockSystem`. Both subscribe to `Game.tick_advanced` and mutate parallel pool dicts. StockSystem mutates `stocks` and `refill_accumulators`; DemandSystem mutates `demand_pools` and `demand_decay_accumulators`. Listener ordering on `tick_advanced` is irrelevant because the mutation key sets are disjoint.

## Reasoning
Symmetry with StockSystem makes the structure read at a glance. The disjoint-mutation contract is preserved trivially: the two systems touch orthogonal dict keys, so a listener-order race is structurally impossible. Performance cost of two iterations per tick is approximately 56 dict lookups (7 nodes x 4 goods x 2 systems) on travel-only ticks, well below noise.

DemandSystem lives at `godot/systems/demand/demand_system.gd`, mirroring `godot/systems/stock/stock_system.gd`. The folder placement signals the parallel.

DemandSystem's body is a near-byte-for-byte copy of StockSystem with `stock*` -> `demand_*` and `refill_*` -> `demand_decay_*`. The duplication is honest about the symmetry and is below the threshold where a shared helper earns its keep.

## Alternatives considered
- **Fold supply refill + demand decay into one `PoolSystem`** -- rejected: would reduce evolvability. The slice-7 precedent is split systems (StockSystem split from PriceModel even when both were tick-listeners); same logic applies here. A combined system would be a premature abstraction over two genuinely orthogonal mechanics that happen to share a tick boundary.

## Confidence
High. Designer leaned split; Architect S2 explicitly ratified with reasoning and perf estimate.

## Source
Designer (spec §4 table, §9 row) + Architect S2 ratification (2026-05-04 session).

## Related
- [[2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation]] -- the disjoint-mutation contract this extends (now applies between StockSystem and DemandSystem after PriceModel drops out)
- [[2026-04-29-one-autoload-only-game]] -- DemandSystem lives under `Main`, not as a new autoload
