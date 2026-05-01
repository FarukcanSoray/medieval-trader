---
title: BeginAnewConfirmDialog as a separate class, not an extension of travel ConfirmDialog
date: 2026-05-01
status: ratified
tags: [decision, architecture, ui, single-responsibility, slice-1]
---

# Begin Anew confirm dialog is a separate class

## Decision
Create a new class `BeginAnewConfirmDialog extends AcceptDialog`, co-located in `godot/ui/death_screen/`. The class body is essentially empty (declaration + `_ready()` that calls `add_cancel_button("Cancel")`); configuration lives in `begin_anew_confirm_dialog.tscn`. The travel `ConfirmDialog` is **not** reused for restart confirmation.

## Reasoning
Three options were weighed:

- **(a) Instance the existing `ConfirmDialog` class inside `death_screen.tscn`, set `dialog_text` / `ok_button_text` / `add_cancel_button` directly from DeathScreen.** Rejected: `ConfirmDialog`'s reason for existing is to encapsulate the travel-confirm contract — its docstring says so, its single public method `prompt(from_id, to_id, cost, ticks)` is shaped for travel, and it carries domain logic (the `gold >= cost` predicate) that is not shared with Begin Anew. Field-poking from DeathScreen would leak `AcceptDialog`'s API surface and produce two callers with two contracts: one calls `prompt()`, one bypasses it. The class becomes a leaky bag.

- **(b) Add a sibling method `ConfirmDialog.prompt_generic(message, ok_text, cancel_text)`.** Rejected: keeps the abstraction but breaks the single-responsibility boundary. Travel-confirm's gold predicate now lives in the same file as a generic message dialog with no predicate. The docstring lies; future readers subclass off the wrong example.

- **(c) New class `BeginAnewConfirmDialog`.** Picked. Same complexity cost as (b) — one small file — but produces two single-purpose dialogs that each match Godot's natural shape. Different concerns, different files. The "more boilerplate" cost in (c) is roughly six lines and is "not boilerplate; it's a named seam." If the class later needs a method (e.g., to centralize the body string), it has a place to live.

Co-located under `ui/death_screen/` rather than `ui/hud/` because it serves death-screen flow only. Travel `ConfirmDialog` stays in `ui/hud/` (HUD-scoped).

## Alternatives considered
- (a) Field-poke the travel ConfirmDialog. Rejected — leaks AcceptDialog API; two callers with conflicting contracts.
- (b) Sibling method on ConfirmDialog. Rejected — breaks single-responsibility seam.

## Confidence
High. The single-responsibility argument is concrete and the cost differential between (b) and (c) is six lines.

## Source
- Designer leaned (a) but flagged for Architect.
- Architect structural pass (this session) pushed back on Designer's lean and picked (c).
- Reviewer pass (this session): ratified.

## Related
- [[godot-idioms-and-anti-patterns]] (skill) — composition and responsibility seams
- [[2026-05-01-restart-requires-confirmation]] — companion decision about the modal's role
- [[2026-05-01-begin-anew-order-rule]] — handler order in DeathScreen that consumes this dialog's signals
