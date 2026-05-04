---
title: Initial demand-pool fill state on v5->v6 migration set to target (demand_cap)
date: 2026-05-04
status: ratified
tags: [decision, slice-8, migration, save, ux]
---

# Initial demand-pool fill state on v5->v6 migration set to target (demand_cap)

## Decision
When an existing slice-7 (v5) save loads under slice-8 (v6) code, each node's `demand_pools[good_id]` is initialized to `demand_caps[good_id]` (full unmet demand). Symmetric to slice-7's supply migration which set `stocks = stock_caps` (full supply) via `_author_stock`.

## Reasoning
The v5->v6 boundary is the player's first contact with demand pools -- there is no prior demand history for the world to remember. Loading at `target` (= demand_cap) is the honest read of "demand exists at its authored steady-state; the player's actions have not moved it yet."

The first post-update leg will read as broadly favorable for selling -- every demand pool is at peak fill, so every sell sits at the curve's high end. Director named this as upgrade-UX cost, not free lunch: "the first post-update leg will read as broadly favorable for selling; this is acceptable upgrade-UX cost, not a bug." Pools then drain on subsequent sells and recover toward target on travel ticks.

Cross-cutting flag for play-feel verification: migrated worlds need a few legs before pools diverge from target. The harness uses fresh-generated worlds, so gates 1-3 are not affected; play-feel verification (slice-8 §12.2) should discount the first migrated session's read.

## Alternatives considered
- **Saturated (demand_pool = 0)** -- rejected: makes player's first contact with demand pools a misleading read at maximum extreme. "Selling is impossible everywhere; I have to wait for demand to recover" feels like the upgrade broke selling.
- **Empty (demand_pool = 0, different framing)** -- mechanically identical to saturated; same rejection.
- **Mid (demand_pool = demand_cap / 2)** -- the blandest read but the most honest in steady-state terms. Rejected in favor of `target` for symmetry with slice-7's supply migration.

## Confidence
High. Director Q1 explicitly ratified with reasoning; symmetric to slice-7's `stocks=cap` precedent.

## Source
Director Q1 ratification (2026-05-04 session). Spec at `docs/slice-8-pricing-v2-spec.md` §11.1.

## Related
- [[2026-05-03-slice-7-migration-helpers-static-on-resource]] -- the slice-7 migration shape this mirrors
- [[2026-05-04-slice-8-economy-primary-texture-pillar]] -- the pillar this fill choice protects
- [[2026-05-02-slice-2-no-schema-bump-trigger-named]] -- the migration-trigger-named precedent
