---
date: 2026-05-03
type: session
tags: [session, slice-5, goods-expansion, gated-continuation]
---

# Slice-5 day-2 close -- iron addition, measurement gate pass, playtest save-bug discovery

## Goal

Execute slice-5 day-2 (iron catalogue entry and measurement gate at N=4), validate forward-port on load, and close the slice with decisions ratified. Measurement gate gates day-2; day-2 success gates the slice ship. The session also surfaced three save-persistence bugs in playtest; determine whether they block the slice or carryover to slice-5.x.

## Produced

**Code (modified, 2 files):**

- `godot/game/game.gd` -- iron preload appended to `goods` array after salt. Catalogue is now `[wool, cloth, salt, iron]`.
- `godot/tools/measure_bias_aborts.gd` -- extended for day-2: `GOOD_PATHS` list now includes iron.tres; `N_SWEEP` extended from `[2, 3]` to `[2, 3, 4]`; `GATE_N` constant changed from 3 to 4; top doc-comment and verdict-block labels updated to post-day-2 state. Cosmetic Engineer pass in round 2 cleaned stale commentary.

**Code (new, 1 file):**

- `godot/goods/iron.tres` -- expensive-stable fourth good (id="iron", display_name="Iron", base=22, floor=14, ceiling=32, vol=0.05). Role and shape match salt.tres, establishing the expensive-stable corner of the 2x2 taxonomy.

**Measurement and validation:**

Headless `tools/measure_bias_aborts.gd` ran over 1000 seeds at each N in {2, 3, 4}. Result: **0.0% abort rate at N=4**. B1 invariant harness clean (P1-P6 pass). Per-good `allowed_range` histograms at N=4 matched Designer's pre-measurement prediction exactly: wool in [0.30, 0.40), cloth in [0.20, 0.30), salt in [0.60, 0.80), iron in [0.20, 0.30). Iron is the load-bearing predicate good as designed.

User validated in-editor: iron rows render at every city/town/village with seeded prices; prices differ per node; forward-port load on slice-5 save produces no corruption toast. Day-1's migration code is confirmed working.

## Decisions ratified

- [[2026-05-03-slice-5-day-2-pass-ships-at-n4]] -- binding day-2 verdict: 0.0% abort rate over 1000 seeds at N=4. Slice-5 ships.
- [[2026-05-03-gated-continuation-shape-engineer-reviewer-only]] -- precedent: when a slice is fully pipelined and a day is fully named, the pipeline shape is Engineer -> Reviewer only. Director, Critic, Designer, Architect skipped. This shaped day-2's execution.
- [[2026-05-03-slice-5-save-bugs-deferred-to-5x]] -- three save bugs surfaced in playtest; all deferred to slice-5.x per [[feedback_carryover_check_protocol]]. Slice-5 ships with these carryover.

## Pipeline shape

Engineer round 1 -> Engineer round 2 (cosmetic self-fix) -> Reviewer (Ship-it verdict, no nits). Headless measurement run -> in-editor playtest -> Debugger pass on carryover bugs -> Decision Scribe -> session note.

The gated-continuation shape (decision 2) codified the precedent: no full re-pipeline when a day is named and a prior day passed all gates.

## Open threads

**Save bugs carryover to slice-5.x (decision 3 details):**

- Bug A: buy + refresh resets trader state. Leading hypothesis: `state_dirty` doesn't write; only `tick_advanced` does; buy doesn't tick; editor Stop doesn't fire the close-request handler.
- Bug B: travel + refresh produces save-corruption toast every time. Wire format verified clean via 5-scenario headless round-trip. Leading hypothesis: editor Stop kills mid-write, leaving truncated JSON.
- Concern C: `_f6_fallback_bootstrap_if_needed` writes a stub save under headless `--script` runs when no save exists. Narrower than initially framed; only triggers when save is missing.

Fix directions sketched in the carryover decision but deliberately not ratified; slice-5.x's design pass picks them up fresh.

**Inherited carryover (unchanged):** Web-export Begin Anew flicker; B1 deferred iters 1/4/5; runbook prose-refresh; `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`; travel confirm-modal Cancel button; bandit goods-loss fraction retune at N=4; producer-threshold-fraction revisit at N=4; weight/cargo capacity (Branch C-weight follow-up); reverse-walk the bump loop in `measure_bias_aborts.gd` if placement-starvation skip masks predicate-fail signal.

**Uncommitted state:** Day-2 work is in the working tree. Commit after session note approval.

## Notes

**Cache stale again.** The headless measurement run at session start failed with script parse errors for on-disk classes until a `godot --headless --path godot --import` refresh cleared the stale global script cache. This is the second hit on this pattern in two days. Pattern and recovery documented at `feedback_class_cache_stale.md` in user-level memory.

**Iron landed exactly on prediction.** The spec §7 forecast "raw range 0.264 with 0.064 of margin" and the histogram bucket confirmed it. Measurement-before-tuning worked: the spec's math was sound enough that the gate measurement was confirmation, not discovery. [[feedback_measurement_before_tuning]] applied deliberately and paid off.

**Playtest exposed the gap between slice delivery and playtest workflow survival.** The slice's technical deliverables (forward-port works, iron renders, prices differ) passed. The *process* of refreshing mid-playtest did not. Slice-5.x gets to fix that; slice-5 ships.

## Links

- [[2026-05-03-slice-5-day-1-pipeline]] -- day-1 full pipeline; day-2 gates on day-1 pass
- [[slice-5-goods-expansion-spec]] -- Designer's binding spec (salt and iron roles, measurement predicate)
- [[feedback_carryover_check_protocol]] -- governs deferred bugs decision
- [[feedback_measurement_before_tuning]] -- meta-pattern applied: headless gate gates the day-2 decision
- [[feedback_critic_stance]] -- framing precedent; gated-continuation decision cites it
