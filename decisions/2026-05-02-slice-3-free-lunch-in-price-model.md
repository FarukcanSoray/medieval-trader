---
title: Free-lunch predicate lives in the price model, not the generator
date: 2026-05-02
status: ratified
tags: [decision, slice-3, free-lunch, pillar-1, design]
---

# Free-lunch predicate lives in the price model, not the generator

## Decision
The free-lunch detection predicate -- whether a short edge's spread can exceed travel cost -- is enforced as a bias bound in the price model at world-gen time, not as a topology rejection rule in the generator.

## Reasoning
Putting the predicate in the generator would reject valid topologies for reasons the player can't see. That violates Pillar 1: "the world is shaped this way for reasons hidden from you" is exactly the opacity the pillar forbids. A pricing-side bound is legible: the player can reason "the spread can never exceed N on a short edge, so the route only pays if drift is favourable." That's a math problem they can win.

## Alternatives considered
- Generator-side topology rejection -- rejected for opacity; the generator would reject layouts for reasons invisible to the player.
- Soft mitigation (accept free-lunch, hope playtesters don't find it) -- rejected on principle; the slice cannot ship with a known kernel violation.

## Confidence
High. Director named the specific Pillar 1 failure mode and chose the legible alternative.

## Source
Director intake, free-lunch resolution section.

## Related
- [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]]
- [[2026-05-02-slice-3-free-lunch-option-a-edge-length-bound]]
- [[project-brief]]
