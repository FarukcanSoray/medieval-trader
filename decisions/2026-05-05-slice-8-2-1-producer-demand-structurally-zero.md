---
title: Producer demand structurally zero via DEMAND_DECAY_MULT_PRODUCER = 0.0
date: 2026-05-05
status: ratified
slice: 8.2.1
tags: [decision, slice-8.2.1, demand-system, world-rules, producer-sell-dead]
---

# Producer demand structurally zero via DEMAND_DECAY_MULT_PRODUCER = 0.0

## Decision
Producer-tag demand pools are held at zero by setting `DEMAND_DECAY_MULT_PRODUCER = 0.0` in `world_rules.gd`. With slice-8.1's `DEMAND_INITIAL_FILL_MULT_PRODUCER = 0.0` (tick-0 fill of zero), zero decay means the pool can never grow. Drain still runs (proportional to `pool/cap`) but trivially produces zero units when pool = 0.

For symmetry and intent documentation, `DEMAND_DRAIN_MULT_PRODUCER` is also set to 0.0 (was 0.67). The pool stays at 0 either way; both being 0 documents that producer-tag demand is structurally inert.

## Reasoning
Director's slice-8.2.1 framing called for producer steady-state ratio of 0.0 ("sell-dead is intentional"). The proportional drain formula `drain_rate * (pool/cap)` cannot force a positive pool to 0 at finite drain rate -- equilibrium is `decay/drain`. For ratio = 0.0 in continuous math, drain must be infinite, which is not implementable.

Engineer evaluated three implementations:

1. **Magic-large drain mult (e.g., 100.0)** -- equilibrium `0.2/100 = 0.002` quantizes to 0 at small caps. Works but requires a magic number whose intent is opaque to future readers.
2. **Special-case producer in DemandSystem code** -- skip drain math, set `pool = 0` for producer cells. Cleaner intent, but adds a code branch in the per-(node, good) hot loop.
3. **Set `DEMAND_DECAY_MULT_PRODUCER = 0.0`** (chosen) -- decay never refills producer demand. Pool stays at slice-8.1's tick-0 value of 0 forever. No magic number, no DemandSystem branch, asserts still pass (`drain_rate < cap` holds at 0).

Option 3 is the cleanest: producer demand is structurally inert by construction, not by tuning. The mechanism reads "producer tag never gains demand" rather than "producer drains very fast" or "producer is a special case."

## Alternatives considered
- **Magic-large drain mult (~100.0)** -- rejected; opaque magic number.
- **Special-case producer branch in `DemandSystem`** -- rejected; pollutes the hot loop with a tag check.
- **Allow producer to have small steady-state ratio (e.g., 0.05)** -- rejected by Director; "producer sell-dead is intentional" was the framing, not "producer is mostly sell-dead."

## Confidence
High. Engineer's structural reasoning is clean; Director's intent ("sell-dead is intentional") aligns; Reviewer confirmed asserts in `world_gen.gd` still pass with rates at 0.0; pass criteria green.

## Source
Engineer's implementation choice during slice-8.2.1 retune (2026-05-05); Director's framing.

## Related
- [[2026-05-05-slice-8-1-asymmetric-initial-demand-fill-by-tag]] -- the slice-8.1 tick-0 fill of 0 that this decision keeps stable forever
- [[2026-05-05-slice-8-2-drain-conservation-composed]] -- the drain mechanism this special case interacts with
- [[2026-05-05-slice-8-2-1-same-node-shadow-permanent-gate]] -- the kernel-collision gate that producer's zero-demand ratio cleanly satisfies
