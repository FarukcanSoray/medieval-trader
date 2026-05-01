---
title: Slice-2 no schema bump; trigger condition for future bumps named
date: 2026-05-02
status: ratified
tags: [decision, save-system, slice-2, schema]
---

# Slice-2 no schema bump; trigger condition for future bumps named

## Decision

`schema_version` stays at **1** for slice-2. No migration code is written. Slice-1 saves load into slice-2 as 3-node worlds without crashing; testers should manually delete `user://save.json` (or clear browser IDB) after upgrading.

**Trigger condition for future schema bumps:** *any new required field on an existing per-node or per-edge Resource* (`NodeState`, `EdgeState`, `TraderState`, etc.). Examples that would force a bump:

- Node-type metadata (`city`/`town`/`village` discriminator)
- Edge attributes beyond `distance` (terrain, danger, season)
- Fog-of-war state (per-node visibility)

Examples that ride **without** a bump (because `from_dict` defaults missing keys to empty):

- New top-level collections on `WorldState` (e.g. an `events` array, an `encounters` log)

## Reasoning

Slice-1's serializer is generic over array length. `WorldState.to_dict`/`from_dict` iterate `nodes`, `edges`, `history` with `for ... in ...` — no index hardcoding. Going from 3 to 7 nodes is exactly the case the schema was built to absorb. Adding migration code for a slice with no schema-shape change is busywork that erodes the simplicity of the save layer.

Naming the trigger explicitly prevents a future Architect from bumping speculatively or from adding required fields without realising they triggered the bump.

## Alternatives considered

- **Bump to schema_version 2 with migration code.** Rejected. Adds engineering complexity for no correctness gain; slice-1 saves are still playable in slice-2 even if the world shape is "wrong" (3-node).
- **Reject slice-1 saves outright with an error message.** Rejected. The save loads cleanly; rejecting it is hostile, and the user-visible workaround (delete the save) is one click away.

## Confidence

High. Architect's structural lean; Critic's joint-question response confirmed; user ratified by approving the Architect handoff.

## Source

This session (2026-05-02 PM). Architect handoff §0 decision 7 + §9 schema sanity check; Critic joint question 3 confirmed.

## Related

- [[2026-04-29-save-format-first]]
- [[slice-spec]]
- [[2026-05-02-slice-2-scope-procgen-map-only]]
