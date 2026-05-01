---
title: WorldRules — shared-static-config class in godot/shared/, holds TRAVEL_COST_PER_DISTANCE
date: 2026-04-30
status: ratified
tags: [decision, architecture, structure, slice-0.5, precedent]
---

# `WorldRules` — shared-static-config class in `godot/shared/`

## Decision
Introduce a new file `godot/shared/world_rules.gd` to hold cross-feature world tuning constants and the small static helpers that read them. Concrete shape:

```gdscript
class_name WorldRules
extends Object

const TRAVEL_COST_PER_DISTANCE: int = 3

static func edge_cost(e: EdgeState) -> int:
    return e.distance * TRAVEL_COST_PER_DISTANCE
```

`TRAVEL_COST_PER_DISTANCE` is migrated out of `travel_controller.gd` (where it was previously a `const`) into `WorldRules`. Both `TravelController` and `DeathService` read from `WorldRules`; neither system exposes the constant for the other.

`extends Object` (not `RefCounted`, not `Resource`) because the class is a static-method holder and is never instantiated. The folder `godot/shared/` is created by this decision; per [[slice-architecture]] §6 it is "populated as cross-feature needs arise" — Slice 0.5 is the first such need.

## Reasoning
Slice 0.5's revised stranded predicate ([[2026-04-30-stranded-predicate-v2-affordability-checks]]) requires `DeathService` to compute edge cost. Three placements were on the table:

1. **Option A — expose `TravelController.edge_cost(e: EdgeState) -> int` as a static.** Rejected. `TravelController` is a gameplay verb (mutates trader, drives ticks); `DeathService` is a passive evaluator. Having Death reach into Travel inverts the dependency direction — the passive system would depend on the active one. Bad for [[godot-idioms-and-anti-patterns]] (dependencies flow inward, not toward verbs).
2. **Option B — lift the multiplier into a shared static-config holder both systems read.** Chosen. Both Travel and Death are clients of the same world-tuning fact; lifting the fact above both is the composition the architecture wants. New systems that need the same constant (e.g. a future Encounter system that imposes travel-cost surcharges) plug into `WorldRules` without depending on Travel.
3. **Option C — bake `cost` onto `EdgeState` itself at world-gen time.** Rejected. Bakes a tuning number into save data — every retune becomes a save-schema migration. The point of the slice's tuning loop is to retune freely until the fantasy is right. Save-data immutability protects a different concern.

The folder `godot/shared/` was already named in [[slice-architecture]] §6 as the home for cross-feature plumbing; this is the first concrete inhabitant. Future sibling files (`world_constants.gd`, `world_clock.gd`, etc.) follow the same idiom: small, static-only, no instance state, dependencies flow upward into them.

## Alternatives considered
- **Option A: TravelController exposes the constant.** Rejected as above.
- **Option C: per-edge baked cost.** Rejected as above.
- **Singleton autoload.** Rejected by silent default — Slice 0.5's standing rule (no new autoloads without one-sentence justification, see [[2026-04-29-one-autoload-only-game]]) makes this the highest-friction option, and a static class achieves the same read pattern.
- **`Resource` subclass with `@export`s for hot-reload tuning.** Considered briefly. Defer to a future round if/when designers want non-programmer-editable tuning; for Slice 0.5 a `const` is sufficient.

## Confidence
High at the placement. Medium on the long-term shape — `WorldRules` may grow into either (a) a small constants bucket that stays static-only, or (b) a `Resource` once tuning needs hot-reload. Either evolution is cheap from this starting shape.

## Source
- Architect's verdict, Slice 0.5 (this conversation), Q2b ratification.
- Engineer's implementation: file created at `godot/shared/world_rules.gd`; `travel_controller.gd` migrated; `_edge_distance(a, b)` renamed to `_find_edge(a, b) -> EdgeState` so callers can pass the EdgeState directly to `WorldRules.edge_cost`.
- Reviewer ratification, Slice 0.5: confirmed `WorldRules` is never instantiated in the codebase.

## Related
- [[2026-04-30-stranded-predicate-v2-affordability-checks]] — the consumer that motivated the lift
- [[2026-04-29-one-autoload-only-game]] — standing rule that disqualified the autoload alternative
- [[godot-idioms-and-anti-patterns]] — composition and dependency-direction guidance
- [[project-structure-conventions]] — `shared/` folder usage
- [[slice-architecture]] §6 — folder layout (`shared/` named here)
