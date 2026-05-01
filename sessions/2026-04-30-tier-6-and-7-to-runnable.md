---
date: 2026-04-30
type: session
tags: [session, engineer, reviewer, debugger, architect, tier-6, tier-7, runnable]
---

# Tier 6 + Tier 7 — slice runnable

## Goal

Drive the slice from headless-complete to first-runnable. Build five Tier 6 UI scenes, then close Tier 7 (Main + entry wiring), bringing the project to F5-runnable for the first time. Maintain [[2026-04-29-bottom-up-no-sanity-scene]] discipline up through Tier 7's wiring; resolve the two `[verify on Tier 7]` integration markers carried from prior tiers via the live boot path; absorb cross-system bugs through the Debugger lane rather than guessing.

## Produced

- **Tier 6 UI scenes** under `godot/ui/`:
  - `hud/status_bar.tscn`+`.gd`, `hud/node_panel.tscn`+`.gd`, `hud/travel_panel.tscn`+`.gd`, `hud/confirm_dialog.tscn`+`.gd`
  - `death_screen/death_screen.tscn`+`.gd`
  - All signal-driven `_refresh()`, no `_process` polling, all wires code-side via `Callable`s.
- **Helper migration** — `godot/world/world_state.gd` gained `get_node_by_id(node_id) -> NodeState`; five call sites (StatusBar, NodePanel, TravelPanel, DeathScreen, Trade) collapsed onto it.
- **Tier 7 entry** — `godot/main.tscn` and `godot/main.gd` written; `godot/project.godot` updated with `run/main_scene`. Main owns the canonical async `_ready()` ordering, three boot paint nudges, modal travel confirm wiring, and the death-scene change with `await SaveService.write_now()`.
- **`Game` autoload patches** — `godot/game/game.gd` gained an idempotent `bootstrap()` with a stashed `bootstrap_completed` signal; later, the file's `class_name Game` was removed to resolve the Godot 4 autoload-singleton collision.
- **Spec patches** — `docs/slice-architecture.md` updated in §2.1 wiring, §6 folder layout (game.gd line), §7 item 10 (no-class_name on autoload), and §7 item 22 (Tier 7 Main shape).

## Decisions

- [[2026-04-30-world-state-get-node-by-id-helper]]
- [[2026-04-30-death-scene-export-packed]]
- [[2026-04-30-idempotent-bootstrap-signal]]
- [[2026-04-30-boot-paint-three-emit-order]]
- [[2026-04-30-no-class-name-on-game-autoload]]
- [[2026-04-30-tier7-deferred-followups]]

## Open threads

- **First playtest now possible.** Tuning numbers carried as `[needs playtesting]` from prior session: starting gold 100, `WorldGen.DRIFT_FRACTION 0.10`, `PriceModel.DRIFT_FRACTION 0.10`, `TRAVEL_COST_PER_DISTANCE 3`. Designer feedback target.
- **`[verify on Tier 7]` markers** — `world_gen.gd:55-56` (hash byte-stability across desktop/HTML5) and `travel_controller.gd:80-82` (Godot 4 empirical FIFO resume-order on `SceneTree.process_frame`) are now exercisable. Desktop side is live; HTML5 side requires web export.
- **Three deferred Tier 7 follow-ups** — see [[2026-04-30-tier7-deferred-followups]]. Pick up post-playtest.
- **Designer call still pending: years/ticks conversion** for `age_ticks` display. StatusBar and DeathScreen render ticks until ruled.
- **`.tres` UID lines** still deferred — Godot regenerates on first editor open.

## Process notes

Tier 6 ran Engineer → Reviewer with three inline patches (real bug: dictionary-keys mutation during iteration in `travel_panel.gd`), no re-review. Architect ran a short-pass before Tier 7 to resolve Main._ready ordering, the `WorldState.get_node_by_id` helper question, and the PackedScene loading approach. Tier 7 surfaced a cross-system bug (bootstrap re-entry race + StatusBar paint asymmetry) that the Engineer correctly escalated rather than guessed at — Debugger diagnosed both, Engineer applied, Reviewer ratified with one inline patch. The autoload-collision parser error appeared only at first F5 (caught at runtime, not by static review) and was patched into the spec to prevent recurrence.

## Notes

The most architecturally load-bearing artifact this session was the idempotent `bootstrap()` shape. The prior tier's race was latent — every existing `load_or_init()` path happened to assign `Game.world` before any `await`, so the original `if world != null: return` guard accidentally worked. Tier 7 is the first context where two callers of `bootstrap()` co-exist, and the Engineer's instinct to escalate rather than ship a "works today" guard was correct: the Debugger's option-(c) fix (stashed completion signal) is the only one that survives a future async insertion before world assignment, and the order-sensitive boot-paint nudges in Main directly depend on bootstrap being silent on signals — the two decisions are paired. The `class_name`/autoload collision is a Godot 4 idiom worth absorbing into future Architect handoffs; the spec said `class_name Game extends Node`, the Engineer faithfully wrote that, and only the parser objected. Slice is now runnable end-to-end. Death paths exist but the only way to die in the slice is `stranded`, which requires running gold to zero with no affordable travel — exercise it deliberately.
