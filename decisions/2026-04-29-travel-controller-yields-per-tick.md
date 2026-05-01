---
title: TravelController yields per-tick to serialize SaveService writes
date: 2026-04-29
status: ratified
tags: [decision, architecture, save-mechanics, async]
---

# TravelController yields per-tick to serialize SaveService writes

## Decision
`TravelController.process_tick()` awaits `get_tree().process_frame` after every per-iteration emit, before the next iteration mutates state. The exact loop body sequence per iteration:

1. Mutate `_world.tick` and `_trader.travel.ticks_remaining`.
2. On arrival (`ticks_remaining <= 0`): set `_trader.location_node_id = travel.to_id`; clear `_trader.travel = null`. (Restores the [[2026-04-29-trader-travel-location-mutex]] before any signal emit.)
3. Emit `Game.state_dirty` (sets `SaveService._dirty = true`).
4. Emit `Game.tick_advanced` (synchronously runs `SaveService._on_tick_advanced` which calls `await write_now()` — yields).
5. `await get_tree().process_frame` (registers AFTER `SaveService`'s await; resumes second on the next frame).

Implementation: `godot/travel/travel_controller.gd:63-83`.

## Reasoning
TravelController drives the per-step tick loop ([[2026-04-29-tick-granularity-per-step]] — N tick_advanced for N-tick travel). Every `tick_advanced` triggers `SaveService.write_now()` (coalesced via `_dirty`), which is async (awaits one `process_frame` after `store_string` to ensure HTML5 IndexedDB durability per slice-spec §3).

Without a yield in the loop, a tight-loop emit could fire a second `tick_advanced` before the first `write_now()` completes, causing two in-flight `FileAccess.open(SAVE_PATH, WRITE)` calls — undefined territory on HTML5, racy on desktop.

The yield in TravelController serializes them. Because `SaveService`'s await registers first (during the synchronous handler invoked by the emit), Godot 4's coroutine resume order (empirically FIFO on `SceneTree.process_frame`) lets `write_now()` complete before TravelController's next iteration runs. The behaviour also aligns with the per-tick UI update need — the StatusBar updates once per tick, and a yield is natural between updates.

The empirical-FIFO assumption is flagged at `travel_controller.gd:80-82` as `[verify on Tier 7]`. If save races appear under fast travel during integration testing, the fallback is to add a re-entry guard on `SaveService._on_tick_advanced`. The decision today is to rely on the empirical ordering and verify at integration; the in-flight guard is the named contingency, not the chosen path.

## Alternatives considered
- **Add an `_in_flight: bool` re-entry guard on `SaveService._on_tick_advanced`** — rejected: adds defensive complexity to a sealed Tier 4 service. Kept as the named contingency if Tier 7 verification surfaces a race.
- **Both: yield in TravelController AND guard in SaveService** — rejected: defense-in-depth not justified at slice scale; the slice's tick frequency is player-driven, so back-to-back ticks within a single frame don't occur in normal play.
- **No yield, no guard** — rejected: violates HTML5 durability contract; first refresh during fast travel would lose state.

## Confidence
High at slice scale; medium pending Tier 7 verification of the resume-order assumption. The mitigation if the empirical order doesn't hold is named and one-line; the cost of being wrong is bounded.

## Source
This conversation, mid-session ratification ("Question B: 1"). The race was surfaced by the Tier 4 Code Reviewer as a Tier 5 forward concern; the constraint was baked into the Tier 5 Engineer brief and is now codified in `travel_controller.gd:63-83`.

## Related
- [[2026-04-29-tick-granularity-per-step]] — per-step tick emissions are what create the race window this decision closes
- [[2026-04-29-tick-on-player-travel]] — only player-driven ticks; back-to-back-within-frame ticks are pathological, not normal
- [[2026-04-29-trader-travel-location-mutex]] — preserved by step 2 of the loop body before any signal emit
- [[2026-04-29-callable-injection-resource-mutators]] — the Callable seam that lets `Game.emit_state_dirty.call()` reach SaveService
- [[slice-architecture]] — §5 save lifecycle
- [[slice-spec]] — §3 HTML5 IndexedDB flush requirement
