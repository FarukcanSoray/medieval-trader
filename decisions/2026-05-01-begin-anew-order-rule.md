---
title: Begin Anew confirm-handler order rule — null Game refs before await, change scene after
date: 2026-05-01
status: superseded-in-part
superseded_by: [2026-05-02-slice-2-followup-begin-anew-delete-save]
tags: [decision, architecture, ordering, signals, slice-1]
---

> **Note (2026-05-02):** Partially superseded by [[2026-05-02-slice-2-followup-begin-anew-delete-save]]. The "null Game refs BEFORE the disk op, change scene AFTER" ordering rule stays valid and is preserved exactly. The `await SaveService.wipe_and_regenerate()` between the null-refs and the scene change is replaced with synchronous `SaveService.delete_save()`; regeneration moves to the new Main scene's bootstrap, which has the real `MapPanel` rect.

# Begin Anew order rule

## Decision
`DeathScreen._on_begin_anew_confirmed` executes in this exact order:

1. `assert(Game.world != null and Game.trader != null, ...)`
2. Resolve `SaveService` via `Game.get_node("SaveService") as SaveService` (asserted non-null).
3. `Game.world = null` and `Game.trader = null` — **before** the await.
4. `await SaveService.wipe_and_regenerate()` — async; propagates the IndexedDB flush.
5. `get_tree().change_scene_to_file("res://main.tscn")` — **after** the await resolves.

## Reasoning
The order is load-bearing for two invariants:

**Null-before-await: subscribers don't observe a populated dead world during the flush.** Between steps 3 and 5, `Game.world` is null. Any signal handler that fires during the await (autoload-children: `SaveService`, `DeathService`) sees null state — the same null state Main's bootstrap branch and `Main._distance_to` already guard against. This is the "subscribers see consistent state during regen" guarantee.

Walking actual current subscribers, none would fire during the await — `gold_changed` and `tick_advanced` are emitted by Trade/Travel/TravelController in the previous scene which is being torn down. The rule is a **preemptive contract for future systems**: if a system gains an autonomous timer or a `_process` body that reads `Game.world` directly, this invariant must still hold. Document the invariant so a future change ratifies or revisits it deliberately.

**Scene-change-after-await: the write must complete before the new scene's first read.** `change_scene_to_file` is deferred to the next idle frame, so this ordering is mostly belt-and-suspenders against a future change that adds synchronous work between the two calls. On web, the IndexedDB flush requires `await get_tree().process_frame` inside `write_now()`; running `change_scene_to_file` before the await resolves would race the flush.

## Alternatives considered
- **Null refs after the await** (clear refs, then change scene; or change scene without nulling). Rejected — opens a window where a stray subscriber could observe `Game.world.dead == true` (the old dead world, not yet replaced) on a populated trader. The future-systems contract is cheaper to honor preemptively.
- **Change scene before the await** (start scene change, then await wipe-and-regenerate in the background). Rejected — fights Godot's deferred-scene-change lifecycle and races the IndexedDB flush.

## Confidence
High on the rule. The "preemptive vs. overstated" question (raised by Reviewer) is captured here as **preemptive**: the rule survives future systems being added to `Game` without each one having to re-prove safety.

## Source
- Designer spec (this session) named the order constraint.
- Architect structural pass (this session): ratified the order with explicit reasoning about subscriber observability.
- Reviewer pass (this session): asked whether the rule was preemptive or overstated; user resolved as preemptive.
- User playtest confirmed.

## Related
- [[2026-05-01-wipe-and-regenerate-ownership]] — the method this handler awaits
- [[2026-05-01-restart-requires-confirmation]] — handler triggers on modal confirm
- [[2026-05-01-begin-anew-confirm-dialog-separate-class]] — dialog whose `confirmed` signal invokes this handler
- [[2026-04-30-idempotent-bootstrap-signal]] — bootstrap idempotency that makes the post-scene-change boot a clean no-op (Main's `await Game.bootstrap()` early-returns on `world != null`, populated by step 4)
- [[slice-spec]] §3 — IndexedDB flush contract
