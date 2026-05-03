---
title: Plentiful and scarce tag multipliers become load-bearing mechanical knobs
date: 2026-05-03
status: ratified
tags: [decision, slice-7, design, mechanics, tags]
---

# Plentiful and scarce tag multipliers become load-bearing mechanical knobs

## Decision
The `(plentiful)` and `(scarce)` tags graduate from HUD labels to mechanical drivers. They drive both stock cap and refill rate via four constants on `WorldRules`:

- `STOCK_CAP_MULT_PLENTIFUL = 4.0`
- `REFILL_MULT_PLENTIFUL = 5.0`
- `STOCK_CAP_MULT_SCARCE = 0.25`
- `REFILL_MULT_SCARCE = 0.2`

Final per-(node, good) caps and rates are derived at world-gen time from `Good.base_stock_cap * tag_mult` and `Good.base_refill_rate * tag_mult`. The procgen-world decision survives -- nodes are still generated, not authored; tags are the mechanical handle.

## Reasoning
The user's "fuller scope" choice asked for character-tuned refill (Hillfarm refills wool faster than salt). The straightforward reading was per-node `.tres` authoring, but that conflicts with the procgen-world decision (`2026-04-29-procgen-world-authored-vocabulary`). Designer reconciled the two by deriving final values from `Good.base_*` * tag multipliers: nodes stay procgen, but the `(plentiful)` tag at Hillfarm's wool slot produces a high-cap / fast-refill outcome, identical in felt experience to per-node authoring.

This **amends** `2026-05-02-slice-3-tags-as-label-not-driver`. Slice-3 said tags are HUD labels with no mechanical effect. Slice-7 explicitly extends tags into mechanics: tags now drive stock economics. Bias-as-pricing-driver is unchanged; tags drive stock economics in addition.

## Alternatives considered
- **Per-node `.tres` cap/rate authoring** -- rejected: conflicts with procgen-world decision.
- **Authored multipliers on `Good.tres` per-good per-tag** (e.g., `Good.cap_mult_plentiful` field) -- rejected: explodes the authoring surface for no expressive gain over a global table.
- **Decouple stock economics from tags entirely** -- rejected: would require a third per-(node, good) authoring axis next to bias and tags, fragmenting node character.

## Confidence
High by acceptance. User accepted the tag-multiplier shape by silence at the Designer-summary step; explicit ratification was deferred until session close.

## Source
Designer spec §4.2 and §6.2; user silence at the Designer-summary step is taken as ratification per pipeline norms.

## Related
- [[2026-05-02-slice-3-tags-as-label-not-driver]] -- amended by this decision (tags are now also mechanical drivers, not only HUD labels)
- [[2026-04-29-procgen-world-authored-vocabulary]] -- the constraint Designer reconciled the user's "per-node tuning" against
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- where the multiplier results live in the save
