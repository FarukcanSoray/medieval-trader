---
date: 2026-05-01
type: session
tags: [session, boot, death-screen, save-system, slice-1]
---

# Boot-time terminal-state fix and Begin Anew feature

## Goal

Fix two coupled playtest-driven bugs: (1) dead-state boot landing in a silently no-op HUD instead of the death screen, and (2) the death screen having no restart option, leaving the player permanently stuck after death. Both ran end-to-end through the full pipeline.

## Produced

- `godot/main.gd` — terminal-state branch after `await Game.bootstrap()` redirects to `_death_scene` if `Game.world.dead`.
- `godot/systems/save/save_service.gd` — `wipe_and_regenerate()`, public async method composing `_generate_fresh()` + `write_now()` + `_dirty = false`.
- `godot/ui/death_screen/death_screen.gd` — three new signal handlers (`_on_begin_anew_pressed`, `_on_begin_anew_canceled`, `_on_begin_anew_confirmed`), `_save_service()` helper extracted, await in `_on_quit_pressed`.
- `godot/ui/death_screen/death_screen.tscn` — `BeginAnewButton` above `QuitButton`, `BeginAnewConfirm` instance as sibling of Panel.
- `godot/ui/death_screen/begin_anew_confirm_dialog.gd` (new) — `AcceptDialog` subclass; `add_cancel_button("Cancel")` in `_ready()`.
- `godot/ui/death_screen/begin_anew_confirm_dialog.tscn` (new) — dialog scene with title/body/OK label pre-configured.

## Decisions

- [[2026-05-01-boot-terminal-state-branch-in-main]]
- [[2026-05-01-death-screen-quit-awaits-write-now]]
- [[2026-05-01-restart-entry-on-death-screen]]
- [[2026-05-01-restart-new-world-seed-every-life]]
- [[2026-05-01-restart-requires-confirmation]]
- [[2026-05-01-restart-label-begin-anew]]
- [[2026-05-01-begin-anew-confirm-dialog-separate-class]]
- [[2026-05-01-wipe-and-regenerate-ownership]]
- [[2026-05-01-begin-anew-order-rule]]

## Open threads

- **Tab-close during `await wipe_and_regenerate()`** — DeathScreen lacks `NOTIFICATION_WM_CLOSE_REQUEST` handler (Main has one). Exposure widened by the await but deferred per Architect Q5. Inheriting DeathScreen's existing posture; revisit if real bug surfaces.
- **Quit-handler save flushing semantics** — `_on_quit_pressed` now awaits `write_now()`, but on dead-state boot the prior session's save is the durable one. Sanity-check in next playtest sequence to confirm no edge case.
- **UX divergence between confirm modals** — travel `ConfirmDialog` has no Cancel button; `BeginAnewConfirmDialog` has OK + Cancel. Flagged by Reviewer for future Designer pass; not a Reviewer call.
- **Tier 7 deferred markers still open** from prior slice ([[2026-04-30-tier7-deferred-followups]]) — hash byte-stability and FIFO resume order on HTML5 not verified this session. Web export pass still pending.

## Notes

The preemptive-contract framing of the order rule ([[2026-05-01-begin-anew-order-rule]]) is the architecturally durable artifact this session produced: Reviewer asked whether the "no populated-dead-world during flush" rule was contract-for-future-systems or overstated against current subscribers; user resolved as preemptive. The rule survives future systems being added to `Game` without each one having to re-prove safety. That framing applies to other invariants written defensively against subscribers that don't yet exist.

Boot fix and Begin Anew were tightly coupled — the second gap only became visible after the first shipped. Splitting them across sessions would have masked the design gap behind a "fixed" status. Running both in one session was the right call even though it produced nine decisions.
