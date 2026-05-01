---
title: Death-cause label is "stranded" (not "bankruptcy"); past-participle tone precedent
date: 2026-04-29
status: ratified
tags: [decision, design, death, tone]
---

# Death-cause label is "stranded" (not "bankruptcy"); past-participle tone precedent

## Decision
The slice's only death cause uses the literal cause string `"stranded"`. The death screen reads, sketch:

> Lived 47 years. Stranded at Rivertown with 0 gold and nowhere to go.

The Director also set a **tone precedent** for all future death-cause labels: single concrete past-participle states a chronicler would write in a ledger — `stranded`, `slain`, `taken by age`, `lost on the pass` — never clinical nouns (`bankruptcy`, `mortality`, `combat`).

This binds:
- `Game.died.emit("stranded")` (not `"bankruptcy"`)
- `world.death.cause = "stranded"` in the save schema

## Reasoning
"Bankruptcy" is 19th-century legal-financial register and frames the trader as a corporate entity, not a person on a road. "Stranded" is literal-physical (broke at a node, can't move), period-neutral, and protects the careful-merchant fantasy: the trader miscalculated a route, ran the numbers thin, and the road ran out before the gold did. It rhymes with the death-screen's job — "leaving a story, not a verdict" (kickoff resolution: no-win + permadeath = sandbox with one terminal punctuation).

The single word matters more than usual because the death screen is the only narrative punctuation in the game.

## Alternatives considered
- **`"bankruptcy"`** — rejected: wrong register, modern-corporate framing, undercuts the medieval-trader fantasy. Was the slice-spec's original literal.
- Other unspecified labels (`"ruin"`, `"destitute"`) — not discussed; Director chose `stranded` as the archetype.

## Confidence
High. Director call with explicit reasoning; both `slice-spec.md` (§5, §11) and `slice-architecture.md` (§2.2 epitaph, §3 signal table, §7 Tier 4, §8) were patched post-decision.

## Source
Director call resolving Q1 from `slice-architecture.md` §8 open questions, 2026-04-29 evening.

## Related
- [[project-brief]] — Pillar 1 "careful merchant" fantasy that the label protects
- [[slice-spec]] — §5 (death trigger) now uses `"stranded"`
- [[slice-architecture]] — §2.2, §3, §7 Tier 4, §8 all use `"stranded"`
- [[2026-04-29-no-win-condition]] — death is the game's only terminal punctuation
- [[2026-04-29-death-rare-and-earned]] — the tone the label has to live up to
