---
title: Demand fields on NodeState as four parallel dicts (mirrors supply shape)
date: 2026-05-04
status: ratified
tags: [decision, slice-8, structure, save-format, nodestate]
---

# Demand fields on NodeState as four parallel dicts (mirrors supply shape)

## Decision
`NodeState` gains four new parallel dicts for demand: `demand_pools`, `demand_caps`, `demand_decay_rates`, `demand_decay_accumulators`. This mirrors the slice-7 supply shape exactly: `stocks`, `stock_caps`, `refill_rates`, `refill_accumulators`. Field-order intent: identity -> bias/tags -> supply pool (4 dicts) -> demand pool (4 dicts). The `prices` dict is removed; the `has_affordable_good` method is removed.

## Reasoning
Three structural reasons for parallel dicts over a per-good `MarketEntry` Resource:

1. **Save format precedent.** Slice-7's supply state already ships as four parallel dicts on disk. A `MarketEntry`-per-good shape would break wire compatibility with slice-7's stock dicts unless they are migrated too. Wholesale-rewrite of the slice-7 shape, in slice-8, for symmetry, is scope creep.

2. **Godot Resource serialization cost.** The save path is JSON via `to_dict`/`from_dict`. A `MarketEntry` would need its own `to_dict`/`from_dict`, and the wire format would gain a layer of nesting (`{"wool": {"supply": ..., "demand": ...}}` instead of two flat dicts). No determinism or correctness gain; pure friction.

3. **Honest about shape.** A per-(node, good) record-as-Resource would imply that supply and demand are coupled per good, but they are not -- supply refill and demand decay are orthogonal mechanics that happen to be authored at the same gen-time stage. Two parallel dict-quads honestly say "two orthogonal four-knob systems"; a `MarketEntry` Resource hides that.

If a future slice introduces per-(node, good) state that genuinely couples supply and demand (e.g., spoilage on a per-stack basis with stack age), that is the right time to introduce a `MarketEntry`-shaped Resource -- and the slice that introduces it will already be paying the migration cost.

## Alternatives considered
- **Per-good `MarketEntry` Resource** -- rejected for the three reasons above.

## Confidence
High. Designer leaned this; Architect S4 explicitly ratified with reasoning.

## Source
Designer (spec §3.1, §3.4 rationale) + Architect S4 ratification (2026-05-04 session).

## Related
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- the slice-7 four-dict supply shape this mirrors
- [[2026-05-04-slice-8-demand-rates-frozen-at-gen-time]] -- the freezing-at-gen-time decision that applies to two of the four new dicts
