---
title: Full procgen world, hand-authored vocabulary
date: 2026-04-29
status: ratified
tags: [decision, design, procgen]
---

# Full procgen world, hand-authored vocabulary

## Decision
The world is procedurally generated (map shape, node placement, price tables, event seeds), but the vocabulary is hand-authored and stable (goods catalogue, encounter types, cost structures). Mastery is procedural reasoning ("find this world's wool-to-cloth corridor"), not memorized geography.

## Reasoning
Director resolved the "full procgen vs. knowable system" tension by splitting scope. Procgen the world; hand-author the vocabulary. This lets the player build mental models that transfer across maps without requiring encyclopedic memorization. It also helps web export — procgen is cheap, hand-authored places are asset-heavy.

## Alternatives considered
- Full hand-authoring (rejected: violates the user's "procgen full" answer; expensive on web).
- Full procgen including the vocabulary (rejected: kills mastery; the player has no stable language to reason in).

## Confidence
High. Explicit tension resolution; clearly spelled out in the brief.

## Source
`docs/project-brief.md` — "Tensions resolved during intake" section; Director's second tension resolution.

## Related
- [[project-brief]] — fully captured there
- [[2026-04-29-open-questions-combat-procgen-meta]] — the "procgen full" answer this refines
- [[2026-04-29-fantasy-careful-merchant]] — vocabulary stability protects "knowable system" mastery
