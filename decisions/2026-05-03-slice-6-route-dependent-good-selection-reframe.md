---
title: Slice-6.0 reframed -- route-dependent good selection, not per-leg portfolio composition
date: 2026-05-03
status: ratified
tags: [decision, slice-6, scope, reframe]
---

# Slice-6.0 reframed -- route-dependent good selection, not per-leg portfolio composition

## Decision
Slice-6.0's deliverable is reframed (mid-slice, post-harness-FAIL) from "every buy panel is a knapsack problem" to **"the player learns which good is optimal for each route, and the cart cap makes that commitment binding."**

What ships:
- **Route-dependent good selection** -- different routes prefer different goods (delivered: per-good aggregate weight-shares stay in [10%, 50%] band)
- **Capacity as commitment** -- the cart cap turns "what to carry" into a binding commit per trip

What does NOT ship (acknowledged narrower than original Director purpose):
- Per-leg portfolio composition (mixing multiple goods on a single route's optimal cart)

## Reasoning
The Director's original slice purpose was: *"Add per-good weight and a fixed trader cargo capacity that gates the buy action, so route choice becomes 'which **goods** to bring' instead of just 'whether to buy.'"* The plural "goods" implied per-leg multi-good optimal carts.

The first harness sweep proved per-leg portfolio composition is structurally unreachable under the slice's scope (see [[2026-05-03-slice-6-knapsack-degeneracy-lesson]]). At the chosen tuple (4,3,2,10) cap=60 gold=200, 85.4% of routes have single-good optimal carts; at gold=400, 100% are single-good. No tuning fix exists in slice-6.0 scope.

But the macro-level intent IS preserved: per-good aggregate weight-shares (wool 24%, cloth 14%, salt 45%, iron 17%) all sit inside [10%, 50%], proving different routes prefer different goods. This is real and load-bearing -- the player learns "on this edge salt is best, on that edge iron is best, and the cart cap means I can only commit to one." It is bigger than slice-5 (where good selection was decoupled from any binding constraint).

The reframe respects both pillars:
- **Pillar 1** (math problem the player can win) -- the math is "compute profit-per-weight for each good on this route, pick the winner." Legible, winnable.
- **Pillar 2** (travel always costs something the player feels) -- capacity adds opportunity cost: every unit of wool you carried is a unit of iron you didn't.

Designer ratified the reframe in spec §2 ("Honest framing, post-harness") and concluded "no Director re-greenlight needed" -- the slice still delivers something real, the bigger redesigns that would deliver per-leg portfolio are explicitly logged for future Director conversations.

User accepted the reframe in-conversation, choosing path 1 ("proceed to Engineer for the harness criterion update + re-run + commit") over path 2 ("loop the Director briefly on the singular-vs-plural shift"). The reframe ships as part of slice-6.0.

## Alternatives considered
- **Push the singular-vs-plural shift back to Director for re-greenlight** -- not chosen; user picked path 1. Designer's argument: slice still delivers route-shape decision (real), structural mechanics for per-leg portfolio are out-of-scope (logged for future).
- **Retune weights to chase the original criterion** -- rejected: structurally impossible (see knapsack-degeneracy lesson).
- **Cut the slice entirely as failed-design** -- rejected: per-good aggregate divergence IS the slice's macro intent and IS delivered; the failure was in the criterion's bundled second claim.

## Confidence
High. The reframe is data-grounded (per-good aggregate shares clearly distinguish goods at the route level), the user explicitly accepted, and the spec §2 + §13 capture both the framing and the lesson.

## Source
`docs/slice-6-weight-cargo-spec.md` §2 (honest framing), §13.2 (what slice-6.0 actually delivers); user's "1" reply selecting Engineer-continuation over Director-re-loop.

## Related
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the structural finding that forced this reframe
- [[2026-05-03-slice-6-revised-harness-criterion]] -- the criterion that now measures the reframed deliverable
- [[project-brief]] -- pillars and kernel against which the reframe was checked
