---
title: Drift formula gains mean-reversion (MEAN_REVERT_RATE = 0.10)
date: 2026-05-02
status: ratified
tags: [decision, slice-3, pricing-model, kernel]
---

# Drift formula gains mean-reversion (MEAN_REVERT_RATE = 0.10)

## Decision
The per-tick drift formula adds a mean-reversion term: `mean_revert = roundi((anchor - old_price) * MEAN_REVERT_RATE)`. Default rate is `0.10`, defined in `WorldRules.MEAN_REVERT_RATE`.

## Reasoning
Without mean-reversion, a sequence of same-sign volatility samples can walk a node's price all the way to the floor or ceiling and pin it there. The structural identity of the slice (regional bias the player can read) disappears -- the price reads as having no source/sink character because it's stuck at a clamp. Mean-reversion pulls the price back toward the biased anchor over a few ticks. Designer called this "the structural fix the slice's whole point depends on."

## Alternatives considered
None named -- presented as mandatory for the slice's integrity.

## Confidence
High. Designer rooted it in slice identity (without it, bias has no observable effect over time).

## Source
Designer spec §5.4.

## Related
- [[2026-05-02-slice-3-bias-multiplicative-anchor]]
- [[2026-05-02-slice-3-bias-constants-in-world-rules]]
- [[2026-04-29-deterministic-price-drift]] -- the seed contract this decision preserves
