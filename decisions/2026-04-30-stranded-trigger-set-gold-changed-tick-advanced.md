---
title: Stranded predicate evaluation triggers — gold_changed and tick_advanced only
date: 2026-04-30
status: ratified
tags: [decision, design, signals, death-mechanics, slice-0.5]
---

# Stranded predicate evaluation triggers — `gold_changed` and `tick_advanced` only

## Decision
`DeathService` re-evaluates the stranded predicate ([[2026-04-30-stranded-predicate-v2-affordability-checks]]) on exactly two signals:

- `Game.gold_changed(new_gold, delta)` — kept from the prior implementation.
- `Game.tick_advanced(new_tick)` — newly added in Slice 0.5.

It does **not** subscribe to `arrived`, `bought`, `sold`, or `state_dirty`.

Because the two signals have incompatible signatures (`(int, int)` vs `(int)`), `DeathService` uses thin signal-shape adapters (`_on_gold_changed`, `_on_tick_advanced`) that both call a single `_check_stranded()` body — the predicate is identical on either entry path.

## Reasoning
The predicate is a snapshot, never a forecast. It evaluates only after state changes that could plausibly strand the player.

- **`gold_changed` covers the economic surface.** Buy/sell/travel-departure all route through `apply_gold_delta` → `gold_changed`, so a single subscription catches every gold-mutation event. Subscribing separately to `bought` or `sold` would double-evaluate without adding coverage.
- **`tick_advanced` covers price drift and arrival.** Prices drift each tick via `PriceModel._on_tick_advanced` (slice-spec §5 drift formula). A tick that pushes the cheapest good above the trader's gold can newly strand them with no gold mutation. Without `tick_advanced` in the trigger set, the player at gold=5 with cheapest=4 (and no affordable edge) stays alive across a tick that drifts cheapest to 6 — until they next buy/sell, which they cannot. The predicate would become a dead letter. `tick_advanced` also fires on the arrival tick of travel (when `travel == null` and `location_node_id` is set to the destination), so a separate `arrived` trigger is unnecessary.
- **`state_dirty` deliberately skipped.** It fires on every trade and travel-departure, leading to extra evaluations. Cheap, but redundant — every productive `state_dirty` at this stage is preceded by a `gold_changed`. (Note: this is also what makes the connection-order edge case in [[2026-04-30-stranded-connection-order-deferred]] a real gap rather than a non-issue.)

The trigger set composes cleanly with the existing `Game` autoload's signal surface — no new signals introduced by Slice 0.5.

## Alternatives considered
- **Add `arrived` as a separate trigger** — rejected. Redundant with `tick_advanced` fired during the travel loop's arrival tick.
- **Add `bought` / `sold` as separate triggers** — rejected. They already route through `gold_changed` via `apply_gold_delta`.
- **Add `state_dirty` (Option C from the connection-order discussion)** — rejected for Slice 0.5. Adds extra cheap evaluations on every trade; useful only as a workaround for the PriceModel-after-DeathService ordering issue, which is itself deferred.
- **Connect both signals to one method directly (no adapters)** — rejected. Godot would emit mismatched argument shapes; adapters are mechanically required, not stylistic.

## Confidence
High. Trigger set is mechanically derivable from the predicate's read set (gold, inventory, current-node prices, outbound edges) and the signal surface that mutates each.

## Source
- Designer's spec call, Slice 0.5 (this conversation), §3 of the rule spec.
- Engineer's implementation note on the adapter pattern (signature incompatibility).
- Reviewer ratification, Slice 0.5.

## Related
- [[2026-04-30-stranded-predicate-v2-affordability-checks]] — the predicate these triggers evaluate
- [[2026-04-30-stranded-connection-order-deferred]] — a known gap in the `tick_advanced` ordering
- [[2026-04-29-tick-on-player-travel]] — `tick_advanced` only fires on player-driven travel
- [[2026-04-29-tick-granularity-per-step]] — N tick_advanced for N-tick travel, not batched
- [[2026-04-30-idempotent-bootstrap-signal]] — same lifecycle-await family
