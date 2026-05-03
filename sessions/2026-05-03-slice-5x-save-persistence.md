---
date: 2026-05-03
type: session
tags: [session, slice-5x, save-persistence, bug-closure]
---

# Slice-5.x close -- save persistence bugs fixed, P6 discovered and patched, slice purpose delivered

## Goal

Fix three save-persistence bugs that [[2026-05-03-slice-5-day-2-close]] playtest surfaced (A: buy + refresh resets state; B: travel + refresh corrupts save; C: headless writes stub save). Slice-5.x's stated purpose: "Save persistence survives refresh -- buy/travel writes commit, file writes are atomic, headless bootstrap is gated." Also surface and resolve any bugs blocking that purpose during implementation.

## Produced

**Code (modified, 4 files):**

- `godot/travel/trade.gd` -- `try_buy` and `try_sell` become coroutines awaiting `SaveService.write_now()` after history push. Bool return preserved; signal handlers untouched.
- `godot/travel/travel_controller.gd` -- `process_tick` arrival branch awaits `write_now()` after `_apply_encounter` and `_trader.travel = null`.
- `godot/systems/save/save_service.gd` -- `write_now` writes `.tmp` then atomic-ish `rename_absolute`; `load_or_init` runs `_sweep_orphan_tmp()` at entry; `delete_save` cleans `.tmp` files.
- `godot/game/game.gd` -- `_f6_fallback_bootstrap_if_needed` adds early-return guard: `current_scene == null`.

**Code (new, 4 files):**

- `godot/systems/save/save_persistence_checker.gd` -- four static `check_*` methods verifying buy writes, travel-arrival writes, orphan-tmp sweep, and atomic-rename behavior.
- `godot/systems/save/save_persistence_test.gd` -- in-scene driver running four persistence checks. Mid-session extended to re-run B1 after 5.x checks populate travel history.
- `godot/systems/save/save_persistence_test.tscn` -- harness scene.
- `godot/systems/save/check_headless_bootstrap_gate.gd` -- `--script` entry verifying no save written under headless gate.

**Code (patched, 1 file mid-session):**

- `godot/systems/save/save_invariant_checker.gd` -- P6 root-cause fix: `_check_history_integrity` now scans `world.nodes` for matching `display_name` instead of calling `get_node_by_id`. ~5 lines.

**Spec:**

- `docs/slice-5x-save-persistence-spec.md` -- Designer's binding spec with four Architect calls appended and resolved.

## Decisions ratified

- [[2026-05-03-slice-5x-ships-save-persistence-restored]] -- slice closure: A, B, C all fixed; P6 discovered-and-patched; slice purpose ("save persistence survives refresh") delivered; user verified in-editor.
- [[2026-05-03-scope-expansion-when-discovered-bug-blocks-slice-purpose]] -- precedent: when a discovered bug (not named in slice scope) blocks the slice's stated purpose and four conditions hold, scope expands to include it. Documents P6's approval path.
- [[2026-05-03-invariant-harnesses-run-against-post-mutation-state]] -- testing pattern: invariants on accumulated state must run *after* representative mutation, not just at bootstrap. B1 had run only pre-history; P6 went undetected until B1 ran post-travel. Layered runs are the shape.

## Pipeline shape

Full pipeline front-half: Director (scope) -> Critic (reduced A to discrete commit points) -> Designer (binding spec) -> Architect (4 calls resolved, including source-verified Windows atomic-rename behavior in Godot 4.5.1).

Engineer round 1 (A, B, C fixes + harnesses) -> round 2 (cosmetics) -> Reviewer (Ship-it). Then headless harness verification -> user playtest -> P6 surfaces -> scope-expansion call -> Engineer (P6 patch + harness extension) -> verification -> user playtest ("it is persisted! good work") -> Decision Scribe -> session note.

## Open threads

**Slice-5.y candidates (named, not built):**

- Web-export durability. itch.io test completed *before* P6 fix; not re-tested after. If web surfaces a refresh regression, that slice measures it separately (likely involving JavaScript bridge verification of IndexedDB durability before tab close).
- Editor Stop not a quit signal. Windows desktop: editor Stop kills process without firing `NOTIFICATION_WM_CLOSE_REQUEST`. Atomic-write covers travel (orphan-sweep on load); a buy within ~1 frame of Stop can still be lost. Accepted limitation; user playtest didn't reproduce.
- Test isolation. Both B1 and slice-5.x harness write to production `user://save.json`, destroying the user's real save when the test scene runs. Pre-existing tradeoff; slice-5.y cleanup candidate if test plumbing consolidates.

**Carryover from prior sessions (unchanged):** bandit goods-loss fraction retune at N=4; producer-threshold-fraction revisit at N=4; weight/cargo capacity (Branch C-weight follow-up); reverse-walk bump loop in `measure_bias_aborts.gd` if placement-starvation skip masks predicate-fail signal; B1 deferred iters 1/4/5; runbook prose-refresh; `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`; travel confirm-modal Cancel button; web-export Begin Anew flicker.

**Uncommitted state:** All slice-5.x work in the working tree. Commit after session note approval.

## Notes

**The invariant harness blind spot is the load-bearing lesson.** B1 had P6 wired as a predicate correctly; it just never had the inputs (travel history) to fire. Bootstrap-time invariant runs catch boot-shape bugs but are vacuous for accumulated-state invariants. The third decision codifies the layered-run pattern (boot + post-mutation) for all future harnesses.

**Cache stale hit a third time.** Today's headless runs required `--import` refresh after `class_name SavePersistenceChecker` landed. Third occurrence in three days; pattern and recovery are documented at `feedback_class_cache_stale.md`.

**"Slice ships unverifiably broken" was the near-miss.** Code-correct fixes with harness green but user-unobservable behavior (P6 wipe-and-regen on every load) would have shipped if playtest didn't happen. The standing discipline -- "user playtest is part of correctness contract" from day-2 close -- caught it. Don't let harness green substitute for playtest.

## Links

- [[2026-05-03-slice-5-day-2-close]] -- prior session; bugs were carryover from its playtest
- [[slice-5x-save-persistence-spec]] -- Designer's binding spec
- [[feedback_carryover_check_protocol]] -- governs open-thread carryover decisions
- [[feedback_class_cache_stale]] -- the cache-stale recovery pattern, hit again today
