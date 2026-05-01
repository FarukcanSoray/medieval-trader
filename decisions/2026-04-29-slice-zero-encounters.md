---
title: Zero encounters in the slice
date: 2026-04-29
status: ratified
tags: [decision, slice, scope]
---

# Zero encounters in the slice

## Decision
The vertical slice includes **zero encounter systems**. Encounters (bandits, weather, spoilage, tolls) are deferred to a second pass. They remain in full project scope.

## Reasoning
The kernel — `arbitrage profit ⊥ travel cost` — is fully testable with gold-per-distance travel cost alone (worked example in slice spec §5). An encounter system adds at minimum four subsystems: trigger roll, pause-travel screen, choice UI, outcome readback. For the slice this is zero kernel value at high integration cost.

The Scope Critic's "four mini-systems in one coat" warning lands hard here. Encounters belong after the simpler loop is proven end-to-end and the integration plumbing is stable.

## Alternatives considered
Include one minimal encounter type (bandits, text modal, no choice) in the slice. Designer recommended against; user ratified.

## Confidence
High. Designer's explicit decision; ratified via the slice spec approval.

## Source
`docs/slice-spec.md` §10 — "Zero encounters in the slice. Justification: the kernel is `arbitrage profit ⊥ travel cost`..."

## Related
- [[slice-spec]] — fully captured in §10
- [[2026-04-29-no-cuts-slice-first]] — the construction strategy this operationalises
- [[2026-04-29-slice-one-death-cause-bankruptcy]] — pairs with this; violent-encounter death is also deferred
