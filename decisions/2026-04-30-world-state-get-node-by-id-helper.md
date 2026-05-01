---
title: WorldState.get_node_by_id helper, migrate 5 call sites
date: 2026-04-30
status: ratified
tags: [decision, architecture, world-state, helper]
---

# WorldState.get_node_by_id helper, migrate 5 call sites

## Decision
`WorldState` exposes `func get_node_by_id(node_id: String) -> NodeState` (returns `null` on miss or empty id). The five call sites that previously inlined the `for n in nodes: if n.id == id` loop now delegate to the helper:

- `ui/hud/status_bar.gd` (`_node_display_name`)
- `ui/hud/node_panel.gd` (replaced the private `_current_node` helper, inlined at call site)
- `ui/hud/travel_panel.gd` (`_node_display_name`)
- `ui/death_screen/death_screen.gd` (`_node_display_name`)
- `travel/trade.gd` (replaced the private `_current_node` helper)

Display-name fallback wrappers stay in StatusBar / TravelPanel / DeathScreen — that's a separate concern (display-name-with-fallback) — but their internals call the new helper.

## Reasoning
The lookup loop was duplicated five times and behaviour had drifted: StatusBar returned the raw `node_id` on miss; DeathScreen returned `"-"`; the others returned `null`. The drift was a smell — collapsing the seam while it's small (5 sites) is cheaper than letting it grow. The user's slice-first stance ([[2026-04-29-no-cuts-slice-first]]) favours getting the seam right while it's small.

DeathScreen's miss-fallback also flipped from raw-id to `"-"` during migration, aligning with StatusBar — a UX leak removed in passing.

## Alternatives considered
- **Leave as five inline loops** — rejected; duplication and drift were both visible.
- **Defer until post-slice cleanup** — rejected after Architect short-pass; the divergence was already growing across multiple files.

## Confidence
High. Architect ratified during Tier 7 short-pass before Engineer touched Main. Five trivial substitutions, helper is small and pure.

## Source
- `godot/world/world_state.gd:21-28` — the helper.
- Five migrated call sites listed above.
- Architect short-pass handoff (this session).

## Related
- [[2026-04-29-no-cuts-slice-first]] — the slice-first construction stance the migration was justified against
- [[slice-architecture]] — §4.3 (`WorldState` shape)
