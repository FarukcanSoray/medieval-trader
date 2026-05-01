---
date: 2026-05-02
type: session
tags: [session, slice-2-procgen, full-pipeline]
---

# Slice-2 procgen map — full pipeline to shippable implementation

## Goal

Run the full project pipeline (Director -> Critic -> Designer -> Architect -> Engineer -> Reviewer) on slice-2: procgen map. Land an implementation ready for visual playtest. Close with decisions ratified.

## Produced

**Code (modified):**

- `godot/world/world_state.gd` — added `get_starting_node_id()` helper.
- `godot/game/world_gen.gd` — complete rewrite from slice-1's hardcoded triangle. Static methods: `_place_positions`, `_build_mst` (Prim's), `_add_extra_edges`, `_assign_names`, `_materialize_nodes`, `_materialize_edges`, `_is_connected`, `_emit_log_line`. Added 40-name `NAME_POOL` const.
- `godot/systems/save/save_service.gd` — `seed_override` plumbed through `load_or_init`/`wipe_and_regenerate`/`_generate_fresh`; replaced hardcoded `"hillfarm"` with `Game.world.get_starting_node_id()`.
- `godot/game/game.gd` — `bootstrap(seed_override: int = -1)`.
- `godot/main.gd` — `_parse_seed_override()` with regex match + `push_warning` for negative seeds.
- `godot/ui/hud/status_bar.tscn` + `.gd` — added `SeedLabel` with `VSeparator`.
- `godot/main.tscn` — `MapView` added as child of `World`.
- `godot/pricing/price_model.gd` — comment-only update.

**Code (new):**

- `godot/world/map_view.gd` — `class_name MapView extends Node2D`; `_draw()` paints edges -> node fills -> neighbour rings -> names. ~94 lines.

## Decisions ratified

- [[2026-05-02-slice-2-scope-procgen-map-only]]
- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]]
- [[2026-05-02-slice-2-mapview-compress-not-split]]
- [[2026-05-02-slice-2-no-schema-bump-trigger-named]]
- [[2026-05-02-slice-2-loaded-saves-win-cli-seed-fresh-only]]
- [[2026-05-02-slice-2-store-effective-seed-as-world-seed]]
- [[2026-05-02-slice-2-5-named-tuning-pass]]
- [[2026-05-02-slice-2-log-line-only-no-dump-catalog]]
- [[2026-05-02-derive-starting-node-via-world-state-helper]]
- [[2026-05-02-member-ordering-lifecycle-before-private]]

## Pipeline shape

Six rounds with two plain-language step-backs (post-Critic, post-Designer; per the standing memory rule for 3+ agent rounds). Critic's "Hidden-Expensive" verdict on the generator-complexity stack reframed cleanly into slice-2.5 because the user's slice-first stance treats Critic verdicts as construction order, not deletion. Engineer fix loop fired after Reviewer disproved its own blocker (NodePanel/TravelPanel are transparent Controls — no MapView occlusion). Engineer pushed back on one Reviewer nit (member ordering); user accepted Engineer's reading of the conventions skill.

## Open threads

- **Visual playtest pending.** No build run this session. MapView occlusion was reasoned, not verified; slice-1 -> slice-2 save round-trip is reasoned, not exercised.
- **Slice-2.5 tuning pass** — ~20 generated worlds, rejection criteria ratification.
- **Seed-bumps edge case.** If `MAX_SEED_BUMPS` exhausts, `assert(false)` returns `null` in release builds. Math says unreachable; flagged as out-of-scope; would propagate `null` through callers if it ever fired.
- **Carryover threads:** B1 deferred iters 1/4/5, runbook prose-refresh items, `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`, travel confirm-modal Cancel button, Tier 7 deferred markers.

## Links

- [[2026-05-02-b1-execution-and-close]] — earlier-same-day session (B1 close).
- [[slice-spec]], [[slice-architecture]] — slice-1 baseline.
- [[CLAUDE]] — workflow + ASCII rule + project scope.

## Notes

**Member-ordering pattern.** Reviewer asked for an order contradicting the `gdscript-conventions` skill (lifecycle-after-private). Engineer correctly pushed back. The durable defense is [[2026-05-02-member-ordering-lifecycle-before-private]]. Pattern to preserve: Reviewer needs the skill re-grounded each round, otherwise the same nit resurfaces.

**Critic's Hidden-Expensive reframing.** Without the user's slice-first stance, Critic's verdict on generator complexity could have read as "cut" and lost the deferred work. Naming slice-2.5 explicitly preserved it as construction order. This is the mechanism that lets Critic stay adversarial without erasing scope.
