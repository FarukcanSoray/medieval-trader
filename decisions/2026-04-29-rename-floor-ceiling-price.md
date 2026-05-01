---
title: Rename Good.floor / Good.ceiling → Good.floor_price / Good.ceiling_price
date: 2026-04-29
status: ratified
tags: [decision, naming, gdscript]
---

# Rename Good.floor / Good.ceiling → Good.floor_price / Good.ceiling_price

## Decision
The `Good` resource's per-good price bounds are named `floor_price` and `ceiling_price`, not `floor` and `ceiling`. Rename applied across `godot/goods/good.gd`, `godot/goods/wool.tres`, `godot/goods/cloth.tres`, and `docs/slice-architecture.md` §4.4 and §7 Tier 1.

`docs/slice-spec.md` §5's price drift formula notation (`floor`/`ceiling`) is left as the math symbols — it refers to *concepts*, not field names.

## Reasoning
The literal names `floor` and `ceiling` shadow GDScript's global `floor()` and `ceiling()` functions. The shadow is legal — scoped member access disambiguates `good.floor` from a free `floor(x)` call — but it's a maintenance hazard during review and a confusion vector for future readers.

The renamed fields also gain symmetry with `base_price`, which makes the `Good` schema read consistently as a small price-tuning record.

Cost is low: the rename happened before any code outside `Good` referenced the fields. Benefit is real: no surprise shadowing, no future debugging episode where someone wonders why `floor(x)` doesn't behave as expected.

## Alternatives considered
- **Keep `floor` / `ceiling`** — rejected: shadowing is a maintenance hazard; the symmetry argument with `base_price` was real; the literal names from the formula notation could be preserved as math symbols in the spec without being mirrored as code identifiers.
- **`min_price` / `max_price`** — not discussed; `floor_price`/`ceiling_price` was chosen because it directly parallels the slice-spec formula notation (`floor`, `ceiling`) so the conceptual link to the math is obvious.

## Confidence
Medium. This is a code-hygiene rename surfaced by the Engineer during Tier 1 build, ratified by the user. Logged here so future references in slice-spec or any new doc to "the floor field" aren't confused.

## Source
- Engineer Tier 1 deviation report, 2026-04-29 evening.
- User ratification: "Rename `Good.floor` / `Good.ceiling` → `floor_price` / `ceiling_price`."
- Implemented in `godot/goods/good.gd:8–9`, `godot/goods/wool.tres`, `godot/goods/cloth.tres`. Architecture doc patched.

## Related
- [[slice-spec]] — §5 formula notation (the source of the original names; the math symbols `floor` / `ceiling` remain unchanged)
- [[slice-architecture]] — §4.4 (Good Resource) and §7 Tier 1 file 1, both patched
- [[gdscript-conventions]] — naming guidance
