---
date: 2026-05-02
type: session
tags: [session, cleanup, slice-2]
---

# Cleanup pass: slice-2 review nits

## Goal

Land six deferred review nits from [[2026-05-02-slice-2-followup-mappanel-fix]] as a focused Engineer -> Reviewer -> Engineer -> Reviewer cycle. Objective: ship cleanly with no semantic drift.

## Produced

Eight files updated (no new files):

- `godot/world/world_state.gd` -- `const SCHEMA_VERSION: int = 2` extracted; multi-line "Slice-2 follow-up" comment removed.
- `godot/game/world_gen.gd` -- schema assignment now references `WorldState.SCHEMA_VERSION` instead of literal `2`.
- `godot/systems/save/save_invariant_checker.gd` -- `_check_schema_version` uses constant; verbose comment trimmed to 2 lines.
- `godot/systems/save/save_service.gd` -- `_FALLBACK_MAP_RECT` promoted to public `FALLBACK_MAP_RECT`; three verbose comments trimmed (9-line + 3-line + 2-line blocks to 1-2 lines each).
- `godot/game/game.gd` -- `bootstrap()` now uses `SaveService.FALLBACK_MAP_RECT`; deferred-sentinel rationale trimmed 6 -> 3 lines; service-ordering comment removed.
- `godot/ui/death_screen/death_screen.gd` -- code-archaeology comment trimmed 9 -> 3 lines.
- `docs/slice-spec.md` -- JSON example schema_version updated `1` -> `2`.
- `docs/slice-architecture.md` -- three sites updated (Tier-1 entry, boot-table cell, fields list) to reference `SCHEMA_VERSION`.
- `docs/b1-test-protocol.md` -- P3 predicate and example FAIL line updated to reference `SCHEMA_VERSION`.

## Decisions

- [[2026-05-02-from-dict-schema-version-belt-and-braces]] -- `w.schema_version = SCHEMA_VERSION` in `WorldState.from_dict` retained as defensive guard against future `@export` default drift.

## Open threads

- Web-export Begin Anew flicker (Reviewer Q1, [[2026-05-02-slice-2-followup-mappanel-fix]]) -- stays deferred; build-and-test task.
- Reviewer Q2 process question (B1 harness CLI invocation) -- user to answer offline.
- Four corruption-regen branches (file-unreadable, JSON-unparseable, missing-trader, non-dict-trader) -- still untested; reasoned not exercised this cycle.
- Slice-2.5 tuning pass (~20 worlds, rejection criteria ratification) -- named-next per [[2026-05-02-slice-2-5-named-tuning-pass]].
- B1 deferred iters 1/4/5; runbook prose-refresh; `TRAVEL_COST_PER_DISTANCE` needs playtesting; travel confirm-modal Cancel button; Tier 7 deferred markers.

## Links

- [[2026-05-02-slice-2-procgen-pipeline]]
- [[2026-05-02-slice-2-followup-mappanel-fix]]
- [[2026-05-02-slice-2-5-named-tuning-pass]]

## Notes

Cleanup-pass workflow proved viable: six non-blocking review nits identified at prior session close landed in one focused Engineer-direct + two Reviewer passes without semantic drift. Pattern to preserve: defer nits at session close, land in a discrete cleanup session before the next slice. Keeps review discipline while keeping feature pipelines linear.

Incidental finding: doc drift in `docs/` schema_version references surfaced during Reviewer's cross-check. The cleanup pass absorbed the fixes (5 lines total) as adjacent work rather than opening a separate task. Reusable pattern: in-flight cleanup absorbs adjacent stale-doc fixes when small.

Engineer-direct (not subagent) was appropriate for clerical edits with no design content; Reviewer stayed in loop for verification. No roundtrip cost. Worth noting for future cleanup passes -- the GDScript Engineer agent isn't load-bearing on edits this small.
