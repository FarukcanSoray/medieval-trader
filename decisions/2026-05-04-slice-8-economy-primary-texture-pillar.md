---
title: New pillar -- world economic state is the game's primary texture
date: 2026-05-04
status: ratified
tags: [decision, pillar, slice-8, world-memory, supersession]
---

# New pillar -- world economic state is the game's primary texture

## Decision
The project's world-memory pillar is replaced with a sharper formulation:

> **The world's economic state is the game's primary texture. Stock and demand at every node remember what happened, and prices are the player's window into that memory.**

This sits alongside the kernel-collision pillar (arbitrage profit ⊥ travel cost). Both are protected. The kernel pillar describes what it costs to chase arbitrage; the new pillar describes where the arbitrage comes from.

The original world-memory pillar (`2026-05-03-slice-7-world-has-memory-pillar`) is **superseded**: world memory was the precondition; this pillar makes that memory legible at the price label and elevates legibility to a pillar property. CLAUDE.md's pillar text is updated accordingly in the same session.

## Reasoning
Slice-8's playtest signal triggered a Director-level pillar reframing. The user originally framed it "this is an economy-based game, the economy should carry weight" -- which Director rejected as too broad to filter (it would let in any feature that touches prices, stock, or trade, which is most of the game).

The substituted pillar **filters**:

- It rules out RNG-driven price events that bypass stock state -- a "merchant guild raises iron prices for 3 turns" scripted event would fail this filter; prices have to come from stock.
- It rules out features that read economy state without being readable as economy -- a hidden reputation system that affects prices fails; the player has to be able to read the cause from the stock.
- It elevates legibility to a pillar property, which is what the player is reaching for when they say "stockpiles should feel real."
- It absorbs the prior world-memory pillar (memory is now mechanical-and-price-shaped) without losing it.

Travel and encounters are reframed: not co-equal pillars, never were. They are textures that serve the kernel collision and now also serve the economy pillar. Future slices in those areas are evaluated on that basis. A weather encounter that just adds RNG damage is now harder to justify; a weather encounter that makes certain trade routes seasonally viable serves the pillar.

## Alternatives considered
- **"The economy is the game"** (user's original framing) -- rejected by Director: too broad to filter; would let in any feature that touches prices, stock, or trade.
- **Keep the old world-memory pillar; add an economy texture as a sub-property** -- not formally weighed but implicit rejection: the new pillar absorbs the old one without losing it; keeping both would create overlap.

## Confidence
High. Director explicitly chose this wording, rejected the user's broader version, and named the kernel-pillar relationship.

## Source
Director (initial slice-8 ratification, 2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` introduction.

## Related
- [[2026-05-03-slice-7-world-has-memory-pillar]] -- superseded by this decision (the prior pillar this absorbs and sharpens)
- [[CLAUDE]] -- project-level pillar text updated to this wording in the same session
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula that implements the legibility property
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- the structural decision that makes prices a function of memory rather than a separate stored field
