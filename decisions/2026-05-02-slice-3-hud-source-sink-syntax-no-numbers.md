---
title: HUD shows tags as `(source)` / `(sink)`; bias number is not exposed
date: 2026-05-02
status: amended
tags: [decision, slice-3, hud-legibility, pedagogy, amended]
---

> **Amended 2026-05-02 same day:** the `(source)` / `(sink)` word choice was replaced with `(plentiful)` / `(scarce)` after first playtest -- see [[2026-05-02-slice-3-hud-tags-plentiful-scarce]]. The framework below (ASCII parens, lowercase single word, no exposed bias number) still holds; only the words changed.

# HUD shows tags as `(source)` / `(sink)`; bias number is not exposed

## Decision
Node panel renders producer/consumer tags as `(source)` and `(sink)` -- ASCII parens, lowercase, single word -- appended to the price label (e.g., `wool 8g (source)`). The numeric bias value is **not** exposed in the UI.

## Reasoning
Exposing the bias number invites the player to compute `base_price * (1 + bias)` themselves -- one inferential step the slice doesn't earn. Tags name the abstraction; numbers would replace the abstraction with arithmetic. If playtesting shows the tag isn't legible enough, escalate to numbers in slice-3.x.

Rejected alternative syntaxes: `(wool +)` (cryptic), `[wool source]` (square brackets read as UI controls). ASCII-only per project rule.

## Alternatives considered
- Expose the bias number alongside the tag -- rejected as over-explaining the mechanic before it has earned the player's attention.

## Confidence
High. Designer named the specific pedagogical reason.

## Source
Designer spec §7.

## Related
- [[2026-05-02-slice-3-tags-as-label-not-driver]]
- [[2026-05-02-ascii-rule-overrides-copy-decisions]]
- [[2026-05-01-ascii-arrows-in-ui-strings]]
