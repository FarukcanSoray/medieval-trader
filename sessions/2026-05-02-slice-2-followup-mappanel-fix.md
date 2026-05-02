---
date: 2026-05-02
type: session
tags: [session, slice-2-mapview, bug-fix]
---

# Slice-2 followup -- MapPanel occlusion fix, two-pass pipeline

## Goal

Run the full bug pipeline on the visual-playtest finding (procgen map overlapped HUD panels). Land a structural fix that survives existing decision constraints. Close with decisions ratified and playtest confirming the fix.

## Produced

**Code (modified, nine files):**

- `godot/main.tscn` -- new `HUD/MapPanel` (Control, anchors `(0,0,1,1)`, offsets `(436, 48, -376, -8)`, `mouse_filter=IGNORE`) wraps relocated `MapView`. `World` (Node2D) left empty as reserved seam.
- `godot/main.gd` -- reads `$HUD/MapPanel.size` at `_ready`, threads `Rect2` through `await Game.bootstrap`. `class_name Main` already present.
- `godot/world/map_view.gd` -- added `@export var _map_panel: Control` for explicit parent dependency; TODO marker for slice-3 hover hit-testing.
- `godot/game/world_gen.gd` -- `generate(seed, goods, map_rect: Rect2)`; dropped `POS_BOUNDS` constant; inner-margin shrink derived from rect.
- `godot/world/world_state.gd` -- schema version 1 -> 2; `from_dict` rejects schemas != 2.
- `godot/systems/save/save_invariant_checker.gd` -- version check bumped to 2.
- `godot/systems/save/save_service.gd` -- new `_FALLBACK_MAP_RECT` constant; `load_or_init`/`wipe_and_regenerate`/`_generate_fresh` accept `map_rect`; new public `delete_save()` with `remove_absolute` warning; all five corruption-regen branches set `Game._save_corruption_notice_pending = true`.
- `godot/game/game.gd` -- `_ready` no longer eager-bootstraps; `call_deferred("_f6_fallback_bootstrap_if_needed")` schedules sentinel checking `_bootstrapping`, `world != null`, `current_scene is Main` (order matters).
- `godot/ui/death_screen/death_screen.gd` -- `_on_begin_anew_confirmed` nulls Game refs, calls synchronous `delete_save()`, then `change_scene_to_file`. No await.

## Decisions ratified

**New (5):**

- [[2026-05-02-slice-2-followup-mappanel-owns-map-rect]] -- MapPanel (HUD) holds map_rect; World Node2D reserved.
- [[2026-05-02-slice-2-followup-deferred-bootstrap-f6-sentinel]] -- autoload creates services; Main schedules deferred sentinel for world bootstrap with fallback rect.
- [[2026-05-02-slice-2-followup-begin-anew-delete-save]] -- synchronous `delete_save()` replaces await pattern; nulls before disk-op preserved.
- [[2026-05-02-slice-2-followup-schema-bump-semantic-reinterpretation]] -- `schema_version` bumped 1->2 for semantic reinterpretation of existing fields.
- [[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]] -- five corruption-regen branches (unreadable, unparseable, missing-trader, non-dict-trader, schema-reject) all set corruption notice flag.

**Superseded in part (2):**

- [[2026-04-30-idempotent-bootstrap-signal]] -- three-state guard preserved; "autoload eager-bootstraps" premise reversed to deferred sentinel.
- [[2026-05-01-begin-anew-order-rule]] -- null-refs-before-disk-op rule preserved; await pattern replaced with synchronous `delete_save`.

**Amended (1):**

- [[2026-05-02-slice-2-no-schema-bump-trigger-named]] -- trigger condition extended to cover semantic reinterpretation.

## Pipeline shape

Two passes through Architect -> Engineer -> Reviewer. Architect round 1 spec was complete; Engineer implemented cleanly but surfaced that [[2026-04-30-idempotent-bootstrap-signal]] made the fix non-functional (autoload eager-bootstrap beat Main's panel-rect read). Architect round 2 named the supersession explicitly and reframed bootstrap split into "services" vs "world generation" with deferred F6 sentinel. Engineer round 2 + fix loop addressed Reviewer blockers (delete_save dirty-clear, remove_absolute warning) plus a semantic gap (schema rejection wasn't firing corruption toast). Reviewer round 2 closed cleanly. User playtest confirmed.

Two plain-language step-backs delivered (post-Architect round 2, post-Reviewer round 1; per standing memory rule for 3+ agent rounds).

## Open threads

- **Six review nits deferred to comment-cleanup pass:** `SCHEMA_VERSION` const on WorldState (dedupes literal `2`); `_FALLBACK_MAP_RECT` duplicated between `game.gd` and `save_service.gd`; comment hygiene in `game.gd._ready`, `save_service.gd:101-103`, `death_screen.gd:107-115`, `world_state.gd:116-118`.
- **Reviewer Q1 -- Begin Anew flicker on web export.** New flow has Main paint empty for one frame between scene change and first bootstrap-completion paint. Not yet verified on web build; only desktop visual playtest exercised the fix.
- **Reviewer Q2 -- process question.** Reviewer couldn't find `--check-only`/`--quit` parsing; how is B1 harness invoked in CI/dev? User to answer offline.
- **Four corruption-regen branches untested.** Schema-rejection tested manually (edited save's `schema_version` to 1); file-unreadable, JSON-unparseable, missing-trader, non-dict-trader share the same toast-flag line, reasoned but not exercised.
- **Carryover:** B1 deferred iters 1/4/5, runbook prose-refresh, `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`, travel confirm-modal Cancel button, Tier 7 deferred markers, slice-2.5 tuning pass (~20 worlds, rejection criteria).

## Links

- [[2026-05-02-slice-2-procgen-pipeline]] -- earlier-same-day session; this fix continued from its "MapView occlusion reasoned, not verified" open thread.
- [[slice-architecture]], [[slice-spec]].
- [[CLAUDE]] -- workflow + ASCII rule + project scope.

## Notes

**Two decisions superseded in one session.** First time in the project log a fix rolled back two ratified decisions partially. Architect's framing -- preserving load-bearing parts (three-state guard, null-refs-ordering rule) and naming exactly what reverses -- is the durable shape. Pattern to preserve: when a new constraint reveals an old decision was right for its slice but wrong now, supersede explicitly rather than route around it.

**Decision conflict surfaced in pipeline, not after.** Engineer round 1 caught the [[2026-04-30-idempotent-bootstrap-signal]] collision before Reviewer ran. Cost was one extra Architect pass; gain was avoiding a "fix" that didn't fix anything. Evidence the full-pipeline-no-shortcuts rule is paying for itself.

**Sentinel guard order non-commutative.** `_bootstrapping` first, then `world != null`, then `current_scene is Main`. Real window during `await load_or_init` where `_bootstrapping == true` and `world == null`. Rationale preserved in [[2026-05-02-slice-2-followup-deferred-bootstrap-f6-sentinel]].
