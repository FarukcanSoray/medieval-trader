---
title: Stranded condition includes empty-inventory check
date: 2026-04-29
status: superseded
superseded_by: 2026-04-30-stranded-predicate-v2-affordability-checks
superseded_date: 2026-04-30
tags: [decision, design, death-mechanics, superseded]
---

> **Superseded 2026-04-30** by [[2026-04-30-stranded-predicate-v2-affordability-checks]]. The `gold == 0` clause was too narrow — it missed the small-gold dead-zone (gold > 0 but unable to afford any good or edge, inventory empty). The successor decision replaces the gold-amount clause with affordability existence checks. The `inventory.is_empty()` clause from this decision is preserved in the successor; only the gold clause was wrong. See the successor for the v2 predicate, the `>=` boundary call, and the trigger set.

# Stranded condition includes empty-inventory check

## Decision
The stranded predicate evaluated by `DeathService` on every `gold_changed` is:

```
gold == 0 AND trader.travel == null AND trader.inventory.is_empty() AND not world.dead
```

This enriches the literal slice-spec §5 wording ("cannot afford to buy and cannot afford to travel anywhere") with an explicit inventory-empty check. The implementation already reflects the ratified predicate at `godot/systems/death/death_service.gd:11-23`.

## Reasoning
At `gold == 0`, the literal §5 predicate reduces to "at a node, not travelling" — because every good costs > 0 (so no buy possible) and every edge has cost > 0 (so no travel possible). But a player who buys at `gold == cost` lands at `gold == 0` *with goods to sell*, and selling at the same node would recover them. The literal predicate kills them too eagerly.

"Stranded" in the slice's tone is about *no productive action available*, not a precise mechanical predicate. The inventory check captures the spec's intent: a player is stranded when there is genuinely nothing to do — no gold to buy with, no goods to sell, no edge they can afford to traverse. With goods in inventory, selling unstrands them.

The alternative (literal predicate) creates a cliff that surprises careful merchants — the very player archetype the project's careful-merchant fantasy is built around (see [[2026-04-29-fantasy-careful-merchant]] and [[2026-04-29-death-rare-and-earned]]).

## Alternatives considered
- **Use the literal §5 predicate** (`gold == 0 AND not travelling`) — rejected: kills the player at gold 0 even with goods to sell; counterintuitive and contradicts the careful-merchant fantasy.
- **Defer to playtesting** — rejected as the default but kept as a check: if first slice playtest shows the enriched predicate is wrong (e.g., players exploit by always carrying inventory), revisit.
- **Enrich with the inventory check** — chosen: aligns with the spec's clear intent and the careful-merchant tone.

## Confidence
High at the predicate level; medium on the long-term tuning. The mechanical correctness is clear; whether the predicate tunes correctly under playtest is a separate question, deferred to the slice's first end-to-end run.

## Source
This conversation, mid-session ratification ("Question A: 1"). The slice-spec §5 ambiguity was surfaced by the Tier 4 Engineer; the inventory-clause enrichment was added in `death_service.gd` and flagged `[needs Designer call]` until ratification.

## Related
- [[2026-04-29-death-cause-stranded]] — the cause label for this death is `"stranded"`
- [[2026-04-29-slice-one-death-cause-bankruptcy]] — slice has one death cause; this is it
- [[2026-04-29-death-rare-and-earned]] — careful-merchant ⇒ death is rare and earned, not a mechanical cliff
- [[2026-04-29-fantasy-careful-merchant]] — fantasy this predicate must serve
- [[slice-spec]] — §5 stranded condition (literal text)
