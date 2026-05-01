---
title: B1 split — 5 of 12 failure modes via in-code harness, 7 via tester checklist
date: 2026-05-01
status: ratified
tags: [decision, b1, test-design, save-system]
---

# B1 split — 5 of 12 failure modes via in-code harness, 7 via tester checklist

## Decision

B1 enumerates 12 failure modes (the bad post-refresh outcomes that would constitute Pillar-2 exploits). The test split assigns each mode to where it can actually be evaluated:

- **5 modes are catchable by an in-code harness** running as a pure function over post-load `(trader, world)`: limbo state, phantom travel, silent schema bump, death-state injection, and partial coverage of tick desync (negatives only).
- **7 modes require pre/post-refresh comparison** and cannot be evaluated by a function that only sees post-load state. These are caught by the tester via a manual checklist against a snapshot recorded before refresh: free arrival, free travel-back, goods-keep rollback, cost-keep rollback, selective revert, world regen, and the tick-consistency-with-branch portion of tick desync.

The harness is the gate; the runbook is the rest of the test. Both must pass for an iteration to pass.

## Reasoning

Designer's mapping pass against Architect's sketched predicates surfaced the structural distinction: a save file showing "trader is at destination, gold is X" is a perfectly valid save file from a single-boot perspective — there is no way for code to know whether the player paid for that trip or rolled back to it. That class of mode is fundamentally a comparison of two states across the refresh boundary, and a pure post-load function cannot evaluate it.

The split is not a compromise — it's the correct decomposition. Promoting the 7 comparison modes into the harness would require either (a) shipping a pre-refresh snapshot mechanism (rejected separately) or (b) cross-boot state persistence (rejected via "no schema bump"). Both add moving parts that don't earn their cost. The tester runbook records the snapshot in markdown columns; the harness handles what it can; together they cover all 12 modes.

## Alternatives considered

- **All-harness coverage**: rejected as impossible without pre-refresh state recording, which adds infrastructure that doesn't ship to players.
- **All-manual coverage**: rejected. The 5 single-boot-catchable modes are kernel-level invariants worth automating; manual-only means every future Engineer touch to save/load re-runs them by eyeball.
- **Hybrid (chosen)**: each mode assigned to the mechanism that can actually evaluate it.

## Confidence

High. The split is a structural fact about post-load functions, not a preference.

## Source

- Designer's first B1 spec (12 modes enumerated).
- Designer's second pass (mapping modes against Architect's predicate sketch).

## Related

- [[2026-05-01-save-invariant-checker-harness-no-autoload]] — the harness shape itself
- [[2026-05-01-b1-no-debug-snapshot-resource]] — why the comparison modes go to runbook, not code
- [[b1-test-protocol]] — the runbook §6 manual checklist
