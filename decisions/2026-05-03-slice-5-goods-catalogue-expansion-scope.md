---
title: Slice-5 scope = goods catalogue expansion to 4 goods (Branch B compressed)
date: 2026-05-03
status: ratified
tags: [decision, slice-5, scope, design]
---

# Slice-5 scope = goods catalogue expansion to 4 goods (Branch B compressed)

## Decision
Slice-5 expands the goods catalogue from 2 to 4 hand-authored goods spanning a deliberate (price, volatility) role taxonomy. Director's "Branch A" (count expansion) and "Branch B" (count + named personality roles) are compressed into one slice -- A alone is a tuning pass dressed as a slice, so B is what ships. Branch C (mechanical axes -- perishability, weight, regional bias) is explicitly out of slice-5: weight is named slice-5.x, perishability is slice-6+. Director's fit-to-pillars verdict was conditional: legibility per good must hold (each good's identity must be holdable in the player's head -- "the volatile cheap one," "the steady expensive one"). Mastery transfers as procedural reasoning per [[2026-04-29-procgen-world-authored-vocabulary]]; new rules per good (perishability, weight) violate that and belong in later slices.

## Reasoning
The brief promised 6-12 goods; the slice currently shipped 2. Pure count expansion (Branch A) without role differentiation would be tuning surface inflation -- the player would carry a longer inventory list with no new decision per item, making the math problem bigger but not deeper (Pillar 1 violation). Adding mechanical axes (Branch C) would introduce N rules for N goods rather than one rule applied to N values -- the geography-memorization failure mode the procgen-vocabulary decision was meant to rule out.

Critic's compression call: A and B are not separate slices because B is what A becomes when tuned deliberately. Critic also pressure-tested the joint risk of count+axis in one slice and ruled them must sequence -- you cannot diagnose 4-good legibility cleanly while a new "cargo full" gate is also in play.

Four goods is the minimum count where role identity is forced into legibility (with two, every good is "the other one"; with four, the player must name the role to track it).

## Alternatives considered
- **Branch A alone (count expansion to 4-6 goods, identical fields)** -- Critic-compressed; A is what ships only when B's role-spread tuning is also applied.
- **Branch C (perishability or weight) in slice-5** -- Critic deferred; weight to slice-5.x, perishability to slice-6+. Joint risk with count expansion is the binding rejection.
- **Old-age death** (alternative slice-5 candidate before user picked goods) -- not chosen this session; remains live as a future slice.
- **Second encounter type** (weather, spoilage, tolls) -- same; future slice.

## Confidence
High. Director ratified fit-to-pillars (with legibility condition); Critic compressed branches and sequenced; Designer ratified the four-good catalogue at spec §1; Architect and Reviewer rounds did not reopen scope.

## Source
Director's framing (Round 1, fit-to-pillars verdict); Critic's compression and sequencing (Round 2); Designer spec `docs/slice-5-goods-expansion-spec.md` §1, §2.

## Related
- [[2026-04-29-slice-two-goods]] -- the slice-1 commitment to 2 goods, with the explicit promise to expand
- [[2026-04-29-procgen-world-authored-vocabulary]] -- procedural-reasoning constraint that ruled out new rules per good
- [[2026-05-03-slice-5-four-good-role-taxonomy]] -- the role taxonomy this scope ratifies
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- the day-1/day-2 split gate
