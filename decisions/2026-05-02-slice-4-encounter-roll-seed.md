---
title: Encounter roll seed = hash([world_seed, tick, lo_id, hi_id, "encounter_roll"])
date: 2026-05-02
status: ratified
tags: [decision, slice-4, determinism, encounters]
---

# Encounter roll seed = hash([world_seed, tick, lo_id, hi_id, "encounter_roll"])

## Decision
Per-leg encounter roll uses RNG seeded by:
```
hash([world_seed, tick, lo_id, hi_id, "encounter_roll"])
```
where `lo_id` / `hi_id` are the **lex-min canonicalised** `EdgeState.a_id` / `EdgeState.b_id`.

## Reasoning
- **`world_seed`** — same world, same fates (slice-3 determinism contract preserved).
- **`tick`** included so re-crossings of the same edge get fresh rolls. Without it, a player who took a bandit road, returned, and re-crossed would always get the same outcome — gameable.
- **`lo_id` / `hi_id` lex-min canonicalised** so `(a -> b)` and `(b -> a)` hash equal. The edge is undirected; fate is a property of the road and the moment, not the direction of travel.
- **`"encounter_roll"`** sub-namespace, sibling to slice-3's `"bias"` / `"place"` / `"names"`. Cannot collide with any existing namespace by construction (different array shape).
- **`trader.gold` excluded** so wealth doesn't drive whether the dice fall — only what falls if they do (the loss percentage). Including gold would mean a wealthy trader has different luck than a poor one on the same road, which violates the Pillar-1 reasoning model.

## Alternatives considered
- **Include `trader.gold`** — rejected; wealth shouldn't drive the roll, only the outcome magnitude.
- **Omit `tick`** — rejected; would make re-crossings deterministically identical (gameable).
- **Use raw `(a_id, b_id)` without canonicalisation** — rejected; direction-dependent outcomes are unintuitive.

## Confidence
High. Designer-spec'd; Architect-confirmed; Engineer-verified hash array order is byte-identical.

## Source
Designer spec §5.3.

## Related
- [[2026-04-29-deterministic-price-drift]] — the seed contract pattern this extends
- [[2026-05-02-slice-4-roll-fires-at-departure]]
