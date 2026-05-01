---
title: Save-invariant violation in release builds regenerates the world; toast says "Save was corrupted — beginning anew"
date: 2026-05-01
status: ratified
tags: [decision, save-system, player-experience, b1]
---

# Save-invariant violation in release builds regenerates the world; toast says "Save was corrupted — beginning anew"

## Decision

When `SaveInvariantChecker` reports a violation:

- **Debug build**: `push_warning` per violation, then `assert(false, ...)` halts the frame so the corruption is not missed.
- **Release build**: `push_warning` per violation, then call existing `SaveService.wipe_and_regenerate()` to discard the save and generate a fresh world. Set a one-shot flag (`Game._save_corruption_notice_pending`) consumed by `Main` via `Game.consume_save_corruption_notice() -> bool`. `Main` triggers a transient toast on the HUD `StatusBar` with the text: **"Save was corrupted — beginning anew."**

The branching site is inside `Game.bootstrap()` itself — one place, not scattered.

## Reasoning

Director overruled Architect's warn-only lean. The argument: warn-only is functionally indistinguishable from not having the harness — Pillar 3's "choices accumulate" only means anything if the state recording those choices is trustworthy, and an invariant violation means it isn't. Letting a player keep playing on a violated save preserves the appearance of a run while hollowing out the invariant the harness exists to defend.

Treating violation the same as schema-version mismatch per slice-spec §8 ("Save discarded, new world generated. Slice doesn't do migrations.") aligns the release-build behavior with the slice's existing posture for unrecoverable saves. The player-facing notice prevents the wipe from feeling like a silent nuke.

The toast copy follows two existing precedents:
- Past-participle tone ("corrupted" sits with "stranded", "slain", "taken by age"): single concrete past-participle states, no clinical nouns.
- Reuse of the "Begin Anew" verb from death-screen restart, so the player learns one vocabulary across death and corruption recovery.

The two-clause shape (cause, action) tells the player what happened and what's happening next in one read.

The reuse of `SaveService.wipe_and_regenerate()` requires no adaptation — that method already does `_generate_fresh()` + `write_now()` + `_dirty = false` atomically.

## Alternatives considered

- **Warn-only in release** (Architect's lean): rejected. Functionally equivalent to no harness. Director's framing: "preserves the appearance of a run while hollowing out the invariant Pillar 2 depends on."
- **Halt in release** (no regeneration): rejected. Locks the player out of their game; worse player experience than wipe-and-restart.
- **Different copy** (e.g. "Save data error", "World reset"): rejected. Past-participle tone register and "Begin Anew" verb already established; using different vocabulary teaches the player two grammars instead of one.

## Confidence

High. Director's call was definitive on the warn-only override; toast copy was ratified against established precedents.

## Source

- Director's second ruling (release-build violation behavior, overruling Architect's warn-only lean).
- Director's toast copy ratification.

## Related

- [[2026-05-01-restart-label-begin-anew]] — verb precedent
- [[2026-04-29-death-cause-stranded]] — past-participle tone precedent
- [[2026-05-01-save-invariant-checker-harness-no-autoload]] — the harness whose failures trigger this path
- [[slice-spec]] — §8 schema-mismatch posture being reused here

## Footnote — 2026-05-02 ASCII downgrade

The toast text as ratified above contains an em-dash. Per [[2026-05-02-ascii-rule-overrides-copy-decisions]], the implementation in `godot/ui/hud/status_bar.gd` ships the ASCII substitute `"Save was corrupted -- beginning anew"` because Godot's HTML5 default font has no em-dash glyph. The em-dash form above is the canonical copy and becomes correct again if/when a custom font with em-dash coverage is bundled into the project theme.
