---
date: 2026-05-03
type: session
tags: [session, slice-6, weight-cargo, harness-reframe]
---

# Slice-6 pipeline -- weight and cargo capacity end-to-end; harness FAIL reframed the predicate

## Goal

Implement Slice-6.0 (weight/cargo capacity) end-to-end: Critic-gated scope (cargo as code constant, TraderState migration deferred to 6.1), Designer binding spec, Architect resolution, Engineer implementation with mid-slice harness feedback, and ship with Reviewer. The slice purpose: route-dependent good selection now matters because carrying everything simultaneously becomes impossible.

## Produced

**Code (modified, 7 files):**

- `godot/goods/good.gd` -- added `weight: int` field with `@export_range(1, 20)`
- `godot/goods/{wool,cloth,salt,iron}.tres` -- authored weights (wool=4, cloth=3, salt=2, iron=10)
- `godot/shared/world_rules.gd` -- `CARGO_CAPACITY = 60` constant (route-economy derived)
- `godot/game/game.gd` -- `goods_by_id` Dictionary built once at boot
- `godot/travel/trade.gd` -- buy-gate enforces load ceiling; refund mirrors deduction (atomicity contract); orphan-id defense
- `godot/ui/hud/node_panel.gd` -- `CartLabel` wiring + extended `_update_row` (weight predicate + tooltip) + tooltip-clearing for disabled buttons
- `godot/ui/hud/node_panel.tscn` -- `CartLabel` authored between TitleLabel and Rows

**Code (new, 2 files):**

- `godot/cargo/cargo_math.gd` -- `CargoMath` static helper (`compute_load`); mirrors `EncounterResolver` pattern
- `godot/tools/measure_cargo_decision_divergence.gd` -- harness with revised Interpretation-C criterion (per-good band + multi-good floor + gold-cap sanity)

**Spec:**

- `docs/slice-6-weight-cargo-spec.md` -- binding Designer spec with §13 harness lessons added during Designer-2 reframe (includes three out-of-scope mechanics for future Director conversation: per-node production caps, sell-side elasticity, multi-leg route commitments)

**Verdict:**

- `godot/tools/cargo_divergence_verdict.txt` -- PASS at gating tier (74/105 sweep tuples PASS after reframe)

**Commit:** `d9f2ded` -- "Add cargo decision divergence measurement tool and enhance trade UI"

## Decisions ratified

- [[2026-05-03-slice-6-cargo-cap-as-code-constant]] -- Critic-driven scope reduction; TraderState migration deferred to slice-6.1
- [[2026-05-03-slice-6-per-good-weights]] -- wool=4, cloth=3, salt=2, iron=10
- [[2026-05-03-slice-6-cargo-capacity-60]] -- derived from route-economy math
- [[2026-05-03-slice-6-cargo-math-static-helper]] -- script-only static helper, mirrors EncounterResolver
- [[2026-05-03-slice-6-goods-by-id-lookup]] -- Dictionary built once at boot
- [[2026-05-03-slice-6-current-load-derived]] -- not stored, four-axis Critic comparison
- [[2026-05-03-slice-6-buy-gate-refund-mirrors-deduction]] -- atomicity contract
- [[2026-05-03-slice-6-knapsack-degeneracy-lesson]] -- the load-bearing project-level lesson
- [[2026-05-03-slice-6-route-dependent-good-selection-reframe]] -- the slice-purpose reframe (Designer-2 decision after harness FAIL)
- [[2026-05-03-slice-6-revised-harness-criterion]] -- per-good band + multi-good floor + gold-cap sanity
- [[2026-05-03-slice-6-cart-full-boundary-gte]] -- defensive `>=` for slice-5-save overflow
- [[2026-05-03-slice-6-tooltip-clearing-disabled-branches]] -- defensive UI pattern

## Pipeline shape

10 agent rounds. Director -> Critic (Hidden-Expensive -> slice-6.0 + slice-6.1 deferral) -> Designer-1 (binding spec with original §7.2 criterion) -> Architect (4 calls resolved, ratified Designer leans) -> Engineer-1 (files 1-9 + harness run, timeout mid-stream) -> Engineer-2 (files 10-12, judgment calls flagged) -> **harness FAIL (0/105)** -> Designer-2 (Interpretation C disentanglement; spec §13 lessons added) -> Engineer-3 (criterion update + harness re-run, 74/105 PASS at gating tier) -> Reviewer (Ship with minor fixes) -> Engineer-4 (orphan-id defense + tooltip-clear extension).

The harness FAIL was the load-bearing event. Mid-slice measurement revealed the original §7.2 predicate was testing the wrong thing; Designer's reframe (Interpretation C) corrected the slice *purpose*, not just the check. Without measurement-before-tuning, a technically-passing harness would have shipped the wrong game.

## Open threads

**Slice-6.1 candidates (named, not built):**

- TraderState migration when capacity needs to vary per-trader (cart upgrades, mules)
- Bandit interaction weight-awareness (lose by weight vs. by value) -- pending playtest of felt-proportionality
- Tooltip-on-disabled-button discoverability on web export -- spec §11 [needs playtesting]

**Three out-of-scope mechanics for future Director conversations** (logged in spec §13.3): per-node production caps, sell-side elasticity, multi-leg route commitments. Each would unlock per-leg portfolio depth.

**Carryover from prior sessions (unchanged):** TRAVEL_COST_PER_DISTANCE [needs playtesting], bandit goods-loss fraction retune at N=4, producer-threshold-fraction revisit at N=4, B1 deferred iters 1/4/5, runbook prose-refresh, travel confirm-modal Cancel button, web-export Begin Anew flicker, test isolation cleanup.

## Notes

**The harness FAIL was the load-bearing event of the session.** Without measurement-before-tuning, the slice would have shipped a broken predicate that user playtest would expose later. The feedback rule [[feedback_measurement_before_tuning]] paid off; the Designer's second pass (Interpretation C reframe) corrected the slice's *purpose*, not just the harness criterion.

**Engineer's orphan-id defense and tooltip-clearing catches were defensive finds** that the spec didn't anticipate. These are the judgment calls that Reviewer ratifies at hand-off; they matter for durability.

**Cache-stale didn't hit this slice** (the prior `--import` refresh cleared it; new `class_name CargoMath` landed clean).

**The 10-round count is justified by the structural surprise**, not by the slice's size. A slice without the harness FAIL would have been 6 rounds.

## Links

- [[feedback_measurement_before_tuning]] -- the meta-pattern that surfaced the harness FAIL
- [[feedback_critic_stance]] -- user's slice-first stance reframed Critic verdicts as sequencing
- [[feedback_pipeline_step_back]] -- plain-language step-backs at rounds 4 and 6
- [[2026-05-03-slice-5x-save-persistence]] -- prior session; carryover state unchanged
- [[slice-6-weight-cargo-spec]] -- the binding Designer spec
