---
title: Tick granularity during travel — per-step (not batched)
date: 2026-04-29
status: ratified
tags: [decision, design, kernel, tick]
---

# Tick granularity during travel — per-step (not batched)

## Decision
When a trader travels for N ticks, `Game.tick_advanced` fires **N separate times**, once per step — not once batched at arrival. Price drift, aging, and save coalescing all run per step. `TravelController` advances `world.tick` by 1 per step, decrements `trader.travel.ticks_remaining`, emits the signal, and loops until arrival.

## Reasoning
The kernel is "travel costs bite *because* prices change while you're committed to a route." Batched ticks erase that bite mid-trip — prices wouldn't change until arrival, which reads as **arrival-surprise** (luck-based), violating Pillar 1 ("careful merchant" / a math problem the player can win).

Per-step tick emission preserves the pressure: the player commits knowing they can't cancel, then watches prices drift on every step. Playtest can now separate "drift feels like time pressure" (good signal — kernel works) from "drift feels random / unfair" (bad signal — tune drift % down).

`slice-spec.md` §5's worked arbitrage example is built on per-step semantics ("If drift pushes B's price down to 14 mid-trip, sale yields +140g…"). Batching would invalidate the math.

## Alternatives considered
- **Batched tick at arrival** — rejected: erases the pressure mid-trip; reads as luck; would invalidate the §5 worked example; would conflate "the market moved" with "I arrived" so playtest can't distinguish them.

## Confidence
High. Designer ratified the Architect's per-step choice with explicit kernel-feel reasoning. The signal contract in `slice-architecture.md` §3 names per-step semantics; SaveService's coalesce window depends on it.

## Source
Designer call resolving Q3 from `slice-architecture.md` §8, ratifying SceneArchitect's choice. 2026-04-29 evening.

## Related
- [[project-brief]] — Pillar 1 "careful merchant"
- [[slice-spec]] — §5 worked example assumes per-step drift
- [[slice-architecture]] — §3 signal routing, §5 save lifecycle (coalesce window)
- [[2026-04-29-tick-on-player-travel]] — the kickoff decision that ticks advance only on travel
- [[2026-04-29-deterministic-price-drift]] — per-step ticks are when drift fires
