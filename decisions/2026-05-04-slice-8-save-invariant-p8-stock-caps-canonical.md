---
title: Save invariants P8/P9/P10 keyed off stock_caps and demand_caps as canonical sets
date: 2026-05-04
status: ratified
tags: [decision, slice-8, save-invariants, schema-v6, parity-check]
---

# Save invariants P8/P9/P10 keyed off stock_caps and demand_caps as canonical sets

## Decision
The slice-8 save invariants in `SaveInvariantChecker` are shaped as follows:

- **P8 (reframed from slice-7):** supply-quad parity, with `node.stock_caps.keys()` as the canonical key set. Every node's `stocks`, `refill_rates`, and `refill_accumulators` dicts must have exactly the same keys as `stock_caps`.
- **P9 (new):** demand bounds. Mirror of P7's stock-bounds check: `0 <= demand_pools[good_id] <= demand_caps[good_id]` for every (node, good).
- **P10 (new):** demand-quad parity + cross-quad parity. `demand_caps.keys()` is the canonical key set for the demand quad; `demand_pools`, `demand_decay_rates`, `demand_decay_accumulators` must match. Additionally, supply keys (`stock_caps.keys()`) and demand keys (`demand_caps.keys()`) must be equal -- a node cannot have a good in one quad without the other.
- **Empty-canonical rail:** if the canonical key set (`stock_caps` for P8, `demand_caps` for P10) is empty, the check returns an explicit error string naming the node id and which quad failed, rather than vacuously passing.

## Reasoning
Slice-7's P8 anchored on `node.prices.keys()`. Slice-8 drops the `prices` field entirely (per `2026-05-04-slice-8-prices-field-dropped-pull-driven`), so P8 cannot reference it.

The four parallel dicts on each side (`stocks` / `stock_caps` / `refill_rates` / `refill_accumulators` and the symmetric demand quad) must stay in lockstep -- a missing key in any of them causes runtime divergence. Picking the `_caps` dict as canonical mirrors slice-7's pattern (slice-7 already anchored other parity checks on `stock_caps`); using the same canonical key choice across schema generations keeps the invariant semantics legible.

Cross-quad parity is the slice-8-specific addition: the symmetric design requires every authored good to appear on both sides of every node. A node with wool in `stock_caps` but no wool in `demand_caps` is a structural corruption -- the migration helper or `world_gen` must have skipped a side. P10 catches this.

The empty-canonical rail was added in the second engineer pass after the Reviewer flagged that `is_empty()` canonicals would loop zero times and silently pass. A node with no goods authored at all is itself a corruption case worth catching.

## Alternatives considered
- **Anchor P8 on `node.stocks.keys()` instead of `stock_caps.keys()`.** Equivalent under the parity invariant, but slice-7 already chose `stock_caps` as the canonical and slice-8 mirrors that. Asymmetric canonicals across slices would make the invariant code harder to read.
- **Single combined parity check across all eight dicts at once.** Rejected: the supply quad and demand quad are independent state machines (different mutators -- StockSystem and DemandSystem); separating P8 (supply) from P10 (demand) localises any failure to one side. The cross-quad check is the third thing P10 does; it's not folded into P8.
- **Skip the empty-canonical rail; trust upstream code never produces empty quads.** Rejected by the Reviewer in the second pass -- defensive rails on save invariants are cheap and the failure mode (silent pass on a corrupt save) is exactly the class of regression the invariant suite exists to prevent.

## Confidence
High. Engineer's choice of canonical keys mirrors a pre-existing pattern (slice-7); Reviewer accepted with one fixup (empty-canonical) which the Engineer addressed in the same session; cross-quad parity is structurally necessary for the symmetric pool design.

## Source
Engineer implementation pass; Reviewer's verdict identifying the empty-canonical edge case; Engineer's second pass adding the rail. Spec §8 / §9 named P9 and P10 generically without locking the canonical-key choice -- this decision locks it.

## Related
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the prerequisite that forced P8 to be reframed
- [[2026-05-04-slice-8-nodestate-demand-dicts-shape]] -- the four demand dicts that P9/P10 check
- [[2026-05-04-slice-8-pricemodel-reshaped-stateless-query]] -- the read-side companion to the save-side invariant work
