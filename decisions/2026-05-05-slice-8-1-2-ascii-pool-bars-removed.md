---
title: ASCII pool bars removed from node panel display
date: 2026-05-05
status: ratified
slice: 8.1.2
tags: [decision, slice-8.1.2, ui-simplification, pillar-alignment]
---

# ASCII pool bars removed from node panel display

## Decision
Remove the `[#####]<#####>` ASCII supply/demand pool bars from the node panel row. Display row simplified to:

`Wool   B 12g  S 25g (plentiful)  [20 left]   x0`

Removed from `godot/ui/hud/node_panel.gd`:
- `BAR_WIDTH` const
- `_ascii_bar` helper
- `demand_pool`, `demand_cap`, `stock_cap` locals in `_update_row` (used only for bar rendering)
- bar slots in the price-label format string

Retained:
- `[N left]` integer (hard buy-side stockout limit)
- Tags `(plentiful)` / `(scarce)` (reflect node structural role from `node.produces` / `node.consumes`)

## Reasoning
The bars were redundant. The slice-8 pricing formula explicitly encodes pool state in price (`buy = base * (1 + (cap - stock)/cap)`, `sell = base * (1 + demand_pool/demand_cap)`), so the buy and sell prices already convey pool fullness. Showing pool numbers separately is "showing through the window AND through the wall" -- a direct contradiction of the `2026-05-04-slice-8-economy-primary-texture-pillar` ("prices are the player's window into pool memory").

`[N left]` was retained because stock count is a hard buy-side limit -- you cannot buy what isn't there -- and price alone doesn't convey that constraint. Tags were retained because `produces` / `consumes` are structural node roles that don't reduce to current pool state.

## Alternatives considered
- **Replace bars with stock/demand numerals (e.g. `stock 20/20  demand 18/20`)** -- considered briefly, rejected: still violates the pillar by exposing pool state separately from price. The user surfaced the redundancy explicitly.
- **Keep the bars** -- rejected: redundant with both `[N left]` and prices.

## Confidence
High. User identified the redundancy directly via the pillar; reasoning was clear and self-consistent; no dangling references after removal.

## Source
User observation on 2026-05-05 ("these # symbols are nonsense, ... we have the number there already"); follow-up clarification that prices already encode pool state.

## Related
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this realigns with
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula that encodes pool state in price, making the bars redundant
