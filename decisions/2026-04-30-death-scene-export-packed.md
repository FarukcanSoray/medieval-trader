---
title: Death scene loaded via @export var _death_scene: PackedScene
date: 2026-04-30
status: ratified
tags: [decision, architecture, scene-loading, main]
---

# Death scene loaded via @export var _death_scene: PackedScene

## Decision
`Main` declares `@export var _death_scene: PackedScene`, wired in `main.tscn`'s Inspector to `res://ui/death_screen/death_screen.tscn`. `_on_died` calls `get_tree().change_scene_to_packed(_death_scene)`. No `preload()` of the death scene; no `load()` by path string.

## Reasoning
Two rejected alternatives created friction:

- `preload()` on Main carries class-load cycle risk on editor F6 entry paths. `DeathScreen` references the `Game` autoload; preloading it from Main pulls the dependency graph eagerly, and F6'ing into individual scenes during development can hit ordering quirks where the autoload isn't fully initialised.
- `load("res://ui/death_screen/death_screen.tscn")` by string defeats static typing and makes refactors silent-break (a path rename produces a runtime null instead of a parse error).

`@export var _death_scene: PackedScene` + Inspector binding gives static typing, no eager class-load, and a refactor-safe scene reference. Establishes the precedent for future scene-change wiring.

## Alternatives considered
- **`preload("res://ui/death_screen/death_screen.tscn")`** — rejected; class-load cycle risk on F6 entry paths.
- **`load(path_string)`** — rejected; loses static typing, refactors silent-break.

## Confidence
High. Architect explicit during Tier 7 short-pass. One-line change with clear failure modes for the alternatives.

## Source
- `godot/main.gd` (the `@export` declaration and `_on_died`).
- `godot/main.tscn` (the Inspector binding).
- `docs/slice-architecture.md` §7 item 22 (patched to reflect this).

## Related
- [[slice-architecture]] — §2.1 / §7 item 22
