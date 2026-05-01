---
title: Three nodes in the slice (not two)
date: 2026-04-29
status: ratified
tags: [decision, slice, topology]
---

# Three nodes in the slice (not two)

## Decision
The vertical slice includes **3 nodes** (towns/cities), not 2. This is a structural slice decision, not a tuning number.

## Reasoning
Three nodes form the smallest topology that lets the player make a route choice (which node to visit next). Two nodes is just A↔B, which doesn't exercise the real loop. Three is closer to the real game without adding meaningful integration cost.

## Alternatives considered
Two nodes — leaner, but doesn't test the choose-a-route core of the kernel.

## Confidence
High. Explicit user ratification on Designer's recommendation.

## Source
User answer to Designer's open question, 2026-04-29: "3 nodes is ok for this slice." Captured in `docs/slice-spec.md` §6.

## Related
- [[slice-spec]] — captured in the ratifications header and §6
- [[2026-04-29-no-cuts-slice-first]] — slice-first construction strategy this operationalises
