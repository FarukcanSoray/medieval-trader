---
title: Game.goods_by_id Dictionary built once at boot
date: 2026-05-03
status: ratified
tags: [decision, slice-6, architecture, lookup-shape]
---

# Game.goods_by_id Dictionary built once at boot

## Decision
A new field `var goods_by_id: Dictionary[String, Good]` lives on `Game`. Populated in `Game._ready()` immediately after the `goods` array is loaded, by iterating `goods` and keying on `good.id`. Never mutated thereafter. Public (no `_` prefix) -- read by Tier 5 consumers (`CargoMath`, `Trade`, `NodePanel`).

## Reasoning
`CargoMath.compute_load` needs `O(1)` good-lookup by inventory key (to retrieve `weight`). Today `Game.goods` is an array, requiring linear scans. Build-once-at-boot is right because:

1. `Game.goods` is itself preloaded at `_ready()` and never mutated -- the dict can't go stale
2. Spec §10's "good removed from catalogue, inventory still references it" edge case wants `goods_by_id.get(good_id) == null` to return null defensively, which matches `Dictionary.get`'s natural shape
3. Lazy-build at call site or rebuild-per-call would re-walk the array on every NodePanel `_refresh()` -- four entries today, but the precedent is wrong (every future cross-id lookup pays the cost)

The field is public (matching `Game.goods`) because it's externally read by Tier 5 consumers; `_`-prefix would misread these as private.

## Alternatives considered
- **Rebuild dict at each call site** -- rejected: wasteful and risks duplication drift
- **Linear scan on the existing array** -- rejected: acceptable at N=4, but sets the wrong precedent for future cross-id lookups
- **Build the dict lazily on first read** -- rejected: makes the field's lifecycle ambiguous; build-at-boot is cleaner

## Confidence
High. Build-once-at-boot is the natural fit for `Game.goods`'s never-mutated lifecycle; the dict shape matches the spec's defensive null-id pattern.

## Source
`docs/slice-6-weight-cargo-spec.md` §11 (Architect's call on `goods_by_id` shape); `godot/game/game.gd` `_ready()` populates the dict after the `goods = [preload(...)]` block.

## Related
- [[2026-05-03-slice-6-cargo-math-static-helper]] -- the consumer this lookup serves
- [[godot-idioms-and-anti-patterns]] -- composition over `get_node`-style reaches
