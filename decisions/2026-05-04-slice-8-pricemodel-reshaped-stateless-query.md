---
title: PriceModel reshaped to stateless query helper (class_name PricingMath)
date: 2026-05-04
status: ratified
tags: [decision, slice-8, structure, pricing, architect-override]
---

# PriceModel reshaped to stateless query helper (class_name PricingMath)

## Decision
PriceModel is reshaped from a state-mutating Node to a stateless script-only helper class: `class_name PricingMath extends Object` at `godot/pricing/pricing_math.gd`. Public API: `buy_price_for(world, node, good_id) -> int` and `sell_price_for(world, node, good_id) -> int`. The Node block is removed from `main.tscn`; the `_price_model.setup(...)` call in `main.gd` is removed. `godot/pricing/price_model.gd` is deleted.

This is an **Architect override** of Designer's lean. Designer (spec §11.8 option a) leaned "keep as Node, add static methods, minimal disruption to call sites." Architect chose option (c): the file moves to a script-only static helper, mirroring `CargoMath` / `WorldRules` / `EncounterResolver`.

## Reasoning
Stateless Node is a Godot smell. The project's existing static-helper precedent is `class_name X extends Object`: `WorldRules` (`shared/world_rules.gd`), `CargoMath` (`cargo/cargo_math.gd`). Keeping PriceModel as a stateless Node would make it the only stateless-helper-as-Node in the project; the scene editor would show it; new contributors would wonder why it is there.

Call-site disruption is the same either way -- under both options call sites switch from `node.prices[good_id]` to `PricingMath.buy_price_for(world, node, good_id)`. The class name is what changes, not the call shape. Designer's "minimal disruption" framing referred to the file location, not the call sites.

Net cost over Designer's lean: ~10 lines edited across 3 files (rename `price_model.gd` -> `pricing_math.gd`; change `extends Node` -> `extends Object`; remove `@onready var _price_model` and `_price_model.setup()` line in `main.gd`; remove the PriceModel node block in `main.tscn`). Benefit: file lives at the layer it actually occupies.

The renaming is honest: the current file is `PriceModel`, which connotes "thing that models prices over time" -- a stateful drift system. The new file is a stateless math kernel. `PricingMath` matches `CargoMath`, signals to a reader that this file has no behavior between calls.

Argument-shape decision: `buy_price_for(world, node, good_id)` takes both `world` (for `world_seed` and `tick`) and `node` (for the pool dicts). The alternative `buy_price_for(world, node_id, good_id)` with internal `world.get_node_by_id` is per-call O(N) on the node list; callers already have `NodeState` references at the read point (NodePanel, Trade, DeathService.is_stranded). Pass the resolved node, not the id. Call frequency is per-row-per-paint: 7 nodes x 4 goods x 2 sides = 56 calls per panel refresh.

## Alternatives considered
- **Option (a): keep as Node, add static methods** (Designer's lean) -- rejected: stateless Node is a Godot smell; project precedent is script-only.
- **Option (b): instance methods on Node** -- rejected: same issue as (a), plus call sites need a Node reference.
- **Fold into existing helper (e.g., WorldRules)** -- not weighed in the override but implicit rejection: PricingMath has its own surface area distinct from world-rules constants; a separate file is the right granularity.

## Confidence
High. Architect explicitly overrode Designer with detailed reasoning and cost estimate.

## Source
Architect S3 override (2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` §11.8.

## Related
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the structural premise (pull-driven prices) that makes PriceModel stateless in the first place
- [[2026-04-30-world-rules-shared-static-config]] -- the project's static-helper precedent
