---
title: Saturation sell gate removed from try_sell and UI
date: 2026-05-05
status: ratified
slice: 8.1.1
tags: [decision, slice-8.1.1, gating, softlock-fix, pillar-alignment]
---

# Saturation sell gate removed from try_sell and UI

## Decision
Remove the slice-8 demand-pool sell gate. Specifically:

- In `godot/travel/trade.gd::try_sell`, delete `if _world.demand_for(node.id, good_id) <= 0: return false`.
- In `godot/ui/hud/node_panel.gd`, delete the `market_open` predicate, the `_sell_tooltip` helper, and the "local market saturated" string.
- Sell button now disabled solely on `not has_owned`; tooltip empty.

Remaining gates in `try_sell` (in-inventory check, `price > 0` defensive fallback) are identity / defensive checks, not economic rules. They stay. Director's one-liner sign-off was the only design step; no full Designer/Architect pass.

## Reasoning
The `2026-05-04-slice-8-economy-primary-texture-pillar` says "prices are the player's window into pool memory." A hard "you cannot sell" gate speaks in rule, not number, and contradicts the pillar by preempting the price signal with a UI block.

Concrete trigger: user hit a real softlock with goods, 0 gold, and every reachable market saturated. `DeathService::_check_stranded` (lines 38-40) short-circuits when the trader holds inventory under the assumption "holding goods means a sell is still productive." That assumption was false under the slice-8 gate -- death never triggered and the player could not act at all.

Math safety check (verified before removal):
- `PricingMath.sell_price_for` at `demand_pool=0` returns `~base` (curve `base * (1 + 0/cap)`, then clamp to `[floor_price, ceiling_price]`). Never 0.
- `world_state::decrement_demand` is defensive at `pool <= 0`, no underflow.
- Same-node arbitrage analysis: profit gap exists when `stock + demand > cap`. At a saturated node demand=0, so the gap vanishes regardless of stock. No new exploit introduced.
- `DeathService`'s "holding goods means productive" assumption becomes structurally correct again: `try_sell` no longer refuses on saturation.

## Alternatives considered
- **Keep the gate, fix `DeathService` to detect saturated-stranded** -- rejected: still contradicts the pillar; treats the gate as load-bearing when it isn't.
- **Reshape the sell curve so saturated price falls below floor_price** -- deferred to slice-8.2 (Designer territory; touches the locked formula).

## Confidence
High. Director one-liner sign-off; math safety verified explicitly; Reviewer confirmed no dangling references and `DeathService` structural correctness post-removal.

## Source
User-reported softlock, Director sign-off, Engineer implementation, Reviewer pass on 2026-05-05.

## Related
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar driving the removal
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula whose price signal now does the regulating alone
- [[2026-04-29-stranded-includes-empty-inventory]] -- the `DeathService` invariant that becomes correct again
