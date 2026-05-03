---
title: Cart "(full)" boundary uses >= not == for slice-5-save overflow defense
date: 2026-05-03
status: ratified
tags: [decision, slice-6, ui, defensive, edge-case]
---

# Cart "(full)" boundary uses >= not == for slice-5-save overflow defense

## Decision
In `node_panel.gd._format_cart_label`, the "(full)" suffix triggers on `current_load >= CARGO_CAPACITY`, not the spec-literal `current_load == CARGO_CAPACITY`.

## Reasoning
Slice-5 saves had no `weight` field on `Good` and no cargo-cap concept. When such a save loads on slice-6.0, the trader's existing inventory may exceed the new `CARGO_CAPACITY = 60` -- e.g., 250 weight units of accumulated wool from a long slice-5 run.

Using `==` would render the label as `"Cart: 250/60"` -- silently misleading; the player sees no signal that they're over the cap, even though every buy will be refused. Using `>=` renders `"Cart: 250/60 (full)"` -- truthful: the cart is at-or-over capacity, no buys allowed until capacity is freed by selling.

The buy gate refuses any purchase regardless of the label (correct -- `current_load + weight > CARGO_CAPACITY` whenever `current_load >= CARGO_CAPACITY` AND `weight >= 1`, which the `Good.weight` `@export_range(1, 20)` guarantees). So the defensive `>=` is purely a UI-honesty measure; it does not change runtime behaviour.

This is a deliberate Engineer judgment call, surfaced explicitly during round 2 implementation, ratified by Reviewer in the slice-6.0 review pass: *"slice-5 saves with inventory > 60 will read e.g. 'Cart: 250/60 (full)', which is truthful. Spec §10 explicitly anticipates 'Cart: 250/60' without the suffix; appending '(full)' here is a minor deviation but a strictly more honest one. Fine."*

## Alternatives considered
- **Strict equality `current_load == CARGO_CAPACITY`** -- rejected: misses the over-cap case; player sees `"Cart: 250/60"` with no signal that buys will be refused.
- **Reject the load (refuse to load slice-5 saves)** -- rejected: loses player data; the slice-5.x save-persistence work would be undone for no gain.
- **Migrate old saves to clamp inventory at load** -- rejected: silent data loss; the player would lose unsold inventory accumulated during slice-5.
- **Append "(over)" or "(over capacity)" suffix** -- not chosen, but acceptable. "(full)" is sufficient because the *consequence* (no buys) is the same as exact-full.

## Confidence
Medium-high. The decision is small but defensive; the "spec-literal `==` would be misleading" reasoning is concrete. Could be revisited if a future UX pass wants distinct strings for at-cap vs over-cap.

## Source
Engineer's judgment-call flag during round 2 implementation; Reviewer confirmation in slice-6.0 review (Reviewer's non-blocking suggestion #4). `godot/ui/hud/node_panel.gd:80-87` (`_format_cart_label`).

## Related
- [[2026-05-03-slice-6-route-dependent-good-selection-reframe]] -- slice-6.0 ships scope; this is one of its edge-case behaviours
- `docs/slice-6-weight-cargo-spec.md` §10 (edge cases including slice-5-save load behaviour)
