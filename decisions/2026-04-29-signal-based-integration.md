---
title: Signal-based integration pattern (not get_node lookups)
date: 2026-04-29
status: ratified
tags: [decision, architecture, signals]
---

# Signal-based integration pattern (not get_node lookups)

## Decision
Systems communicate via signals, not via `get_node` lookups. The pattern:

- One **`TraderState`** resource and one **`WorldState`** resource hold all persistent fields.
- Systems are pure-ish functions over these resources.
- Cross-system communication is signal-based: `tick_advanced(new_tick: int)`, `gold_changed`, `state_dirty`, `died(cause)`.
- Mutations go through narrow methods: `apply_gold_delta(amount: int) -> bool` for gold, `apply_inventory_delta(good_id, qty)` for inventory. No system pokes resource fields directly.

This is the architectural surface the Engineer will build against.

## Reasoning
Avoids tight coupling and makes the integration model legible — every dependency is a named signal, not a hidden node-tree search. Directly addresses the Scope Critic's "month 3 sinkhole" warning about integration tax between AI-generated systems: when systems are decoupled and own their state cleanly, adding or swapping a system is lower-friction.

## Alternatives considered
Direct `get_node` lookups and inline mutation of resource fields. Rejected for tight-coupling and integration-tax reasons. This pattern is also a standing Godot idiom (see `godot-idioms-and-anti-patterns`).

## Confidence
High. Explicit integration rule; load-bearing for the Engineer.

## Source
`docs/slice-spec.md` §9 — "The pattern: one **TraderState** resource and one **WorldState** resource hold all persistent fields. Systems are pure-ish functions over them. Cross-system communication is signal-based, never via `get_node` lookups."

## Related
- [[slice-spec]] — fully captured in §9
- [[godot-idioms-and-anti-patterns]] — signal-based pattern is a standing Godot idiom
- [[2026-04-29-save-format-first]] — TraderState and WorldState are the contract surface
- [[2026-04-29-no-cuts-slice-first]] — integration discipline that makes slicing safe
