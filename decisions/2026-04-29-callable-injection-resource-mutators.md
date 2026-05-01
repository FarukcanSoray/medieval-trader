---
title: Callable injection for Resource mutators (signals live on Game, not on resources)
date: 2026-04-29
status: ratified
tags: [decision, architecture, signals, resource]
---

# Callable injection for Resource mutators (signals live on Game, not on resources)

## Decision
`TraderState` mutator methods take `Callable` parameters for notification:

- `apply_gold_delta(amount: int, on_changed: Callable, on_dirty: Callable) -> bool`
- `apply_inventory_delta(good_id: String, qty: int, on_dirty: Callable) -> bool`

`Game` injects `Game.gold_changed.emit` and `Game.state_dirty.emit` as `Callable`s when calling mutators. The four cross-system signals (`tick_advanced`, `gold_changed`, `state_dirty`, `died`) are declared on `Game`, not on the Resource classes.

Defensive guard: mutators check `Callable.is_valid()` before invoking, so the methods work during boot before `Game` has wired the callbacks.

## Reasoning
This is a deliberate push-back on slice-spec §9, which read as if signals would come from "the Trader resource."

`Resource` *can* declare signals in Godot 4, but **connections do not survive serialization**. The slice's save-load cycle re-creates `TraderState` from JSON on every boot, so every subscriber would need to re-connect after every load. That's a footgun and adds ceremony to deserialization.

Moving signals to `Game` (which is the autoload — stable across loads) and threading callbacks through mutator parameters preserves the §9 ownership claim ("Trader resource owns gold mutation" — only `apply_gold_delta` writes gold) while sidestepping the re-wiring brittleness. Equivalent semantic coupling, zero subscription overhead at load time.

## Alternatives considered
- **Signals declared on `TraderState` / `WorldState`** — rejected: connections lost on save-load; subscribers would need to re-bind after every `from_dict` call.
- **Explicit re-subscription logic in `from_dict`** — rejected: bleeds signal-subscriber knowledge into deserialization; adds ceremony every load.
- **Polling / event aggregator** — rejected: more complexity, no benefit over callback injection.

## Confidence
High. Architect named the footgun explicitly; user ratified the architecture document. Pattern is now the contract for Tier 4 (`SaveService`) and any future Resource that needs to notify subscribers.

## Source
`docs/slice-architecture.md` §3 "Signal routing" + §9 "Where I pushed back on §9 (and where I didn't)" — the Resource-cannot-easily-emit problem section.

## Related
- [[2026-04-29-one-autoload-only-game]] — `Game` is where the signals live
- [[2026-04-29-resource-not-autoload-state]] — why the resources are deserialized fresh on load
- [[2026-04-29-signal-based-integration]] — the kickoff decision that this refines
- [[slice-architecture]] — §3 binding spec
