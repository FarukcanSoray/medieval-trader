---
date: 2026-05-02
type: session
tags: [session, tick-duration, b1-harness, ascii-precedence]
---

# Tick duration validated, B1 harness implemented

## Goal

Confirm whether `TICK_DURATION_SECONDS = 0.45` was stable under extended playtest (carried from [[2026-05-01-slow-tick-and-resume]]), and run the B1 Engineer round on the invariant-checking harness designed in [[2026-05-01-b1-pipeline]].

## Produced

- [[2026-05-02-tick-duration-450ms-confirmed]] — formal closure of tentative tick duration; retune band now closed.
- `godot/systems/save/invariant_report.gd` — `InvariantReport` Resource with `ok: bool` and `violations: Array[String]`.
- `godot/systems/save/save_invariant_checker.gd` — `SaveInvariantChecker` (RefCounted), static `check(trader, world) -> InvariantReport` running predicates P1-P6 with visible PASS/FAIL console output.
- Modified `godot/game/game.gd` — added `_save_corruption_notice_pending`, harness invocation in `bootstrap()`, debug-vs-release branching (assert vs wipe), public `consume_save_corruption_notice()` getter.
- Modified `godot/main.gd` — corruption toast consumption block in `_ready()`.
- Modified `godot/ui/hud/status_bar.gd` — `CORRUPTION_TOAST_SECONDS`, `CORRUPTION_TOAST_TEXT` consts and `show_corruption_toast()` method.
- Modified `godot/ui/hud/status_bar.tscn` — hidden `CorruptionToast` Label on right edge.

## Decisions

- [[2026-05-02-tick-duration-450ms-confirmed]]
- [[2026-05-02-ascii-rule-overrides-copy-decisions]] — UI text precedence: ASCII-only rule from [[CLAUDE.md]] overrides copy decisions (e.g. em-dashes in [[2026-05-01-save-corruption-regenerate-release-build]]) when they conflict.

## Open threads

- **B1 web-deployer round pending** — harness code complete; export preset, COOP/COEP headers, and browser smoke-test against `docs/b1-test-protocol.md` still needed per [[2026-05-01-b1-pipeline]].
- **`TRAVEL_COST_PER_DISTANCE = 3` `[needs playtesting]`** — only tick duration validated this session.
- **Runbook prose refresh** — `docs/b1-test-protocol.md` §5/§7 use Unicode `->` but harness checks ASCII `->`.
- **Unicode ellipsis at `godot/ui/hud/node_panel.gd:47`** — `"Travelling..."` flagged in [[2026-05-01-slow-tick-and-resume]].
- **Travel confirm-modal UX** — ConfirmDialog lacks Cancel button per [[2026-05-01-boot-fix-and-begin-anew]] and [[2026-05-01-slow-tick-and-resume]].
- **Tier 7 deferred markers** — [[2026-04-30-tier7-deferred-followups]].

## Links

- [[CLAUDE.md]] — ASCII UI rule and standing workflow.
- [[2026-05-01-b1-pipeline]] — harness design and test protocol reference.
- [[2026-05-01-slow-tick-and-resume]] — prior session carrying tick duration and open threads.
- [[2026-05-01-save-corruption-regenerate-release-build]] — decision requiring ASCII precedence clarification.

## Notes

The most instructive artifact this session was the precedence rule between standing rules (ASCII-only UI text) and ratified decisions (em-dash copy): it surfaced not from design speculation but from Engineer implementation friction. This suggests that precedence rules between standing rules and copy decisions are best captured at the point of conflict, not anticipated upfront. The rule is now in [[2026-05-02-ascii-rule-overrides-copy-decisions]] with a cross-reference footnote on [[2026-05-01-save-corruption-regenerate-release-build]].
