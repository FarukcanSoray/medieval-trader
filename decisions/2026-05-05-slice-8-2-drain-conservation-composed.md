---
title: Slice-8.2 ships drain + partial conservation composed in one slice
date: 2026-05-05
status: ratified
slice: 8.2
tags: [decision, slice-8.2, demand-system, scope, mechanic-shape]
---

# Slice-8.2 ships drain + partial conservation composed in one slice

## Decision
Slice-8.2 implements proportional-to-fill demand drain AND probabilistic partial conservation of demand caps in the same version. Drain mutates `demand_pools` per tick; conservation mutates `demand_caps` probabilistically on each successful sell (`CONSERVATION_FRACTION = 0.10`, floor `MIN_DEMAND_CAP_AFTER_EROSION = 2`). The two effects are decoupled by field but compose through equilibrium equation `pool*/cap = decay/drain`.

Tag-differentiated drain reuses the existing 3 tags (producer / consumer / neutral). No new tag taxonomy.

## Reasoning
Scope Critic recommended sequencing: ship uniform drain only in 8.2, defer conservation to 8.3, defer tag-differentiation to 8.4. User explicitly overrode the sequencing: "I want them in one version" and "don't sequence the improvements to different versions." Director had given Designer permission to compose candidates 2 (conservation) and 4 (drain) in the design intent framing.

Designer's load-bearing math choice: drain is **proportional to fill**, not flat. With proportional drain, equilibrium ratio = `decay_mult / drain_mult`, and `base_demand_decay_rate` cancels — so existing decay rates do NOT need to be retuned. This kills one of Critic's flagged hidden costs.

The decoupled-fields architecture (drain -> pools, conservation -> caps) keeps the two effects independently tunable and leaves PricingMath untouched.

## Alternatives considered
- **Sequence drain / conservation / tag-diff into separate slices (Critic's recommendation)** -- rejected by user; "don't sequence."
- **Flat (not proportional) drain** -- rejected by Designer; flat drain forces retune of decay rates because equilibrium would be a saturation-bounded process rather than a ratio.
- **Single field for both effects (e.g., conservation directly lowers pool, not cap)** -- not formally weighed; the decoupling came out of Architect's structural pass.

## Confidence
High. User locked the scope explicitly; Designer specced proportional drain with the analytic story written out; Architect ratified the decoupled-fields structure.

## Source
User scope decision in slice-8.2 pipeline (2026-05-05); Designer spec at `docs/slice-8-2-demand-reshape-spec.md`; Architect handoff at `docs/slice-8-2-architect-handoff.md`.

## Related
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this mechanism implements
- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- the formula left untouched by the decoupling
- [[2026-05-05-slice-8-1-asymmetric-initial-demand-fill-by-tag]] -- the slice-8.1 fix this builds on
- [[2026-05-05-slice-8-2-schema-v8-strict-reject]] -- save schema bump driven by this mechanism
- [[2026-05-05-slice-8-2-1-same-node-shadow-permanent-gate]] -- kernel-collision gate added after this slice's empirical breach
