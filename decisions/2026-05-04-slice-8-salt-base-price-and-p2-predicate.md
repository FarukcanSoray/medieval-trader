---
title: Salt ships at base_price=7; P2 predicate diagnostic, not blocking
date: 2026-05-04
status: ratified
tags: [decision, slice-8, salt, free-lunch-predicate, harness]
---

# Salt ships at base_price=7; P2 predicate diagnostic, not blocking

## Decision
Salt ships under slice-8 with `base_price = 7` (unchanged from slice-7). The free-lunch P2 predicate -- the gen-time check that worst-case spread on the shortest edge can cover travel cost -- becomes **diagnostic, not blocking**. P2 logs a gen-time warning if a good fails it; the harness measures profitable-edge fraction per good. The blocking condition is the harness-reported count, not the gen-time predicate.

## Reasoning
A 4-good catalogue where every good is profitable on every edge is a flat world without economic texture. Salt's role as "short-edge / filler good" fits the new pillar: economic state varies by good identity, and the player learns "salt is for short hauls and topping off cargo." That is exactly the kind of legible economic identity the pillar wants.

Real medieval salt was a low-margin bulk staple; the setting fit is a tiebreaker, not a driver.

The P2 predicate was originally derived against slice-3 random-walk math (`R * base_price + 2 * volatility * ceiling_price < max_spread_gold`). Under pools, the predicate's inputs change and it no longer maps cleanly to "profitable-on-any-edge." The harness is the truth source for ship/no-ship; the predicate becomes a diagnostic warning at gen-time.

If the slice-8 harness reports salt's profitable-edge fraction = 0 across all seeds, the slice still ships (the gates do not block on salt) but slice-8.5 picks up the salt question -- and at that point retune-base / special-case-multipliers / cargo-retune are compared against each other in one pass, with harness data in hand.

## Alternatives considered
- **Bump salt's base_price to 12** (matching wool) -- rejected: cascading retunes across the catalogue; obscures the genuine signal that salt's role is filler.
- **Special-case salt with its own multiplier table** (higher demand, lower supply) -- rejected: adds a per-good design surface that does not pay for itself in a 4-good catalogue. With 12 goods someday, special-casing might pay off; today it does not.

## Confidence
High. Director Q4 explicitly ratified with reasoning and alternatives weighed.

## Source
Director Q4 ratification (2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` §5.10, §11.1.

## Related
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this decision protects (texture via good differentiation)
- [[2026-05-04-slice-8-harness-gate-floors]] -- the harness that becomes salt's truth source

## Slice-8.5 owe-note
If `tools/measure_pricing_v2.gd` reports salt profitable-edge fraction = 0 across all seeds, slice-8.5 surfaces the salt-tuning question. Compare in one pass: retune base_price (option B), per-good multiplier table (option C), cargo retune (the already-queued slice-8.5 work). Don't pre-commit which.
