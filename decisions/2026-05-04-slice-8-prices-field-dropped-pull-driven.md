---
title: Prices field dropped from v6 save schema; pull-driven computation
date: 2026-05-04
status: ratified
tags: [decision, slice-8, save-format, pricing, schema]
---

# Prices field dropped from v6 save schema; pull-driven computation

## Decision
The `NodeState.prices` dict is dropped entirely from slice-8's v6 save schema. Prices are computed on every read (pull-driven) as pure functions of pool state, perturbation seed, and good base attributes. PriceModel's `_drift_node_prices` and tick subscription are removed; no per-tick price mutation.

## Reasoning
Pool state is already authoritative for pricing under the new curve. Storing prices alongside is redundant state and creates a save-vs-derived drift class the system does not otherwise have: the price could be stored, then the formula tuned in code, and a save would load with stale prices that diverge from the formula's current output.

Determinism replay (gate 3) ensures perturbation seed is stable across save/load; pull-driven prices have no stored-but-derivable field that can drift.

NodePanel access pattern changes: every render reads via `PricingMath.buy_price_for(world, node, good_id)` / `PricingMath.sell_price_for(...)` rather than `node.prices[good_id]`. B1 invariant predicates that referenced `node.prices` are rewritten: P5 drops its prices clause (the `clampi(..., floor_price, ceiling_price)` in PricingMath structurally guarantees non-negativity); P8 uses the supply key set as the canonical reference instead of prices.

This decision **partially supersedes** `2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation`: PriceModel no longer mutates state, so it drops out of the disjoint-mutation contract. The contract now applies between StockSystem and DemandSystem on disjoint pool dicts.

## Alternatives considered
- **Keep prices as per-tick cache** -- rejected: mirrors slice-7's stocks pattern but buys nothing here. Pool state is already in the save; prices are a deterministic function of it. Caching introduces an invalidation bug the system does not currently have.

## Confidence
High. Designer leaned drop entirely (spec §3.3); Architect S1 ratified with concurring reasoning.

## Source
Designer (spec §3.3) + Architect S1 ratification (2026-05-04 session).

## Related
- [[2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation]] -- partially superseded by this decision (PriceModel drops out of contract)
- [[2026-04-29-deterministic-price-drift]] -- the determinism contract this strengthens
- [[2026-05-04-slice-8-pricemodel-reshaped-stateless-query]] -- the structural decision that reshapes PriceModel into a stateless query helper
