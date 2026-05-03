---
title: Per-node production caps anointed for slice 7
date: 2026-05-03
status: ratified
tags: [decision, slice-7, design, scope, director-call]
---

# Per-node production caps anointed for slice 7

## Decision
Slice-7 ships **per-node production caps with character-tuned refill** as its load-bearing mechanic. Each (node, good) pair has a stock cap and a per-tick refill rate; cleaning out a node leaves it empty until refills restore it. The two slice-6 §13.3 alternatives (sell-side elasticity, multi-leg route commitments) are deferred.

## Reasoning
Caps live *inside* the existing buy panel -- no new screen, no new verb. Both halves of the kernel collision tighten on the same decision: the buy decision sharpens (the best good is now finite on this leg), and the travel decision sharpens (returning to the same node too soon wastes a leg). Caps also break the integer-knapsack degeneracy slice-6 documented: with a cap of N on the best good, a cart big enough to overflow that cap forces the second-best good to be recruited. The mixed-cart promise becomes recoverable without changing any verb, screen, or planning layer.

## Alternatives considered
- **Sell-side elasticity** (selling N units drops local price). Strengthens the kernel but more sideways: touches the slice-1 single-unit buy/sell verb contract. Either price-shifts during a sell or requires a depth-of-book UI.
- **Multi-leg route commitments** (player commits to A->B->C ahead of time). Pulls sideways: planning layer adjacent to the kernel rather than inside it. Risks becoming a separate game.
- **Bandit weight-awareness retune / TraderState migration / more goods** (named carryover). None of these address the §13.3 ceiling that slice-6 documented.

## Confidence
High. Director gave a structured fit-to-pillars verdict; user accepted with "ok go for production caps."

## Source
Director report (in slice-7 pipeline conversation, 2026-05-03). Spec §1 codifies the framing.

## Related
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the §13.3 ceiling caps are designed to break
- [[2026-05-03-slice-7-fuller-scope-not-cuts]] -- the scope shape ratified at the Critic step
- [[2026-05-03-slice-7-world-has-memory-pillar]] -- the project-shape consequence of choosing caps
