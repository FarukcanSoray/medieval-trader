---
title: Tier 7 deferred follow-ups (final-statement comment, _quitting guard, typed save_service accessor)
date: 2026-04-30
status: ratified
tags: [decision, deferred, tier-7, post-slice]
---

# Tier 7 deferred follow-ups (final-statement comment, _quitting guard, typed save_service accessor)

## Decision
Three small Tier 7 hardening items surfaced by the Tier 7 Debugger and Code Reviewer are explicitly **deferred to a post-slice cleanup pass**, not applied in the slice-shipping round:

1. **Final-statement comment on `change_scene_to_packed` in `_on_died`.** The call must remain the final statement of `_on_died` (Main is the scene root being replaced; any code after it would run on a dying node). Current code is correct; only a comment to lock in the constraint is missing.
2. **`_quitting: bool` re-entry guard on `_quit_with_save()`.** Hardens against double X-click during HTML5 IndexedDB flush — without the guard, two `write_now()` coroutines can race on the same `user://save.json` handle. Same lifecycle-await family as the bootstrap idempotency (`[[2026-04-30-idempotent-bootstrap-signal]]`).
3. **Typed `save_service` accessor on `Game`.** Currently Main reaches `_save_service()` via `Game.get_node("SaveService") as SaveService`. A typed property on `Game` would eliminate the cast and the path-string dependency.

## Reasoning
None of the three blocks first playtest:
- (1) is a comment, not a behavioural change.
- (2) is a hardening for a corner case (double-close) that requires deliberate user behaviour to trigger.
- (3) is API ergonomics; the current `get_node` cast works.

The Reviewer marked all three as out-of-scope for the slice-shipping round. The user's slice-first stance ([[2026-04-29-no-cuts-slice-first]]) favours archiving deferred work via decision-log + session-summary rather than expanding the round.

Logged so they're not lost. Pick up in a post-playtest cleanup pass once tuning numbers and the two `[verify on Tier 7]` markers (hash byte-stability, FIFO resume order) have been exercised.

## Alternatives considered
- **Apply all three inline this round** — rejected; expands the slice-shipping round past the Reviewer's scope and risks introducing fresh issues at the moment of first runnability.
- **Drop them entirely** — rejected; (2) is a real reliability concern on HTML5, (3) is a useful seam for future systems that need SaveService access.

## Confidence
Medium. Each item is small and well-specified, but their priority depends on what playtest surfaces. (2) becomes high-priority if the X-click race is observed; (1) and (3) are low-priority in any case.

## Source
- Tier 7 Code Reviewer flag (this session).
- Tier 7 Debugger spot-check (this session).
- `godot/main.gd` — current state of `_on_died`, `_quit_with_save`, `_save_service()`.

## Related
- [[2026-04-30-idempotent-bootstrap-signal]] — same lifecycle-await family as item (2)
- [[2026-04-29-no-cuts-slice-first]] — the stance under which deferral is the right move
- [[slice-architecture]] — §5 (save lifecycle, the quit-await flow that item 2 hardens)
