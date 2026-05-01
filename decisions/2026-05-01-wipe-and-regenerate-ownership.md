---
title: SaveService owns wipe_and_regenerate; _generate_fresh stays private
date: 2026-05-01
status: ratified
tags: [decision, architecture, persistence, encapsulation, slice-1]
---

# wipe_and_regenerate ownership

## Decision
`SaveService` owns a public async method `wipe_and_regenerate() -> void` that handles the full state-reset lifecycle: it composes the existing private `_generate_fresh()` (which repopulates `Game.world` and `Game.trader`) with `await write_now()` (which flushes via the IndexedDB `process_frame` await), then sets `_dirty = false`.

The helper `_generate_fresh()` remains underscore-prefixed and private. It is called only from inside `SaveService` (`load_or_init` corruption-recovery branches and `wipe_and_regenerate`).

## Reasoning
Three potential owners for the wipe-and-regenerate logic were weighed:

- **`Game` autoload.** Rejected: `Game` doesn't own persistence. It would have to delegate to `SaveService` anyway; the delegation adds nothing.
- **`WorldGen`.** Rejected: `WorldGen` is one-shot world construction. It doesn't know about `Game.trader`, `Game.world`, or `_dirty`.
- **`DeathScreen`.** Rejected: would require leaking `SaveService`'s private `_generate_fresh()` API; DeathScreen would also own ordering rules that belong with the persistence service.

`SaveService` already composes `_generate_fresh()` + `write_now()` in four corruption-recovery branches inside `load_or_init()`. `wipe_and_regenerate()` is the same composition, made explicit and public.

The privacy of `_generate_fresh()` is load-bearing: it enforces the seam. Regen always routes through `wipe_and_regenerate()`, which is the only caller that knows the full lifecycle (state replace → flush → dirty clear). Promoting `_generate_fresh()` to public would invite a future caller to bypass the wrapper and manage the lifecycle piecemeal — breaking the invariant that any regen leaves `_dirty == false` and a freshly written save on disk.

The `_dirty = false` placement is *after* the await (opposite of `_on_tick_advanced`'s clear-before-await pattern) for a non-obvious reason: in regen, no in-flight `state_dirty` can fire — Trade and Travel live in the previous scene, which is being torn down. The freshly written state is canonical. A comment in the source captures this so a future reader doesn't "fix" it to match the other pattern.

## Alternatives considered
- **`Game.wipe_and_regenerate()`** delegating to SaveService. Rejected — pure delegation with no added value.
- **Free function on `WorldGen`.** Rejected — wrong responsibility scope.
- **DeathScreen calls `_generate_fresh()` directly.** Rejected — leaks private API; spreads ordering rules.
- **`_generate_fresh()` promoted to public `generate_fresh()`.** Rejected — invites bypass of the lifecycle wrapper.

## Confidence
High. Responsibility argument is clean; the privacy seam is a real invariant guard, not stylistic preference.

## Source
- Designer spec named `wipe_and_regenerate()` as the seam (this session).
- Architect structural pass (this session): confirmed placement and `_generate_fresh()` privacy.
- Reviewer pass (this session): ratified.

## Related
- [[2026-05-01-restart-new-world-seed-every-life]] — what this method implements
- [[2026-05-01-begin-anew-order-rule]] — caller-side ordering that depends on this method's contract
- [[slice-spec]] §3 — IndexedDB flush requirement (the inner `await get_tree().process_frame` in `write_now`)
