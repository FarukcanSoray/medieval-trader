---
title: Slice-3 splits into day-1 kernel and day-2 in-slice tag/HUD work
date: 2026-05-02
status: ratified
tags: [decision, slice-3, sequencing]
---

# Slice-3 splits into day-1 kernel and day-2 in-slice tag/HUD work

## Decision
Slice-3 ships in two ordered tranches:
- **Day-1 (kernel):** per-good volatility, drift mean-reversion, bias on `NodeState`, free-lunch predicate, schema bump.
- **Day-2 (in-slice):** producer/consumer tags + HUD ASCII labels.
- **Deferred to slice-3.x:** empirical topology-revisit against slice-2.5 seeds with live pricing.

## Reasoning
Critic named the split to keep day-1 focussed on the kernel work that makes the pricing slice mean what it says. Tags depend on bias being in place; sequencing them after the kernel proves out lets HUD render against a working pricing model rather than chase it. Deferring the empirical topology-revisit honours the slice-first stance: the carryover stays named (slice-3.x), the work doesn't evaporate.

## Alternatives considered
None named explicitly -- this was Critic's sequencing recommendation, and the user ratified by proceeding.

## Confidence
Medium-high. Sequencing is concrete; rationale ("cheaper to focus") is comparative rather than quantified.

## Source
Critic stress-test, sequencing section.

## Related
- [[2026-05-02-slice-3-tags-in-slice]]
- [[2026-05-02-slice-3-min-edge-distance-3-pulled-forward]] -- the slice-3.x deferred topology fix that ended up pulled forward
