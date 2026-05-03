---
title: Slice-5.x ships -- save persistence survives refresh; bugs A/B/C and P6 all fixed
date: 2026-05-03
status: ratified
tags: [decision, slice-5x, ratification, save-persistence]
---

# Slice-5.x ships -- save persistence survives refresh; bugs A/B/C and P6 all fixed

## Decision
Slice-5.x is closed. The slice's stated purpose ("save persistence survives refresh -- buy/travel writes commit, file writes are atomic, headless bootstrap is gated") is delivered and verified by user playtest in-editor. Four bugs fixed:

- **Bug A** (buy + refresh resets state). Discrete commit points: `Trade.try_buy` / `try_sell` await `SaveService.write_now()` after their history push. `TravelController.process_tick` arrival branch awaits `write_now()` after `_apply_encounter` and `_trader.travel = null`. Existing tick-coalesced write preserved.
- **Bug B** (travel + refresh corrupts save). Atomic-ish write via `.tmp + rename_absolute`. Architect-verified Godot 4.5.1's `rename_absolute` does internal remove-then-MoveFileW on Windows; the irreducible kill window is covered by orphan-sweep on `load_or_init`. Linux/macOS get true atomicity via `::rename(2)`.
- **Concern C** (headless `--script` writes stub save). Gate at the top of `Game._f6_fallback_bootstrap_if_needed`: if `get_tree().current_scene == null`, return early before the `is Main` check.
- **Bug P6** (pre-existing invariant bug surfaced by slice-5.x). `SaveInvariantChecker._check_history_integrity` was using `world.get_node_by_id(...)` on display names parsed from travel history detail strings ("Underhill->Brackenford"). The lookup never matched because IDs are `node_N`, not display names. P6 fired on every load with travel history, triggering wipe-and-regen in release or assertion-halt in debug. Fix: scan `world.nodes` for matching `display_name`. ~5 lines, no schema impact, no UI change.

Test infrastructure: a new headless harness (`save_persistence_checker.gd`, ~150 lines) ships alongside the existing B1 invariant checker, with a driver scene (`save_persistence_test.tscn`) and a `--script`-mode gate-test entry (`check_headless_bootstrap_gate.gd`). The driver re-runs B1 *after* its 5.x checks populate travel history -- this catches P6-shaped regressions (invariants that are vacuous at bootstrap because the relevant accumulated state hasn't been generated yet).

## Reasoning
The three named bugs (A, B, C) had explicit fix directions in the binding spec at `docs/slice-5x-save-persistence-spec.md`. Engineer shipped them, Reviewer cleared. P6 was *not* in the spec but surfaced during user playtest validation when slice-5.x's correct behavior (atomic write + discrete commit points reliably persisting travel history) reliably exposed P6's broken lookup. The causal chain made it impossible to verify the slice's stated purpose without also fixing P6:

1. Slice-5.x persists travel history reliably on every load.
2. P6's broken lookup fires on every load with travel history.
3. P6's failure path (wipe-and-regen) wipes the world before the player can observe slice-5.x's behavior.
4. Result: slice-5.x's fixes are invisible; the user sees "starts new game on refresh" exactly as before.

Per the slice's stated purpose (not just its named bugs), fixing P6 was in scope -- see [[2026-05-03-scope-expansion-when-discovered-bug-blocks-slice-purpose]] for the precedent.

User in-editor playtest of the original symptoms (buy + refresh, travel + refresh) confirmed: "it is persisted! good work." Both gold/inventory and travel-arrival state survive refresh on desktop.

Web export (itch.io) was tested and the symptoms reproduced before P6 was fixed. After P6 fix, web has not been re-tested -- but the on-disk wire format and invariant logic are platform-shared, so the fix should apply. Web-specific durability (IndexedDB tab-close race) is explicitly out of scope per Director's anti-goals; if web still surfaces a refresh-related regression, that goes to a separate slice with its own measurement.

## Alternatives considered
- **Defer P6 to slice-5.y as carryover** -- rejected: would have shipped slice-5.x with code fixes in place but unverifiable, because every load with travel history would wipe-and-regen before the user could observe behavior. Slice's stated purpose would not deliver.
- **Stop at A/B/C and call slice-5.x done by code-shipped, defer playtest verification** -- rejected: violates the "playtest is part of slice correctness contract" lesson from slice-5 day-2 close ([[2026-05-03-slice-5-save-bugs-deferred-to-5x]]). Code-shipped without playtest verification is not "shipped."
- **Re-engineer the wire format to use IDs in history detail** -- rejected: requires a HistoryEntry schema bump or a UI translation layer at the death screen. Both violate Director's anti-goals (no schema bump, no UI changes). The display-name lookup in P6 is the smallest fix.
- **Test infrastructure: extend B1 in place rather than ship a sibling harness** -- rejected during Designer pass: B1 is shape-invariant (validates the *save blob's structure*); slice-5.x is timing/FS-shaped (validates *file persistence behavior across operations*). Shapes don't compose cleanly; sibling harness is the right factoring.

## Confidence
High. The slice's stated purpose is verified by user playtest. All four bugs have headless invariant tests that pass deterministically. The P6 fix is small (~5 lines) and the harness extension catches future P6-shaped regressions. The user's acceptance ("good work") confirms the end-to-end chain works in real gameplay conditions.

## Source
Today's session: Director scope, Critic guard, Designer spec, Architect resolutions, Engineer pass + cosmetic patch + P6 patch, Reviewer Ship-it, headless harness verification (5.x + post-travel B1 all PASS), user in-editor playtest confirmation.

## Related
- [[2026-05-03-slice-5-save-bugs-deferred-to-5x]] -- the slice-5 close that named A, B, C as carryover
- [[2026-05-03-scope-expansion-when-discovered-bug-blocks-slice-purpose]] -- the precedent that brought P6 into slice-5.x scope
- [[2026-05-03-invariant-harnesses-run-against-post-mutation-state]] -- the testing pattern that prevents future P6-shaped misses
- [[slice-5x-save-persistence-spec]] -- Designer's binding spec, Architect's calls appended
- [[2026-04-29-strict-reject-from-dict]] -- the strict-reject contract Bug B's atomic write protects
- [[2026-05-01-save-corruption-regenerate-release-build]] -- the wipe-and-regen path that P6 was triggering on every load
