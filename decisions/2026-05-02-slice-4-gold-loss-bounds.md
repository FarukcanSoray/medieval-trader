---
title: Gold-loss outcome = 5%-20% of carried gold, hard cap 30g
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, encounters, balance, pillar-2, pillar-3]
---

# Gold-loss outcome = 5%-20% of carried gold, hard cap 30g

## Decision
When a bandit encounter fires, the gold loss is computed as:
```
loss_fraction  = randf_range(0.05, 0.20)  // BANDIT_GOLD_LOSS_MIN/MAX_FRACTION
gold_loss      = mini(30, roundi(loss_fraction * trader_gold))
                                  // BANDIT_GOLD_LOSS_HARD_CAP
```
The percentage is rolled per encounter; the hard cap is absolute.

## Reasoning
- **Percentage scaling** makes the loss felt proportionally (Pillar 2: "travel always costs something the player feels"). A flat loss would trivialise in late game and cripple in early game.
- **Hard cap (30g)** protects Pillar 3 (death rare and earned). Without a cap, a single roll could remove 80% of a fortune and softlock the run. The cap means even a wealthy trader can survive a streak of bad rolls.
- **5%-20% band** keeps the encounter felt without making it dominate the round-trip math. Critic's Pillar-1 protection (cost-preview shows `+0..30g`) is what makes this tractable for the player.

## Alternatives considered
- **Flat gold loss** — rejected; trivialises late-game.
- **Uncapped percentage** — rejected; breaks Pillar 3.
- **Cap as percentage of wealth (e.g. 30%)** — rejected; same softlock risk on bad streaks.

## Confidence
High for the structural choices (percentage + cap); medium for the specific numbers (`[needs playtesting]` per spec §6).

## Source
Designer spec §5.4, §6.

## Related
- [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] — Pillar-1 surface for these bounds
- [[2026-04-29-death-rare-and-earned]]
