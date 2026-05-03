---
title: Tooltip clearing pattern in disabled UI branches prevents stale refusal strings
date: 2026-05-03
status: ratified
tags: [decision, slice-6, ui, defensive, pattern]
---

# Tooltip clearing pattern in disabled UI branches prevents stale refusal strings

## Decision
When `node_panel.gd` disables a buy or sell button in a branch where no refusal reason applies (e.g., `node == null` pre-bootstrap, `force_disabled` during travel, or `_set_all_rows_disabled()`), the row's button `tooltip_text` is **explicitly cleared** to `""`. Each refresh owns the tooltip state; stale refusal strings from a prior state cannot bleed through.

## Reasoning
Buy buttons get refusal-reason tooltips per spec §8.2 (gold-only, cart-only, both). When a row enters a fully-disabled state for an *unrelated* reason (e.g., pre-bootstrap nullity, travel-state lock-out), the button's `disabled` flag is set, but the `tooltip_text` field remains untouched -- and shows the *previous* refusal reason. This is misleading: the player sees "Cart full" or "Need 15g" while travelling, when the truth is "you can't buy mid-travel."

Engineer surfaced this during round 2 implementation: spec §8.2 specified the four-case tooltip branch for the active-buy-row case but did not address the inactive branches. The pattern: **explicit `tooltip_text = ""` in every disabled-but-not-for-refusal-reason branch.**

Reviewer confirmed as load-bearing in slice-6.0 review: *"Engineer's judgment call #4 ... explicit tooltip_text = '' in node == null and force_disabled branches: correct and load-bearing. Spec didn't address it; the engineer caught a real stale-string leak."*

The pattern was extended in Engineer round 4 to `_set_all_rows_disabled()` for symmetry (Reviewer's non-blocking suggestion #2), even though that helper currently only fires on empty `_rows` (no-op today). The extension prevents the same bug from re-emerging if a future caller hits the helper post-row-build.

## Generalisable shape
**When a UI element carries state-dependent strings (tooltips, labels, helper text), every code path that mutates the element's enabled-state should also explicitly own the string state.** The default behaviour ("disable but don't touch text") is a stale-state leak waiting to happen.

## Alternatives considered
- **Skip clearing in non-refusal disabled branches** -- rejected (Reviewer-confirmed): leaks stale refusal strings.
- **Set a generic placeholder tooltip ("Unavailable") in non-refusal branches** -- not chosen; empty string is clearer than a generic placeholder that competes with real refusal text.
- **Centralise tooltip clearing in a `_clear_row_state()` helper** -- not chosen at slice-6.0 scope; explicit clears in each branch are visible enough at four total branches. Could be extracted if branch count grows.

## Confidence
Medium-high. Small but real defensive UI pattern; Reviewer confirmed it caught a genuine stale-string leak. The generalisable shape (state-dependent strings need explicit clearing in disabled branches) applies beyond slice-6.

## Source
Engineer's judgment-call flag during round 2 implementation; Reviewer confirmation (slice-6.0 review, judgment call #4 + non-blocking suggestion #2). `godot/ui/hud/node_panel.gd` `_update_row` and `_set_all_rows_disabled` methods.

## Related
- [[godot-idioms-and-anti-patterns]] -- UI state ownership and refresh patterns
- [[2026-05-03-slice-6-cart-full-boundary-gte]] -- adjacent defensive UI judgment from the same Engineer round
