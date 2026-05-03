# Medieval Trader -- Slice 5.x (Save Persistence) Spec

> **Ratified frame (2026-05-03):** Director scoped slice-5.x to fix three save-persistence bugs surfaced in the slice-5 day-2 playtest. Critic compressed three independent designs into one slice on the grounds that all three are pre-existing, all three concern the save-write timing model, and all three need the same headless-test plumbing to verify. User ratified the design shape per bug.
>
> **Slice statement:** *Save persistence survives refresh -- buy/travel writes commit, file writes are atomic, headless bootstrap is gated.*
>
> **No new mechanics. No schema bump. No UI changes. No web-export durability work** (slice-5.x is desktop/editor first; HTML5 IndexedDB async-flush durability remains the existing `await get_tree().process_frame` contract). **No save-format redesign.** No "while we're in here" cleanups in adjacent persistence code. The encounter-outcome serialization, death-write timing, and IndexedDB async-flush are out-of-scope adjacencies; if a fix below brushes against them, name it and stop.

## 1. Pattern reference

Three patterns, one per bug.

- **Bug A: discrete commit points.** Standard *checkpoint-on-action* pattern (e.g., *Stardew Valley*'s end-of-day write, *Slay the Spire*'s post-encounter write). Each gameplay action that mutates persistent state ends with an explicit `await write_now()`. Deviates from a debounced *dirty-flag* model (which is what `state_dirty` is today). The slice's existing tick-coalesced write during travel **stays** -- per-tick travel writes are already a checkpoint; we are adding non-tick checkpoints for buy/sell/arrival/quit.
- **Bug B: atomic file replace via `.tmp` + rename.** The standard POSIX/Windows pattern for crash-safe writes (git's index, SQLite's WAL, every editor's atomic save). Write to sibling tempfile, fsync-equivalent (Godot's `f.close()` plus the existing `await process_frame` for IndexedDB), then rename over the target. Deviates from a journaled-writes pattern (overkill here) and from a write-in-place pattern (what we have today). Windows-specific: `rename` over an existing target is not atomic on Win32; we open a (smaller) crash window between `remove` and `rename`. The orphan-sweep on load handles the residue.
- **Bug C: bootstrap gate on scene state.** Standard *defensive-autoload* pattern -- autoload that needs the scene tree to exist gates on `current_scene != null`. Deviates from "autoload runs unconditionally" (what we have). One-line guard; no redesign.

## 2. Scope

**In scope:**

1. **Bug A.** Add explicit `write_now()` calls at four commit points: buy success, sell success, travel-arrival, quit. The existing tick-coalesced write during travel is preserved.
2. **Bug B.** Replace `write_now`'s in-place file write with a `.tmp` + rename atomic-replace protocol. Add an orphan-`.tmp`-sweep on load.
3. **Bug C.** Gate `_f6_fallback_bootstrap_if_needed` on `get_tree().current_scene != null` so headless `--script` runs do not write a stub save.
4. **Tests.** Headless invariant tests covering all three fixes, in the existing `SaveInvariantChecker` harness style. Test plumbing decision: see §5.

**Out of scope (anti-goals, name and stop):**

- New schema fields. New signals. New autoloads. UI changes (no toasts, no commit indicators).
- Web-export durability work. The HTML5 IndexedDB `await process_frame` flush stays exactly as it is. If a desktop fix doesn't carry to web cleanly, that's a slice-5.y carryover, not in 5.x.
- Death-write timing. `_on_died` already calls `write_now` synchronously; that path is correct.
- Encounter-outcome serialization shape (`travel.encounter` dict). Untouched.
- "Refactor `write_now` to take a payload arg." Out. The full Game.world + Game.trader blob remains the unit of write (see §3.A).
- Promoting `_find_edge` / `_find_outbound_edge` to `WorldState`. Out.

## 3. Rules

### 3.A -- Bug A: commit-point semantics

**Commit points (binding, exhaustive):**

1. **Buy success** (Trade.try_buy after history-push).
2. **Sell success** (Trade.try_sell after history-push).
3. **Travel arrival** (TravelController.process_tick, on the iteration where `ticks_remaining` reaches 0, after `_apply_encounter` but before the `state_dirty` / `tick_advanced` emits that fire on the same iteration).
4. **Quit** (Main._quit_with_save -- already exists, keep as-is; named here for completeness).

**What each commit point passes to `write_now`:** nothing. `write_now` reads `Game.world` and `Game.trader` directly (existing contract; line 110-111 of `save_service.gd`). The full blob is the unit of write -- no delta concept. This is binding: introducing a delta is its own design pass and is out of scope.

**Call shape for buy/sell.** Trade is a `Node`, not async. The existing `try_buy` / `try_sell` return `bool` synchronously. Two options:

- **Option (a): Trade.try_buy / try_sell become `async` (await'd by their callers).** Caller is `NodePanel.buy_requested` / `sell_requested` signal -> connected to `_trade.try_buy` directly in `main.gd:52-53`. Signals don't await return values, so making them async is fire-and-forget from the caller's perspective. The bool return is then unobservable -- which the codebase doesn't currently rely on (the signal connections discard the return).
- **Option (b): Trade calls `await Game.get_node("SaveService").write_now()` at the end of try_buy / try_sell, but the function stays non-async by chaining the await internally.** This requires a coroutine-from-non-async pattern. Not idiomatic.

**Designer call: option (a).** Trade.try_buy / try_sell become coroutines that `await save_service.write_now()` after the history push, before returning. The bool return is preserved (Godot coroutines can return values; the caller-via-signal simply doesn't read them). This matches the existing pattern in `main.gd:_on_died` and `_quit_with_save`.

**Architect ratifies option (a).** Verified: the only callers of `try_buy` / `try_sell` are the two `signal.connect(...)` calls at `main.gd:52-53`. No other call site reads the bool return; no test scene currently constructs Trade and calls these methods directly. Godot 4 signal handlers may be coroutines -- the engine treats the connected `Callable` as fire-and-forget, the return value (whether bool, void, or a coroutine state) is discarded by `emit_signal`, and a new `emit` does not preempt an in-flight handler from the same emitter (handlers run to first await synchronously, then resume on the awaited completion -- a second emit during the await schedules a second handler invocation that runs *after* the first resumes). Concretely:

- **Half-emitted signal:** does not occur. `emit_signal` returns once the synchronous prelude of every connected handler has run (i.e., up to the first await). Subsequent awaits inside the handler do not retroactively un-emit.
- **Double-fire on rapid input:** sequential by construction. NodePanel.buy_pressed -> handler-1 runs `try_buy` synchronously up to `await write_now()`. A second click during that await emits `buy_requested` again; Godot queues handler-2 to run after handler-1's await resolves. Each `await write_now()` runs to completion before the next is reached. This is the same serialization §3.A's "buy then immediately buy again" already documents.
- **No chain conversion needed.** NodePanel and Main are untouched. The signal connection in main.gd:52-53 stays as-is. Only `try_buy` and `try_sell` gain `await` calls and become coroutines.

The non-async-with-internal-coroutine option (b) is rejected: it requires `call_deferred` or a self-emitted signal to chain the await out of the synchronous return, which is a coroutine-from-non-async pattern. Idiomatic Godot 4 lets a function that contains `await` be a coroutine; the bool return is preserved unchanged.

**Call shape for travel-arrival.** TravelController.process_tick is **already** a coroutine (it has `await` on the wall-clock timer). Add `await save_service.write_now()` on the arrival branch, after `_apply_encounter` and before `Game.emit_state_dirty.call()`. The existing tick-coalesced write fires on the same `tick_advanced` emit a few lines later, but `_dirty == true` was set by the `state_dirty` emit earlier, and our `write_now` already cleared `_dirty` via the `_on_tick_advanced` race-handling pattern (line 168 of `save_service.gd`).

**Wait -- the race.** The existing `_on_tick_advanced` does:

```
_dirty = false   # cleared BEFORE await
await write_now()
```

This is load-bearing: a `state_dirty` fired during the in-flight write is preserved for the next tick. Our explicit arrival-write fires at a different point in the sequence:

1. `_trader.travel = null` (clears mutex).
2. `_apply_encounter(...)` (mutates gold/inventory, fires `state_dirty` via apply_gold_delta / apply_inventory_delta -- sets `_dirty = true`).
3. **NEW: `await save_service.write_now()`** (writes the cleared-mutex + post-encounter state).
4. `Game.emit_state_dirty.call()` (line 90 of travel_controller.gd, the explicit one for the arrival itself -- sets `_dirty = true` again, redundantly).
5. `Game.tick_advanced.emit(...)` (line 97).
6. `_on_tick_advanced` runs synchronously: sees `_dirty == true`, clears it, awaits `write_now()` again.

**Consequence:** an arrival writes the save twice in quick succession. This is **acceptable**. The two writes carry identical content (no state mutates between them). Disk thrash is one extra `~5KB` write per travel arrival -- negligible. Removing the redundant write requires either (a) suppressing the `_on_tick_advanced` write when our explicit one just ran (state machine), or (b) clearing `_dirty` after our explicit write (couples Trade/TravelController to SaveService internals). Neither is worth the coupling. **Let it ride.**

**Buy/sell race -- write-in-flight when another commit fires.** Two scenarios:

- **Buy then immediately buy again** (rapid-fire UI clicks). Each `await write_now()` runs to completion before the next try_buy's await is reached, because Godot's coroutine semantics serialize `await` -- the second click's signal handler is queued but does not preempt the first. **No race; sequential by construction.**
- **Buy fires while travel-tick write is in flight.** Cannot happen by Trade's existing gate: `if _trader.travel != null: return false` (line 14 of `trade.gd`). Trade refuses to act while travelling. The UI is also gated (NodePanel does not present buy/sell UI mid-travel). **Cannot occur.**
- **Quit fires while a buy/travel write is in flight.** Main._quit_with_save awaits `write_now` again. The two awaits run to completion sequentially -- `set_auto_accept_quit(false)` (already in place, `main.gd:27`) keeps the engine alive. The second write is redundant but correct. **Let it ride.**

**Lock-step or queue?** Lock-step. Coroutines serialize naturally on `await`; no explicit queue is needed. If a future feature introduces a writer that does *not* await (e.g., a background autosave on a `Timer.timeout`), this assumption breaks -- name that as a slice-5.y open-question if it ever surfaces.

**The existing `state_dirty` flag stays.** Buy/sell/arrival fire `state_dirty` (via `apply_gold_delta`'s callback chain) AND fire `write_now` directly. The `state_dirty` -> `_dirty = true` path is then read by `_on_tick_advanced`, which produces a redundant write **only when** a tick happens to fire (i.e., during travel). For non-travel buy/sell, no tick is in flight, so `_on_tick_advanced` never runs and the `_dirty` flag sits at true until the next tick advance (which clears it via the existing handler). The flag-stays-true state is not a bug; it's a lossless drift indicator. **Do not touch the flag-management code.**

### 3.B -- Bug B: atomic-write protocol

**Sequence (binding, post-Architect):**

1. Open `user://save.json.tmp` for WRITE. On null: existing one-shot warning, return.
2. `f.store_string(JSON.stringify(blob, "\t"))`.
3. `f.close()`.
4. `await get_tree().process_frame` (the existing IndexedDB-flush-await; preserved).
5. `DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)`. Capture the err; on failure, push_warning and return -- the original save (where present) survives on Linux/macOS; on Windows, the original may already be gone (Godot's internal remove ran), in which case the `.tmp` is the new source of truth and the orphan-sweep on next load deletes it -- crashing back to no-save -> regen. Documented Windows-only failure mode; spec accepts it (§7).

(Designer's prior step 5 -- "on Windows, explicit remove first" -- is dropped: Godot's `rename_absolute` already does the remove internally on Windows, so an explicit one before it is redundant.)

**Per-platform behavior:**

- **Linux / macOS:** `rename(2)` is atomic over an existing target. Skip step 5; step 6 atomically replaces. The window where a kill leaves no `save.json` on disk is **zero**.
- **Windows:** Designer's `MOVEFILE_REPLACE_EXISTING` hypothesis is **wrong**. Godot 4.5.1 source (`drivers/windows/dir_access_windows.cpp`, `DirAccessWindows::rename`, lines 269-311) on the case-different rename branch (`save.json.tmp -> save.json` falls here) does:

    ```cpp
    if (file_exists(new_path)) {
        if (remove(new_path) != OK) {
            return FAILED;
        }
    }
    return MoveFileW(...) != 0 ? OK : FAILED;   // plain MoveFileW, NOT MoveFileExW
    ```

    This is **not** atomic on NTFS. A process kill between `remove(new_path)` and `MoveFileW` leaves only the `.tmp` on disk -- the original `save.json` is gone, the rename never completed. **Godot does the remove-then-rename itself, internally**, so the spec's explicit step 5 (Designer's defensive remove) is redundant -- `rename_absolute` already does it.
  - **Architect's call: drop spec step 5; accept Godot's internal remove+rename window as the irreducible Windows-only failure mode.** The `.tmp + rename_absolute` shape stays. The orphan-sweep on next load handles the residue. The window is small (microseconds-to-milliseconds between Godot's internal `remove` and `MoveFileW`); a kill landing inside it produces "lose the last action" (orphan-sweep deletes `.tmp`, no-save branch regens). This matches §7's documented failure-mode contract -- direction is correct.
  - **Linux/macOS** route through `DirAccessUnix::rename` -> `::rename(2)`, which IS atomic over an existing target (verified `drivers/unix/dir_access_unix.cpp:416`). Zero-window on those platforms.
  - **No platform branch in the GDScript.** SaveService calls `DirAccess.rename_absolute(SAVE_PATH + ".tmp", SAVE_PATH)` unconditionally; the platform-specific atomicity is Godot's concern, not ours. The spec's per-platform behavior is descriptive (what happens on each OS), not prescriptive (no `if OS.has_feature("windows")` branch).
- **Web (HTML5 IndexedDB):** `user://` maps to IndexedDB. `rename_absolute` on IndexedDB-backed `user://` is implemented by Godot's HTML5 platform; the operation is atomic at the IndexedDB transaction level. The `await process_frame` after `f.close()` ensures the IDB transaction has committed. **In scope only to the extent that the existing await stays.** Web-export-specific durability bugs are slice-5.y.

**Orphan-sweep contract:**

- **Trigger:** runs once at the top of `SaveService.load_or_init`, **before** the `FileAccess.file_exists(SAVE_PATH)` check.
- **Looks for:** any file matching `user://save.json.tmp` (one specific path; not a glob -- the only orphan possible is the singleton tmp from a partial write).
- **Action:** `DirAccess.remove_absolute(...)` the orphan. Capture err; on failure, push_warning and continue (load proceeds; an orphan that won't delete is non-fatal -- the next successful write will overwrite it).
- **Why before file_exists:** an orphan could be the only file on disk if the kill happened inside Godot's internal Windows remove+rename window (rename step 5 above) -- the previous save was already removed, the `.tmp` was not yet moved into place. Sweeping first means the no-save branch of load_or_init runs cleanly: fresh world, fresh write, no tmp residue.

**Multiple-`.tmp` edge case:** by construction, only one `.tmp` can exist at a time -- step 1 truncates-on-open. A user could not produce two `.tmp` files via a single playthrough. Possible only if the user manually copies a `.tmp` aside (out of scope) or two engine instances run concurrently against the same `user://` (out of scope; Godot does not support this). **Do not handle.**

**Rename-fails edge case:** original save preserved (on Linux/macOS the rename is atomic; on Windows the remove-then-rename leaves a window but if the rename fails after the remove, the original is gone -- the `.tmp` is the new source of truth on next load). **The orphan-sweep deletes the `.tmp` on next load**, meaning a Windows rename-fail-after-remove crashes back to no-save -> regen. This is the documented Windows-only failure mode; the slice accepts it. Director's anti-goal forbids closing this window further in 5.x.

### 3.C -- Bug C: bootstrap gate semantics

**Gate condition (binding):**

```
func _f6_fallback_bootstrap_if_needed() -> void:
    if _bootstrapping:
        return
    if world != null:
        return
    var current: Node = get_tree().current_scene
    if current == null:        # NEW: headless --script run, no scene tree.
        return
    if current is Main:
        return
    bootstrap()
```

**Why `current_scene == null` is the right check:**

- Headless `--script` runs (Godot CLI with `--script tools/foo.gd`) load no scene; `get_tree().current_scene` is `null`. The autoload still runs `_ready` (autoloads always do), but with no scene, no playthrough is in progress -- writing a save is sabotage.
- F6-isolated scenes (running a single `.tscn` from the editor) have a non-null `current_scene` that is NOT `Main`. The existing `is Main` check covers Main; the new null-check covers headless. Together they triage all three callers correctly: Main run -> Main does its own bootstrap, F6 scene -> autoload self-bootstraps (existing intended behavior), headless -> autoload returns (NEW).
- **Not** `OS.has_feature("editor")` -- editor-vs-export does not partition correctly. F6 in-editor *should* self-bootstrap (existing F6-fallback intent); headless-in-editor *should not*. Editor-feature is too coarse.
- **Not** `OS.has_feature("standalone")` or `--headless` flag introspection -- those are also coarse, and `--headless` does not always imply `--script` (e.g., headless export runs may want a save). The scene-tree predicate is more precise: "is anyone going to play this?"

**Semantic interpretation:** `current_scene == null` means *"no scene was loaded for this run."* The autoload does not know who is running it; `current_scene` is the cleanest available proxy for "interactive playthrough vs. tooling run."

**`Game.bootstrap()` called explicitly from a tool script that *should* write:** out of scope. Currently no such tool exists. If a future tool needs to bootstrap-and-save (e.g., a save-fixture authoring tool), it will call `Game.bootstrap()` explicitly -- the gate above is on the *fallback*, not on `bootstrap()` itself. The explicit bootstrap call still runs. Tools that need a save can author one directly via SaveService. **Document but do not handle preemptively.**

## 4. Numbers

None. The slice introduces no tunable knobs.

## 5. Test infrastructure

**Decision (binding): the existing `SaveInvariantChecker` does NOT extend cleanly. Slice-5.x ships a small new test harness alongside it, in the *same style* (static `check` -> `InvariantReport`-shaped output). Total scope: one new file, ~150 lines.**

**Why not extend B1:** `SaveInvariantChecker.check` is shape-only -- it validates a loaded blob against schema invariants. The slice-5.x bugs are timing- and FS-shaped: "did a write occur before refresh?", "did the rename atomically replace?", "did the gate suppress the headless write?". These are not invariants on the blob; they're invariants on the *write protocol*. Forcing them into B1 would muddy B1's role.

**New harness: `godot/systems/save/save_persistence_checker.gd` (sibling to B1).**

Scope (binding):

1. `static func check_buy_writes(...) -> bool` -- given a fresh world, simulates a buy via Trade.try_buy, asserts `user://save.json` exists post-await, asserts its content reflects the buy (gold decremented, inventory key incremented).
2. `static func check_travel_arrival_writes(...) -> bool` -- similar, for arrival. Constructs a 1-tick travel; awaits process_tick; asserts post-arrival save content.
3. `static func check_atomic_replace_orphan_sweep(...) -> bool` -- writes a stub `.tmp` orphan via direct FileAccess; runs `load_or_init`; asserts the orphan is gone, the original load succeeded.
4. `static func check_headless_bootstrap_gate(...) -> bool` -- mocks `current_scene == null` (run via `--script`, the actual headless path); asserts no `user://save.json` is written. **This one runs as a real `--script` invocation, not as a `check_*` static call from inside a scene** -- the gate's whole point is the scene tree state. The "test" is the `--script` run itself, plus a manual check that no save file was created. (Logged as a one-line manual-test instruction in the slice's playtest plan; the other three are static `check_*` calls runnable from a test scene.)

**The new harness is run from a test scene** (`godot/systems/save/save_persistence_test.tscn`, sibling to `save_persistence_checker.gd` and `save_invariant_checker.gd`) plus a `--script` entry point for the headless test. Engineer wires the boilerplate.

**Architect's placement call: under `godot/systems/save/`** (sibling to B1's `save_invariant_checker.gd`).

- **Trade-off accepted:** B1 has no test scene today (it runs in-line during `Game.bootstrap`); save-persistence harness is the first invariant-checker that needs an isolated runner. Placing it next to the system it validates means the save folder grows a 5th file (`save_persistence_checker.gd`) and a 6th (`save_persistence_test.tscn`) -- it's no longer a tiny folder, but it's still a single-system folder and the pairing is obvious to a reader.
- **Rejected: `godot/tools/`** (precedent: `measure_bias_aborts.gd`). Tools is for one-off measurement / fixture-authoring scripts -- single-purpose, often deletable, oriented at the engineer's workflow. The persistence harness is not single-purpose; it's the test surface for an ongoing system invariant. Lumping it with tools blurs the "tool I throw away" / "test I keep" line.
- **Rejected: new `godot/tests/` folder.** Nothing in the project uses it, the slice's done-definition explicitly forbids "build a unit-test framework" (§5), and creating a tests-root for a single 150-line harness is the kind of one-line precedent that becomes a sinkhole once slice-5.y opens "consolidate save tests." If slice-5.y promotes test plumbing to its own concern, *that* slice creates `godot/tests/` and migrates B1 + persistence-checker into it. Slice-5.x does not pre-empt that.
- **Headless `--script` entry for check 4:** lives at `godot/systems/save/check_headless_bootstrap_gate.gd`, runnable as `godot --headless --script systems/save/check_headless_bootstrap_gate.gd`. It is a peer file to the harness, not a child folder; the slice's done-definition treats it as a one-line manual playtest instruction, not a test-runner subsystem.

**Risk this bloats the slice:** the harness is one file, four static checks, no new framework. The headless `--script` run is a one-line manual instruction in the playtest plan. If the harness creeps past 200 lines, **stop and hand back to Designer.** The slice's done-definition includes "headless invariant tests cover each fix" -- not "build a unit-test framework."

**Slice-5.y carryover (named):** if the harness reveals systemic gaps in test plumbing (e.g., we keep needing per-bug ad-hoc harnesses), slice-5.y opens "consolidate save tests into a real framework." Not in 5.x.

## 6. Feedback (programmer-art level)

The slice is invisible to the player by design. Feedback is all programmer-side:

- **Bug A:** the existing `print` from B1 harness PASS lines is the model. No new prints. Engineer can add one transient `print("[5.x] write committed at <commit point>")` line during implementation to verify each commit fires, **but must remove it before merging.** No production logging.
- **Bug B:** `push_warning` on every error path (open-tmp-fail, remove-fail, rename-fail, orphan-sweep-remove-fail). Existing one-shot `_warn_once_no_save` flag is preserved for the open-tmp-fail (it's the same "no IDB" / "read-only filesystem" condition).
- **Bug C:** silent. The gate's job is to do nothing. No log; the absence of a stub `save.json` after a `--script` run is the signal.
- **Player-visible feedback:** none. Specifically:
  - No "save committed" toast on buy / sell / arrival. The whole point is invisibility.
  - The corruption toast on load (existing `consume_save_corruption_notice`) stays exactly as is. If Bug B's atomic-replace eliminates corruption-on-refresh, fewer toasts will fire -- that's the fix landing, not a UX change.

## 7. Edge cases and failure modes

- **Buy fires, write completes, player kills process before next frame.** Save survives. Bug A fix landed.
- **Buy fires, kill during `store_string` of `.tmp`.** `.tmp` exists, possibly truncated; `save.json` is still the previous good state. Next load: orphan-sweep deletes the truncated `.tmp`, load_or_init reads the previous good save. **Player loses the unsaved buy** -- this is the irreducible window between action and disk. Acceptable.
- **Travel arrival, kill during the post-arrival `await write_now()`.** Same as above -- truncated `.tmp` on disk, original `save.json` unchanged, orphan-swept on load. Player respawns at origin with full gold. **This is a regression from current behavior** (where the partial-write-of-`save.json` corrupts and triggers a regen). Direction is correct: corruption-on-refresh becomes "lose the last action," not "lose the world." Bug B fix landed.
- **Buying with full inventory and zero gold.** Existing `apply_gold_delta` returns false on negative-gold; Trade.try_buy returns false before the `await write_now()` is reached. **No save fires on a failed buy.** Inventory has no max in slice-5; "full inventory" doesn't apply. Death-trigger interaction: a buy that drops gold to exactly 0 may strand the player on next travel attempt; that's the existing DeathService path, unchanged. **No new edge case.**
- **Travel ticks_remaining=1 with a populated EncounterOutcome.** The arrival branch runs `_apply_encounter` (which mutates gold via apply_gold_delta, fires state_dirty), then our new `await write_now()`, then the `state_dirty` and `tick_advanced` emits. The save written reflects: trader at destination (mutex on location side), gold post-encounter, inventory post-encounter, history with encounter entry, `world.tick` incremented. Mutex invariant holds. **No new edge case beyond §3.A's redundant-write note.**
- **Two refreshes in rapid succession.** Each load runs orphan-sweep + load_or_init. The first refresh leaves the player at the post-buy state on disk; the second refresh reads that state. **No race.** Godot's `user://` is locked-per-process; concurrent reads from a second process are out of scope (slice constraint).
- **Player buys, then travels, then quits before arrival.** Sequence of writes:
  1. Buy: `await write_now()` from try_buy. Save reflects buy.
  2. Travel-confirm: `request_travel` mutates trader.travel + gold; fires `state_dirty`. No explicit write here. **`process_tick` starts.**
  3. Each tick during travel: `tick_advanced` -> `_on_tick_advanced` -> `await write_now()` (existing behavior, unchanged).
  4. Player quits mid-travel: `NOTIFICATION_WM_CLOSE_REQUEST` -> `_quit_with_save` -> `await write_now()`. Save reflects mid-travel state with `ticks_remaining` populated.
  5. Engine quits.
  - **Quit-mid-travel preserves the in-flight travel.** Next launch: `resume_if_in_flight` (existing, `main.gd:75`) restarts process_tick. Bug A and Bug B fixes are both load-bearing here.
- **Quit before any commit point fires.** First-launch boot runs `load_or_init`'s no-save branch, which calls `await write_now()` directly (line 24 of save_service.gd). That write goes through the new atomic-replace protocol. **First write of a fresh save uses the same code path as steady-state writes.** No special-casing.
- **Editor Stop on Windows (the original repro).** Editor Stop sends SIGTERM-equivalent without `NOTIFICATION_WM_CLOSE_REQUEST`. The buy-write commit point in §3.A means the save was already on disk **before** Editor Stop fires. The atomic-replace means a write-in-flight at Stop-time leaves the previous good save intact. **Both fixes converge on this case.** This is the playtest-reproducible scenario.
- **Headless `--script` run with no save on disk.** Pre-fix: stub save written. Post-fix: gate returns; no save written. **Verified by §5 check 4.**
- **Headless `--script` run with an existing save on disk.** Pre-fix: gate already returned (`world != null` check at line 111). Post-fix: same; new check is one earlier and identical-outcome. **No behavior change for this case.**
- **F6-isolated scene that is not Main.** Pre-fix: autoload self-bootstraps with fallback rect, writes a save (existing F6-fallback-intent). Post-fix: same -- `current_scene` is non-null, `is Main` is false, falls through to bootstrap. **No behavior change.**
- **Web export with IndexedDB private-mode (no IDB).** `FileAccess.open` returns null; existing `_warn_once_no_save` fires. The atomic-replace protocol's first step (open `.tmp`) hits the same null and returns. **No new failure mode.** Web durability is slice-5.y.
- **Orphan `.tmp` already exists from a prior run, valid JSON, larger than current save.** Orphan-sweep deletes it unconditionally. **Correct:** the `.tmp` is by definition not the canonical save; the rename-step never ran for it, so it's untrusted. No salvage attempt. (A salvage path would be its own design; out of scope.)
- **Orphan `.tmp` that won't delete (read-only flag, AV lock).** push_warning, continue. Next successful write overwrites the `.tmp`. **No retry loop.**
- **`delete_save` (existing, `save_service.gd:120`).** Removes `save.json` only; does not touch `.tmp`. **Designer call:** extend `delete_save` to also remove a `.tmp` if present, mirroring the orphan-sweep. One-line extension; in scope as a defensive cleanup tied to Bug B. Engineer adds it. **Architect ratifies (single extended method, no helper split):**
  - **One method, two `remove_absolute` calls.** `delete_save` becomes: clear `_dirty`; `remove_absolute(SAVE_PATH)` with the existing warning; `remove_absolute(SAVE_PATH + ".tmp")` with a parallel warning. Two lines added; no new function.
  - **Rejected: split into `delete_save` + private `_sweep_tmp` helper called by both `delete_save` and `load_or_init`.** Tempting on DRY grounds, but the orphan-sweep on load wants its own warning text ("orphan-sweep: ...") distinct from delete_save's ("delete_save: ..."), and the loadtime sweep is a single line of disk I/O -- factoring it out costs more in indirection than it saves in dedup. Keep both inline; if a third caller appears in slice-5.y, promote then.
  - **Begin Anew + regen interaction:** the Begin Anew flow (`death_screen.gd:_on_begin_anew_confirmed`) calls `delete_save()` then `change_scene_to_file("res://main.tscn")`. The new Main bootstraps, which runs `load_or_init`. With `delete_save`'s tmp-sweep in place, `load_or_init`'s tmp-sweep is redundant on the Begin Anew path -- but it stays. Reason: `load_or_init` is also the entry from cold boot, F6, and forward-port, where no `delete_save` ran. The sweep belongs in both places; the Begin Anew double-sweep is one extra `remove_absolute` on a non-existent file (no-op, no warning -- `remove_absolute` returns OK on missing files per its docs and we already handle the err code). Cost: one cheap syscall on Begin Anew. Worth it for the symmetry.
  - **wipe_and_regenerate is unchanged.** It calls `_generate_fresh` then `write_now`; the fresh write goes through the new atomic protocol (`.tmp + rename`), which leaves no orphan on success. No tmp-sweep call here.

## 8. Integration touchpoints

| Touch point | Files | Owner | Change |
|---|---|---|---|
| Buy-write commit | `godot/travel/trade.gd` | Trade | `try_buy` becomes async; awaits `Game.get_node("SaveService").write_now()` after history-push. |
| Sell-write commit | `godot/travel/trade.gd` | Trade | `try_sell` becomes async; same shape. |
| Arrival-write commit | `godot/travel/travel_controller.gd` | TravelController | `process_tick` arrival branch awaits `write_now()` after `_apply_encounter`, before the `state_dirty` emit. |
| Atomic write protocol | `godot/systems/save/save_service.gd` | SaveService | `write_now` uses `.tmp` + `rename_absolute`. No per-platform branch (Architect's A2 call: Godot's Windows rename does the remove internally; spec accepts the small Windows window per §7). |
| Orphan sweep | `godot/systems/save/save_service.gd` | SaveService | `load_or_init` runs orphan-sweep at the top, before `file_exists` check. |
| `delete_save` extension | `godot/systems/save/save_service.gd` | SaveService | Also remove `save.json.tmp` if present. |
| Bootstrap gate | `godot/game/game.gd` | Game | `_f6_fallback_bootstrap_if_needed` adds `current_scene == null` early-return. |
| New test harness | `godot/systems/save/save_persistence_checker.gd` (NEW) + `save_persistence_test.tscn` (NEW) + `check_headless_bootstrap_gate.gd` (NEW, --script entry) | SaveService neighborhood | Static `check_*` methods + scene to drive them. Architect's placement call: all three live under `godot/systems/save/` next to B1. |

**Trade's signal contract.** `node_panel.buy_requested` and `sell_requested` connect directly to `_trade.try_buy` / `_trade.try_sell`. Godot's signal system fire-and-forgets the return; making try_buy/try_sell coroutines does not break the connection. **Architect verifies** that no other caller reads the bool return (Designer's read says no, but Architect's structural call covers this).

**Main's bootstrap flow.** Unchanged. `await Game.bootstrap(...)` still runs; the new gate in `_f6_fallback_bootstrap_if_needed` only affects the deferred-fallback path, not Main's explicit call.

**B1 harness order.** Unchanged. B1 still runs in `Game.bootstrap` after `load_or_init`. Slice-5.x's new harness runs only from the test scene / `--script` runner -- not in production boot.

## 9. Open questions

- **[Architect resolved 2026-05-03]** Trade.try_buy / try_sell becoming coroutines. Verified: only callers are the two signal-connects in main.gd:52-53; bool return is discarded; signal handlers may be coroutines in Godot 4. Option (a) ships. See §3.A.
- **[Architect resolved 2026-05-03]** Godot 4.5.1's `DirAccess.rename_absolute` Windows behavior. Source-verified: NOT atomic; uses `file_exists` -> `remove` -> `MoveFileW` (no `MOVEFILE_REPLACE_EXISTING`). Spec drops explicit step 5 (Godot does it internally), accepts the small Windows window as documented failure mode. See §3.B.
- **[Architect resolved 2026-05-03]** Test scene placement: `godot/systems/save/` (sibling to B1). Tools is for one-off scripts; new tests/ folder is sinkhole-shaped for one harness. See §5.
- `[needs playtesting]` After fix lands: does the buy + refresh case hold across 10 buys? 100? Does travel + refresh produce zero corruption toasts across 20 trips? The playtest reproduces the original symptoms first (on a build before the fix), then runs the same actions on the post-fix build.

## 10. Anti-goal watch (Engineer reads this)

Director's binding rules, repeated for the Engineer:

- **No new mechanics. No schema bump. No new signals. No UI changes.** If you find yourself wiring `state_dirty` to a new subscriber, or adding a field to `TraderState`, or routing a "save committed" signal to the HUD -- **stop.** Hand back to Designer.
- **No web-export durability work.** The HTML5 IndexedDB `await get_tree().process_frame` after `f.close()` is the existing contract; preserve it exactly. If you find yourself adding async-flush retry loops or IDB transaction polling, **stop.**
- **No save-format redesign.** No version bump. No new top-level keys. The blob shape is stable.
- **No "while we're in here" cleanups.** If you spot a dead `_warn_once_no_save` reset path, or an awkward `_dirty` flag interaction, or a redundant `await` -- **leave it.** This slice ships three fixes, not a cleanup pass. Log defensively-shaped owe-notes via DecisionScribe instead.
- **Encounter-outcome serialization untouched.** The `travel.encounter` dict shape is what it is. If your atomic-write protocol changes how the dict is JSON-encoded, you've gone out of scope.
- **Death-write timing untouched.** `_on_died` calls `await write_now()` and that's correct. Do not move it, wrap it, or coalesce it.

**Engineer-side translation of Bug C's anti-pattern guard:** the gate is one early-return in one function. If you find yourself splitting the autoload, factoring out a "scene-tree-state predicate" helper, or auditing other autoloads for similar gates -- **stop.** One file, one function, four lines added. Anything else is slice creep.

---

## Hand off to Architect

The Architect must make four structural calls before the Engineer touches code:

1. **Trade.try_buy / try_sell coroutine conversion.** Verify the signal-callsite contract holds (the bool return is unread; making the function async fire-and-forgets cleanly). If a non-async path is structurally preferred, ratify option (b) from §3.A and Designer revises.
2. **Windows `rename_absolute` semantics on Godot 4.5.1.** Verify whether `MOVEFILE_REPLACE_EXISTING` is set. Decides whether the explicit-remove fallback ships or the protocol is identical across platforms.
3. **Test scene placement and entry-point shape.** Where the new test scene lives; whether the headless `--script` test ships as a tool script or as part of the harness.
4. **`delete_save` extension.** Confirm extending `delete_save` to remove the `.tmp` orphan is the right shape (vs. relying on the orphan-sweep on next load to clean it). Designer's lean is yes -- extending closes the cleanup-on-Begin-Anew gap. Architect ratifies.

The slice's done-definition is binding (Director): all three bugs reproduce-fixed, headless invariant tests cover each fix, one explicit playtest reproduces original symptoms and confirms survival, DecisionScribe entry names the timing model. Engineer should not author any code path until the four Architect calls land.

Designer is unblocked. Spec is binding for the Engineer once Architect ratifies the four calls above. Numbers in this slice: none.

---

## Architect's calls (2026-05-03)

All four Designer-flagged calls resolved. Engineer is unblocked.

1. **A1 -- Trade coroutine conversion (option (a)).** `try_buy` / `try_sell` become coroutines that `await save_service.write_now()` after the history push. Only callers are the two `signal.connect` lines in `main.gd:52-53`; the bool return is discarded by `emit_signal`. Godot 4 signal handlers may be coroutines (engine treats the return value as fire-and-forget); rapid clicks queue handler-2 to run after handler-1's await resolves -- sequential by construction, no half-emit, no double-fire. NodePanel and Main are not touched. (Spec §3.A.)

2. **A2 -- Windows `rename_absolute` is NOT atomic; drop explicit step 5.** Source-verified in `drivers/windows/dir_access_windows.cpp:269-311`: Godot 4.5.1 does `file_exists` -> `remove` -> plain `MoveFileW` (no `MOVEFILE_REPLACE_EXISTING`). Designer's hypothesis was wrong, but the consequence is benign: Godot already does the remove-then-rename internally, so the spec's explicit step 5 was redundant. Drop it. The small Windows window between Godot's internal `remove` and `MoveFileW` is the irreducible failure mode -- a kill there leaves only the `.tmp` on disk; orphan-sweep cleans it on next load -> "lose the last action," matching §7's accepted contract. Linux/macOS use `::rename(2)`, atomic over existing target. No platform branch in GDScript -- the `.tmp + rename_absolute` shape ships unchanged across platforms. (Spec §3.B.)

3. **A3 -- Test placement: `godot/systems/save/`** (sibling to B1's `save_invariant_checker.gd`). All three new files (`save_persistence_checker.gd`, `save_persistence_test.tscn`, `check_headless_bootstrap_gate.gd`) live there. Rejected `godot/tools/` (that's for one-off measurement scripts, not ongoing invariant tests) and a new `godot/tests/` folder (sinkhole-shaped for a single 150-line harness; if slice-5.y consolidates test plumbing, *that* slice creates the folder and migrates B1 + persistence-checker together). (Spec §5.)

4. **A4 -- `delete_save` extends in place; no helper split.** Two `remove_absolute` calls inline in `delete_save` (one for `save.json`, one for `save.json.tmp`), each with its own warning text. Rejected the `_sweep_tmp` helper because the loadtime sweep wants a different warning prefix and the dedup saves less than the indirection costs. Begin Anew flow gets a redundant tmp-sweep on next-Main's `load_or_init` (one cheap syscall on a non-existent file, no-op) -- accepted for symmetry. `wipe_and_regenerate` is unchanged. (Spec §7 edge-case bullet on `delete_save`.)
