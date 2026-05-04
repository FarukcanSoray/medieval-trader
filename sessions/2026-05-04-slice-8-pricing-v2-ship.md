---
date: 2026-05-04
type: session
tags: [session, slice-8, pricing-v2, engineering, hot-path, determinism]
---

# Slice-8 (Pricing v2): Engineering to ratification

## Goal

Ship Slice-8 (Pricing v2: two-sided pool curve) end-to-end. Director/Critic/Designer/Architect rounds completed earlier; today's work was implementation, review, fixes, and ratification: Engineer -> Code Reviewer -> Engineer-fix -> spec amendment -> Decision Scribe -> session close.

## Produced

- [[godot/pricing/pricing_math.gd]] -- stateless pull-driven price helper (replaces deleted price_model.gd); includes cached static RNG and _mix64 integer combiner
- [[godot/systems/demand/demand_system.gd]] -- tick-listener system mirroring StockSystem; manages demand pool decay
- [[godot/tools/measure_pricing_v2.gd]] + .tscn -- three-gate slice-8 harness; all gates PASS
- [[godot/tools/pricing_v2_verdict.txt]] -- harness output (100/100 seed round-trip on gate 3)
- [[docs/slice-8-pricing-v2-spec.md]] -- §5.1, §5.2, §5.4, §13 amended to reflect mid-slice spec reframe (intent-normative combiner language, no-per-call-heap invariant codified)

**Modified (substantive):**
- [[godot/world/node_state.gd]] -- dropped `prices` field, added four `demand_*` dicts
- [[godot/world/world_state.gd]] -- SCHEMA_VERSION 6; v5->v6 migration + v4 strict-rejected; demand accessors
- [[godot/travel/trade.gd]] -- try_buy/try_sell now pull via PricingMath
- [[godot/ui/hud/node_panel.gd]] -- new row format with buy/sell prices and supply/demand bars
- [[godot/systems/save/save_invariant_checker.gd]] -- P8 reframed, P9+P10 added, empty-canonical rails
- [[godot/game/world_gen.gd]], [[godot/systems/death/death_service.gd]], [[godot/shared/world_rules.gd]], [[godot/main.tscn]] and supporting files per commit 852d0df

**Deleted:**
- `godot/pricing/price_model.gd` -- slice-3 drift pricing, retired

## Decisions

- [[2026-05-04-slice-8-perturbation-seed-mix-supersedes-hash-array]] -- splitmix64 integer mix replaces hash([...]) Array literal on hot path; resolves Reviewer Blocker 1
- [[2026-05-04-slice-8-spec-perturbation-seed-intent-normative]] -- spec §5.4 reframed as intent-normative (five invariants); combiner is reference implementation, not bit-exact
- [[2026-05-04-slice-8-save-invariant-p8-stock-caps-canonical]] -- save invariants P8/P9/P10 keyed off stock_caps and demand_caps as canonical sets; empty-canonical rail added
- [[2026-05-04-slice-8-pricing-math-static-rng-cache]] -- PricingMath reuses single static RNG, reseed per call; addresses Blocker 1 heap-RNG allocation
- [[2026-05-04-slice-8-encounter-resolver-prices-via-pricingmath]] -- encounter resolver materializes origin-node prices at call site (travel_controller.gd) post-prices-field-drop

## Open threads

**From Code Reviewer (queued as carryover):**
- 6 non-blocking suggestions: missing `_author_supply` migration for future good catalogue growth (P10 spurious-fire risk); missing `assert(rate < cap)` rail in migration; P5 coverage shrinkage; unreachable defensive branches; undocumented harness-vs-production tick-ordering parallel; `try_sell` drain comment gap
- 7 nits: stale comments (removed PriceModel / `has_affordable_good` / "seeds tick-0"); dead conditional; bar widget rounding
- 3 open questions: harness decay-only sweep acceptable for slice-ship gate?; encounter resolver tie-breaking under floor/ceiling ties (slice-8.x play-feel); discarded bootstrap world before sweep

**From Engineer's notes:**
- Thread-safety of cached static RNG -- single-threaded today, hazard if threading introduced
- Godot warning spam from `_emit_p2_warnings` during harness (~5MB stderr)

**Carried forward from Slice-7:**
- TRAVEL_COST_PER_DISTANCE tune; bandit goods-loss fraction; producer-threshold-fraction; B1 deferred iters; runbook prose-refresh; travel confirm-modal Cancel; web-export Begin Anew flicker; test isolation; slice-6 tooltip discoverability; stock_caps -> supply_caps rename deferred to slice-8.x

**Slice-7 supersession candidate (not promoted today):**
- `2026-05-03-slice-7-pricemodel-stocksystem-disjoint-mutation` partially superseded by PriceModel deletion; disjoint-mutation contract now applies between StockSystem and DemandSystem. Worth a forward DS note on next slice touching this seam.

## Links

- [[2026-05-04-slice-8-pool-curve-formula-locked]] -- formula reference partially updated by perturbation-seed supersession
- [[2026-05-04-slice-8-prices-field-dropped-pull-driven]] -- prerequisite: removed prices field, enabled PricingMath pull-driven design
- [[2026-05-04-slice-8-nodestate-demand-dicts-shape]] -- shape of demand quads now validated by P9/P10
- [[2026-05-04-slice-8-pricemodel-reshaped-stateless-query]] -- replaced by new PricingMath stateless helper

## Notes

Mid-slice spec amendment is precedent-setting: intent-normative spec language survives implementation pivots that preserve load-bearing invariants. Invariant 5 (no per-call heap) was codified in §5.4 because Reviewer's Blocker 1 surfaced a hot-path constraint absent from the original Designer pass.

Pipeline ran lean: Engineer + Reviewer + Engineer-fix + spec amendment was four rounds, no Architect/Designer return trips (compare Slice-7's six rounds, Slice-6's ten).

Commit 852d0df bundles 21 modified + 5 new + 2 deleted files; all gates harness-verified. Code Reviewer verdict was Ship-with-minor-fixes; three blockers addressed in Engineer-fix pass.
