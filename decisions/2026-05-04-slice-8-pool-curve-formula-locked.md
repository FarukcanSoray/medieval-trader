---
title: Two-sided pool curve formula with +/-5% perturbation locked
date: 2026-05-04
status: ratified
tags: [decision, slice-8, pricing-formula, pool-curve, determinism]
---

# Two-sided pool curve formula with +/-5% perturbation locked

## Decision
Price formula under slice-8 (computed pull-driven on read, not stored):

```
price = clamp(
    base_price * (1 + (target - current) / target) * (1 + perturbation),
    floor_price,
    ceiling_price
)
```

applied separately per side:

- **Buy side:** `target = stock_caps[good_id]`, `current = stocks[good_id]`. Empty supply pool -> `(target - 0) / target = 1` -> 2x base price (clamped at ceiling). Full pool -> base price.
- **Sell side:** `target = demand_caps[good_id]`, `current = demand_pools[good_id]`. Full demand pool (full unmet demand) -> 2x base price. Empty pool -> base price (clamped at floor).

Perturbation is +/-5% (`PERTURBATION_FRACTION = 0.05` on `WorldRules`), seeded deterministically as `hash([world_seed, tick, node_id, good_id, side])` where `side` is `"buy"` or `"sell"`.

## Reasoning
The user locked the two-sided pool shape early in the session: "I stand with the two-sided pools. since this is a economy based game, then it should be good." Designer specced the formula symmetric across sides; Architect ratified the structural shape.

The clamp to `floor_price` / `ceiling_price` matches the per-good identity bounds that have been on `Good` since slice-1; the curve never leaks below floor or above ceiling regardless of pool extreme.

Perturbation seed includes `tick` (perturbation re-rolls each travel tick, consistent with slice-3's per-tick drift cadence) and `side` namespace (buy/sell perturbations are decorrelated). It does not include pool fill, because making the perturbation depend on pool fill would create discontinuous re-rolls that defeat the legibility of "perturbation is the world breathing on top of a stable curve."

Perturbation magnitude (5%) is small enough that individual buys (each moving the curve by ~5% under slice-8's volume bump) sit within the perturbation envelope -- so per-click price jiggle is indistinguishable from world breathing, and only cumulative pressure visibly moves the curve. See `2026-05-04-slice-8-5x-supply-cap-bump-rationale` for the load-bearing reason this magnitude was chosen.

## Alternatives considered
- **Asymmetric per-side formulas** -- rejected: symmetry preserves the legibility property; player learns one curve shape, not two.
- **Perturbation seeded without tick (constant per save)** -- rejected: would freeze prices between travel ticks; curve would feel stuck.
- **Larger perturbation (10%, 15%)** -- rejected: above ~10%, perturbation hides the curve's signal; legibility fails. Director Q2 ratification noted "above that and we're back to RNG hiding the signal."

## Confidence
High. User locked early; Designer specced thoroughly (spec §5.1-§5.4); Director ratified perturbation envelope via Q2.

## Source
User (early conversation) + Designer (spec §5.1-§5.4) + Director (Q2 perturbation envelope, 2026-05-04 session).

## Related
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the pull-driven decision that makes this formula a stateless function rather than stored state
- [[2026-05-04-slice-8-5x-supply-cap-bump-rationale]] -- the volume bump that calibrates perturbation magnitude against per-buy price impact
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this formula implements (prices as the player's window into pool memory)
- [[2026-05-04-slice-8-demand-multiplier-inverse-supply]] -- the multiplier table that drives target sizes per node tag
