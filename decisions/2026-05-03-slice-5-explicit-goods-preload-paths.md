---
title: Game._ready() loads goods via explicit preload calls inline (no directory scan)
date: 2026-05-03
status: ratified
tags: [decision, slice-5, architecture, goods-loader]
---

# Game._ready() loads goods via explicit preload calls inline (no directory scan)

## Decision
Goods are loaded via explicit `preload` calls in `Game._ready()`, listed inline in `game.gd`:

```gdscript
goods = [
    preload("res://goods/wool.tres") as Good,
    preload("res://goods/cloth.tres") as Good,
    preload("res://goods/salt.tres") as Good,
    # iron added in day-2 ONLY after measurement gate passes
]
```

Not lifted to `WorldRules`. Not abstracted to a directory scan. The canonical good-list order is `[wool, cloth, salt, iron]` (and `[wool, cloth, salt]` until day-2). The measurement tool's `_load_goods(n)` MUST mirror this order via the same explicit array literal in `tools/measure_bias_aborts.gd` (`GOOD_PATHS` const).

Iron's preload line is *literally absent* from `game.gd` on day-1 -- adding it before `iron.tres` exists would crash the editor's resource scanner.

## Reasoning
`Game.goods` is the existing one source of truth; everything reads from it (`world_gen.gd`, `node_panel.gd`, `price_model.gd`, `save_service.gd`). Lifting the list to `WorldRules` creates two sources of truth (the const list + `Game.goods`).

A directory scan defeats `preload`. `preload` resolves at parse time -- web export inlines the resource. `load` resolves at runtime -- web export round-trips through the resource cache. For HTML5 cold-boot latency, `preload` matters.

Directory scan also couples loading to filesystem ordering. `DirAccess.get_files()` is sorted by default in Godot 4.0+, but depending on a filesystem invariant for the measurement tool's first-N semantics is exactly the kind of footgun the Idioms skill flags. One stray `.tres` file in `godot/goods/` (export-tagged sample, future weight-system prototype) would silently extend the catalogue. Explicit list immunizes us.

The "iron-absent-by-design" mechanism makes the day-1 / day-2 split self-documenting: the goods array literal is the gate signal. Engineer cannot accidentally ship iron on day-1 because the array doesn't include it; the editor cannot scan-load iron because the file doesn't exist. Both safety nets reinforce the spec §6 measurement-gate rule.

## Alternatives considered
- **Directory scan** of `godot/goods/*.tres` -- rejected; couples to filesystem state, defeats `preload`, opens stray-file vulnerability, makes the day-1/day-2 split harder to enforce structurally.
- **Lift the canonical list to `WorldRules`** as a const -- rejected; creates two sources of truth (the const list + `Game.goods`), no benefit since `Game` is already global.
- **Lift to a separate `goods_catalogue.gd`** const file -- rejected; no caller other than `Game._ready` and the measurement tool, doesn't earn a file.

## Confidence
High. Architect's binding ruling on Call 2; Engineer round 1 implemented; Reviewer rounds 1 and 2 verified the preload order and the iron-absent invariant.

## Source
Architect's handoff (Call 2 ruling); Designer spec `docs/slice-5-goods-expansion-spec.md` §11 (Architect call: explicit paths vs directory scan).

## Related
- [[2026-04-30-one-autoload-only-game]] -- `Game` as the single source of truth that this decision builds on
- [[2026-05-03-slice-5-forward-port-saves]] -- the migration that depends on `Game.goods` order being canonical
- [[2026-05-03-slice-5-max-abort-rate-5pct]] -- the measurement gate that the goods array's day-1 absence enforces structurally
