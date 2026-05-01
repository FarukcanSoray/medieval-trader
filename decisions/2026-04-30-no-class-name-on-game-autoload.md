---
title: No class_name on game.gd — autoload name "Game" is global identifier
date: 2026-04-30
status: ratified
tags: [decision, godot-4, autoload, idiom]
---

# No class_name on game.gd — autoload name "Game" is global identifier

## Decision
`godot/game/game.gd` declares `extends Node` only — no `class_name` directive. The autoload name `Game` (registered in `project.godot`) is the project's global identifier for this script. All references (`Game.trader`, `Game.world`, `Game.tick_advanced.connect(...)`, etc.) work via the autoload name.

## Reasoning
Godot 4 forbids a `class_name` matching an autoload singleton name — they share the same global namespace. Declaring `class_name Game` while `Game` is also registered as an autoload produces a parser error: `Class "Game" hides an autoload singleton.` Discovered at first F5 attempt of the Tier 7 slice.

The autoload name is sufficient — it's globally accessible from any script as if it were a `class_name`. The only thing lost is using `Game` as a type annotation (e.g., `var x: Game`), which the slice never needs because external code references the autoload by name, not by type.

The original slice-architecture spec instructed `class_name Game extends Node`. That's been patched in two places (§6 folder layout comment and §7 item 10) to reflect the correct shape.

## Alternatives considered
- **Keep `class_name Game`** — rejected; parser error, project won't run.
- **Rename the autoload (e.g., `GameAutoload`)** — rejected; would break every reference across the slice and contradicts [[2026-04-29-one-autoload-only-game]]'s naming.
- **Rename the class (e.g., `class_name GameRoot`)** — rejected; pointless second name for the same singleton.

## Confidence
High. Mechanical Godot-4 constraint; the "class hides autoload" parser error names it explicitly. Spec patch makes the rule visible to future readers.

## Source
- `godot/game/game.gd:1-3` (extends Node + comment explaining the absence of class_name).
- `docs/slice-architecture.md` §6 (line 225) and §7 item 10 (patched this session).

## Related
- [[2026-04-29-one-autoload-only-game]] — the autoload this constraint applies to
- [[2026-04-29-public-callable-naming-on-game]] — naming on `Game` (related namespace concern)
