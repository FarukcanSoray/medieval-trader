---
title: Producer/consumer tags are a label of bias, not a separate pricing driver
date: 2026-05-02
status: ratified
tags: [decision, slice-3, design, hud-legibility]
---

# Producer/consumer tags are a label of bias, not a separate pricing driver

## Decision
`NodeState.produces` and `NodeState.consumes` are derived from authored bias values via thresholds (`PRODUCER_THRESHOLD_FRACTION`, `CONSUMER_THRESHOLD_FRACTION` of the per-good bias range). Tags do not appear in any pricing math. They exist only as a player-readable surface for the HUD.

## Reasoning
Designer drew a hard line: tags are the *abstraction* the player reads, not an independent input. Letting tags drive bias would mean two systems competing to define a node's identity; making tags a label means there is one source of truth (the bias values), and the HUD just translates it into language the player understands.

## Alternatives considered
- Tags drive bias (or vice-versa) -- rejected to keep one source of truth.

## Confidence
High. Designer stated this as a design constraint to prevent feature creep.

## Source
Designer spec §5.6.

## Related
- [[2026-05-02-slice-3-bias-multiplicative-anchor]]
- [[2026-05-02-slice-3-hud-source-sink-syntax-no-numbers]]
- [[2026-05-02-slice-3-tags-in-slice]]
