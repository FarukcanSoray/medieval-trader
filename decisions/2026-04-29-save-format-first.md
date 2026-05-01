---
title: Save format specified first as binding contract
date: 2026-04-29
status: ratified
tags: [decision, architecture, persistence]
---

# Save format specified first as binding contract

## Decision
The save format (single JSON blob at `user://save.json`, integers only, prices stored not regenerated, written end-of-tick + on quit + on death) is specified before the systems that touch it. It is the binding contract every system reads/writes against.

## Reasoning
Determines where state lives, how durability works (especially on HTML5 IndexedDB with async flush), and what gets persisted vs. regenerated. Fixing it early prevents downstream integration surprises. This is a direct response to the Scope Critic's "month 3 sinkhole" warning about integration tax between AI-generated systems.

## Alternatives considered
Save format designed after the systems exist (late binding). Rejected because it creates rework risk on integration — every system that already wrote to ad-hoc state has to be retrofitted.

## Confidence
High. Designer's explicit ratification; load-bearing rule for the slice and beyond.

## Source
`docs/slice-spec.md` §3 — "Save format contract (specified first — every system reads/writes this)."

## Related
- [[slice-spec]] — fully captured in §3
- [[2026-04-29-deterministic-price-drift]] — pairs with this (prices stored, not regenerated)
- [[2026-04-29-signal-based-integration]] — the architectural pattern that consumes this contract
- [[2026-04-29-no-cuts-slice-first]] — slice-first works only if the contract is stable
