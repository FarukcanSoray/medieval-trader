---
title: Loaded saves always win; --seed=N applies only to fresh generation
date: 2026-05-02
status: ratified
tags: [decision, save-system, cli, slice-2]
---

# Loaded saves always win; --seed=N applies only to fresh generation

## Decision

The CLI argument `--seed=N` is parsed in `Main._ready()` from `OS.get_cmdline_user_args()` and threaded as `seed_override: int = -1` through `Game.bootstrap()` -> `SaveService.load_or_init()` -> `SaveService._generate_fresh()`.

**Behavioural rule (binding):** if a save exists and parses, it loads. The seed override is **ignored**. The seed override applies **only** when no save exists and a fresh world must be generated (or after a corruption-driven regeneration via `wipe_and_regenerate`).

`-1` is the no-override sentinel. Negative seed values from the CLI parse successfully but emit `push_warning` and fall back to wall-clock — slice-2's CLI grammar forbids negative seeds.

## Reasoning

Slice-1's contract is that saves are deterministic and authoritative — the world is what's in the JSON. Letting `--seed=N` reroll an existing save would silently rewrite the player's world, which is a footgun and a reproducibility bug (the seed in the save no longer describes the world that was loaded).

Treating `--seed=N` as a developer tool for **bootstrapping fresh worlds** matches the actual use case (deleted save, want a specific test world) and preserves the load-path's identity-with-the-save. Players never see this; it's a debug surface.

## Alternatives considered

- **`--seed=N` overrides loaded saves too.** Rejected. Breaks "the save is the world" contract; makes reproducibility brittle.
- **No CLI seed at all; require manual save deletion + relaunch each time.** Rejected. CLI override is the cheapest possible developer ergonomics for slice-2.5's catalog work (run with 20 different seeds, capture log lines).
- **Parse `--seed` inside `Game` (autoload) instead of `Main`.** Rejected by Architect. Keeps `Game` ignorant of `OS.get_cmdline_user_args()` and keeps the boot path testable.

## Confidence

High. Architect declared this as binding; Engineer implemented; Reviewer flagged the negative-seed silent-drop, Engineer added `push_warning` in fix loop.

## Source

This session (2026-05-02 PM). Architect handoff §4 CLI seed flow; Reviewer non-blocker #5; Engineer fix loop.

## Related

- [[2026-04-29-save-format-first]]
- [[2026-05-02-slice-2-store-effective-seed-as-world-seed]]
- [[slice-architecture]]
