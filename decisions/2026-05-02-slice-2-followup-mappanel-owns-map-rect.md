---
title: HUD/MapPanel Control owns the map drawing rect; WorldGen takes Rect2 as a parameter
date: 2026-05-02
status: ratified
tags: [decision, architecture, ui-layout, slice-2-followup]
---

# MapPanel Control owns the map drawing rect

## Decision

`MapView` lives under `HUD/MapPanel/MapView` where `MapPanel` is a `Control` with anchors `(0, 0, 1, 1)` and offsets `(436, 48, -376, -8)`. Node positions are stored as panel-local pixels in `NodeState.pos` (Vector2; on-disk shape unchanged from slice-2). `WorldGen.generate(seed, goods, map_rect: Rect2)` takes the target rect as a parameter; `Main._ready` reads `$HUD/MapPanel.size` and threads it through `Game.bootstrap` -> `SaveService.load_or_init` -> `WorldGen.generate`.

## Reasoning

The rect *is* a Control's size, owned by the parent's anchor/offset layout. Engine convention aligns with this: `Control` dimensions are the source of truth for "what region does this UI element own." Anything else teaches a second source of truth to lie about the first -- the moment a panel resizes, the constant or hardcoded bounds drift away from reality.

The previous slice-2 shape hardcoded `WorldGen.POS_BOUNDS = Rect2(80, 60, 640, 380)` in screen coordinates, which overlapped with `NodePanel` (8..428, 48..248), `TravelPanel` (anchored right), and `StatusBar` (top 48px). Map labels and circles painted in the same pixels as UI text. Visual playtest confirmed the collision.

## Alternatives considered

- **Absolute coords + a centralised constant** (project setting / autoload const). Rejected: "constant is a lie, drifts." Same overlap bug returns the moment a panel offset changes.
- **Normalised 0..1 positions, MapView scales at draw time.** Rejected for slice-2: "solves slice-3 problems we don't have." Breaks save-format meaning, pushes a transform into MapView for every draw call (edges, neighbour outlines, label positions). Worth revisiting when window-resize support lands.
- **SubViewport + SubViewportContainer.** Rejected: "render-target pass too heavy for two rectangles shouldn't overlap" on web/GL Compatibility. Right answer when pan/zoom lands, not before.

## Confidence

High. Architect explicitly ranked all four options with trade-offs; Reviewer verified the structure; user-confirmed visual playtest.

## Source

Slice-2 follow-up session (2026-05-02). Architect round 1 spec §2; Engineer round 1 implementation; user playtest confirmation.

## Related

- [[slice-architecture]]
- [[2026-04-29-bottom-up-no-sanity-scene]]
- [[2026-05-02-slice-2-mapview-compress-not-split]]
- [[2026-05-02-slice-2-followup-deferred-bootstrap-f6-sentinel]] -- the boot-order shape that delivers the rect from Main to WorldGen
