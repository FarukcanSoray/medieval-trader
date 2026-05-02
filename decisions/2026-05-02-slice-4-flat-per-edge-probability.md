---
title: Per-edge encounter probability is flat across all bandit-tagged edges
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, encounters, balance]
---

# Per-edge encounter probability is flat across all bandit-tagged edges

## Decision
All bandit-tagged edges share the same per-leg encounter probability: `BANDIT_ROAD_PROBABILITY = 0.30`. Probability does not vary by edge length, position, or any other factor.

## Reasoning
Variable per-edge probability would force the player to read a percentage on every edge before deciding (the cost preview would have to show a different `~N%` per route). Flat probability means **one number to learn, one math model**. Once the player internalises "30%", the route decision collapses to "is the spread worth `0.30 * expected_loss` of expected cost on top of base?"

This pairs with [[2026-05-02-slice-4-bandit-tag-pure-random]]: the binary tag tells you risk is present; the constant probability tells you how often. Two facts, fully composable.

## Alternatives considered
- **Probability scales with edge length** — rejected; multiplies cognitive load.
- **Probability scales with carried wealth** — rejected; would convert the system into a punishment-scaling roguelite mechanic, against the careful-merchant fantasy.

## Confidence
High. Designer call.

## Source
Designer spec §5.2.

## Related
- [[2026-05-02-slice-4-bandit-tag-pure-random]] — the matching choice on tag uniformity
