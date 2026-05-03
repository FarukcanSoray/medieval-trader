---
title: Slice-6.0 cargo capacity is a code constant, not a TraderState field
date: 2026-05-03
status: ratified
tags: [decision, slice-6, schema, scope]
---

# Slice-6.0 cargo capacity is a code constant, not a TraderState field

## Decision
`CARGO_CAPACITY` lives in `godot/shared/world_rules.gd` as a static `const int`. It is **not** a field on `TraderState`. Slice-6.0 ships without a save-schema bump (schema_version stays at 2). Migration to a per-trader field is deferred to slice-6.1, triggered when capacity actually needs to vary per trader (cart upgrades, mules, capacity progression).

## Reasoning
The slice-6.0 Director frame names "fixed trader cargo capacity." If it's fixed, it's a constant -- moving it onto `TraderState` would force schema_version 2 -> 3 for a value that does not vary this slice. Slice-5.x just hardened save persistence; spending a schema bump on a non-varying value pays the cost twice: once now (migration plumbing for a value that doesn't yet move), once later (when it actually moves and the migration shape may need to differ).

The Critic flagged this explicitly during slice-6.0 sizing: "TraderState getting a new field is genuinely new ground -- slice-5.x just stabilised save persistence. Recommend pulling the migration out as slice-6.1 prerequisite, not part of slice-6 proper." The user accepted the reduction; the slice-6.0 spec §4.2 codifies the constant placement.

The slice-5.x save-format forward-port pattern (saves with no `weight` info still load because goods are .tres on disk) means adding `weight: int` to `Good.gd` and `weight = N` to each .tres just works. The same pattern would apply to TraderState fields, but only after slice-6.1 actually introduces a varying capacity.

## Alternatives considered
- **Add `cargo_capacity: int` to `TraderState` now** -- rejected: unnecessary schema bump for a non-varying value; future-proofs work the slice doesn't yet need.
- **Per-edge baked capacity** -- rejected: couples tuning to save data; hides the constant's value behind world generation.
- **Constant on `Game` instead of `WorldRules`** -- rejected: conflates gameplay state (which `Game` holds) with tuning constants (which `WorldRules` holds).

## Confidence
High. The Critic-driven reduction is explicit, the constant placement aligns with established WorldRules pattern, and the slice-6.1 trigger condition is named in spec §12.

## Source
`docs/slice-6-weight-cargo-spec.md` §4.2 (constant placement), §12 (slice-6.1 hand-off note); slice-6.0 Critic verdict during scoping pass.

## Related
- [[2026-04-30-world-rules-shared-static-config]] -- established the WorldRules pattern for shared tuning constants
- [[feedback_critic_stance]] -- user reframes Critic verdicts as sequencing; this is one of those reframings (Hidden-Expensive -> slice-6.0 + slice-6.1 split)
- [[2026-05-03-slice-5-forward-port-saves]] -- the precedent for goods-catalogue forward-port; the pattern this slice rides
