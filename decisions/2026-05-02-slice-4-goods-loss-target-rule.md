---
title: Goods-loss target = most-valuable-by-origin-price, 50% of stack, lex-min tie-break
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, encounters, day-2]
---

# Goods-loss target = most-valuable-by-origin-price, 50% of stack, lex-min tie-break

## Decision
When a bandit encounter fires AND the trader carries any goods, the encounter ALSO targets the most-valuable good in cargo:

- **Selection:** the good with the highest **origin-node price** (the price at the leg's `from_id`). Ties broken by lex-min `good_id`.
- **Quantity:** `max(1, floor(BANDIT_GOODS_LOSS_FRACTION * stack_qty))` where the constant is `0.50`. So a stack of 1 loses 1; a stack of 4 loses 2; a stack of 10 loses 5.
- **No new RNG draw.** Selection is purely derived from inventory + origin prices.
- Goods loss is **additive** to gold loss, not in place of it.

## Reasoning
The player must be able to predict what gets stolen. Hidden selection criteria (e.g., random good, weighted-by-quantity) would break Pillar 1 — the player couldn't reason about whether to carry a high-value cargo through bandit territory. "Most-valuable-by-origin-price, 50% of stack" is computable from observable state (inventory + the origin node's price panel).

Lex-min tie-break is deterministic and order-independent (Dictionary iteration order doesn't affect the result).

Origin prices (not destination) because the loss happens en route, not at sale — bandits steal what they can move, valued by where they are now.

## Alternatives considered
- **Random good, weighted by stack qty** — rejected; player can't reason ahead.
- **Most-valuable-by-DESTINATION-price** — rejected; couples loss to a price the trader hasn't yet observed (intended buyer's price), making the math harder.
- **All-goods-prorated loss** — rejected; spreads the loss across cargo, weakening the "this specific cargo was risky" signal.

## Confidence
High for the structural rule; medium for the 50% fraction (`[needs playtesting]`).

## Source
Designer spec §5.7.

## Related
- [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] — the sibling Pillar-1 surface
