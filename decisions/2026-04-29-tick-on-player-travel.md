---
title: Tick advancement only on player-initiated travel
date: 2026-04-29
status: ratified
tags: [decision, design, tempo]
---

# Tick advancement only on player-initiated travel

## Decision
Ticks advance only when the player initiates travel. Idle-at-node does not advance ticks. There is no "wait at node" verb in the slice.

## Reasoning
Keeps the core loop pure: the player must accept travel cost to advance time, which puts both sides of the kernel (profit potential + travel cost) in tension on every tick boundary. Removes a dominant strategy ("wait for prices to swing in my favour") and simplifies scope — no idle-state UI, no waiting animation.

This is a slice-level rule. A "wait" verb may return in later passes if playtest shows the slice feels too narrow.

## Alternatives considered
Tick advancement on a clock that continues even when idle. Rejected — would let the player extract value without paying travel cost, undermining the kernel.

## Confidence
High. Explicit Designer rule.

## Source
`docs/slice-spec.md` §5 — "Tick advancement. Ticks advance only on player-initiated travel."

## Related
- [[slice-spec]] — captured there
- [[2026-04-29-travel-cost-at-departure]] — pairs with this
- [[2026-04-29-slice-let-asymmetry-ride]] — flat-market ticks are mitigated by this rule (player must travel to escape, which costs)
