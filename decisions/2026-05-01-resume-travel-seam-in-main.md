---
title: Resume mid-travel on boot via seam in Main, not Game
date: 2026-05-01
status: ratified
tags: [decision, architecture, save-system, lifecycle, resume]
---

# Resume mid-travel on boot via seam in Main, not Game

## Decision

When a save is loaded with `trader.travel != null`, `Main._ready()` calls a new public method `TravelController.resume_if_in_flight()` that re-enters `process_tick()` to drive the journey to completion. The call is placed **after** the boot-paint emits in `Main._ready()`. The method is fire-and-forget (no `await`), matching the existing `_on_travel_confirmed` pattern.

Three constraints on the resume path are part of this decision:

1. **Resume must not call `request_travel()`.** That would conceptually re-debit gold (currently blocked by the re-entry guard at `travel_controller.gd:28`, but the intent is wrong). Per `2026-04-29-travel-cost-at-departure`, cost is paid once at departure; resume only drives the existing `travel.ticks_remaining` to zero.
2. **Resume must not decrement `travel.ticks_remaining`.** Saves happen at tick boundaries (per `2026-04-29-tick-on-player-travel`); the partial wall-clock that elapsed pre-refresh is at most one 450ms timer's worth, and losing it is the correct simpler choice.
3. **Resume branching lives in `Main`, not `Game.bootstrap()`.** Same precedent as `2026-05-01-boot-terminal-state-branch-in-main` — terminal-state and in-flight-state branching belong in `Main`; `Game` stays a passive orchestrator.

## Reasoning

The bug surfaced in playtest of the 450ms tick change: refresh during travel left the player permanently stuck — `trader.travel != null` forever, all UI predicates disabled, no progression. Debugger diagnosed as a save-state-restore + lifecycle gap: the save schema correctly captures `travel != null` (the *what*), but the implicit runtime assumption "process_tick is currently running" (the *how*) wasn't reconstituted on load. The coroutine that was awaiting `create_timer(...).timeout` died with the page refresh, and `process_tick()` had exactly one caller (`Main._on_travel_confirmed`), leaving no resume seam.

The bug existed before the slow-tick change but was unreachable manually in a 12ms window. The slow tick widened it from "effectively unreachable" to "trivially reachable" — exactly the failure mode B1 was sequenced to surface. The pipeline did its job in advance of B1's harness even shipping.

Placement after the boot-paint emits ensures the resumed loop's first `tick_advanced` → `SaveService.write_now` captures the freshly-painted state instead of racing the boot-paint. The boot-paint sequence ends with `state_dirty.emit()` flipping `_dirty=true`, so the resume's first tick correctly observes a dirty state.

## Alternatives considered

- **Resume from `TravelController._ready()`.** Rejected — `Main` already owns scene-transition and state-driven branching; the dead-state precedent (`2026-05-01-boot-terminal-state-branch-in-main`) is the same shape.
- **Resume from `Game.bootstrap()`.** Rejected — keeps `Game` a passive orchestrator. Branching on populated state is `Main`'s job.
- **Place `resume_if_in_flight()` before boot-paint.** Rejected — would race the resume's first save-write against the boot-paint emits and capture a less-fresh state.
- **Call `request_travel()` from resume.** Rejected — wrong intent (re-debits gold conceptually, even if blocked by the re-entry guard).
- **Decrement `ticks_remaining` to account for partial wall-clock pre-refresh.** Rejected — saves happen at tick boundaries; one timer's worth of loss is acceptable; the correction would be both unnecessary and hard to compute correctly for the very-first-tick case.

## Confidence

High. Debugger diagnosed, Engineer implemented per the named seam, user playtest confirmed the journey now resumes and completes after refresh.

## Source

- Bug discovered in user playtest of the 450ms tick change.
- Debugger diagnosis (this session) — `process_tick()` had no resume caller; missing seam in `Main._ready()`.
- Engineer implementation in `godot/travel/travel_controller.gd:82-87` and `godot/main.gd:69-72`.
- User playtest confirmation immediately before ratification.

## Related

- [[2026-05-01-boot-terminal-state-branch-in-main]] — the dead-state precedent this mirrors
- [[2026-04-30-boot-paint-three-emit-order]] — the boot-paint ordering that determines resume placement
- [[2026-04-29-travel-cost-at-departure]] — the gold-debit rule resume must not violate
- [[2026-04-29-tick-on-player-travel]] — tick-boundary save semantics that justify not decrementing on resume
- [[2026-05-01-tick-duration-450ms-first-pass]] — the change that made this bug reachable in the first place
- [[2026-05-01-b1-scope-12-failure-modes-5-harness-catchable]] — this is the "phantom travel" failure mode the harness alone cannot catch (see [[b1-test-protocol]] for the runbook companion)
