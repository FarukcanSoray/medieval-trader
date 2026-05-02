---
title: Begin Anew uses delete_save + scene change instead of awaited wipe_and_regenerate
date: 2026-05-02
status: ratified
tags: [decision, architecture, lifecycle, slice-2-followup]
supersedes: [2026-05-01-begin-anew-order-rule]
---

# Begin Anew uses delete_save + scene change

## Decision

`DeathScreen._on_begin_anew_confirmed` executes in this order:

1. `assert(Game.world != null and Game.trader != null, ...)`
2. Resolve `SaveService` via `Game.get_node("SaveService") as SaveService` (asserted non-null).
3. `Game.world = null` and `Game.trader = null` -- **before** the disk op.
4. `SaveService.delete_save()` -- **synchronous**; removes `user://save.json` if present, warns on `remove_absolute` failure.
5. `get_tree().change_scene_to_file("res://main.tscn")`.

The new Main scene's `_ready` runs `bootstrap(seed_override, real_rect)` with `$HUD/MapPanel.size`; `load_or_init` sees no save and takes the fresh-generation branch.

## Reasoning

Begin Anew previously called `await SaveService.wipe_and_regenerate()` directly. That ran with no panel rect (DeathScreen has no `MapPanel` of its own) and locked in the fallback rect for the next Main scene -- the same race shape as the boot-order issue addressed in `[[2026-05-02-slice-2-followup-deferred-bootstrap-f6-sentinel]]`.

Moving regeneration to the new Main avoids the race: regen-with-real-rect is *always* Main's job, and "Begin Anew" is conceptually "delete and replay boot." `delete_save()` is synchronous (file removal, no IndexedDB flush needed), so the await disappears.

## Supersedes

Partially supersedes `[[2026-05-01-begin-anew-order-rule]]`:

- **Stays valid:** "null Game refs BEFORE the disk op, change scene AFTER" ordering rule. Step 3 (null refs) precedes step 4 (delete) precedes step 5 (scene change). The "subscribers don't observe a populated dead world during the swap" invariant is preserved.
- **Replaced:** `await SaveService.wipe_and_regenerate()` between the null-refs and the scene change. Now it's `SaveService.delete_save()` (sync) instead, and regeneration moves to the new Main scene's bootstrap.

## Alternatives considered

- **Keep `wipe_and_regenerate` but plumb a rect from somewhere.** Rejected: DeathScreen has no `MapPanel` to read from, and reading the next Main scene's panel before the scene exists is a fundamental ordering inversion.

## Confidence

High. Architect explicitly walked the supersession; Engineer implemented; Reviewer round 2 closed; user-confirmed playtest.

## Source

Slice-2 follow-up session (2026-05-02). Architect round 2 §3.5; Engineer round 2; Reviewer round 2.

## Related

- [[2026-05-01-begin-anew-order-rule]] -- partially superseded; ordering rule preserved
- [[2026-05-01-wipe-and-regenerate-ownership]] -- still owns the regen seam, just not invoked from Begin Anew now
- [[2026-05-02-slice-2-followup-deferred-bootstrap-f6-sentinel]] -- the boot-order shape that lets the new Main's bootstrap own regen
- [[2026-04-30-death-scene-export-packed]]
