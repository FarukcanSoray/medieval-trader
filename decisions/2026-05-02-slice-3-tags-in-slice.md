---
title: Tags + HUD legibility ship in slice-3, not deferred
date: 2026-05-02
status: ratified
tags: [decision, slice-3, hud-legibility, pillar-1]
---

# Tags + HUD legibility ship in slice-3, not deferred

## Decision
Producer/consumer tags (derived from bias extremes) and the HUD legibility pass that surfaces them as ASCII labels are implemented in slice-3, not deferred to slice-3.x.

## Reasoning
Without legibility, regional bias is hidden state and Pillar 1 breaks. Tags are the player-facing representation of the bias structure that drives the kernel; without them the pricing pattern is opaque and arbitrage looks random. The slice's purpose is "prices have identifiable structure the player can read" -- tags are the surface that makes the structure readable.

## Alternatives considered
- Defer tags + HUD to slice-3.x -- rejected because shipping bias without legibility creates a slice-3 build that runs but teaches the player nothing, silently violating Pillar 1.

## Confidence
High. Director rooted the decision in Pillar 1 and Critic chose to sequence-late rather than defer.

## Source
Director intake. Critic kept tags in-slice but sequenced them as day-2 work.

## Related
- [[2026-05-02-slice-3-day-1-day-2-split]]
- [[2026-05-02-slice-3-tags-as-label-not-driver]]
- [[2026-05-02-slice-3-hud-source-sink-syntax-no-numbers]]
