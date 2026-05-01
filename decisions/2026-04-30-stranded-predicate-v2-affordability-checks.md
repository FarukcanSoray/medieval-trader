---
title: Stranded predicate v2 — affordability existence checks (supersedes 2026-04-29 gold==0 form)
date: 2026-04-30
status: ratified
tags: [decision, design, death-mechanics, slice-0.5, supersession]
---

# Stranded predicate v2 — affordability existence checks

## Decision
The stranded predicate, evaluated by `DeathService` on the trigger set defined in [[2026-04-30-stranded-trigger-set-gold-changed-tick-advanced]], is revised to an affordability-existence form:

```
not world.dead
AND trader.travel == null
AND trader.inventory.is_empty()
AND not node.has_affordable_good(trader.gold)
AND for every outbound edge: trader.gold < WorldRules.edge_cost(edge)
```

Where the affordability boundary is strict `>=` (see [[2026-04-30-affordability-boundary-strict-gte]]), and the read-only accessors `NodeState.has_affordable_good(gold)` and `WorldState.outbound_edges(node_id)` were placed by the Architect alongside the existing `get_node_by_id`.

This **supersedes [[2026-04-29-stranded-includes-empty-inventory]]**. The prior decision's `gold == 0` clause was an implementation shortcut that misfired in the small-gold dead-zone.

The predicate's intent in one sentence: *the trader is stranded when no productive action is available* — they cannot afford to buy any good at the current node, cannot afford to traverse any outbound edge, are not already mid-travel, and hold no goods that selling could convert back into agency.

## Reasoning
First playtest exposed a soft-lock: the user spent gold on travel, ended at a node with non-zero gold but couldn't afford any good *and* couldn't afford any edge, inventory empty. Game did not end. The literal `gold == 0` clause was too narrow — it killed the player at gold-zero-with-empty-inventory (correctly) but missed the case where money exists yet is functionally useless.

The Director's fit-to-pillar verdict: the narrow predicate fails the careful-merchant fantasy ([[2026-04-29-fantasy-careful-merchant]]) precisely where it matters. Pillar 1 says every trade decision is a math problem the player can win; the dead-zone the playtest surfaced is one where the math has already been lost but the system refuses to acknowledge it. That is worse than death — it converts the careful merchant into a confused merchant staring at a non-zero number that means nothing.

Drift-check confirmed against the four intake resolutions: this widens the *shape* of stranded states, not their *frequency*. Death-rare-and-earned ([[2026-04-29-death-rare-and-earned]]) is preserved — a competent careful merchant still won't hit it for hours. The buffer-discipline lesson only works if the punishment lands cleanly when the buffer fails; previously it didn't land at all.

The decision file being superseded pre-flagged this revisit explicitly: *"if first slice playtest shows the enriched predicate is wrong, revisit."* Now is that revisit.

## Alternatives considered
- **Re-ratify the v1 predicate as-is** — rejected. The playtest defect is not a tuning issue; the boundary is wrong, not the constants.
- **Frame `gold == 0` as the lesson and call the dead-zone "earned punishment for misjudging the buffer"** — rejected. The dead-zone leaves the player alive with no legal move, which is worse UX than death; "buffer discipline" only reads as a lesson if death actually punctuates it.
- **Defer the fix to Slice 1** — rejected. The bug masks the death loop and blocks further playtest of the slice-spec §5 mechanic.

## Confidence
High at the predicate level (intent is unambiguous; Director ratified). Medium on long-term tuning — whether `>=` is the right boundary may shift under more playtest, but the existence-check shape is settled.

## Source
- Director's verdict, Slice 0.5 post-playtest (this conversation).
- User's playtest report: "I spent nearly all my money for travelling, and I left with money that cannot buy anything or travel, yet it was not 0 so the game didn't end."
- Designer's spec call (this conversation).
- Reviewer ratification, Slice 0.5 (this conversation).

## Related
- [[2026-04-29-stranded-includes-empty-inventory]] — superseded by this decision
- [[2026-04-30-affordability-boundary-strict-gte]] — defines the `>=` boundary used here
- [[2026-04-30-stranded-trigger-set-gold-changed-tick-advanced]] — defines when this predicate is evaluated
- [[2026-04-30-world-rules-shared-static-config]] — defines `WorldRules.edge_cost` used here
- [[2026-04-30-stranded-connection-order-deferred]] — known gap in this predicate's evaluation timing
- [[2026-04-29-fantasy-careful-merchant]] — fantasy this predicate must serve
- [[2026-04-29-death-rare-and-earned]] — drift-check passed
- [[2026-04-29-death-cause-stranded]] — cause label remains "stranded"
- [[slice-spec]] §5 — death trigger
