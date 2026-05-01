---
title: Slice-2.5 named as a tuning pass for generator rejection criteria
date: 2026-05-02
status: ratified
tags: [decision, scope, slice-2-5, tuning, deferral]
---

# Slice-2.5 named as a tuning pass for generator rejection criteria

## Decision

A named follow-up slice, **slice-2.5**, exists to ratify the generator rejection criteria deferred from slice-2. Its scope:

- Boot the slice-2 generator with ~20 different seeds.
- Inspect the resulting worlds against the per-generation log line (`seed=N nodes=K edges=M starting=<id> min_edge_dist=d max_edge_dist=D`).
- Identify degenerate shapes: hub-and-spoke topology, free-lunch arbitrage corners, dominant routes, isolated long edges, flat-market boots.
- Ratify rejection thresholds (max degree, min edge distance, max spread/cost ratio, etc.).
- Decide whether to enforce the thresholds in the generator (for slice-3+) or accept the entropy.

Slice-2.5 is **thin** — it produces decisions and possibly a small set of generator constants, not new code surface beyond rejection predicates if any are accepted.

## Reasoning

Slice-2 ships connectivity-only (see [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]]) on the principle that you can't tune rejection thresholds blind. Slice-2.5 is the operational follow-up: now that worlds exist, look at them and decide.

Naming this slice explicitly serves the user's standing slice-first stance: deferred work is preserved through the decision log, not erased. Without slice-2.5 named, the rejection criteria would quietly disappear into the gap between slice-2 closure and slice-3 kickoff.

The thinness is intentional. Slice-2.5 is a tuning ratification, not a feature build. If rejection criteria turn out to be cheap to add, slice-2.5 may produce a small generator patch; if they turn out expensive (free-lunch detection requires generator-times-pricing coupling), 2.5 may produce only the decision to accept-or-reject and push enforcement to slice-3.

## Alternatives considered

- **Don't name slice-2.5; let rejection criteria emerge from slice-3 design.** Rejected. Risks losing the carryover. The user's slice-first stance specifically says: name deferred work, archive through decisions, keep moving.
- **Bundle slice-2 and slice-2.5 into one slice.** Rejected upstream by Critic — that's the Hidden-Expensive compression that gets us into trouble.

## Confidence

High. Director, Critic, and user converged on naming this as a follow-up. Pattern matches prior project precedent (slices named ahead of work to preserve scope).

## Open threads (for slice-2.5 to address)

- Hub detection threshold (max degree?)
- Free-lunch detection (loop A-B-C-A with short edges and wide spreads)
- Planarity / edge-crossing tolerance (visual-only, gameplay-neutral)
- Starting-node policy review (highest-degree currently; revisit if it produces too-similar opening 5 minutes across seeds)

## Source

This session (2026-05-02 PM). Director-Critic-User negotiation around slice-2 generator scope.

## Related

- [[2026-05-02-slice-2-scope-procgen-map-only]]
- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]]
- [[2026-05-02-slice-2-log-line-only-no-dump-catalog]]
