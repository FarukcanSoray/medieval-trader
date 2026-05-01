---
title: Idempotent Game.bootstrap() via stashed bootstrap_completed signal
date: 2026-04-30
status: ratified
tags: [decision, architecture, autoload, async, lifecycle]
---

# Idempotent Game.bootstrap() via stashed bootstrap_completed signal

## Decision
`Game.bootstrap()` is idempotent across multiple awaiters via a three-state guard:

```
if world != null:
    return                          # already done
if _bootstrapping:
    await bootstrap_completed       # in flight; park
    return
_bootstrapping = true
await _save_service.load_or_init()
_bootstrapping = false              # cleared before emit so awaiters wake consistent
bootstrap_completed.emit()
```

`bootstrap_completed` is a private implementation-detail signal — not advertised as part of `Game`'s public API. Comment in `game.gd` marks it as such.

## Reasoning
`Game._ready()` calls `bootstrap()` un-awaited (fire-and-forget). Later, `Main._ready()` awaits `Game.bootstrap()` separately. The original guard `if world != null: return` happened to work because every path inside `_save_service.load_or_init()` synchronously assigned `Game.world` before its first `await` — but any future `await` inserted before that assignment would produce a double `_generate_fresh()`, double `write_now()`, and a different `world_seed` than Main awaited.

The fix needs to survive future async insertions. Stashing the in-flight completion as a signal lets the second awaiter park on something concrete; the first awaiter runs the body to completion and emits. Both exit with `Game.world != null` and consistent state.

Flag is cleared **before** emit so awaiters waking from the signal see consistent state and a future early-return inserted between flag-clear and emit can't strand them.

## Alternatives considered
- **(a) `await` in `Game._ready()`** — rejected; couples autoload lifetime to disk I/O latency (matters on web).
- **(b) Drop `bootstrap()` from `Game._ready()`, make Main the sole caller** — rejected; breaks editor F6 contract on individual scenes (slice-spec §2.1 requires bootstrap to be idempotent for F6 entry).
- **(d) `_bootstrapping: bool` flag alone, no signal** — rejected; second caller has nothing to await on. Either busy-wait or get a stale guard.

## Confidence
High. Debugger diagnosed the race as latent-but-fragile, explicitly walked through the alternatives, and named (c) as the only one that survives a future async insertion. Engineer applied; Reviewer ratified with one inline patch (flag-clear-before-emit).

## Source
- `godot/game/game.gd:9-11, 24, 44-58` — the signal, flag, and three-state guard.
- Tier 7 Debugger diagnosis (this session).

## Related
- [[2026-04-29-one-autoload-only-game]] — `Game` is the autoload this guards
- [[2026-04-29-callable-injection-resource-mutators]] — the seam Game owns post-bootstrap
- [[slice-architecture]] — §2.1 (bootstrap idempotency contract)
