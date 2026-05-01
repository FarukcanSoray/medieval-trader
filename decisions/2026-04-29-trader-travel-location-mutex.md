---
title: TraderState invariant — travel and location_node_id are mutually exclusive
date: 2026-04-29
status: ratified
tags: [decision, architecture, invariant, state]
---

# TraderState invariant — travel and location_node_id are mutually exclusive

## Decision
A trader is either **at a node** or **on a road**, never both, never neither. Concretely:

- `travel != null` AND `location_node_id != ""` → contradictory; reject.
- `travel == null` AND `location_node_id == ""` → contradictory; reject.

Enforced in `TraderState.from_dict()` (a save violating this returns `null`, regenerated). Save-format mapping: `location_node_id == ""` round-trips to JSON `null` and back, per `slice-spec.md` §3.

## Reasoning
The slice-spec's travel state machine (§5: `IDLE` → `TRAVELLING` → `IDLE` at destination) **implies** mutual exclusion but doesn't state it as a wire-format invariant. The Engineer surfaced and enforced it during Tier 1 implementation, and the user accepted it as a sharpening of the spec's implicit intent rather than an extension.

Stronger validation prevents subtle bugs where a trader could be in a half-state — e.g. at a node with a travel scheduled, or mid-travel with a location lingering. A half-state would corrupt every system that branches on either field.

## Alternatives considered
- **Allow mixed states with recovery logic** — rejected: violates the state machine semantics.
- **Document but don't enforce** — rejected: better to fail loudly on load than to debug a half-state at runtime.

## Confidence
High. Engineer surfaced the invariant; user accepted as a spec sharpening; enforced in `godot/trader/trader_state.gd:80–83`.

## Source
- Engineer Tier 1 fix-pass implementation, 2026-04-29 evening.
- Slice-spec §5 "Travel state machine" — the implicit source.

## Related
- [[slice-spec]] — §3 (save schema) and §5 (travel state machine)
- [[slice-architecture]] — §4.1 TraderState, §4.2 TravelState
- [[2026-04-29-strict-reject-from-dict]] — this invariant is one of the rejection conditions
- [[2026-04-29-travel-cost-at-departure]] — kickoff decision that gold is deducted on departure (anchors the IDLE→TRAVELLING transition)
