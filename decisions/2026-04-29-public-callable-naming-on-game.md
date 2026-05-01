---
title: Public Callable naming on Game (no leading underscore)
date: 2026-04-29
status: ratified
tags: [decision, architecture, naming, conventions]
---

# Public Callable naming on Game (no leading underscore)

## Decision
The two Callable members on `Game` that systems consume to notify the autoload of state mutations are **public** (no leading underscore):

- `var emit_gold_changed: Callable` — invoked by `TraderState.apply_gold_delta`
- `var emit_state_dirty: Callable` — invoked by `TraderState` mutators, `Aging`, `PriceModel`, `Trade`, `TravelController`

The architecture spec was patched at `docs/slice-architecture.md` §7 items 10 and 14 to drop the leading underscore from the prescribed names (`_emit_gold_changed` → `emit_gold_changed`; `_emit_state_dirty` → `emit_state_dirty`).

## Reasoning
The Tier 3 Code Reviewer flagged a divergence: the Engineer's implementation used the no-underscore form while the architect's spec specified leading underscores. By the gdscript-conventions skill's rule that `_` prefix is for private members, these Callables are *not* private — they are consumed externally by Tier 4 (`SaveService` indirectly via mutator callbacks) and Tier 5 systems (`Aging`, `PriceModel`, `Trade`, `TravelController`) which pass them as callbacks to `TraderState` mutators.

The Engineer's choice was the more correct call by the convention. Ratifying it as code → spec rather than spec → code preserved the cleared Tier 3 implementation and brought the spec in line with the convention skill.

## Alternatives considered
- **Update the code to match the spec** (re-add `_` prefix) — rejected: locks the spec but makes externally-consumed members read like private ones, violating the convention skill.
- **Update the spec to match the code** (drop `_` prefix) — chosen: aligns spec with convention; the Callables are publicly consumed, and naming should reflect that.

## Confidence
High. The convention's rule is unambiguous, the Tier 3 Reviewer surfaced the divergence cleanly, and the only Tier 4–5 callsites that depend on these names match the patched spec.

## Source
This conversation, mid-session ratification ("Option 1"). See `godot/game/game.gd:14-17` (declarations) and `docs/slice-architecture.md:302, 312` (patched spec lines).

## Related
- [[2026-04-29-callable-injection-resource-mutators]] — defines the seam these Callables implement
- [[slice-architecture]] — §7 items 10 and 14 patched
