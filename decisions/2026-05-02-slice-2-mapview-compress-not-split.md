---
title: Slice-2 MapView is cheapest-viable _draw(); slice not split into 2a/2b
date: 2026-05-02
status: ratified
tags: [decision, scope, slice-2, ui]
---

# Slice-2 MapView is cheapest-viable _draw(); slice not split into 2a/2b

## Decision

Slice-2 ships its MapView as a **cheapest-viable `_draw()`** on a dedicated child node of `World (Node2D)`. The slice is **not split** into 2a (generator) + 2b (MapView).

Concrete shape:

- New file `godot/world/map_view.gd`, `class_name MapView extends Node2D`.
- Reads `Game.world` and `Game.trader` directly (same documented exception class as `DeathScreen` and `StatusBar` — read-only renderer of global state, not interactive).
- Subscribes to `Game.tick_advanced` and `Game.state_dirty`, calls `queue_redraw()` on each.
- Paints: edges (1px lines) → node fills (16-radius circles) → neighbour outline rings (1px) → display names (14pt, fixed offset).
- No pan, no zoom, no click, no animation, no font asset, no transform.

## Reasoning

Director's hard pillar-1 line was "whole map visible from day one" (no fog-of-war, no exploration gating). Slice-1 had no graph rendering — `World (Node2D)` was an empty placeholder. The pillar requirement therefore required **either** a new MapView component **or** an erosion of the pillar.

Critic surfaced two paths:

- **Split:** slice-2a = generator, slice-2b = MapView (sequenced).
- **Compress:** cheapest-viable `_draw()` inside slice-2 (single shippable thing).

Compression won because the cheapest-viable shape is genuinely small (~150 lines of GDScript, no new UI subsystem, no scene asset, no animation budget) and splitting adds session-boundary friction for code that depends tightly on the generator's output. Click-to-travel is the part that earns its own slice; static rendering does not.

## Alternatives considered

- **Split into slice-2a + slice-2b.** Rejected by user. Adds a session boundary for ~150 lines of code that has to land before slice-2 can be playtested.
- **Erode the pillar (TravelPanel-as-map, neighbours-only).** Rejected upstream by Director. Pillar 1 wants the math problem visible, not just the next hop.
- **Defer MapView entirely with a TODO label.** Not seriously considered; would block slice-2 playtest.

## Confidence

High. User explicit ratification ("B - compress").

## Open threads carried forward

- Click-to-travel on the map: deferred (Critic-vetoed for slice-2). Designer may resurrect for slice-3 once the readout is verified.
- Pan/zoom: deferred. Map is sized to fit the viewport without scrolling at slice-2 fidelity.

## Source

This session (2026-05-02 PM). Critic offered both paths; user picked compress.

## Related

- [[2026-05-02-slice-2-scope-procgen-map-only]]
- [[slice-architecture]]
- [[CLAUDE]]
