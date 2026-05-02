---
title: Free-lunch detection deferred to pricing slice; topology-revisit owed
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, deferral, free-lunch, cross-slice-dependency, kernel]
---

# Free-lunch detection deferred to pricing slice; topology-revisit owed

## Decision

Free-lunch degeneracy detection -- a short edge whose price spread will reliably exceed travel cost under any plausible pricing -- cannot be ratified in slice-2.5. The check requires generator-times-pricing coupling, and slice-2.5 has the generator but no pricing system.

Detection and threshold ratification are deferred to **whichever slice introduces price-spread systems**. That slice owes a **topology-revisit step**: examine slice-2.5 survey data with live pricing in hand, decide whether free-lunch needs a topology rejection predicate (in the generator) or a pricing constraint (in the price model).

## Reasoning

Critic identified the structural gap in Director's "no, unless" frame condition 3 (defer thresholds that need systems not yet built). Free-lunch passes that gate cleanly in isolation -- defer it -- but the deferral creates a cross-slice dependency: the pricing slice has to remember to revisit topology rejection on its own. Without an artifact carrying that memory, the question goes silent.

Logging this as an explicit decision is the artifact. Pattern matches [[2026-05-02-slice-2-5-named-tuning-pass]] -- name the deferred work, archive through decisions, keep the carryover live.

## Alternatives considered

- **Attempt detection in slice-2.5 against placeholder spreads.** Rejected. Inauthentic; would have to be re-done against live pricing anyway, and the threshold from placeholders would mislead.
- **Leave the coupling implicit.** Rejected. Critic named this as the silent-carryover failure mode the slice-first stance is built to prevent.
- **Remove free-lunch from the named degeneracy list.** Rejected. The kernel violation (arbitrage profit erp travel cost gone) is real; the question survives, only its slice changes.

## Confidence

Medium. The structural dependency is high-confidence; the *resolution* (which slice, how to revisit, whether topology or pricing owns the predicate) is unsettled. This decision logs the dependency, not the resolution.

## Source

This session (2026-05-02 PM, slice-2.5 framing). Critic stress-test "The 'no, unless' framing -- accept, with one gap" section; Critic's recommendation to land this as a follow-up Decision Scribe entry.

## Related

- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]] -- the prior deferral this one extends.
- [[2026-05-02-slice-2-5-named-tuning-pass]] -- the slice-first stance this carryover preserves.
- [[slice-2-5-survey-protocol]] -- holds the survey data the pricing slice will revisit.
