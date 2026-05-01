---
title: Slice-2 generator is connectivity-only; rejection criteria deferred to slice-2.5
date: 2026-05-02
status: ratified
tags: [decision, scope, slice-2, generator, deferral]
---

# Slice-2 generator is connectivity-only; rejection criteria deferred to slice-2.5

## Decision

Slice-2's procgen generator implements a **single invariant: connectivity**. Specifically:

- 7 nodes placed in an 800x500 box with 80-unit min spacing.
- Topology: Euclidean MST + 2 extra nearest-bias edges.
- Connectivity asserted by BFS post-build (defensive; MST guarantees it).
- Seed-bump retry on packing failure, capped at 5 bumps.

The following rejection criteria are **NOT** in slice-2:

- Hub-and-spoke rejection
- Free-lunch world rejection (where one short edge connects two extreme-spread nodes)
- Planarity / edge-crossing rejection
- Degree-distribution rejection sampling

These move to **slice-2.5** (see [[2026-05-02-slice-2-5-named-tuning-pass]]).

## Reasoning

Director's initial frame named six invariants stacked together. Scope Critic priced this as **Hidden-Expensive**: each invariant needs its own predicate, threshold, and corpus of "what does an unhealthy world look like" before the threshold can be tuned. Tuning blind is worse than tuning after seeing 20 generated worlds — you don't know which worlds are degenerate until you can render them.

Connectivity-only ships in slice-2; the rejection rules ratify in slice-2.5 once we have real worlds to inspect. The per-generation log line (see [[2026-05-02-slice-2-log-line-only-no-dump-catalog]]) is the slice-2.5 instrumentation.

## Alternatives considered

- **Implement all six invariants in slice-2.** Rejected. Generator-times-pricing coupling for free-lunch detection alone is a non-trivial new seam, and threshold values can't be sanity-checked without the very worlds the generator hasn't produced yet.
- **Defer procgen entirely until rejection criteria are designed.** Rejected. Connectivity is foundational; without a generator we cannot inspect the worlds we'd tune against.

## Confidence

High. Critic's Hidden-Expensive verdict was direct; user ratified the lean explicitly.

## Open threads carried forward

Degenerate worlds **are accepted in slice-2**. A free-lunch run, a hub-and-spoke run, or a long-isolated-edge run is a legitimate slice-2 output. Slice-2.5's job is to find them and rule.

## Source

This session (2026-05-02 PM). Director frame, Critic Hidden-Expensive finding, user explicit ratification ("A - lean critic").

## Related

- [[2026-05-02-slice-2-scope-procgen-map-only]]
- [[2026-05-02-slice-2-5-named-tuning-pass]]
- [[2026-05-02-slice-2-log-line-only-no-dump-catalog]]
- [[2026-04-29-slice-three-nodes]]
