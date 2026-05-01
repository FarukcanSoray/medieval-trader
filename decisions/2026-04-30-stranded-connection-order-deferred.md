---
title: Deferred — DeathService runs before PriceModel on tick_advanced (drift-at-arrival edge case)
date: 2026-04-30
status: ratified
tags: [decision, deferred, signals, slice-0.5, post-playtest]
---

# Deferred — `DeathService` runs before `PriceModel` on `tick_advanced` (drift-at-arrival edge case)

## Decision
A known gap in Slice 0.5's stranded-detection coverage is **deferred to a post-playtest pass**, not patched in this round. Concretely:

- Signal-handler connection order on `Game.tick_advanced` is `SaveService → DeathService → PriceModel`.
- `SaveService` and `DeathService` are added as children of `Game` in `Game._ready()` (autoload phase, runs first).
- `PriceModel` is a child node of `main.tscn` (scene-tree phase, runs after autoloads).
- Godot 4 signal handlers fire in connection order. Therefore on every `tick_advanced` emit (including arrival ticks of travel), `DeathService._check_stranded` runs against **pre-drift** prices for that tick, then `PriceModel` drifts.

The narrow gap: if pre-drift prices at the arrival node are affordable, but post-drift prices at that same arrival tick would strand the trader (every good above gold AND every outbound edge above gold AND empty inventory), the stranding is not detected on that tick. The next signal (`gold_changed` or another `tick_advanced`) would catch it — but a fully stranded player can neither trade nor travel, so no further signal fires. The result is a soft-lock that may never resolve.

This gap is logged here so it isn't lost. Pick up post-playtest, alongside the items in [[2026-04-30-tier7-deferred-followups]].

## Reasoning
Three options were considered at end-of-slice:

- **(A) Ship Slice 0.5 + log the gap** — chosen. The user's observed playtest case is fully fixed by Slice 0.5 as implemented (pre-drift prices were already unaffordable when they landed). The drift-causes-strand-at-arrival case is genuinely narrow: it requires the drift on one specific tick to flip a previously-affordable arrival node to fully unaffordable, with empty inventory and no affordable edges, in the exact moment of arrival. None of the user's playtest scenarios so far have hit it; deferring loses no observed coverage.
- **(B) Loop Architect now to fix connection order** — rejected. Cleanest fix is moving `PriceModel` into `Game._ready()` and adding it before `DeathService`, so the order becomes `Save → Price → Death`. Reasonable architecturally, but expands the slice-shipping round past its boundary at the moment of first close-out.
- **(C) Subscribe `DeathService` to `state_dirty` as a third trigger** — rejected. `PriceModel` already emits `state_dirty` after drifting (`price_model.gd:25`), so this would catch the gap. But it adds extra evaluations on every trade and creates a third subscription on an autoload signal whose contract was set explicitly to two signals only ([[2026-04-30-stranded-trigger-set-gold-changed-tick-advanced]]). Mechanically simple, conceptually a regression.

The user's slice-first stance ([[2026-04-29-no-cuts-slice-first]]) favours archiving deferred work via decision-log + session-summary rather than expanding the round. This decision follows that stance and the precedent of [[2026-04-30-tier7-deferred-followups]].

## When to revisit
Pick up in the post-playtest cleanup pass. Triggers that should escalate this from deferred to active:

1. **A playtest reproduces the soft-lock.** Any save where the trader is alive at a node with no affordable good, no affordable edge, no inventory — and the save persisted across at least one tick.
2. **PriceModel becomes part of the autoload phase for any other reason.** If it moves into `Game._ready()` for unrelated reasons, the connection-order gap closes incidentally — verify and clear this decision.
3. **A second cross-system signal handler is added that depends on `PriceModel`'s mutations being visible.** The same ordering pitfall would apply; fix everything together rather than one-off-ing each consumer.

When picking it up, the preferred fix is Option B (move PriceModel into `Game._ready()` before DeathService). Option C remains a fallback if Option B introduces other ordering pain.

## Alternatives considered
See "Reasoning" above — Options A (chosen), B (deferred to post-playtest), C (rejected as a regression on the trigger-set decision).

## Confidence
Medium. The gap is mechanically real but narrow; deferral is appropriate given the slice-first stance. Confidence rises if the playtest log shows no soft-locks across a meaningful number of plays; falls if any playtest reproduces it.

## Source
- Code Reviewer's question on PriceModel ordering, Slice 0.5 review (this conversation).
- Direct verification: `game.gd:36-41` adds SaveService then DeathService in `_ready()`; `main.tscn:23` instantiates PriceModel as a Main child.
- User ratified "ship + log" at end-of-slice.

## Related
- [[2026-04-30-stranded-predicate-v2-affordability-checks]] — the predicate this gap concerns
- [[2026-04-30-stranded-trigger-set-gold-changed-tick-advanced]] — the trigger set Option C would have widened
- [[2026-04-30-tier7-deferred-followups]] — same archival pattern; pick up together post-playtest
- [[2026-04-30-idempotent-bootstrap-signal]] — same signal-ordering family
- [[2026-04-29-no-cuts-slice-first]] — the stance under which deferral is correct
- [[2026-04-29-tick-on-player-travel]] — explains why `tick_advanced` fires only during travel
