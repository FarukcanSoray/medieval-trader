---
date: 2026-05-03
type: session
tags: [session, slice-5, goods-expansion, full-pipeline]
---

# Slice-5 goods catalogue expansion -- full pipeline with day-1/day-2 in-slice split

## Goal

Run the full project pipeline (Director -> Critic -> Designer -> Architect -> Engineer -> Reviewer) on slice-5 (goods catalogue expansion). Add the first new tradeable good (salt) beyond the starter wool/cloth pair; establish the framework for multi-good measurement and carryover tuning. Close with decisions ratified and day-1 code shipped. The measurement gate (headless tool on user machine) is deferred pending user run.

## Produced

**Spec:**

- `docs/slice-5-goods-expansion-spec.md` -- Designer's binding spec, 13 sections (scope, taxonomy, role definitions, preload strategy, forward-port implementation, measurement predicate, day-1 carryover tuning list).

**Code (modified, 5 files):**

- `godot/game/game.gd` -- salt preload appended to `goods` array; iron deliberately absent (day-2 gated).
- `godot/game/world_gen.gd` -- three new public statics: `needs_goods_forward_port`, `forward_port_goods`, `compute_topology_min_edge_distance` (cleanest support API for histogram split). Existing `_author_bias` and `_seed_prices` signatures unchanged (already accepted goods subsets).
- `godot/systems/save/save_service.gd` -- forward-port call inserted after `from_dict` succeeds, before `Game.world`/`Game.trader` assignment; predicate-fail falls through to existing corruption-toast + regen path.
- `godot/pricing/price_model.gd` -- cosmetic comment fix (2 goods -> 3 goods).
- `godot/tools/measure_bias_aborts.gd` -- extended to sweep N in [2, 3] over 1000 seeds; per-good `allowed_range` histogram split into success and abort populations; verdict line gates day-1 on `abort_pct(N=3) <= 5.0%`.

**Code (new, 1 file):**

- `godot/goods/salt.tres` -- day-1 cheap-volatile good (id="salt", base=7, floor=3, ceiling=14, vol=0.13).

## Decisions ratified

- [[2026-05-03-slice-5-goods-catalogue-expansion-scope]]
- [[2026-05-03-slice-5-four-good-role-taxonomy]]
- [[2026-05-03-slice-5-max-abort-rate-5pct]]
- [[2026-05-03-slice-5-histogram-split-success-abort]]
- [[2026-05-03-slice-5-forward-port-saves]]
- [[2026-05-03-slice-5-explicit-goods-preload-paths]]

## Pipeline shape

Eight rounds: Director, Critic, Designer, Architect, Engineer round 1, Reviewer round 1 (blocking), Engineer round 2, Reviewer round 2 (Ship-it).

**Critic's compression call was load-bearing:** Director surfaced three branches (A: count expansion only; B: count + named roles; C: mechanical axes including weight and perishability). Critic compressed A+B into one slice (B is what A becomes when tuned deliberately) and deferred C entirely. Honored the user's standing pattern ([[feedback_critic_stance]]) of holding scope and reframing Critic verdicts as sequencing.

**Reviewer round 1 overturned Engineer's first-pass histogram approach:** Engineer sampled successes only, reasoning "the data of interest is for worlds that did succeed." Reviewer ruled this structurally incapable of answering "which good drove the aborts" -- the failing good is exactly the one whose distribution gets clipped out. Engineer round 2 implemented the split; new public static `WorldGen.compute_topology_min_edge_distance` was the cleanest support API.

**Expensive-volatile fourth corner explicitly excluded** -- spec §7 reasoning: under the slice-3 free-lunch predicate at `MIN_EDGE_DISTANCE = 3`, an expensive-volatile good (e.g., base=25, vol=0.12, ceiling=45) burns more than the entire 9g per-good budget on the volatility term alone. Spice/silk/gemstones become slice-6+ candidates only if a future slice expands the predicate budget.

Plain-language step-backs issued post-Designer, post-Architect, post-Reviewer round 2 per standing rule for 3+ agent rounds.

## Open threads

**Day-1 measurement not yet run.** Engineer's tool extension (`measure_bias_aborts.gd` with N=[2,3] sweep + histogram split) is shippable; the user paused before running it on their machine. Day-2 work is gated on `abort_pct(N=3) <= 5.0%`.

**Day-2 work (gated, fully named):**

- Author `godot/goods/iron.tres` (base=22, floor=14, ceiling=32, vol=0.05).
- Append iron preload to `game.gd`.
- Extend `measure_bias_aborts.gd`: append iron path to `GOOD_PATHS`, extend `N_SWEEP` to [2, 3, 4], retune `GATE_N` to 4.
- Re-run measurement; manually validate forward-port produces salt+iron rows on first load and persists on second.

**Slice-5.x carryover (named owe-notes, not built):**

- `BANDIT_GOODS_LOSS_FRACTION` retune at N=4 (tuned against 2 goods; 1-of-N feel needs revisit).
- `PRODUCER_THRESHOLD_FRACTION` revisit at N=4 if tag legibility breaks on tight-range goods.
- Weight/cargo capacity-only as Branch C-weight follow-up.
- Optional: reverse-walk the bump loop in `measure_bias_aborts.gd` if placement-starvation skip masks predicate-fail signal in practice.

**Slice-6+ candidates:**

- Perishability (its own slice; schema bump on `TraderState.inventory`).
- Expensive-volatile good (spice/silk/gemstone), pending predicate budget expansion.

**Inherited carryover (unchanged):** Web-export Begin Anew flicker; B1 deferred iters 1/4/5; runbook prose-refresh; `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`; travel confirm-modal Cancel button; Tier 7 deferred markers.

**Uncommitted state:** Day-1 work is in the working tree, not committed. Project convention is to commit after a slice-day's pipeline closes; the user paused before measurement, so commit is deferred until the gate runs.

## Links

- [[slice-5-goods-expansion-spec]] -- ratified spec
- [[2026-05-02-slice-4-encounters-pipeline]] -- prior slice close; carryover tuning from this session extends slice-4 constants
- [[feedback_measurement_before_tuning]] -- the meta-pattern, invoked: measurement gate gates day-2
- [[feedback_critic_stance]] -- reframing Critic verdicts as sequencing, applied this session
- [[project-brief]] -- project kernel (arbitrage + travel cost collision)

## Notes

**Histogram split was the critical refinement.** The question "which good fails the forward-port predicate?" is distribution-shaped. Engineer's first instinct (success-only sampling) was structurally unsound for data like this -- it would have masked the answer. Reviewer's catch is the kind of cross-system reasoning that justifies the pipeline.

**Salt's parameters (base=7, floor=3, ceiling=14, vol=0.13) are Designer's pick, not derived.** The spec carries the rationale (tight range, high volatility, cheap so it scales within 9g budget), but the exact numbers await measurement verdict. If `abort_pct(N=3)` exceeds 5.0%, day-2 may retune or substitute a different good entirely. This is measurement-before-tuning applied: we ship the architecture and a plausible candidate, then let data decide.

**Forward-port pattern sets a precedent for future catalogue growth.** Slice-N saves loaded onto slice-N+1 builds get re-seeded in place rather than corruption-toasted. The pattern hinges on `_author_bias` and `_seed_prices` being callable on a goods *subset* with the saved `world_seed`. As long as that contract holds, the catalogue can grow several more times without schema bumps. The decision codifies the precedent for slice-6+.
