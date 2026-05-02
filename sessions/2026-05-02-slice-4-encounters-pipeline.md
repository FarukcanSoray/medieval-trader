---
date: 2026-05-02
type: session
tags: [session, slice-4, encounters, full-pipeline]
---

# Slice-4 encounters -- full pipeline with day-1/day-2 in-slice split

## Goal

Run the full project pipeline (Director -> Critic -> Designer -> Architect -> Engineer -> Reviewer) on slice-4 (encounters). Add stakes to the round-trip arbitrage loop -- "travel cost is more than gold-per-distance, route risk is itself a math problem." Close the carryover from [[2026-04-29-slice-zero-encounters]]. Close with decisions ratified.

## Produced

**Code (modified, 8 files):**

- `godot/shared/world_rules.gd` -- six new bandit constants (`BANDIT_ROAD_FRACTION = 0.35`, `BANDIT_ROAD_PROBABILITY = 0.30`, `BANDIT_GOLD_LOSS_MIN/MAX_FRACTION`, `BANDIT_GOLD_LOSS_HARD_CAP = 30`, `BANDIT_GOODS_LOSS_FRACTION = 0.50`).
- `godot/world/edge_state.gd` -- `is_bandit_road: bool` added.
- `godot/trader/travel_state.gd` -- `encounter: EncounterOutcome` added (nullable; null = no encounter fired).
- `godot/world/history_entry.gd` -- `KINDS` extended with `"encounter"`.
- `godot/world/world_state.gd` -- `SCHEMA_VERSION` 3 -> 4; per-edge `to_dict` + `_edge_from_dict` strict-reject for `is_bandit_road`.
- `godot/trader/trader_state.gd` -- `to_dict`/`_travel_from_dict` ferry the new `encounter` sub-block.
- `godot/game/world_gen.gd` -- `_author_encounters` static + insertion in `generate()` after `_author_bias`, before `_seed_prices`.
- `godot/travel/travel_controller.gd` -- `request_travel` rolls encounter post-cost-deduction; `process_tick` arrival branch snapshots state before clearing `_trader.travel`; new `_apply_encounter`, `_format_encounter_detail`, `_origin_prices_for_leg` private methods.
- `godot/main.gd` -- `_on_travel_requested` extended with edge lookup + bandit branch; new `_find_outbound_edge` helper.
- `godot/ui/hud/confirm_dialog.gd` -- `prompt` signature extended with three defaulted encounter params.

**Code (new, 2 files):**

- `godot/travel/encounter_outcome.gd` -- `Resource` with five fields; `to_dict`/`from_dict` strict-reject on missing keys (scalar coercion follows existing pattern).
- `godot/travel/encounter_resolver.gd` -- `class_name EncounterResolver extends Object`, static-only; `try_resolve` (gold + day-2 goods) + `preview_loss_max` (cost-preview helper).

**Docs:**

- `docs/slice-4-encounters-spec.md` -- Designer's binding spec (10 sections); patched at close (constant naming, `gold_lost` -> `gold_loss`, cost-preview `~25%` -> `~30%`).

## Decisions ratified

- [[2026-05-02-slice-4-scope-encounters]]
- [[2026-05-02-slice-4-roll-fires-at-departure]]
- [[2026-05-02-slice-4-no-mid-encounter-choice-ui]]
- [[2026-05-02-slice-4-bandit-roads-telegraphed]]
- [[2026-05-02-slice-4-slain-deferred-to-4x]]
- [[2026-05-02-slice-4-bandit-tag-pure-random]]
- [[2026-05-02-slice-4-flat-per-edge-probability]]
- [[2026-05-02-slice-4-gold-loss-bounds]]
- [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]]
- [[2026-05-02-slice-4-encounter-roll-seed]]
- [[2026-05-02-slice-4-goods-loss-target-rule]]
- [[2026-05-02-slice-4-schema-4-discard-via-toast]]
- [[2026-05-02-slice-4-history-encounter-kind]]
- [[2026-05-02-slice-4-readback-consumed-preempted]]
- [[2026-05-02-slice-4-encounter-resolver-placement]]
- [[2026-05-02-slice-4-encounter-outcome-resource]]
- [[2026-05-02-slice-4-store-only-when-it-bites]]
- [[2026-05-02-slice-4-confirm-dialog-extended-signature]]
- [[2026-05-02-slice-4-from-dict-scalar-coercion-pattern]]

## Pipeline shape

Eight rounds: Director, Critic, Designer, Architect, Engineer (Tier A-C), Reviewer (Pass 1: "Ship with minor fixes"), Engineer (3 minor fixes applied directly), Engineer (Tier D goods-loss). User opted to skip a re-review on Tier D since the diff was small, mechanical, and the determinism contract was preserved verbatim.

The standout pivot was **Critic's compression check**: Director claimed three subsystems; Critic counted five (trigger + gen-time tag + view-cluster + outcome-resolver + death-cause-context). The reframe-as-sequencing pattern (per [[feedback_critic_stance]]) deferred two of those to slice-4.x (`slain` death cause + resolution modal) without losing scope. The remaining three subsystems shipped clean.

Critic's other load-bearing call: "tag without numbers is a Pillar 1 violation under the cover of legibility." Slice-3's tags worked because price was always visible alongside; slice-4's outcome is hidden until arrival, so the cost-preview MUST surface bounds + probability. This drove [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] from "nice to have" to "ship-blocking day-2 work."

Two plain-language step-backs were issued during the run (post-Designer and post-Architect) per the standing rule for 3+ agent rounds.

## Open threads

**Carryover chain closed.** [[2026-04-29-slice-zero-encounters]] is now resolved -- encounters shipped (bandit-only, gold + goods loss, telegraphed, expected-cost surfaced).

**Slice-4.x candidates (named follow-ups, no decision needed yet):**

- `slain` death cause + DeathService context plumbing -- needs precedent-overturn against [[2026-04-29-slice-one-death-cause-bankruptcy]].
- Encounter resolution modal -- only if playtest shows the history-line readback reads as invisible. `readback_consumed` field already pre-empted in the schema.
- Bandit-road minimum-count invariant -- only if zero-bandit worlds feel hollow at playtest.
- `_origin_prices_for_leg` returns live reference (read-only by contract today; risk if a future caller mutates).
- `qty_to_lose` not capped against `stack_qty` -- assumption only safe while `BANDIT_GOODS_LOSS_FRACTION <= 1.0`.

**Visual playtest pending.** No build run this session. Generation determinism is verified by mathematical inspection of the hash contract; gameplay legibility (do the cost-preview numbers actually help reasoning? does `(+0..30g, ~30%)` parse at a glance? does the two-row history pattern read as "lucky bandit leg"?) is untested.

**Inherited carryover (unchanged from prior sessions):** Web-export Begin Anew flicker; B1 deferred iters 1/4/5; runbook prose-refresh; `TRAVEL_COST_PER_DISTANCE` `[needs playtesting]`; travel confirm-modal Cancel button; Tier 7 deferred markers.

## Links

- [[slice-4-encounters-spec]] -- ratified spec
- [[2026-05-02-slice-3-pricing-pipeline]] -- prior slice close (the "not fun yet" playtest signal that triggered this slice)
- [[2026-04-29-slice-zero-encounters]] -- the carryover chain origin, now closed
- [[2026-05-02-measurement-before-tuning]] -- the meta-pattern, not invoked this slice (no measurement-shaped questions arose)
- [[2026-05-02-slice-3-schema-3-discard-via-toast]] -- the schema-bump pattern this slice extends

## Notes

**Critic's "tag without numbers" insight is a refinement of the slice-3 legibility model.** Slice-3 ratified `(plentiful)` / `(scarce)` tags WITHOUT numbers because the underlying observable (price) was always visible -- the player did the math themselves. Slice-4 inherits the tag syntax but breaks the "no numbers" rule because there is no underlying visible signal: the encounter outcome is invisible until arrival, so the player needs bounds + probability to compute expected cost. Same pillar (Pillar 1), different application: tags work when paired with an observable; they don't work when the observable is hidden. Worth remembering when the next slice introduces another procgen attribute.

**Engineer's "store-only-when-it-bites" simplification ([[2026-05-02-slice-4-store-only-when-it-bites]])** dropped the `EncounterOutcome.fired: bool` field by making null-on-`TravelState.encounter` carry both "not bandit road" and "bandit road but missed." Two cases collapsed into one storage representation. The information distinction is recoverable from `EdgeState.is_bandit_road` if needed, and the history-line two-row pattern carries the "lucky bandit leg" signal anyway. This is the kind of Architect-pass simplification that pays for the round.

**No `slain` death cause this slice.** Encounter-driven insolvency triggers `stranded` via existing DeathService logic. The slice-4.x carryover [[2026-05-02-slice-4-slain-deferred-to-4x]] preserves the work; the slice ships without it because (a) Critic was right that adding `slain` requires precedent-overturn + DeathService refactor, and (b) the kernel ("travel cost can be more than gold-per-distance") is fully testable without a second death cause.
