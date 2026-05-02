---
title: Bandit-road tag generation = pure random per edge (no correlation)
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, encounters, world-gen]
---

# Bandit-road tag generation = pure random per edge (no correlation)

## Decision
Bandit-road tagging is a one-pass per-edge random draw at world-gen, with `BANDIT_ROAD_FRACTION = 0.35`. Tag does **not** correlate with edge length, edge endpoints, distance from start, or graph position. Sub-seed `hash([effective_seed, "encounters"])` (sibling to `"bias"`/`"place"`/`"names"`).

## Reasoning
Any per-edge correlation would force the player to read multiple variables to predict risk (e.g., "long edges are bandit-prone, except near cities..."). Pure random keeps the model "the tag IS the risk" — one observable, one decision input. The Designer specifically wanted a model where bias is not a function the player has to learn, but a property they can read directly.

## Alternatives considered
- **Length-correlated** (longer edges = higher bandit fraction) — rejected; adds a hidden function the player must reverse-engineer.
- **Position-correlated** (edges far from start = higher bandit fraction) — rejected; same issue plus introduces an "explore vs stay safe" axis the slice doesn't earn.

## Confidence
High. Designer call; Architect ratified the one-pass implementation in `world_gen.gd` (cheaper than slice-3's bias predicate — no satisfiability retry).

## Source
Designer spec §5.1.

## Related
- [[2026-05-02-slice-4-flat-per-edge-probability]] — the matching choice on probability uniformity
- [[2026-05-02-slice-3-bias-multiplicative-anchor]] — slice-3's analogous "one input, one decision" model
