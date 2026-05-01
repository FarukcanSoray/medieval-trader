---
title: Boot paint nudges in Main._ready() — three emits in load-bearing order
date: 2026-04-30
status: ratified
tags: [decision, architecture, signals, ui, boot]
---

# Boot paint nudges in Main._ready() — three emits in load-bearing order

## Decision
After `await Game.bootstrap()` and panel `setup()` calls, `Main._ready()` emits three signals in this exact order:

1. `Game.tick_advanced.emit(Game.world.tick)`
2. `Game.gold_changed.emit(Game.trader.gold, 0)`
3. `Game.state_dirty.emit()`

This forces every HUD panel to paint populated state immediately. `state_dirty` is last so `SaveService` flips `_dirty = true` after the synthetic tick — no immediate disk write at boot.

## Reasoning
Panels' own `_ready()` runs before `Main._ready()` reaches its `await`, so each panel's first `_refresh()` runs against `Game.trader == null` / `Game.world == null` and paints placeholder text. Bootstrap is silent re: the four cross-system signals (per `[[2026-04-30-idempotent-bootstrap-signal]]` and slice-spec §2.1), so without a nudge the slice would launch with placeholder StatusBar / NodePanel / TravelPanel until the player's first action.

Subscription map (verified):
- StatusBar → `gold_changed`, `tick_advanced`
- NodePanel → `tick_advanced`, `gold_changed`, `state_dirty`
- TravelPanel → `tick_advanced`, `state_dirty`

A single `state_dirty.emit()` (the original Engineer attempt) only refreshes NodePanel and TravelPanel — StatusBar stays on placeholder until first travel. Three emits cover all subscribers via the existing wires; no new public API on panels.

Order is load-bearing because `SaveService` subscribes to both `tick_advanced` (gated by `_dirty`) and `state_dirty` (sets `_dirty = true`). Emitting `state_dirty` last means the synthetic `tick_advanced` runs while `_dirty == false` (no-op write); the first real `tick_advanced` post-boot does the deferred write — preserving normal save semantics.

## Alternatives considered
- **(a) Public `refresh()` on every panel + Main calls them post-setup** — rejected; leaks a boot-only concern into every panel's steady-state contract.
- **(b) `Main.refresh_all()` wrapper that calls each panel** — rejected; same leak, plus a method on Main with no other use.
- **(c) New `Game.boot_complete` signal that all panels subscribe to** — rejected; spec change to §2.1's "bootstrap is silent re: signals" claim, heavier than the problem.
- **(e) Leave panels on placeholder until first action** — rejected; UX downgrade.

## Confidence
High. Debugger diagnosed the asymmetry from signal-subscription map, explicitly chose option (d), and called out the order constraint. Engineer applied; Reviewer ratified.

## Source
- `godot/main.gd:48-60` — the three emits with order comment.
- Tier 7 Debugger diagnosis (this session).
- Subscription evidence: `godot/ui/hud/status_bar.gd`, `node_panel.gd`, `travel_panel.gd`, `godot/systems/save/save_service.gd`.

## Related
- [[2026-04-30-idempotent-bootstrap-signal]] — directly depends on this; the silent bootstrap is what creates the paint gap
- [[2026-04-29-callable-injection-resource-mutators]] — the signal seam these emits use
- [[slice-architecture]] — §2.1 (Main wiring), §3 (signal routing table)
