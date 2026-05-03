---
date: 2026-05-03
type: session
tags: [session, slice-7, production-caps, world-memory]
---

# Slice-7 pipeline -- per-node production caps and character-tuned refill; world gains memory

## Goal

Implement Slice-7.0 (per-node production caps with character-tuned refill via tag multipliers) end-to-end: Director anoints caps over elasticity/multi-leg, Critic surfaces Hidden-Expensive opportunities, Designer binds spec, Architect resolves schema questions, Engineer ships with mid-slice harness feedback, and Reviewer gates closure. The slice purpose: make the world have memory of trader actions, so cleaning out a node's stock means returning too soon is a wasted leg, and test the §13.3 promise from slice-6 (mixed carts become rational under caps).

## Produced

**Code (modified, 15 files):**

- `godot/goods/good.gd` -- `base_stock_cap`, `base_refill_rate` exports
- `godot/goods/{wool,cloth,salt,iron}.tres` -- uniform baseline 4 / 0.2
- `godot/shared/world_rules.gd` -- four tag multipliers (plentiful: 4x cap, 5x rate; scarce: 0.25x cap, 0.2x rate)
- `godot/world/node_state.gd` -- four parallel dicts (stocks, stock_caps, refill_rates, refill_accumulators)
- `godot/world/world_state.gd` -- schema v5, `stock_for` / `decrement_stock` accessors, accept-or-migrate `from_dict`, `_migrate_v4_to_v5`
- `godot/trader/trader_state.gd` -- cargo_capacity field absorbed from slice-6.1, migration on field absence
- `godot/game/world_gen.gd` -- `_author_stock` per (node, good), `forward_port_goods` extended
- `godot/travel/trade.gd` -- three-stage stock gate
- `godot/ui/hud/node_panel.gd` -- [N left] segment, eight-case tooltip, `in_stock` predicate, PriceLabel min width 160
- `godot/main.tscn`, `godot/main.gd` -- StockSystem child, setup wiring
- `godot/systems/save/save_invariant_checker.gd` -- P7 (stock bounds) + P8 (key parity)

**Code (new, 2 files):**

- `godot/systems/stock/stock_system.gd` -- StockSystem class, `tick_advanced` listener
- `godot/tools/measure_production_caps.gd` -- two-gate harness (cap mechanic vs. mixed-cart recruitment)

**Spec:**

- `docs/slice-7-production-caps-spec.md` -- binding Designer spec reconciling per-node .tres authoring against procgen-world via tag multipliers

**Verdict:**

- `tools/production_caps_verdict.txt` -- Gate 1 PASS (98-100%, cap mechanic bites); Gate 2 FAIL (27-54%, mixed carts don't structurally land at this scope)

**Commit:** `26a9da8` -- "Implement Slice-7: Per-node production caps + character-tuned refill"

## Decisions ratified

- [[2026-05-03-slice-7-production-caps-anointed]] -- Director's anointment over elasticity / multi-leg
- [[2026-05-03-slice-7-fuller-scope-not-cuts]] -- user override of Critic's 7.0/7.1 split, full scope shipped
- [[2026-05-03-slice-7-world-has-memory-pillar]] -- pillar promotion (CLAUDE.md update pending ratification)
- [[2026-05-03-slice-7-schema-bump-coalesces-cargo-capacity]] -- v4 -> v5 absorbs slice-6.1 deferral
- [[2026-05-03-slice-7-tag-multipliers-load-bearing]] -- (plentiful)/(scarce) graduate from labels to mechanical knobs
- [[2026-05-03-slice-7-gate-2-fail-escalates-separate-slice]] -- pre-ratified by user; bias-spread becomes own slice
- [[2026-05-03-slice-7-two-gate-harness-criterion]] -- slice-6 lesson applied early (don't conflate cap-binding with composition)
- [[2026-05-03-slice-7-refill-on-travel-tick-only]] -- world ticks only when player travels
- [[2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation]] -- ordering unspecified by design
- [[2026-05-03-slice-7-stock-accessor-seam]] -- WorldState.stock_for / decrement_stock helpers
- [[2026-05-03-slice-7-migration-helpers-static-on-resource]] -- no SaveMigrations module yet
- [[2026-05-03-slice-7-caps-rates-frozen-at-gen-time]] -- determinism contract preserved

## Pipeline shape

6 agent rounds. Director -> Critic (Hidden-Expensive, two-bird schema bump opportunity surfaced) -> Designer (binding spec at `docs/slice-7-production-caps-spec.md`, reconciled per-node .tres authoring against procgen-world decision) -> Architect (8 §11 questions resolved, four parallel dicts on NodeState, schema migration as static methods on owning Resource, accessor seam) -> Engineer (15 modified + 5 new files, harness ran mid-slice) -> Reviewer (Ship with minor fixes, 5 non-blocking suggestions queued as carryover).

The harness FAIL (Gate 2) was pre-ratified by user as escalation, not blocker. Gate 1 PASS landed clean; Gate 2 FAIL surfaces a price-spread tuning issue that requires its own slice. Contrast slice-6, where the FAIL forced a Designer reframe of the slice's purpose. Here, the design holds; the data doesn't. The two-gate harness avoided the same trap slice-6 hit: don't conflate cap-binding (fixed) with composition recruitment (tuning).

## Open threads

**Bias-spread slice (slice 7.x or 8, named not built):**

Gate-2 FAIL means second-best goods don't get recruited often enough when caps bind. This is a price-spread tuning issue that needs its own slice, not a patch to slice-7.

**Reviewer's five non-blocking suggestions (queued carryover):**

- Simplify or annotate `_resolve_goods_for_migration` Game-autoload workaround (no live caller today).
- Spec §7.4 wording drift vs §7.1 -- harness implements §7.1 correctly; Designer doc-fix.
- `Trade.try_buy` defensive stock re-read: keep with stronger push_warning text or drop and lean on assert.
- B1 P7's missing-cap branch is redundant with P8; cosmetic dedup.
- Harness scale: N=200 used; N=1000 only matters if Gate-2 ever lands borderline.

**Carryover from prior sessions (unchanged):** TRAVEL_COST_PER_DISTANCE, bandit goods-loss fraction at N=4, producer-threshold-fraction at N=4, B1 deferred iters 1/4/5, runbook prose-refresh, travel confirm-modal Cancel button, web-export Begin Anew flicker, test isolation cleanup, slice-6 tooltip-on-disabled-button discoverability on web export.

## Notes

The harness FAIL was not load-bearing this slice (Gate 1 PASS landed clean; Gate 2 FAIL was pre-ratified as escalation). Contrast slice-6, where the FAIL forced a Designer reframe of the slice's purpose. Here, the design holds; Gate 2 surfaces a composition/price-spread problem that deserves its own slice.

The "world has memory" pillar promotion is the most consequential project-shape change of the session. CLAUDE.md NOTs/pillars get updated in the post-ratification pass.

Six-round pipeline is normal for a Hidden-Expensive slice without structural surprise. Slice-6 was 10 rounds because of the harness FAIL; slice-7 reused that lesson and avoided the same trap by designing a two-gate criterion that separates cap-binding (fixed) from good recruitment (tuning).

## Links

- [[feedback_measurement_before_tuning]] -- the harness criterion pattern
- [[feedback_critic_stance]] -- user's slice-first stance; Critic surfaces sequencing, not cuts
- [[2026-05-03-slice-6-pipeline]] -- immediate predecessor; slice-6 lessons (two-gate harness) applied here
- [[slice-7-production-caps-spec]] -- the binding Designer spec
