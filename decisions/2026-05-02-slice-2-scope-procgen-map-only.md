---
title: Slice-2 scope is procgen map only; all other axes deferred
date: 2026-05-02
status: ratified
tags: [decision, scope, slice-2, deferral]
---

# Slice-2 scope is procgen map only; all other axes deferred

## Decision

Slice-2's axis is **procgen map generation only**. The following remain deferred:

- Encounters (per [[2026-04-29-slice-zero-encounters]] and `slice-spec.md` §10)
- More goods beyond wool + cloth
- Additional death causes beyond `stranded`
- Node-type market behaviour (city/town/village pricing differences)
- Edge attributes beyond `distance` (terrain, danger, toll, season)
- Fog-of-war / exploration gating
- Click-to-travel on the map (TravelPanel still drives travel)

## Reasoning

The slice-1 hardcoded 3-node triangle barely tests pillar 1 (math problem). Procgen map adds the load-bearing kernel decision the triangle cannot generate: **route planning under partial legibility** — comparing multi-hop arbitrage paths against direct paths.

Of the four candidates surfaced (procgen map, encounters, more goods, tuning + B1 cleanup), procgen map is the only one that extends the kernel rather than broadening coverage. The brief's intake resolution 2 ("procgen the world; hand-author the vocabulary") is operationalised by this slice — the others can ride on top later.

Holding scope at one axis keeps "one of each system" honest (intake resolution 3) and keeps the slice shippable.

## Alternatives considered

- **Procgen map + encounters bundle.** Rejected. Adds a fifth subsystem with zero kernel value at slice-2 fidelity. Encounters belong in their own slice once the loop is end-to-end on a real map.
- **Procgen map + more goods.** Rejected. Goods axis is independent; bundling doubles tuning surface and dilutes the slice's job (prove the generator).
- **Tuning + B1 cleanup only.** Rejected. Procgen is pillar-load-bearing; deferring it pushes the structural proof to slice-3 and stretches the kernel-test budget further.

## Confidence

High. User picked the axis explicitly after reviewing the four candidates with their costs.

## Source

This session (2026-05-02 PM). Director ratified fit-to-pillars; user chose axis from candidate list.

## Related

- [[project-brief]]
- [[slice-spec]]
- [[2026-04-29-slice-zero-encounters]]
- [[2026-04-29-one-of-each-system]]
- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]]
- [[2026-05-02-slice-2-5-named-tuning-pass]]
