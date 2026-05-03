---
title: Save-persistence bugs (A, B, C) surfaced in slice-5 playtest deferred to slice-5.x
date: 2026-05-03
status: ratified
tags: [decision, slice-5, scope, carryover, bugs]
---

# Save-persistence bugs (A, B, C) surfaced in slice-5 playtest deferred to slice-5.x

## Decision
Three save-persistence bugs surfaced during the slice-5 day-2 in-editor playtest. All three are deferred to slice-5.x as named carryover; none of them block slice-5 closure.

**Bug A.** Buy + refresh resets trader state to gold=100, empty inventory, tick=0 (world preserved). Cause (Debugger, this session): buy fires `state_dirty` but does not advance ticks; `SaveService._on_tick_advanced` is the only handler that writes during gameplay; editor Stop does not fire `NOTIFICATION_WM_CLOSE_REQUEST` on Windows. Result: in-memory delta lost on next launch.

**Bug B.** Travel + refresh produces save-corruption toast + regen, every time. Cause (Debugger leading hypothesis H1, unconfirmed): editor Stop kills the process during `write_now`'s store_string/close window, leaving truncated JSON. Travel's per-tick wall-clock pacing (~0.45s/tick) opens a wide kill-during-write window that buy does not. Wire format itself is clean (verified by 5-scenario headless round-trip diagnostic during the Debugger pass; tool was deleted post-diagnosis).

**Concern C.** `_f6_fallback_bootstrap_if_needed` writes a stub `user://save.json` when no save exists, including under headless `--script` runs. The autoload bootstraps unconditionally when `current_scene` is null. Narrower than first framed: only writes when the file is missing, so it does not continuously clobber an existing save. But once Bug B corrupts the save and triggers regen, the next stub write looks like a "headless overwrite" -- amplification rather than direct sabotage.

Slice-5.x owns all three. Fix directions are noted in the day-2 session note (this session) but deliberately not ratified as decisions; slice-5.x's own design pass should weigh approaches without being boxed in.

## Reasoning
The Debugger pass was unambiguous on a structural point: all three bugs are pre-existing. Bug A's tick-coalesced write logic is from slice-1; Bug B's `write_now` behavior is from the same era; Concern C's autoload bootstrap predates slice-5. None were introduced or amplified by slice-5 day-1 or day-2 code. The forward-port path itself was confirmed clean by both the headless measurement and the user's in-editor playtest (iron rows render, prices differ per node, no corruption-toast on first load).

Slice-5's own deliverables -- 4-good predicate validation, role taxonomy realization, forward-port migration on slice-N save loads -- are all working. The save bugs invalidate the *playtest workflow* (the user cannot easily verify their own gameplay survives a refresh), but they do not invalidate the slice's correctness. Slicing discipline (Critic's standing month-3-sinkhole warning) makes pulling in structural save-write fixes mid-slice the wrong call: each bug spans multiple subsystems (save service, lifecycle, encounter resolver, travel controller), each is its own design pass, and bundling them into slice-5 risks turning a one-day execution slice into an open-ended sinkhole.

The three bugs are coherent enough as a group (all about save persistence, all surfaced together) to share a slice-5.x scope, but distinct enough that slice-5.x will likely pipeline them as separate features within that follow-up slice.

The user explicitly chose this path over the alternative ("treat as slice-5 blockers, fix before close"), citing the slicing-discipline rationale.

## Alternatives considered
- **Treat as slice-5 blockers; fix all three before slice-5 closure.** Rejected: would violate slicing discipline (Critic's "month-3 sinkhole" warning); would expand a one-day execution slice into a multi-day structural fix; bugs are pre-existing and not introduced by slice-5 work.
- **Ratify the fix directions now (Bug A: write-on-state-dirty; Bug B: atomic .tmp + rename; Concern C: gate autoload on `current_scene != null`).** Rejected: hypotheses are sketches, not designs. Ratifying them pre-empts slice-5.x's own design pass, which should weigh write-on-dirty vs spec revision (Bug A), confirm H1 vs other corruption hypotheses (Bug B), and choose the right gate seam (Concern C). Naming the fix sketches in the session-note carryover is enough.
- **Single combined "save persistence bugs" carryover decision (this one) vs three separate decisions, one per bug.** This is the combined approach. Selected because the three are named together, surfaced together, share a slice-5.x scope, and should be revisited together as a group rather than chased independently.

## Confidence
High on the carryover call itself (slicing discipline is the load-bearing rule). Medium on the framing -- if slice-5.x discovers that one of the three is structurally entangled with a bug we haven't named yet (e.g., death writes have the same atomic-write window Bug B exploits), the framing may need to widen.

## Source
Debugger pass (this session, structured diagnosis: reproduce -> evidence -> hypothesis -> test -> fix direction across all three). User chose option B (carryover) from a two-option framing (option A: blockers).

## Related
- [[2026-05-03-slice-5-day-2-pass-ships-at-n4]] -- the slice-5 closure these bugs were measured against
- [[2026-05-03-slice-5-forward-port-saves]] -- the path that the user's playtest confirmed working despite the save bugs
- [[2026-04-29-strict-reject-from-dict]] -- the strict-reject contract Bug B's truncated JSON path triggers
- [[2026-05-01-save-corruption-regenerate-release-build]] -- the corruption-toast + regen path Bug B routes through
- [[2026-04-29-tick-on-player-travel]] -- the tick-advancement-on-travel rule Bug A interacts with
