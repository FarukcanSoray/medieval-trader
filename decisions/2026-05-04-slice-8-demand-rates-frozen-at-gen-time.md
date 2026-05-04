---
title: Demand caps and decay rates frozen at gen-time; persisted in save
date: 2026-05-04
status: ratified
tags: [decision, slice-8, save-format, determinism, demand-pool]
---

# Demand caps and decay rates frozen at gen-time; persisted in save

## Decision
`demand_caps` and `demand_decay_rates` are computed once at world-gen time (per the §5.7 multiplier table applied to per-good `base_demand_cap` / `base_demand_decay_rate`, keyed by node tag) and persisted in the save file. They are not recomputed on load. Mirrors the slice-7 precedent for supply-side `stock_caps` and `refill_rates`.

## Reasoning
Freezing at gen-time ensures deterministic replay: a loaded world's pool evolution is reproducible only if rates do not re-derive on load. If multipliers were re-read from `WorldRules` on every load, a future tuning change to those constants would silently retune all existing saves -- which would break determinism replay (gate 3) on any save spanning the tuning change.

Symmetric to slice-7's supply-side decision (`2026-05-03-slice-7-caps-rates-frozen-at-gen-time`). The migration helper `_migrate_v5_to_v6` derives the demand fields from the `WorldRules` multipliers as of the migration moment, then those values are written to the save and never recomputed.

## Alternatives considered
- **Recompute caps and rates on load from WorldRules constants** -- rejected: breaks determinism replay across tuning changes; no benefit since the values are deterministic functions of immutable per-(node, good) tags.

## Confidence
High. Designer leaned (spec §11.10 referencing slice-7 precedent); Architect ratified.

## Source
Designer (spec §3.1 + §11.10) + Architect ratification (2026-05-04 session).

## Related
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- the slice-7 precedent this decision applies symmetrically
- [[2026-05-04-slice-8-nodestate-demand-dicts-shape]] -- the four parallel dicts that this decision freezes two of
- [[2026-05-04-slice-8-harness-gate-floors]] -- gate 3 (determinism replay) which this freezing serves
