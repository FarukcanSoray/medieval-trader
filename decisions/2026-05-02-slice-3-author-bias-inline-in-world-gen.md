---
title: `_author_bias` lives inline on `world_gen.gd`, not in a separate file
date: 2026-05-02
status: ratified
tags: [decision, slice-3, architecture, file-placement]
---

# `_author_bias` lives inline on `world_gen.gd`, not in a separate file

## Decision
The `_author_bias` static method (along with `_solve_bias_range` and `_shortest_edge_distance` helpers) lives inline on `WorldGen` in `godot/game/world_gen.gd`. No new `bias_authoring.gd` script.

## Reasoning
`WorldGen` already houses the static-only one-shot generation pipeline (`_place_positions`, `_build_mst`, `_assign_names`, `_seed_prices`, `_materialize_*`). `_author_bias` is one more pipeline stage on the same data, sharing the same RNG-namespacing pattern (`hash([effective_seed, "bias"])` is sibling to `"place"`/`"names"`). Splitting it out would force `_solve_bias_range` to either live in a sibling file or duplicate constants, and would obscure the strict ordering with `_seed_prices` (which now reads bias).

Slice-3.x can extract if/when a second algorithm appears -- not before.

## Alternatives considered
- New `godot/game/bias_authoring.gd` script-only file -- rejected as premature file-splitting (no independent caller; godot-idioms-and-anti-patterns flags this).

## Confidence
High. Architect ratified Designer's lean with project-structure-conventions reasoning.

## Source
Architect handoff §1 (Call A).

## Related
- [[slice-3-pricing-spec]]
