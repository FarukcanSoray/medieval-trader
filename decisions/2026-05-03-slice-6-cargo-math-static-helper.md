---
title: CargoMath as script-only static helper, mirrors EncounterResolver
date: 2026-05-03
status: ratified
tags: [decision, slice-6, architecture, helper-class]
---

# CargoMath as script-only static helper, mirrors EncounterResolver

## Decision
`compute_load(inventory: Dictionary[String, int], goods_by_id: Dictionary[String, Good]) -> int` is implemented as a static method on a new `CargoMath` class, `extends Object`, no instances. Lives at `godot/cargo/cargo_math.gd`. Both `NodePanel` (UI predicate) and `Trade.try_buy` (defensive gate) call this same function.

## Reasoning
The architectural seam: `TraderState` is a `Resource` and has no autoload reach to `Game.goods`. Placing `compute_load` on `TraderState` would require either (a) threading a `goods_by_id` argument through every mutator (API noise on the hot mutation path), or (b) caching a back-reference to `Game.goods` on the Resource (anti-pattern: Resource reaching across the autoload boundary, breaks save/load symmetry).

Placing it on `Trade` couples the math to one call site -- NodePanel would need to reach into `Trade` to evaluate the buy-button predicate.

Placing it on `Game` muddies `Game`'s charter (autoload + EventBus + state holder; not a math library).

`CargoMath` is the precedent-matching answer. The function is `(inventory, goods) -> int`: pure inputs, deterministic output, zero state, zero lifecycle. Exactly the shape `EncounterResolver` already establishes at `godot/travel/encounter_resolver.gd`. Single source of truth: the UI predicate cannot drift from the runtime predicate because both paths call the same function.

Folder `godot/cargo/` is new but consistent with the slice's per-feature precedent (`aging/`, `goods/`). Sized for slice-6.1's `cargo_state.gd` Resource alongside.

## Alternatives considered
- **Method on `Trade`** -- rejected: couples math to one verb; NodePanel would have to reach into `Trade`
- **Method on `TraderState`** -- rejected: Resource has no clean reach to `Game.goods`; mutator API noise
- **Method on `Game`** -- rejected: charter conflation
- **Place at `godot/shared/cargo_math.gd`** -- not rejected, would be acceptable; chose `godot/cargo/` for slice-6.1 future neighbours

## Confidence
High. The seam is real (Resource has no autoload reach), the precedent (EncounterResolver) matches exactly, and the single-source-of-truth property is load-bearing for the UI-vs-runtime predicate consistency the spec §3 calls out.

## Source
`docs/slice-6-weight-cargo-spec.md` §4.3 (compute_load placement), §11 (Architect's call); `godot/travel/encounter_resolver.gd` (the precedent class).

## Related
- [[godot-idioms-and-anti-patterns]] -- composition principle, side-effect-free helpers
- [[2026-04-30-world-rules-shared-static-config]] -- analogous shared-static pattern for tuning constants
