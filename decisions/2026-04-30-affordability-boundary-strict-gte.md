---
title: Affordability boundary is strict >= on both gold-vs-price and gold-vs-edge-cost
date: 2026-04-30
status: ratified
tags: [decision, design, death-mechanics, economy, slice-0.5]
---

# Affordability boundary is strict `>=` on both gold-vs-price and gold-vs-edge-cost

## Decision
When evaluating affordability inside the stranded predicate ([[2026-04-30-stranded-predicate-v2-affordability-checks]]):

- A good is affordable iff `trader.gold >= node.prices[good_id]`.
- An edge is traversable iff `trader.gold >= WorldRules.edge_cost(edge)`.

Both inequalities are equality-including (`>=`, not `>`). Same convention on both sides.

This binds:
- `NodeState.has_affordable_good(gold: int) -> bool` — returns true iff any entry in `prices` satisfies `gold >= price`.
- `DeathService._check_stranded` — the outbound-edge loop uses `gold >= edge_cost` as the affordability gate.

## Reasoning
Buying at `gold == price` is a productive action, not a stranded one — it converts gold into a good that can be re-sold at the same node next tick (if price drifts up) or at a neighbour with a higher price. Landing at `gold == 0` holding a good is exactly the recovery state the careful-merchant fantasy ([[2026-04-29-fantasy-careful-merchant]]) protects.

Symmetric reasoning for edges: spending the last 8 gold on an 8-cost edge lands the trader at a new node with a different price set — productive, not terminal. Either side using strict `>` would create a false-stranded edge case where the trader has *exactly enough* gold but the predicate refuses to count it as agency.

The `>=` boundary keeps the recovery doors open. The careful merchant who lands at `gold == price` of one good (and no other path forward) has a genuine play left: buy, sell back next tick at drift, or carry to a neighbour. The system should respect that play, not punish it.

## Alternatives considered
- **Strict `>` on both sides** — rejected. Creates a false-stranded case at `gold == price` and `gold == edge_cost`, contradicting the predicate's intent (no productive action available).
- **Asymmetric: `>=` for goods, `>` for edges** — not seriously considered; no asymmetry justification surfaced.

## Confidence
High at the boundary choice (Designer call with explicit reasoning). Medium on whether the `gold == price` recovery case actually plays well — that's a tuning question for further playtest, not a correctness question.

## Source
- Designer's spec call, Slice 0.5 (this conversation), §2 of the rule spec.
- Engineer's edge-case walk during implementation confirmed both boundary cases (`gold=5, cheapest good=5 → lives`; `gold=5, cheapest edge=5 → lives`).

## Related
- [[2026-04-30-stranded-predicate-v2-affordability-checks]] — the predicate this boundary serves
- [[2026-04-29-fantasy-careful-merchant]] — fantasy that the boundary protects
- [[2026-04-29-rename-floor-ceiling-price]] — related price-boundary terminology decision
