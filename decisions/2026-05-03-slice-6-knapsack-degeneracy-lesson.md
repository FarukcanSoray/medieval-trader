---
title: Optimization-shaped slice mechanics with no diminishing returns produce single-item optima
date: 2026-05-03
status: ratified
tags: [decision, lesson, design-principle, harness, measurement]
---

# Optimization-shaped slice mechanics with no diminishing returns produce single-item optima

## Decision
**Project-level design lesson** captured in `docs/slice-6-weight-cargo-spec.md` §13.4. Integer knapsack with N goods of distinguishable profit-per-weight, **no diminishing returns at the sell node, no per-node production caps, and rational profit maximization** always degenerates to single-good optimal solutions when the gold constraint is unbinding. This is a math fact, not a tuning failure.

**Future Designer-shaped slices that lean on optimization should work the simplest-case math first, before writing a harness threshold.** When writing a measurement criterion for an optimization-shaped mechanic, ask: "under what condition is multi-item optimal?" If the answer is "diminishing returns or per-item caps," and the slice has neither, the criterion cannot demand multi-item solutions.

## Reasoning
The first slice-6.0 harness sweep returned **0 PASSes across 105 sweep tuples** under the original §7.2 criterion (which required >=60% of routes to have multi-good optimal carts). Five different weight assignments all hit identical degenerate results -- 0.0% multi-good at gold=400 -- proving the failure was not under-tuning but a structural property of the math.

The slice's mechanic, as scoped, gives the optimizer no reason to mix:
- **No diminishing returns** at the sell node: selling 6 iron returns 6x the per-unit price; the 7th iron earns the same per-unit price as the 1st
- **No per-node production caps**: the seller has unlimited supply
- **Capacity-only constraint**: cargo weight is the binding axis when gold is plentiful

Under these conditions, integer knapsack reduces to "rank the goods by profit-per-weight at this route, fill the cart with the winner." With 4 goods of distinguishable profit-per-weight ratios, there is *always* a winner -- ties are vanishingly rare and quickly broken by tick-to-tick price drift.

The original spec promised "every leg is a knapsack problem" with the implicit assumption that knapsack ⇒ multi-item. That implication is wrong. Knapsacks have multi-item solutions only when there's a constraint preventing fill-with-the-best (caps, diminishing returns, non-linear cost, multi-constraint fronts that fragment the cart awkwardly).

## Three out-of-scope mechanics that would unlock per-leg portfolio depth

Logged in spec §13.3 for future Director conversations:

1. **Per-node production caps** -- "Hillfarm has at most 8 wool to sell this tick"
2. **Sell-side elasticity** -- "the 6th iron sells at base price; only the first 5 hit the high price"
3. **Multi-leg route commitments** -- weight matters across legs because the player commits to A→B→C upfront

Each is a real new mechanic and would need its own Director call (pillar fit, scope frame, exclusions).

## Alternatives considered
- **Retune weights to force multi-item solutions** -- rejected: impossible without the structural mechanics above. The harness sweep across 7 weight tuples × 5 capacities × 3 gold tiers found no PASS region for the original criterion.
- **Declare the harness useless, ship without measurement** -- rejected: the harness still discriminates good tuples from bad on macro-divergence (per-good aggregate share band), and catches pathological cases like (1,1,1,1) where salt eats 64% of cargo.
- **Defer the lesson to documentation only, no code change** -- rejected: the lesson without the codified harness pattern leaves future slices to re-derive it. The slice-6.0 spec §13 records this as a project-level design principle.

## Confidence
High. The empirical data is explicit (0/105 PASS under the original criterion across a sweep designed to find a passing tuple if one existed). The structural argument is mechanical (knapsack with no constraint diversity has single-item optima). The lesson generalises: any future slice that says "the player solves a knapsack" should pre-check that the mechanic has the constraint diversity to make multi-item optimal.

## Source
`docs/slice-6-weight-cargo-spec.md` §13 (entire section), especially §13.4 (process lesson). First harness sweep verdict: `godot/tools/cargo_divergence_verdict.txt` (now overwritten by the PASS-under-revised-criterion run; the FAIL data was captured in conversation and in the spec §13 narrative).

## Related
- [[2026-05-03-invariant-harnesses-run-against-post-mutation-state]] -- prior harness-design lesson; this one extends the family
- [[feedback_measurement_before_tuning]] -- the standing rule that surfaced this lesson; rule confirmed even harder by this case
- [[2026-05-03-slice-6-route-dependent-good-selection-reframe]] -- the slice-purpose reframe driven by this lesson
- [[2026-05-03-slice-6-revised-harness-criterion]] -- the criterion that now measures what the slice actually delivers
