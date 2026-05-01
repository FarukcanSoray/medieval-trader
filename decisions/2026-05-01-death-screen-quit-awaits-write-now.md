---
title: DeathScreen._on_quit_pressed awaits SaveService.write_now before quit
date: 2026-05-01
status: ratified
tags: [decision, persistence, cleanup, slice-1]
---

# DeathScreen quit awaits write_now

## Decision
`DeathScreen._on_quit_pressed` looks up `SaveService` via the documented cross-tree reach (`Game.get_node("SaveService") as SaveService`), null-guards it, awaits `write_now()`, then calls `get_tree().quit()`.

## Reasoning
Slice-spec §5 codifies the contract: every quit awaits `write_now()`. `Main._notification(NOTIFICATION_WM_CLOSE_REQUEST)` and `Main._quit_with_save` both honor this. `DeathScreen._on_quit_pressed` was the only violation — it called `get_tree().quit()` directly.

The current behavior is safe in practice: by the time the quit button is reachable, `SaveService._on_died` has already flushed the death write to disk. But that safety is non-local — it relies on `_on_died` having run successfully *in this session*, with the death write already flushed before scene change. The boot-time terminal-state branch ([[2026-05-01-boot-terminal-state-branch-in-main]]) makes the invariant more brittle: a dead-state boot lands the player on DeathScreen *without* a fresh `write_now()` having happened in this session — the save on disk is from the previous session.

For the slice as it stands, that's still safe (the prior session's death write is durable). But the cost of fixing it is six lines and one `await`; the cost of leaving it is a non-obvious invariant that future code can break silently. Folded in while the file was open.

## Alternatives considered
- **Leave as-is, flag for separate cleanup.** Rejected — the new boot path makes the gap more relevant; the fix is small enough that bundling avoids a follow-up.

## Confidence
Medium. The decision is correct but could plausibly have been split off as a separate slice. It earns its place because the §5 invariant is strict and a future reader shouldn't have to re-justify why the death-screen quit path is the one exception.

## Source
- Architect's secondary recommendation (this session) — flagged the gap and recommended folding in.
- Reviewer pass (this session): ratified.

## Related
- [[2026-05-01-boot-terminal-state-branch-in-main]] — primary change in the same engineering pass; rationale for why the gap matters more now
- [[slice-spec]] §5 — every-quit-awaits-write-now contract
