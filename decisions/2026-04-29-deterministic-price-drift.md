---
title: Price drift seeded deterministically by world/tick/node/good
date: 2026-04-29
status: ratified
tags: [decision, design, randomness]
---

# Price drift seeded deterministically by world/tick/node/good

## Decision
Price drift is deterministic. The RNG seed for each price update is `hash(world_seed, tick, node_id, good_id)`. Prices are reproducible on reload.

## Reasoning
Saving mid-travel and reloading must produce the same world — prices cannot reroll. This is necessary on HTML5 where saves can roll back if the IndexedDB flush fails before the player refreshes. It also supports the careful-merchant fantasy: prices are legible and reproducible, not gambling-like.

Per-tick drift is computed deterministically; randomness is a pseudo-random sample, not a session-local RNG state.

## Alternatives considered
Reseed the RNG on each reload (or each session). Rejected — produces post-load surprises that break trust in the pricing model.

## Confidence
High. Explicit Designer rule.

## Source
`docs/slice-spec.md` §5 — "Price drift formula" — "Seed the RNG with `hash(world_seed, tick, node_id, good_id)` so prices are deterministic on reload."

## Related
- [[slice-spec]] — captured in §5
- [[2026-04-29-fantasy-careful-merchant]] — Pillar 1 (every trade decision is a math problem the player can win)
- [[2026-04-29-save-format-first]] — pairs with this; prices are stored AND regenerable from seed
