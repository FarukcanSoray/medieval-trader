---
title: Bias is a multiplicative anchor on base_price (not additive, not target-walk)
date: 2026-05-02
status: ratified
tags: [decision, slice-3, pricing-model, design]
---

# Bias is a multiplicative anchor on base_price (not additive, not target-walk)

## Decision
Per-node, per-good bias is represented as a multiplicative factor on `base_price`. The drift formula's anchor (the value drift walks toward) is `base_price * (1 + bias)`. Bias is float internally; prices stay int (rounded at the drift output).

## Reasoning
- **Multiplicative scales with good identity.** A `bias = -0.3` on a 12g good means -3.6g; on a future 100g good it means -30g. Additive offsets would either be tiny on cheap goods or implausible on expensive ones, requiring a per-good range. Multiplicative is one knob that travels.
- **Integer-math preserved at the boundary.** Float internally, int at the storage/display layer; rounding happens once at the drift output.
- **Floor/ceiling stays clean.** The clamp catches the tail of the distribution, not the centre.

## Alternatives considered
- **Additive offset** -- rejected because absolute offsets don't scale across goods of different base prices.
- **Drift-target anchor** (price chases a target with a smoothing parameter) -- rejected as a third tunable on top of volatility and bias; mean-reversion handles the same need without it.

## Confidence
High. Designer named all alternatives, gave specific reasons for rejecting each.

## Source
Designer spec §5.2.

## Related
- [[2026-05-02-slice-3-mean-reversion-added]]
- [[slice-3-pricing-spec]]
