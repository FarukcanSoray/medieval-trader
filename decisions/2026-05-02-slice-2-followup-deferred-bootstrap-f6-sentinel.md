---
title: Deferred-world bootstrap with F6 sentinel; Main is the sole normal bootstrap caller
date: 2026-05-02
status: ratified
tags: [decision, architecture, autoload, lifecycle, slice-2-followup]
supersedes: [2026-04-30-idempotent-bootstrap-signal]
---

# Deferred-world bootstrap with F6 sentinel

## Decision

`Game._ready()` no longer calls `bootstrap()`. Instead it schedules `call_deferred("_f6_fallback_bootstrap_if_needed")`. The sentinel runs on the next idle frame and:

1. Returns if `_bootstrapping` is true.
2. Returns if `world != null`.
3. Returns if `get_tree().current_scene is Main`.
4. Otherwise self-bootstraps with the fallback rect.

`Main._ready` becomes the sole normal caller of `bootstrap(seed_override, real_rect)`, where `real_rect` comes from `$HUD/MapPanel.size`.

The three-state idempotency guard inside `bootstrap()` itself (`world != null` -> return; `_bootstrapping` -> `await bootstrap_completed`; else run body) stays exactly as ratified in `[[2026-04-30-idempotent-bootstrap-signal]]`.

## Reasoning

The previously-ratified guard treated `Game.world != null` as "bootstrap is done." But the autoload's first un-awaited `bootstrap()` ran synchronously through `WorldGen` with whatever rect was available at autoload time -- which was nothing, because only `Main` knows `MapPanel.size`. The autoload's call locked in the fallback rect (640x380); `Main`'s later call with the real rect (468x664 at 1280x720) early-returned on `world != null` and the real rect was discarded. Nodes overflowed `MapPanel`'s actual width by ~72px, re-overlapping `TravelPanel`. The same race silently dropped `--seed=N` overrides on some paths.

Splitting "create services" (autoload-time, no inputs needed) from "generate world" (caller-time, needs the rect) reflects what actually changed: world generation acquired an input the autoload doesn't know. The autoload's job is *prepare the singleton's services and listeners*; the world is generation output.

The F6 sentinel preserves the editor F6 contract that was the original reason alternative (b) "drop bootstrap from Game._ready, make Main sole caller" was rejected in `[[2026-04-30-idempotent-bootstrap-signal]]`. Isolated F6 scenes get a viable `Game.world` on the next idle frame; main-driven boot has already populated world by then and the sentinel no-ops.

## Alternatives considered

- **Rect-aware re-bootstrap** (second call with new rect mutates `Game.world` in place). Rejected: "creates two world-state lifecycles, makes `world != null` a property nobody can rely on." Mutating world after listeners connected is the worst of both worlds.
- **Normalised 0..1 positions** (so generation is rect-independent). Rejected for the same reasons in `[[2026-05-02-slice-2-followup-mappanel-owns-map-rect]]`. The new boot-order constraint is solved more cheaply by separating bootstrap from world-creation.

## Supersedes

Partially supersedes `[[2026-04-30-idempotent-bootstrap-signal]]`:

- **Stays valid:** the three-state guard inside `bootstrap()` (`world != null`, `_bootstrapping`, `bootstrap_completed` signal). Still load-bearing for Begin Anew round-trip and any future double-await.
- **Reverses:** the premise "`Game._ready()` calls `bootstrap()` un-awaited (fire-and-forget)." That's no longer true. The previously-rejected alternative (b) "Drop `bootstrap()` from `Game._ready()`, make Main the sole caller" becomes picked, with the F6 sentinel covering the F6 contract.

## Confidence

High. Architect explicitly walked the supersession; Reviewer verified guard order in the sentinel (`_bootstrapping` first, then `world != null`, then `current_scene is Main` -- only `_bootstrapping` and `world != null` don't commute, because there's a window during `await load_or_init` where `_bootstrapping == true` and `world == null`). Headless `--check-only` verified the no-Main path; user playtest confirmed Main-driven path.

## Source

Slice-2 follow-up session (2026-05-02). Architect round 2 §3-5; Engineer round 2; Reviewer round 1 + round 2.

## Related

- [[2026-04-30-idempotent-bootstrap-signal]] -- partially superseded; three-state guard preserved
- [[2026-04-29-one-autoload-only-game]]
- [[2026-05-02-slice-2-followup-mappanel-owns-map-rect]] -- the structural call that motivated this reconciliation
- [[2026-05-02-slice-2-followup-begin-anew-delete-save]] -- Begin Anew flow change downstream of this
- [[2026-05-02-slice-2-loaded-saves-win-cli-seed-fresh-only]] -- silent `--seed` race goes away as a side effect (not formally superseded)
