---
title: Bias retires from price formula; kept as tag-derivation seed
date: 2026-05-04
status: ratified
tags: [decision, slice-8, bias, pricing, supersession, amendment]
---

# Bias retires from price formula; kept as tag-derivation seed

## Decision
The `node.bias` field remains on `NodeState` and continues to seed `produces` / `consumes` tag derivation at world-gen time. However, `node.bias[good_id]` is no longer read by any pricing code under slice-8. The slice-3 `_drift_node_prices` function and `MEAN_REVERT_RATE` constant are removed.

This **amends** `2026-05-02-slice-3-bias-multiplicative-anchor` (bias is no longer a price-formula input; bias remains as tag-derivation seed) and **supersedes** `2026-05-02-slice-3-mean-reversion-added` (mean-reversion has no role under pull-driven prices).

## Reasoning
Slice-8 replaces random-walk pricing with a two-sided pool curve. Under pools, price is determined by current pool fill, not by structural anchor. Layering a multiplicative bias on top of `base_price` would add a third anchoring input and lose the symmetry of the `(target - current) / target` formula.

The slice-3 contract of "bias as the tag's load-bearing input" is preserved; only the downstream consumption changes. The pool-based free-lunch predicate (replacing `_solve_bias_range`) still reads tags, which still derive from bias. Removing bias entirely would force re-derivation from scratch and lose three slices of vocabulary.

Bias is **not** a deprecation target. Its role narrowed (price formula -> tag-derivation only), not its existence. Future slices that want to retire bias entirely can do so by routing tag derivation through a different seed; that is a future-slice decision, not a slice-8 cleanup.

## Alternatives considered
- **Drop bias entirely from the schema** -- rejected: cost is real engineering and design-history churn (re-derive `_author_bias`, the free-lunch predicate, the produces/consumes thresholding logic, three slices of vocabulary); benefit is aesthetic schema cleanliness.

## Confidence
High. Director Q3 explicitly ratified with detailed reasoning.

## Source
Director Q3 ratification (2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` §5.3, §11.1.

## Related
- [[2026-05-02-slice-3-bias-multiplicative-anchor]] -- amended by this decision
- [[2026-05-02-slice-3-mean-reversion-added]] -- superseded by this decision
- [[2026-05-02-slice-3-tags-as-label-not-driver]] -- the slice-3 contract this decision preserves
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the pricing formula that displaces bias
