---
title: Schema-bump trigger covers semantic reinterpretation of existing fields
date: 2026-05-02
status: ratified
tags: [decision, save-system, schema, slice-2-followup]
amends: [2026-05-02-slice-2-no-schema-bump-trigger-named]
---

# Schema-bump trigger covers semantic reinterpretation

## Decision

Amends the schema-bump trigger condition in `[[2026-05-02-slice-2-no-schema-bump-trigger-named]]`. Read the original rule as:

> *Any new required field on an existing per-node or per-edge Resource* **OR any semantic reinterpretation of an existing field where existing saves' values would be wrong in the new world.**

Applied this session: `WorldState.schema_version` was bumped 1 -> 2 because `NodeState.pos` shifted from viewport-space coordinates (slice-2's `Rect2(80, 60, 640, 380)`) to panel-local pixel coordinates (`MapPanel.size`, ~468x664 at 1280x720). The field's *type* is unchanged (`Vector2`), and its *presence* is unchanged. Only the meaning of the values shifted.

## Reasoning

The original trigger named "any new required field on an existing per-node or per-edge Resource." That covers shape changes (new keys, new types) but doesn't strictly cover semantic-without-shape changes. Schema-1 saves carrying old-coordinate-space `pos` values would load successfully into a slice-2-followup world and paint nodes outside the new `MapPanel` rect -- silent positional corruption with no diagnostic.

The strict-reject path (`from_dict` returns null on schema mismatch -> corruption-regen with toast, per `[[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]]`) is the right player-visible behaviour. Amending the trigger means the next time a field's meaning shifts under existing values, the bump is required, not optional.

## Alternatives considered

None named explicitly in-session. Architect flagged the gap as part of the round-1 spec ("the original trigger doesn't strictly cover semantic-without-shape changes"); user ratified the amendment via approving the round-1 spec without pushback.

## Amends

`[[2026-05-02-slice-2-no-schema-bump-trigger-named]]` -- extends the trigger condition. The original decision's "stays-without-bump" examples remain valid (new top-level `WorldState` collections that `from_dict` defaults to empty).

## Confidence

Medium-high. The amendment is small and was applied in-session; the rule worked as intended (schema-1 saves rejected; corruption-regen toast fires).

## Source

Slice-2 follow-up session (2026-05-02). Architect round 1 §3.6; Architect round 2 §5 cross-reference.

## Related

- [[2026-05-02-slice-2-no-schema-bump-trigger-named]] -- amended
- [[2026-04-29-strict-reject-from-dict]]
- [[2026-05-02-slice-2-followup-corruption-toast-all-load-branches]] -- toast surface for the rejection path
- [[2026-04-29-save-format-first]]
