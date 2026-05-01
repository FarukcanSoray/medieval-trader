---
title: Let price asymmetry ride in the slice (no enforced guarantee)
date: 2026-04-29
status: ratified
tags: [decision, slice, economics]
---

# Let price asymmetry ride in the slice (no enforced guarantee)

## Decision
There is no enforced guarantee that prices for the same good stay non-identical across nodes in any given tick. Transient flat-market ticks (where all nodes have the same price for a good) are accepted in the slice. Revisit only if playtest shows they feel bad.

## Reasoning
User's reasoning: "easier to add a constraint later than to remove one; slice's job is to surface problems, not pre-empt them." The decision to let the slice reveal the problem (rather than pre-solve it) is a statement about the slice's role: discover what feels bad in actual play before committing engineering effort to guardrails.

The mitigation that exists "for free": ticks advance only on player-initiated travel, so the player can't sit and wait for prices to diverge — they must travel and pay, which means flat-market ticks have natural cost pressure even without an asymmetry rule.

## Alternatives considered
Enforce that at least one price differs from another per tick (tighter guardrail). User chose looser to avoid premature engineering.

## Confidence
High. Explicit user ratification with clear reasoning.

## Source
User answer to Designer's open question, 2026-04-29: "Let it ride for the slice." Captured in `docs/slice-spec.md` §8 (edge cases) and the ratifications header.

## Related
- [[slice-spec]] — captured in §8
- [[2026-04-29-tick-on-player-travel]] — pairs with this; the natural cost pressure that mitigates flat-market ticks
- [[2026-04-29-no-cuts-slice-first]] — same philosophy: slice surfaces problems, doesn't pre-empt them
