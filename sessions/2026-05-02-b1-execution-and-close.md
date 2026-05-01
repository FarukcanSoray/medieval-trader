---
date: 2026-05-02
type: session
tags: [session, b1-execution, web-deployment, save-validation]
---

# B1 execution and partial pass — browser validation and runbook drift

## Goal

Close out the open threads from [[2026-05-02-tick-confirm-and-b1-engineer]] (ASCII fixes, B1 web-deployer round) and run B1 against the live itch.io build to closure.

## Produced

- [[2026-05-02-b1-step-zero-no-threads-no-coop-coep]] — supersedes [[2026-05-01-b1-coop-coep-verification-step-zero]]; Step 0 is now a boot-completion check only.
- [[2026-05-02-b1-partial-pass-iters-2-3-6-deferred-1-4-5]] — closes B1 as partial pass (iters 2, 3, 6 PASS; iters 1, 4, 5 deferred).
- Modified `godot/ui/hud/node_panel.gd:47` — ASCII ellipsis fix (`Travelling...`).
- Modified `docs/b1-test-protocol.md` — §2 rewritten per the Step 0 supersession; all Unicode `->` arrows replaced with ASCII throughout.
- Modified `decisions/2026-05-01-b1-coop-coep-verification-step-zero.md` — superseded marker added.

## Decisions ratified

- [[2026-05-02-b1-step-zero-no-threads-no-coop-coep]]
- [[2026-05-02-b1-partial-pass-iters-2-3-6-deferred-1-4-5]]

## Execution summary

**Web-deployer preflight:** export preset clean, `deploy.yml` clean, local headless export succeeded (toolchain validated end-to-end). Pushed to main; CI deployed to `https://fasolt.itch.io/medieval-trader`.

**Browser execution against itch.io:**

- Resolved iframe-context issue: itch.io serves the game inside an `html-classic.itch.zone` iframe; DevTools console default context was the parent. Switched context to the iframe.
- Resolved `Game` autoload visibility: GDScript autoloads are not exported to `window`; tester wrote `__b1_read()` / `__b1_summary()` helpers that read the IDB save blob directly. The runbook's `Game.world.X` console syntax does not work in browsers.

**Iteration results:**

- **Iter 6 (idle F5, control):** PASS. Pre/post snapshots byte-identical across every field. Harness P1-P6 all PASS.
- **Iter 2/3 territory (mid-late F5):** PASS, single run covered both. Pre-refresh snapshot caught the travel at `ticks_remaining: 1`; resume seam fired the final tick post-load; trader arrived at the destination per Branch A (§6 item 1, "arrived at to_id from snapshot"). World seed unchanged. Gold consistent with Branch A semantics. Node prices drifted by exactly one tick's worth, consistent with the deterministic price drift formula. Harness P1-P6 all PASS.

User chose to wrap with **iters 1, 4, 5 deferred**: iter 1's 0.45s window is too tight for unaided human reflex on this build; iters 4 and 5 deferred for working-session fatigue rather than any blocker.

## Open threads

- **B1 iters 1, 4, 5** — deferred per the partial-pass decision. Iter 1 needs tooling support (debug pause / capture-replay) before it can run reliably; iters 4 and 5 are runnable any session.
- **Runbook prose refresh** — five concrete drift items captured in the "Open threads carried forward" section of [[2026-05-02-b1-partial-pass-iters-2-3-6-deferred-1-4-5]]: IDB store path nesting (`FILE_DATA` schema with `file_data` blob, not a literal `save.json` row); `Game` autoload not on `window`; §4 headers only `wool` while the slice has wool and cloth; §6 item 4's strict tick-drift rule mis-flags arrival-during-resume; itch.io iframe origin requires console-context switching.
- **From morning session (carried):** `TRAVEL_COST_PER_DISTANCE = 3` `[needs playtesting]`, travel confirm-modal Cancel button, Tier 7 deferred markers.

## Links

- [[CLAUDE.md]] — ASCII-only UI text rule and project workflow.
- [[2026-05-01-b1-pipeline]] — B1 design and harness architecture.
- [[2026-05-02-tick-confirm-and-b1-engineer]] — morning session that produced the harness code.
- [[b1-test-protocol]] — runbook the iterations were run against.

## Notes

The most instructive thread this session was **runbook drift**: the B1 protocol was authored before any execution against the actual deploy + browser context, and the prose accumulated drift in five concrete places (none correctness bugs, all prose-vs-reality mismatches). The mismatches showed up in the order: COOP/COEP-vs-no-threads (resolved by the supersession decision before B1 even started), iframe origin (DevTools defaulted to the parent), `Game` autoload not on `window`, IDB schema, single-vs-two-good headers, tick-drift-during-resume. Each one stalled execution for a few minutes while the tester worked around it.

The pattern generalizes: runbooks written before first execution accumulate context-drift systematically, and it is cheaper to budget a runbook-refresh pass after the first run than to try to anticipate every browser/host detail upfront. Logging this so the next time we author a runbook ahead of execution, we plan the refresh pass into the schedule rather than treating it as scope creep.
