---
title: ASCII arrows (->) in web-visible UI strings, not Unicode →
date: 2026-05-01
status: ratified
tags: [decision, web-export, ui, fonts]
---

# ASCII arrows in web-visible UI strings

## Decision

Replace the Unicode right-arrow `→` (U+2192) with ASCII `->` in every web-visible UI string. Four spots were touched:

- `godot/ui/hud/confirm_dialog.gd` — runtime travel-confirm `dialog_text`
- `godot/ui/hud/confirm_dialog.tscn` — editor placeholder `dialog_text`
- `godot/ui/hud/status_bar.gd` — "Travelling A -> B (N ticks left)"
- `godot/travel/travel_controller.gd` — death-screen ledger `entry.detail`

Comments and prose containing `→` were left alone — they don't render at runtime. The hedging comment that previously sat next to the ledger arrow ("Unicode arrow reads cleanly in the death-screen ledger; ASCII would also work") was deleted, since after the swap nothing non-obvious remains to explain.

## Reasoning

Web playtest showed the arrow rendering as a missing-glyph tofu box inside the travel-confirm popup. Godot 4.5's HTML5 export ships no font with `→` coverage, and the project carries no custom theme/font (no `font`/`theme` entries in `project.godot`).

Slice-spec §7 prescribes the dialog text as `"Travel A → B. Cost: 12g. Time: 4 ticks."` but the arrow there is purely a visual separator — no rule, system, or save format depends on it. ASCII `->` carries identical meaning at zero engine, asset, or theme cost.

The tofu also affected two other surfaces the bug report didn't mention but a single grep surfaced — the in-travel status bar text and the death-screen ledger detail. Fixing those in the same pass closed the class of bug rather than just the reported instance.

## Alternatives considered

- **Bundle a Unicode-complete font and theme it in.** Rejected — adds export weight, a theme dependency, and a font-licensing decision in exchange for one decorative glyph. The web-export size budget hasn't been pressured yet; that's no reason to spend it on something a hyphen-greater-than handles.
- **Leave the arrow and rely on the browser's font fallback.** Rejected — Godot's canvas renders text itself, browser-installed fonts are not a fallback, and the tofu is what we'd ship.

## Confidence

High. The fix is mechanical, the rationale is concrete, and the user confirmed the popup renders correctly post-swap.

## Source

- Engineer fix in this session, on the Engineer's own code (no Debugger or Architect handoff per project workflow rules for own-code bugs).
- Confirmed by user playtest in the web build immediately before ratification.

## Related

- [[b1-test-protocol]] — the HTML5 smoke-test protocol that should be expected to catch glyph regressions of this shape
- [[CLAUDE.md]] — standing rule "UI text strings stay ASCII-only until a custom font ships" added in the same session, generalizing this decision
