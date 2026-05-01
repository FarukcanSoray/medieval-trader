---
title: B1 uses a tester runbook for pre-refresh snapshots, not a code-side snapshot Resource
date: 2026-05-01
status: ratified
tags: [decision, b1, test-design, scope]
---

# B1 uses a tester runbook for pre-refresh snapshots, not a code-side snapshot Resource

## Decision

The 7 failure modes that require pre/post-refresh comparison are covered by a **tester-recorded markdown snapshot table** in `docs/b1-test-protocol.md` §4, filled by hand each iteration. There is **no `PreRefreshSnapshot` Resource**, no in-code snapshot trigger UI, no debug-only snapshot lifecycle. B1 ships zero new code beyond the harness itself.

If playtest later reveals manual snapshotting is the bottleneck, a B3 round can add the Resource. Until then, the tester runbook is the proof mechanism.

## Reasoning

The structural call between two options:

- **(a) Tester runbook only** (chosen): markdown table in `docs/`, filled by hand pre-refresh.
- **(b) `PreRefreshSnapshot` Resource**: tester triggers a "snapshot now" debug action; harness reads it post-load and runs comparison predicates against loaded state. Would convert 4 of the 7 manual modes into harness-catchable modes.

Architect's pillar-framed argument for (a): Pillar 3 ("choices accumulate") demands the *production* state be trustworthy across refresh. A debug-only snapshot Resource doesn't ship to players — it would prove the harness catches violations during testing but adds nothing to player-facing trust. The 4 modes (b) would convert are the same modes the tester already catches with a markdown table; (b) trades a slim slice for harness coverage of modes the tester catches anyway.

The slice-first construction stance ([[2026-04-29-no-cuts-slice-first]]) also pushes toward (a): the moving parts in (b) — Resource shape, snapshot trigger UI, file lifecycle, debug-only code path — are exactly the kind of accretion the stance exists to prevent before playtest signal earns it.

## Alternatives considered

- **(b) `PreRefreshSnapshot` Resource**: rejected. Doesn't ship to players; adds debug-only infrastructure for modes the manual checklist already covers; no playtest signal yet that manual snapshotting is the bottleneck.
- **No coverage of the 7 comparison modes** (harness-only B1): rejected. Pre/post comparisons are exactly where Pillar-2 exploits hide; skipping them defeats B1's purpose.
- **Hybrid (some Resource, some manual)**: not seriously considered. Either the Resource exists and covers what it can, or it doesn't.

## Confidence

High. Architect's call against (b) was framed in pillar terms and supported by the slice-first stance; alternative is structural accretion without earning it.

## Source

- Architect's revision (pre-refresh snapshot decision §3 of revised spec).

## Related

- [[2026-04-29-no-cuts-slice-first]] — the stance under which "don't pre-build" is the right move
- [[2026-05-01-b1-scope-12-failure-modes-5-harness-catchable]] — the harness/runbook split that this decision implements
- [[b1-test-protocol]] — §4 snapshot table is the artifact this decision produces
