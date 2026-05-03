---
title: Stock reads route through WorldState.stock_for and decrement_stock helpers
date: 2026-05-03
status: ratified
tags: [decision, slice-7, architecture, encapsulation]
---

# Stock reads route through WorldState.stock_for and decrement_stock helpers

## Decision
All callers that read or mutate stock state route through two new accessors on `WorldState`:

- `func stock_for(node_id: String, good_id: String) -> int`
- `func decrement_stock(node_id: String, good_id: String) -> void`

Both mirror the existing `get_node_by_id` shape: linear walk, defensive on missing IDs (`stock_for` returns 0; `decrement_stock` is a no-op). Direct dict access is reserved for the two writers that own the field shape: `StockSystem._on_tick_advanced` (refill loop) and `WorldGen._author_stock` (gen-time authoring).

## Reasoning
Stock is read from at least four call sites: `Trade.try_buy` (verb), `NodePanel._update_row` (UI), the production-caps harness (measurement), and B1 invariant checkers (P7/P8). Routing all reads through one seam means the per-node dict layout can change (e.g., to a `NodeStock` sub-resource, to top-level `WorldState` dicts) without touching call sites. Mirrors the precedent from `2026-04-30-world-state-get-node-by-id-helper`.

`StockSystem` does not get accessors -- the refill loop is the one place where reaching into the dicts directly is justified, because it mutates four parallel dicts in lockstep per (node, good) pair, and going through a per-field accessor would either (a) require eight method calls per (node, good) per tick or (b) require a new combined accessor that exists only for `StockSystem`'s convenience.

## Alternatives considered
- **Expose `NodeState.stocks` directly; let callers index into it** -- rejected per the encapsulation argument above.
- **Combined accessor that returns a NodeStock-shaped record** -- premature abstraction for one slice; reconsider if a future slice needs to read multiple stock fields per call.
- **Cache stock-by-id at `WorldState` boot** -- rejected: N=7 nodes, no measurable cost on linear walk.

## Confidence
High. Architect call ratified the pattern explicitly; precedent from `get_node_by_id` is established.

## Source
Architect handoff §6 (accessor seams).

## Related
- [[2026-04-30-world-state-get-node-by-id-helper]] -- the precedent this mirrors
