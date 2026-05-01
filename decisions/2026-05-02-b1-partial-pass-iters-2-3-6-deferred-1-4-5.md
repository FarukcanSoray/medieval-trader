---
title: B1 closes as partial pass — iters 2/3/6 verified, iters 1/4/5 deferred
date: 2026-05-02
status: ratified
tags: [decision, b1, save-system, web-export, partial-pass, deferred]
---

# B1 closes as partial pass — iters 2/3/6 verified, iters 1/4/5 deferred

## Decision

B1 (HTML5 refresh-mid-travel save-corruption smoke test, runbook at `docs/b1-test-protocol.md`) is closed as a **partial pass**. Verified this session against the live itch.io build at `https://fasolt.itch.io/medieval-trader`:

- **Iter 6 (idle F5, control):** PASS. Pre/post snapshots byte-identical across `world_seed`, `tick`, `gold`, `inventory`, `location`, `nodes` (all prices), `edges`, `dead`, `history_count`. Harness P1-P6 all PASS.
- **Iter 2 (mid-window F5) and iter 3 (N-1 F5) territory:** PASS, single run covered both. Pre-refresh snapshot caught the travel at `ticks_remaining: 1` (within iter 3's window); F5 reloaded; resume seam fired the final tick post-load and the trader arrived at the destination (Branch A → arrival per §6 item 1). Harness P1-P6 all PASS. World seed unchanged. Gold consistent with Branch A semantics. Node prices drifted by exactly one tick's worth, consistent with the deterministic price drift formula.

**Deferred iterations** (tracked as B2 or follow-up work, not blocking B1 closure):

- **Iter 1 (immediate F5 between Confirm and first tick).** The 0.45s tick window is too tight for unaided human reflex on this build. Revisit with either a debug pause hook (Engineer round) or a different capture protocol that doesn't require capture-before-F5 inside the window.
- **Iter 4 (tab close + reopen).** Mechanism is observably different from F5 (browser process boundary vs. page reload), but the underlying invariant — IDB persistence across the close — is what's being tested. Defer.
- **Iter 5 (incognito fresh-game, no durable save).** Tests the "no save survives" path is handled cleanly. Defer.

The harness itself is validated by the iters that ran. The deferred iters cover *additional* refresh mechanisms; they are not redundant, but they are not blocking either.

## Reasoning

The point of B1 was to verify the save invariant harness in a real browser against the canonical build. That's done: the harness ran on every reload this session, produced the expected six PASS lines on healthy state, and the in-flight Branch A resume semantics held under inspection. The iterations that didn't run are coverage-broadening, not load-bearing — they would have surfaced *additional* failure modes if any existed, but the modes they target (immediate-F5 timing, tab-process boundary, no-save-path) are sufficiently distinct from the modes covered (idle, mid-late F5) that running them now or in B2 is a sequencing call, not a correctness call.

User chose to close B1 with iters 2/3/6 captured rather than push through fatigue on iters 1/4/5, consistent with the project's standing slice-first stance: ship the verified milestone, defer the coverage extension. Closing partial-with-deferral preserves the forward progress (B1 isn't blocking B2) and the deferred work (iters 1/4/5 don't quietly disappear).

## Alternatives considered

- **Push through and complete all 6 iterations now.** Rejected by user: working-session fatigue plus the iter-1 timing problem (which isn't solved by pushing harder, it's solved by adding tooling). Forcing the run produces noisier data than scheduling a follow-up.
- **Block B1 closure until all 6 iterations are run.** Rejected. Coverage is broader than load-bearing; the harness is validated; iters 1/4/5 don't gate any other work.
- **Mark B1 as failed because not all 6 iters ran.** Rejected. Failure has a specific meaning (a harness violation or a §6 manual-checklist violation against a captured pre-state); neither was observed. Calling un-run iters "failures" inflates the failure surface and obscures the real signal.
- **Re-run the runbook against a local threaded build to get tighter control over timing.** Rejected upstream by [[2026-05-02-b1-step-zero-no-threads-no-coop-coep]] — the canonical build is no-threads on itch.io, B1 must test what ships.

## Confidence

High. The harness is observably working. The deferred iters are coverage; the verified iters are the load-bearing checks.

## Open threads carried forward

These do not block B1 closure but should be visible in the next round:

- **Iter 1 (immediate F5)** needs a tooling change (debug pause / longer tick / capture-then-replay) before it can be run reliably. Engineer or Debugger round.
- **Iter 4 (tab close + reopen)** can be run any time; just not run this session.
- **Iter 5 (incognito)** can be run any time.
- **Runbook prose refresh** — five items surfaced during execution: IDB-store path nesting (`FILE_DATA` + `file_data` blob, not a literal `save.json` row); `Game` autoload is not on `window` so JS-console state reads need an IDB helper; §4 headers only `wool` while the slice has wool and cloth; §6 item 4's strict "any tick drift is FAIL" rule mis-flags the valid arrival-during-resume case (drift +1 when `ticks_remaining: 1` at refresh); itch.io serves the game inside an `html-classic.itch.zone` iframe and the DevTools console must be switched to the iframe context. None of these are correctness issues with the harness; they are runbook accuracy issues for future runs.

## Source

- This session (2026-05-02 PM). User explicit close: "enough of testing, I want to proceed, it is getting too long" -> "wrap session". Ratified candidate [1] from Decision Scribe extraction.

## Related

- [[2026-05-02-b1-step-zero-no-threads-no-coop-coep]] — Step 0 supersession that gated this run
- [[2026-05-01-b1-pipeline]] — pipeline session that produced the runbook and harness spec
- [[2026-05-01-b1-scope-12-failure-modes-5-harness-catchable]] — harness/runbook split this run validated
- [[2026-05-01-save-corruption-regenerate-release-build]] — debug-vs-release behavior the harness invokes on FAIL
- [[b1-test-protocol]] — runbook the iterations were run against; the listed prose-refresh items track its drift from observed reality
