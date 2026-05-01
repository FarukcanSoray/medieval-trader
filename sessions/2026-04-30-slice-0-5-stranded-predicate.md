---
date: 2026-04-30
type: session
tags: [session, director, designer, architect, engineer, reviewer, slice-0-5, stranded-predicate]
---

# Slice 0.5 — stranded-death predicate fix

## Goal

User playtested the slice (first playtest after Tier 7 made it runnable) and reported three issues: (1) death-path bug where final gold was non-zero but no goods were affordable, game didn't end; (2) no purchase-price memory; (3) no price-direction indicator. Triage and fix: issue 1 became Slice 0.5 (focused predicate rewrite); issues 2+3 bundled as "price legibility" and deferred to Slice 1. Slice 0.5 ran the full pipeline: Director → Designer → Architect → Engineer → Reviewer (Critic skipped — bug fix against ratified design intent, not a new feature).

## Produced

- **`godot/shared/world_rules.gd` (NEW)** — `class_name WorldRules extends Object`, holds `const TRAVEL_COST_PER_DISTANCE: int = 3` (migrated from `travel_controller.gd`) and `static func edge_cost(e: EdgeState) -> int`. First inhabitant of `godot/shared/` folder.
- **`godot/systems/death/death_service.gd`** — predicate rewritten to subscribe to both `Game.gold_changed` and `Game.tick_advanced` via thin signal-shape adapters calling `_check_stranded()`; `DeathRecord.final_gold` now reads `trader.gold` instead of hardcoded 0.
- **`godot/world/node_state.gd`** — added `has_affordable_good(gold: int) -> bool`.
- **`godot/world/world_state.gd`** — added `outbound_edges(node_id: String) -> Array[EdgeState]`.
- **`godot/travel/travel_controller.gd`** — removed local `TRAVEL_COST_PER_DISTANCE` const; callers now use `WorldRules.edge_cost(e)`; helper `_edge_distance(a, b)` renamed to `_find_edge(a, b)` to avoid re-introducing duplication after migration.
- **Decision log** — five new entries (2026-04-30), one prior decision marked superseded with explicit pointer to successor.

## Decisions

- [[2026-04-30-stranded-predicate-v2-affordability-checks]]
- [[2026-04-30-affordability-boundary-strict-gte]]
- [[2026-04-30-stranded-trigger-set-gold-changed-tick-advanced]]
- [[2026-04-30-world-rules-shared-static-config]]
- [[2026-04-30-stranded-connection-order-deferred]]

Prior decision [[2026-04-29-stranded-includes-empty-inventory]] superseded; `superseded_by` points to the v2 predicate with explanation in a leading note.

## Open threads

- **Slice 1 — "price legibility" features deferred.** Issues 2+3 from playtest (purchase-price memory, price-direction indicator). Share NodePanel UI surface and a per-trader "last-seen-price" store; bundling them is cheaper than separate work. Full pipeline when picked up.
- **Connection-order edge case** ([[2026-04-30-stranded-connection-order-deferred]]). DeathService runs on `tick_advanced` before PriceModel has drifted prices, risking stale affordability reads on the arrival tick. Preferred fix: move PriceModel into `Game._ready()` before DeathService. Deferred post-playtest alongside [[2026-04-30-tier7-deferred-followups]].
- **Tuning numbers still flagged `[needs playtesting]`** — starting gold 100, both `DRIFT_FRACTION` 0.10s, `TRAVEL_COST_PER_DISTANCE` 3 (now in `WorldRules`). First playtest didn't surface tuning complaints; deferred to next playtest pass.
- **`[verify on Tier 7]` markers** — hash byte-stability (`world_gen.gd:55-56`), FIFO resume order (`travel_controller.gd:80-82`). Desktop now exercised; HTML5 requires web export pass.
- **Designer call pending: years/ticks conversion** for `age_ticks` display.

## Process notes

Pipeline ran clean. Director's fit-to-pillar verdict (~400 words) explicitly drift-checked against the four intake resolutions before widening the predicate. Designer's spec covered the affordability boundary (`>=`), trigger-set logic with explicit non-triggers, and named two accessor questions for the Architect. Architect did one-line consults per question with clean reasoning (composition / dependency direction). Engineer made three judgment calls and flagged all in handoff: preserved `DeathRecord` construction order (null-deref avoidance), thin signal adapters (incompatible signatures `(int, int)` vs `(int)`), `_edge_distance` → `_find_edge` rename (re-duplication avoidance). Reviewer caught the connection-order question; user rated it and deferred via "ship + log."

## Notes

The most architecturally load-bearing artifact this session was `WorldRules` ([[2026-04-30-world-rules-shared-static-config]]) — first inhabitant of `godot/shared/`, and sets the precedent that cross-feature tuning constants live above the systems that consume them, not inside one of them. A passive evaluator (DeathService) reaching into a gameplay verb (TravelController) for a constant would invert dependency direction; lifting the fact one level fixes that for all future consumers. The folder was named in slice-architecture §6 but had no inhabitants until now; Slice 0.5 proved the architectural placeholder was correct.

The second takeaway is that the deferred connection-order gap is the same family as [[2026-04-30-idempotent-bootstrap-signal]] — both about signal-handler ordering where two systems need a specific sequence. Bootstrap was solved with an explicit completion signal; connection-order has a simpler fix (move PriceModel into the autoload phase) but was deferred. Two known signal-ordering pitfalls now in the slice's terrain.
