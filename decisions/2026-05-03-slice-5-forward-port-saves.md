---
title: Slice-N saves forward-port goods on slice-N+1 boot (vs corruption-toast)
date: 2026-05-03
status: ratified
tags: [decision, slice-5, architecture, save-format, migration]
---

# Slice-N saves forward-port goods on slice-N+1 boot (vs corruption-toast)

## Decision
When a save authored against a smaller goods catalogue is loaded onto a build with a larger catalogue (typical case: a slice-4 wool/cloth-only save loaded onto a slice-5 build with salt or iron added), the new goods are re-seeded in place rather than rejecting the save. Two new public statics on `WorldGen`:

```gdscript
static func needs_goods_forward_port(world: WorldState, all_goods: Array[Good]) -> bool
static func forward_port_goods(world: WorldState, all_goods: Array[Good]) -> bool
```

The predicate probes `world.nodes[0].bias` only because `_author_bias` writes every (node, good) pair atomically -- one probe suffices. The migrator builds the missing-goods subset, calls `_author_bias(world.world_seed, ..., missing)` and then `_seed_prices(world.world_seed, node, missing)` per node, merging the returned dicts into existing `node.prices` without overwriting wool/cloth keys. The migration runs in `SaveService.load_or_init` after `WorldState.from_dict` succeeds, before `Game.world` and `Game.trader` are assigned.

Predicate-fail on the saved topology (rare -- the new good's bias range falls below `MIN_BIAS_RANGE`) falls through to the existing corruption-toast + regen path. `schema_version` does not bump.

## Reasoning
`from_dict`'s strict-reject is reserved for *structural* corruption (missing required field, type mismatch, out-of-range schema). Adding good IDs is value-level evolution within the existing schema: new keys in existing dicts, no new fields, no new types. Toasting on it would discard player progress for a structurally valid save -- a worse user experience than any prior schema-bump path because there's no actual corruption. It would also normalize "any new good = world wipe," which is the wrong precedent for a 6-12 good catalogue that will grow several more times.

`WorldGen` owns the migration body, not `from_dict` or `SaveService`. `WorldGen` already owns the price/bias seeding RNG seed contract (`hash([effective_seed, "bias"])`, `hash([effective_seed, 0, node_id, good_id])`). `from_dict` does not know about RNG seeds; `SaveService` does not know about gen formulas. Re-using `_author_bias` and `_seed_prices` from anywhere else is a layering violation. `SaveService.load_or_init` is the right call site; `WorldGen` is the right body.

Determinism is preserved by reusing the saved `world.world_seed` (the *effective* seed after any original bumps). Forward-ported salt/iron prices are byte-identical across reloads of the same save. Salt's bias is drawn from RNG state position 0 within the migration's `_author_bias` call, not from the position salt would have occupied if it had been the third good in the original gen pass -- this is acceptable because the slice-4 save was generated without salt, so there is no "original salt position" to honor; the post-migration world is the new canonical state for that save.

The "first iron load" event runs the migration once; `SaveService` writes the new state on the next state_dirty boundary via the existing coalesced-tick pathway. From the second load onward, the predicate returns false and the helper is a no-op. The predicate is the migration flag; no special "migration mode" needed.

## Alternatives considered
- **Corruption-toast + regen** (slice-N save rejected, world regenerated from `seed_override` or random seed) -- simpler, consistent with prior schema bumps. Rejected: discards player progress for a structurally valid save; sets the wrong precedent for future catalogue growth.
- **Migration body inside `from_dict` or `SaveService`** -- rejected as layering violation; RNG seed contract belongs to `WorldGen`.
- **Schema bump to v5** with explicit migration logic -- rejected; no fields changed, no types changed; only dict-key extension. Bumping would mis-signal corruption to all prior saves.
- **Replay the saved world's tick history for the new goods** to get drift-coherent prices -- rejected as complexity the slice does not need; the kernel doesn't depend on cross-good tick-history coherence.

## Confidence
High. Architect's binding ruling on Call 1; Engineer round 1 implemented; Reviewer rounds 1 and 2 verified determinism, idempotence, and corruption-toast reuse.

## Source
Architect's handoff (Call 1 ruling, §1.1-§1.7); Designer spec `docs/slice-5-goods-expansion-spec.md` §10, §12 (edge case: slice-4 save on slice-5 build).

## Related
- [[2026-04-29-strict-reject-from-dict]] -- the strict-reject contract this decision deliberately does not violate (no structural corruption)
- [[2026-05-01-save-corruption-regenerate-release-build]] -- the existing corruption-toast + regen path that forward-port falls through to on predicate-fail
- [[2026-05-03-slice-5-explicit-goods-preload-paths]] -- the goods-loader call that drives the predicate
