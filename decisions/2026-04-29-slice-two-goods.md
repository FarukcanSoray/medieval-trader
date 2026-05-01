---
title: Slice ships with two goods — wool and cloth
date: 2026-04-29
status: ratified
tags: [decision, design, slice, goods]
---

# Slice ships with two goods — wool and cloth

## Decision
The vertical slice includes **2 hand-authored goods**: `wool.tres` and `cloth.tres`. The Engineer created both in Tier 1.

Slice tuning values (placeholder, `[needs playtesting]`):

- **Wool:** `id="wool"`, `base_price=12`, `floor_price=5`, `ceiling_price=25`
- **Cloth:** `id="cloth"`, `base_price=18`, `floor_price=8`, `ceiling_price=32`

## Reasoning
With **1 good**, the only decision is "go where?" — the kernel reduces to a 3-node distance/spread comparison the player can hold in their head in five seconds. That's too thin to test the actual kernel.

With **2 goods**, the player must compare *which* good's spread beats *which* travel cost — that **is** the kernel: `arbitrage profit (per good) ⊥ travel cost`. Two goods also tests the price model's good-independence: if drift accidentally couples goods or the formula is too symmetric, the slice playtest will reveal it. With 1 good you wouldn't see it until later, when finding the bug is more expensive.

## Alternatives considered
- **1 good** — rejected: kernel becomes trivial; doesn't test price-model independence; slice playtest only answers the narrower travel-cost-vs-spread question.
- **3+ goods** — rejected: out of slice scope (`one of each system` discipline); deferred to second pass.

## Open for later
If the slice playtest shows 2 goods is overwhelming at programmer-art fidelity (no audio/animation cues to anchor identity), drop to 1 for tuning passes and re-add. Slice-2 should grow the goods catalogue *before* adding encounters.

## Confidence
High. Designer call with explicit kernel-test reasoning. Files exist in code.

## Source
Designer call resolving Q2 from `slice-architecture.md` §8, 2026-04-29 evening. Slice-spec §6 ratifies (recommends 2). Engineer Tier 1 created both `.tres` instances.

## Related
- [[project-brief]] — Pillar 2 "knowable system" (the kernel must be a math problem the player can read)
- [[slice-spec]] — §6 "Numbers (tuning ranges)" recommends 2
- [[slice-architecture]] — §7 Tier 1 file 1 specifies both goods
- [[2026-04-29-one-of-each-system]] — the discipline that caps goods at 2 not 3+
- [[2026-04-29-slice-three-nodes]] — companion structural slice decision (3 nodes, 2 goods)
