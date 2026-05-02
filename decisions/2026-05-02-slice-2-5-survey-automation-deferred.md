---
title: Headless survey automation considered and not built; proposal preserved for slice-3+ pickup
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, tooling, deferral, automation]
---

# Headless survey automation considered and not built; proposal preserved for slice-3+ pickup

## Decision

The proposed headless GDScript tool `tools/survey.gd` is **not built** in slice-2.5. The proposal shape is recorded here so a future slice can pick it up as-is if a felt degeneracy ever justifies gathering distribution data.

**Proposal shape (preserved):**

- Single GDScript file at `tools/survey.gd`, runnable via `godot --headless --script tools/survey.gd -- --count=N --start=S --out=PATH.csv`.
- Calls `WorldGen.generate(seed, goods, map_rect)` directly (it is already pure static -- no Game autoload, no scene tree).
- Per seed, dumps a CSV row with: `requested_seed`, `effective_seed`, `nodes`, `edges`, `min_edge_dist`, `max_edge_dist` (from existing log line) plus three numeric proxies for the named degeneracies:
  - `max_degree` (hub-and-spoke proxy)
  - `min_free_lunch_ratio` -- min over edges of `edge.distance / shortest_alt_path_distance` (free-lunch proxy)
  - `crossing_count` (planarity proxy)
- Script does **not** classify y/n/borderline and does **not** pick thresholds.

## Reasoning

The tool was proposed as the cheaper substitute for the 45-75 minute eyeball survey. After Director-vs-Critic deliberation, the user adopted Critic's read: building a tool to gather more data to maybe-ratify a threshold the protocol already tells you to default-decline (per §4) is "scope creep dressed as rigor."

Critic's killer test was the deciding frame: "Name the predicate you'd enforce in `world_gen.gd` today if the CSV showed it. If you can't, the tool is theatre." No pre-committable predicate existed in the close turn.

Recording the proposal shape (rather than letting it dissipate) is the slice-first hygiene the project keeps using: name the deferred work, archive through decisions, keep the carryover live without forcing it forward.

## When this might get picked up

Build conditions a future slice should satisfy before reviving this tool:

1. Slice-3+ play has surfaced a felt degeneracy on one of the three threads (hub, free-lunch, or planarity).
2. A specific predicate is pre-committable in advance: "if metric X exceeds Y, reject the seed."
3. The cost of running the predicate against ~100 seeds to set Y is cheaper than tuning the predicate from felt play alone.

If 1 and 2 both hold but 3 is unclear, the tool is still optional -- felt play may be enough.

## Alternatives considered

- **Build the tool now anyway, run it, look at the distribution, decide thresholds post-hoc.** Rejected. Critic flagged this as the sprawl shape.
- **Build a tighter version (50 seeds, two metrics, pre-committed thresholds).** Rejected -- the pre-committed-thresholds gate could not be cleared in this turn, which made the reduction moot.
- **Just discard the proposal entirely (no decision file).** Rejected. The proposal was a real piece of design work; recording it preserves it for re-use without re-derivation.

## Confidence

Medium-High. The decision *not to build now* is high-confidence (follows from the close decision). The preserved proposal shape may need updating if `WorldGen` evolves before slice-3+ picks it up.

## Source

This session (2026-05-02, slice-2.5 close turn). Director and Critic outputs on the proposal; user binding call.

## Related

- [[2026-05-02-slice-2-5-close-via-entropy-default]] -- parent close decision.
- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- posture this defers under.
- [[slice-2-5-survey-protocol]] -- §4 default that made the tool unnecessary now.
