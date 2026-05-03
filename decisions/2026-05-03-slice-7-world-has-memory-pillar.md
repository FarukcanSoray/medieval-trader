---
title: World has memory of trader actions; promoted to load-bearing pillar
date: 2026-05-03
status: ratified
tags: [decision, slice-7, pillar, project-shape]
---

# World has memory of trader actions; promoted to load-bearing pillar

## Decision
The world persisting state caused by trader actions is a **load-bearing pillar of the project**, not a slice-7 side effect. Future slices respect this: world memory becomes part of the game's identity. CLAUDE.md is updated to name world-memory alongside the kernel collision (arbitrage profit / travel cost bite).

## Reasoning
Slice-7 is the first slice where the *world* persists state caused by the trader: cleaning out a node leaves it empty until refills restore it. Every prior slice's world state was either authored at gen-time (tags, biases, prices that drift deterministically by tick) or transient (encounters, save flushes). Slice-7 introduces the first *trader-visible memory of trader-caused mutation*. That texture is the felt experience of the slice -- "the world remembers I was here" -- and it changes the project's shape. Future slices that touch world state should default to "preserve memory," not "reset on each visit."

## Alternatives considered
- **Treat world memory as a slice-7-only texture** -- world state could mutate this slice without committing to the pattern across future slices. Rejected because the texture is what makes caps feel like a real mechanic rather than a tuning knob; future slices that rest world state would erase the texture.
- **Defer the pillar question** -- ship slice-7 without committing to world-memory as a pillar; revisit when a future slice forces the question. Rejected because deferral would mean the next slice could accidentally remove the pillar without realizing it.

## Implications for future slices
- Save-load contract: world-state mutations from trader actions persist across save/load. No refill-on-load, no save-scumming.
- New world-state mutations (e.g., a future faction-rep system, taxes, depleted ore veins) default to *persisted memory* unless explicitly marked transient.
- "World has memory of trader actions, but not of named NPCs or scripted events" -- the pillar is mechanical-state-shaped, not narrative-shaped. The existing `no story / no characters` NOTs remain unchanged.

## Confidence
High. User explicitly ratified: "memory should be a part of the game's identity."

## Source
Designer's spec §12 surfaced the question; user confirmed in slice-7 conversation (2026-05-03).

## Related
- [[2026-05-03-slice-7-production-caps-anointed]] -- the slice that introduces the pillar
- [[2026-04-29-deterministic-price-drift]] -- prior world-state determinism contract; world-memory extends it to trader-action consequences
- [[project_director_intake]] -- prior pillar-shape memory; world-memory joins the named pillars
