---
title: Encounter resolver materializes origin-node prices via PricingMath at call site
date: 2026-05-04
status: ratified
tags: [decision, slice-8, encounter-resolver, pull-driven, signature-stability]
---

# Encounter resolver materializes origin-node prices via PricingMath at call site

## Decision
The encounter resolver's "most valuable carried good" target selection consumes a `Dictionary[String, int]` of origin-node buy prices. With the `prices` field removed from `NodeState` in slice-8, this dict is now materialised at the call site (`travel_controller.gd::_origin_prices_for_leg`) by iterating the player's inventory and calling `PricingMath.buy_price_for(world, origin_node, good_id)` for each carried good.

The encounter resolver's `Dictionary[String, int]` parameter signature is unchanged. The materialisation only spans inventory keys (the only keys the resolver reads), not the full goods catalogue.

## Reasoning
Slice-3's encounter resolver picked the bandit's target good by reading `node.prices[good_id]` for each good in the player's cargo and selecting the highest. The `prices` field is gone in slice-8 (per `2026-05-04-slice-8-prices-field-dropped-pull-driven`).

Two structural options: (a) change the resolver's signature to take `(world, node)` and have it call PricingMath internally, or (b) keep the signature and materialise the dict at the call site. The Engineer chose (b) to preserve the resolver's existing API surface and limit the blast radius of the slice-8 change.

Determinism is preserved. `PricingMath.buy_price_for` is a pure function of `(world.world_seed, world.tick, node.id, good_id, pool_state)` -- same inputs at the same point in tick produce the same output. The encounter resolver's RNG-determinism contract (`same (world_seed, tick, lo_id, hi_id) -> same RNG draws`) holds because the resolver still seeds its RNG from the same state.

Note: under slice-8, prices collapse to `floor_price` or `ceiling_price` more often than they did under slice-3's drift, so ties in the "most valuable" selection will be more common. Tie-breaking is lex-min `good_id` (deterministic). This is filed as a slice-8.x play-feel concern in the Reviewer's open questions.

## Alternatives considered
- **Change resolver signature to `(world, node, ...)`.** Rejected for blast-radius reasons -- the resolver has multiple call sites and tests.
- **Re-introduce a `prices` cache on `NodeState`.** Rejected as relitigation of `2026-05-04-slice-8-prices-field-dropped-pull-driven`.
- **Materialise the full goods catalogue, not just inventory.** Rejected as wasted work -- the resolver only reads inventory keys.

## Confidence
Medium. The change is mechanically simple and determinism-preserving, but it crosses the line between "local refactor" and "decision-shape" -- worth recording so future encounter-system changes know the intent (signature stability + pull-driven materialisation), not just "pricing got pulled at the call site by accident."

## Source
Engineer's slice-8 implementation; Engineer flagged this as a judgment call ("arguably decision-shape, arguably local refactoring -- your call"); user ratified during closeout.

## Related
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the prerequisite that forced this materialisation
- [[2026-05-04-slice-8-pricemodel-reshaped-stateless-query]] -- the helper now called at this site
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula whose floor/ceiling clamps make ties more common, deferred as slice-8.x play-feel concern
