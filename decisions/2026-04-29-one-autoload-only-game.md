---
title: One autoload only — Game
date: 2026-04-29
status: ratified
tags: [decision, architecture, autoload]
---

# One autoload only — Game

## Decision
The slice has exactly one autoload: `Game` (a `Node` script at `godot/game/game.gd`, registered as `Game = "*res://game/game.gd"` in `project.godot`). `Game` hosts `SaveService` and `DeathService` as child nodes, holds `trader: TraderState` and `world: WorldState` as exported references, and declares the four cross-system signals (`tick_advanced`, `gold_changed`, `state_dirty`, `died`).

## Reasoning
Seven subsystems all read/write the same `TraderState`/`WorldState`, and the four §9 cross-system signals must fan out globally. One root service node is the smallest expression of that load-bearing coupling. The user-level standing rule says no new autoloads without one-sentence justification — this autoload meets that bar; everything else does not.

## Alternatives considered
The Architect explicitly weighed and rejected each of these as autoloads:

- **`SaveService` as a separate autoload** — only ever talks to `Game`; child node is simpler.
- **`EventBus` as a standalone autoload** — would be `Game` with extra import friction; folded in.
- **`TraderState` / `WorldState` as autoloads** — singleton-gameplay-state anti-pattern; they're pure data with no scene-tree behavior. They're held as `@export var` on `Game` instead.
- **`DeathService` as a separate autoload** — child of `Game` next to `SaveService`; in-tree subscription work.

## Confidence
High. The Architect's reasoning was explicit and per-rejection; user ratified the full architecture document.

## Source
`docs/slice-architecture.md` §1 "Autoload roster"; SceneArchitect handoff 2026-04-29 evening.

## Related
- [[CLAUDE]] — user-level standing rule "no new autoloads without one-sentence justification"
- [[godot-idioms-and-anti-patterns]] — singleton-gameplay-state anti-pattern
- [[slice-architecture]] — the binding spec
- [[2026-04-29-resource-not-autoload-state]] — what the data fields are instead
- [[2026-04-29-callable-injection-resource-mutators]] — how Resource mutators notify Game's signals
