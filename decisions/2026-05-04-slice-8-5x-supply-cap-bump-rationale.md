---
title: 5x supply cap bump rationale -- perturbation-scale impact, not realism
date: 2026-05-04
status: ratified
tags: [decision, slice-8, tuning, supply-pool, legibility]
---

# 5x supply cap bump rationale -- perturbation-scale impact, not realism

## Decision
Supply cap multipliers on `WorldRules` are bumped 5x from slice-7:

- `STOCK_CAP_MULT_PLENTIFUL`: 4.0 -> 20.0
- `STOCK_CAP_MULT_NEUTRAL`: 1.0 -> 5.0
- `STOCK_CAP_MULT_SCARCE`: 0.25 -> 1.25

With `Good.base_stock_cap = 4` (uniform across goods), per-(node, good) caps become 80 / 20 / 5 (producer / neutral / scarce), up from 16 / 4 / 1 under slice-7.

The rationale is **perturbation-scale impact**, not "more inventory for realism."

## Reasoning
With slice-7 caps (producer=16), buying 4 wool moved the curve numerator from 0 to 4, so price moved by `base_price * 4/16 = 25%` of base. That is a per-click oscilloscope -- every individual buy visibly jiggled the price label, making the curve feel like it was reacting to clicks rather than to cumulative pressure.

With slice-8 caps (producer=80), buying 4 wool moves the curve by `base_price * 4/80 = 5%`. That is **within the +/-5% perturbation envelope** (`2026-05-04-slice-8-pool-curve-formula-locked`). Individual buys no longer visibly jiggle the price; only cumulative drains (10+ units) move the curve outside the perturbation envelope.

This makes the curve player-readable: it represents accumulated pressure on the pool, not a per-click reactor. The 5x is the exact factor that achieves "individual buys move within perturbation noise"; not a round number, not a realism call.

The realism concern (a town with 4 wool reads as toy-sized) is a side benefit and pillar-coherent -- "legibility includes credibility" per Director's framing on the playtest signal -- but not the load-bearing reason for the bump. Designer asked Director to keep this intent in the ratification, not the realism framing alone.

Cargo capacity stays at 60 in slice-8. Cargo is now sometimes the binding constraint; cargo retune is the slice-8.5 single-variable follow-on per Critic's split.

## Alternatives considered
- **Keep slice-7 caps (16/4/1) under pool curve** -- rejected: per-buy price jiggle reads as a per-click reactor; legibility fails.
- **10x bump (cap=160)** -- not formally weighed; would push cumulative drain even further out of player range, risking pools never moving (gate 1 fail).
- **Variable multipliers per good** -- rejected as part of slice-8 scope; deferred to slice-8.x or beyond.

## Confidence
High. Designer specced the rationale; Director silently accepted (no override).

## Source
Designer (spec §5.8, with the rationale flagged for Director ratification, 2026-05-04 session).

## Related
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the curve formula whose sensitivity this bump tunes
- [[2026-05-04-slice-8-harness-gate-floors]] -- gate 1 (pool-motion) is the harness that verifies cumulative drain still moves pools after this bump
