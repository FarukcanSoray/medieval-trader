---
title: Boot-time terminal-state branch lives in Main, not Game.bootstrap
date: 2026-05-01
status: ratified
tags: [decision, architecture, signals, boot-path, slice-1]
---

# Boot-time terminal-state branch lives in Main

## Decision
When `SaveService.load_or_init()` reconstitutes a save with `world.dead == true`, the branch to the death scene is handled in `Main._ready()` after `await Game.bootstrap()`, not by `Game.bootstrap()` re-emitting `died` (or a new `restored_dead` signal).

`Main._ready()` checks `Game.world.dead` post-bootstrap; if true, it calls `change_scene_to_packed(_death_scene)` and returns, skipping all `setup()` calls, HUD wires, the `Game.died.connect(_on_died)` line, and the boot-paint nudge.

## Reasoning
Three structural arguments, in priority order:

1. **Dependency direction.** Main already owns scene flow — the alive→dead path goes `Game.died` → `Main._on_died` → `change_scene_to_packed(_death_scene)`. Game owns state and signals; Main owns scene transitions. Routing the dead-state boot back through Game.bootstrap re-emitting `died` would invert that, and would contradict the slice-spec §2.1 contract that "bootstrap is silent re: cross-system signals" — the same invariant the boot-paint nudge ([[2026-04-30-boot-paint-three-emit-order]]) was invented to preserve. Re-emitting `died` from bootstrap is the same category of mistake the nudge was designed to avoid.

2. **Signal cleanliness.** `Game.died` semantically means "the trader just died" — a transition signal. `DeathService._check_stranded()` correctly guards on `world.dead` to enforce that. Overloading `died` to also mean "booted into dead world" gives false positives to future subscribers (achievement system, death animation trigger, etc.) on every relaunch of a dead save.

3. **Consistency.** Main already reads `Game.world` and `Game.trader` post-bootstrap to drive setup. Reading `Game.world.dead` is the same shape — Main is the orchestrator, querying populated state synchronously after the await resolves. No new signal, no new ordering risk, no new public API on Game.

## Alternatives considered
- **`Game.bootstrap()` emits `died` (or new `restored_dead` signal) on dead-state load.** Rejected: contradicts the bootstrap-is-silent contract; overloads `died` semantics; would also require re-sequencing Main to connect the signal *before* the await (currently it connects after).
- **`SaveService.load_or_init()` drives the scene change.** Rejected: persistence layer driving scene flow is upside-down — SaveService is responsible for state on disk, not for what scene the player sees.
- **`Game.bootstrap()` returns `bool` (or `world.dead`) and Main branches on the return.** Rejected: structurally the same as the chosen option but routed through bootstrap's signature for a one-bit concern that's already exposed on `world`. `world.dead` is the canonical source of truth.

## Confidence
High. The three reasons compose cleanly and the alternatives all introduce drift the existing slice-spec already legislated against.

## Source
- Debugger diagnosis (this session): confirmed `world.dead`/`world.death` round-trip through save correctly, root cause is missing terminal-state branch on boot.
- Architect structural pass (this session): weighed Options 1/2/3, picked Option 1.
- Reviewer pass (this session): ratified.
- User playtest confirmed fix.

## Related
- [[2026-04-30-idempotent-bootstrap-signal]] — bootstrap idempotency contract this decision relies on (early-return on `world != null`)
- [[2026-04-30-boot-paint-three-emit-order]] — precedent that bootstrap-is-silent re: cross-system signals; the nudge exists because of that contract
- [[2026-04-30-death-scene-export-packed]] — `_death_scene` `@export PackedScene` reference style; this decision adds a second caller
- [[2026-05-01-death-screen-quit-awaits-write-now]] — secondary fix folded into the same engineering pass
- [[slice-architecture]] §2.1 — Main wiring contract preserved
