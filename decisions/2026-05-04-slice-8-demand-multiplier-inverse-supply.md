---
title: Demand-pool multiplier table inverts supply table by node tag
date: 2026-05-04
status: ratified
tags: [decision, slice-8, demand-pool, tuning, multipliers]
---

# Demand-pool multiplier table inverts supply table by node tag

## Decision
New `WorldRules` constants for demand-side authoring, structured as the inverse of supply-side multipliers by node tag:

```
DEMAND_CAP_MULT_PRODUCER: float = 0.25
DEMAND_CAP_MULT_NEUTRAL:  float = 1.0
DEMAND_CAP_MULT_CONSUMER: float = 4.0

DEMAND_DECAY_MULT_PRODUCER: float = 0.2
DEMAND_DECAY_MULT_NEUTRAL:  float = 1.0
DEMAND_DECAY_MULT_CONSUMER: float = 5.0
```

Per-(node, good) demand cap and decay rate are derived at world-gen as `Good.base_demand_cap * tag_mult` and `Good.base_demand_decay_rate * tag_mult`, with the multiplier selected by per-node tag (`good in produces` -> producer, `good in consumes` -> consumer, neither -> neutral).

Combined with the supply-side multipliers, each node has a **four-way decision matrix per good**:

- **Producer node** (tagged via `produces`): supply x20 (deep buyable pool) / demand x0.25 (shallow sellable pool). Buy-cheap, sell-expensive-but-trickle.
- **Consumer node** (tagged via `consumes`): supply x0.25 (shallow buyable) / demand x4.0 (deep sellable). Buy-expensive-but-some, sell-cheap-and-deep.
- **Neutral node**: supply x5.0 / demand x1.0. Both moderate.

Decay rates symmetric: producer refills supply fast (x5.0) and recovers demand slowly (x0.2); consumer refills supply slowly (x0.2) and recovers demand fast (x5.0).

## Reasoning
This structure is the slice's load-bearing information density. Player walks into a producer, sees `wool 8g (plentiful) [80 left]` for buy and `wool 22g (scarce) [1 left]` for sell -- the buy/sell prices and pool fills together communicate "this town is a wool source." Walks into a consumer, the labels flip -- "this town wants wool."

The (plentiful) / (scarce) tag on each side drives a coherent four-way decision: buy here, don't buy here, sell here, don't sell here. Without inverse multipliers, every node would be ambiguous about whether it is a source or sink for any given good; the legibility pillar would fail by construction.

Decay rates inverting (producer recovers demand slowly; consumer recovers demand fast) means the world remembers trader actions in a directionally-correct way: dumping wool on a non-consumer briefly satisfies their thin demand and decays slowly back; the player learns "consumer towns are forgiving sellers; producer towns are not."

## Alternatives considered
- **Symmetric multipliers (no inverse structure)** -- rejected: every node would have the same demand pool target; "this town wants wool more than that town" would not be encoded; gradient would collapse.
- **Per-good asymmetric multipliers (e.g., salt has different inverse than wool)** -- deferred to slice-8.x; current scope authors uniformly across goods to keep the slice's surface area bounded.

## Confidence
High. Designer specced this as the slice's core information-density requirement; Director silently accepted (no override).

## Source
Designer (spec §5.7, 2026-05-04 session).

## Related
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar whose legibility property this matrix implements
- [[2026-05-04-slice-8-5x-supply-cap-bump-rationale]] -- the 5x bump on supply side; demand side is untouched (already at 1.0 conceptually)
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the curve formula consuming these multipliers
