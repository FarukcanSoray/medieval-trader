---
title: TraderState and WorldState are Resource subclasses, not autoloads
date: 2026-04-29
status: ratified
tags: [decision, architecture, state, resource]
---

# TraderState and WorldState are Resource subclasses, not autoloads

## Decision
`TraderState` and `WorldState` (and their nested `TravelState`, `NodeState`, `EdgeState`, `HistoryEntry`, `DeathRecord`) are `Resource` subclasses. They are held as `@export var trader: TraderState` and `@export var world: WorldState` on `Game`. They live in memory only — instantiated by `WorldGen` or rehydrated from save JSON; persistence is JSON via `SaveService`, not `ResourceSaver`.

Systems get to them via `setup(trader: TraderState, world: WorldState)` injection from `Main`, never via `get_node` reaches across the tree.

## Reasoning
- They are pure data with tiny mutation methods. No children, no lifecycle, no scene-tree behavior.
- They get **replaced wholesale** on save-load, on death, and on new-world generation. Resource swap is one assignment (`Game.trader = loaded`); replacing an autoload is awkward and risks stale references in scripts that cached the old reference.
- `@export` typing on `Game` gives systems a typed handle without `get_node` reaches.
- Putting them in the scene tree just to be globally reachable would be the singleton-gameplay-state anti-pattern.

## Alternatives considered
- **`TraderState` / `WorldState` as autoloads** — rejected: singleton-gameplay-state anti-pattern; field-by-field reset on load is fragile; reference-swap pattern is cleaner.
- **Nodes in the scene tree holding state** — rejected: unnecessary tree membership for pure data.
- **Plain script-only classes (no Resource extension)** — rejected: loses `@export` typing on `Game`, loses Inspector affordance.

## Confidence
High. The Architect documented the reasoning per rejection; the user asked the question explicitly mid-session ("why are TraderState and WorldState not autoloads, what would happen if they were?") and the answer was confirmed before the Engineer built Tier 1.

## Source
`docs/slice-architecture.md` §4 "State ownership (Resource vs Node)"; user verification mid-session 2026-04-29 evening.

## Related
- [[2026-04-29-one-autoload-only-game]] — what the single autoload holds these references on
- [[2026-04-29-callable-injection-resource-mutators]] — how mutators notify subscribers without resource-emitted signals
- [[2026-04-29-strict-reject-from-dict]] — the save-load contract that makes wholesale replacement work
- [[godot-idioms-and-anti-patterns]] — singleton-gameplay-state anti-pattern
- [[slice-architecture]] — §4 binding spec
