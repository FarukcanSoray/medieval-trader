---
title: `slain` second death cause deferred to slice-4.x; encounter insolvency triggers `stranded`
date: 2026-05-02
status: ratified
tags: [decision, slice-4, scope, death, deferred, slice-4x]
---

# `slain` second death cause deferred to slice-4.x; encounter insolvency triggers `stranded`

## Decision
Slice-4 ships **gold-loss-only encounters**. The `slain` death cause is **not introduced** in this slice. When a bandit encounter drives the trader to insolvency, death is triggered with `cause = "stranded"` (not `slain`) — DeathService's existing predicate is unchanged.

## Reasoning
Slice-1 closed with an explicit "one death cause in the slice" decision ([[2026-04-29-slice-one-death-cause-bankruptcy]]). Adding `slain` requires (a) a precedent-overturn decision against that, plus (b) death-cause-context plumbing — DeathService currently hardcodes `Game.died.emit("stranded")` and has no way to tag the cause based on what triggered the gold change.

Slice-4's kernel ("travel cost can be more than gold-per-distance — route risk is itself a math problem") is fully testable without `slain`. Critic recommended this deferral; it preserves the existing decision precedent intact and lets the encounter system prove itself before death-pipeline surgery.

## Alternatives considered
- **Ship `slain` in slice-4** — rejected; would require precedent-overturn + DeathService refactor as gating work.

## Confidence
High. Critic-flagged, Designer-deferred, Architect-confirmed (death_screen.gd's `match cause` already has a `_:` fallback so no UI breakage).

## Source
Critic stress-test verdict.

## Related
- [[2026-04-29-slice-one-death-cause-bankruptcy]] — the precedent this deferral preserves
- [[2026-04-29-death-cause-stranded]] — tone precedent: single concrete past-participle states
- [[2026-04-29-death-rare-and-earned]]

## Slice-4.x owe-note
The deferred work is "slice-4.x [encounter-death-cause `slain`]." It needs:
1. A precedent-overturn decision against [[2026-04-29-slice-one-death-cause-bankruptcy]]
2. A "why-did-gold-change" context channel (Game signal extension OR DeathService inspection of `TravelState.encounter`)
3. A new `slain` arm in `death_screen.gd:_build_epitaph`
