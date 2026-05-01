---
date: 2026-04-29
type: session
tags: [session, engineer, reviewer, tier-2-5]
---

# Engineer + Reviewer: Tiers 2–5 headless-complete

## Goal

Drive the full Engineer→Reviewer pipeline through Tiers 2, 3, 4, and 5 of the [[slice-architecture]] handoff list. Tier 1 (Resources) was complete; ship four tiers of systems that own gameplay state, persistence, death logic, and the tick loop. Maintain [[2026-04-29-bottom-up-no-sanity-scene]] discipline: the project remains unrunnable until Tier 7.

## Produced

- **Tier 2:** `godot/game/world_gen.gd` — static world generator. Three nodes (Hillfarm, Rivertown, Thornhold) with triangle edges (distances 4, 5, 3). Tick-0 prices seeded per `hash([world_seed, 0, node_id, good_id])` per slice-spec §5.
- **Tier 3:** `godot/game/game.gd` — the sole autoload. Four cross-system signals (`tick_advanced`, `gold_changed`, `state_dirty`, `died`); refs to `trader`, `world`, `goods`; `emit_gold_changed` and `emit_state_dirty` Callable seam. Registered in `project.godot` autoload block.
- **Tier 4:** `godot/systems/save/save_service.gd` and `godot/systems/death/death_service.gd` — persistence and termination as Game children. `Game.bootstrap()` delegates to `SaveService.load_or_init()`. Strict-reject on structural corruption ([[2026-04-29-strict-reject-from-dict]]). HTML5-flush `await` after every `store_string`. Stranded predicate evaluated in DeathService.
- **Tier 5:** `godot/aging/aging.gd`, `godot/pricing/price_model.gd`, `godot/travel/trade.gd`, `godot/travel/travel_controller.gd` — gameplay nodes driving player verbs and tick loop. TravelController owns TRAVEL_COST_PER_DISTANCE = 3 [needs playtesting]; PriceModel owns DRIFT_FRACTION = 0.10 [needs playtesting], independent of WorldGen's tick-0 init.
- **Doc:** `docs/slice-architecture.md` patched §7 items 10, 14 — dropped leading underscore from `emit_gold_changed`/`emit_state_dirty` (matches [[2026-04-29-public-callable-naming-on-game]]).

## Decisions

- [[2026-04-29-public-callable-naming-on-game]]
- [[2026-04-29-stranded-includes-empty-inventory]]
- [[2026-04-29-travel-controller-yields-per-tick]]

## Open threads

- **Tier 6 next: UI scenes.** Five `.tscn` files (`status_bar`, `node_panel`, `travel_panel`, `confirm_dialog` under `ui/hud/`; `death_screen` under `ui/death_screen/`). First visual components in the slice.
- **Tier 7 constraint:** Main must NOT call `TravelController.process_tick` re-entrantly while a prior travel is ticking. HUD grey-out logic gates this; sloppy wiring could interleave `_world.tick` mutations.
- **Two [verify on Tier 7] integration markers** — deferred-test commitments:
  - `world_gen.gd:55-56` — confirm `hash([int, int, String, String])` byte-stability across desktop and HTML5.
  - `travel_controller.gd:80-82` — confirm Godot 4's empirical FIFO resume-order on `SceneTree.process_frame`. Fallback: re-entry guard on SaveService.
- **Tuning numbers still [needs playtesting].** Starting gold 100, WorldGen.DRIFT_FRACTION 0.10, PriceModel.DRIFT_FRACTION 0.10, TRAVEL_COST_PER_DISTANCE 3. Placeholder midpoints set during/after Tier 7 first run.
- **`.tres` UID lines deferred** — same as prior session; Godot will regenerate on first editor open.

## Process notes

Each tier ran full Engineer → Reviewer. Tier 2 produced Reviewer needs-changes (clamp→clampi, world_seed shadowing — fixed inline). Tiers 3/4/5 shipped with minor fixes (1–3 inline patches per tier, applied without re-review). Reviewer surfaced both [verify on Tier 7] markers as codified integration risks; these are named with fallback mitigations.

## Notes

Tiers 4 and 5 together embed the slice's most architecturally subtle invariants: the {travel, location_node_id} mutex preserved at every save boundary including mid-loop arrival; the Callable seam propagating notifications without Resource-emit re-wiring on load; and the serialized SaveService-write / TravelController-yield ordering, which depends on Godot's empirical FIFO resume order. The first two are robust by design (mutex enforced in `from_dict`; Callables stable across the autoload's lifetime). The third is robust at slice scale but flagged [verify on Tier 7] because the absence of a documented contract is exactly what produces 3 a.m. debugging sessions. Naming the fallback (re-entry guard) keeps future-us from relearning this lesson. After this session the slice is **headless-complete**: every system touching persistent state exists, wires through the Callable seam, and round-trips JSON. Only UI (Tier 6) and entry scene (Tier 7) remain before first runnability.
