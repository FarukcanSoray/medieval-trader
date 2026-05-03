---
title: Refill happens only on travel ticks; world ticks only when the player travels
date: 2026-05-03
status: ratified
tags: [decision, slice-7, mechanics, ticking]
---

# Refill happens only on travel ticks; world ticks only when the player travels

## Decision
Stock refill happens once per tick, and ticks advance **only during travel**. There is no refill on player arrival, no refill on save-load, no refill on idle, no burst-refill on first-visit-after-absence. The world ticks only when the player travels.

## Reasoning
The kernel pillar "travel costs bite" extends to "travel is what makes the world tick." Refills are a side effect of leaving and coming back. This makes the temporal availability texture work as designed: a node the player just emptied stays empty until they travel away and return for at least one tick. Refill-on-arrival would let the player buy out a node, take one step back and forth, and return to a refilled market -- defeating the slice's purpose.

This decision composes with `2026-04-29-tick-on-player-travel` (ticks only advance when the player travels). Slice-7 doesn't introduce a new tick source; it adds a new listener (`StockSystem`) to the existing one.

## Alternatives considered
- **Refill on arrival** (burst-refill semantics) -- rejected: would let the player "reset" a node by leaving and returning instantly.
- **Refill on every real-time tick** (decouple stock-tick from travel-tick) -- rejected: introduces real-time pressure that conflicts with the project's `not real-time` NOT.
- **Refill on save-load** -- rejected: creates a save-scumming exploit (save before buyout, reload, buy again). See save-persistence in `2026-05-03-slice-7-caps-rates-frozen-at-gen-time`.
- **Slower refill cadence** (e.g., 1 unit every N ticks) -- not chosen for slice-7's first pass; per-tick keeps the kernel tempo. Slower-refill feel is a tuning question for playtest.

## Confidence
High. Designer named this explicitly load-bearing in spec §3.3; Architect ratified.

## Source
Slice-7 spec §3.3.

## Related
- [[2026-04-29-tick-on-player-travel]] -- the prior decision this composes with
- [[2026-05-03-slice-7-world-has-memory-pillar]] -- the texture this rule protects
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- the save-load contract that complements this rule
