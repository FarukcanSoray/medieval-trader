---
title: Store effective_seed (post-bump) as world_seed in JSON
date: 2026-05-02
status: ratified
tags: [decision, save-system, reproducibility, slice-2]
---

# Store effective_seed (post-bump) as world_seed in JSON

## Decision

When the procgen generator's seed-bump retry loop completes, the **effective seed** (the seed value that actually produced the accepted world, after any bumps) is stored as `world_seed` in the JSON save. The user-supplied input seed (e.g. `--seed=12345`) is **not** stored if it differs from the effective seed.

Initial price seeding inside the same generation also uses `effective_seed`. RNG domain separation (`hash([seed, "place"])` vs `hash([seed, "names"])` vs `hash([seed, 0, node_id, good.id])`) preserves stream independence within a generation.

The per-generation log line surfaces both seeds when they differ: `worldgen: seed=12345 effective=12347 nodes=7 ...`.

## Reasoning

If a user reports a bad world from `--seed=12345` and the generator actually used `12347` due to placement-failure bumps, the saved JSON should record `12347` so re-running `--seed=12347` recreates **exactly that world**. Recording `12345` instead means the input-seed-to-world mapping is non-deterministic across runs (because the bump count depends on RNG state we don't otherwise control), which breaks reproducibility for slice-2.5 catalog work.

This is a subtle invariant: "the seed in the save file is the seed that built the world, not the seed the user typed." Worth its own decision because it's the kind of thing a future engineer would silently invert during a refactor.

## Alternatives considered

- **Store the user's input seed.** Rejected. Reproducibility breaks: same input seed produces different worlds across runs once placement-failure bumps fire.
- **Store both seeds (input and effective) in the JSON.** Rejected. Schema bump for a debug-only field; slice-2's schema discipline is no-bump.

## Confidence

Medium. The reasoning is sound and the Architect recommended it explicitly, but the conversation was thin on this point — Engineer ratified during implementation. If slice-2.5 catalog work surfaces a need for the input seed too, revisit.

## Source

This session (2026-05-02 PM). Architect handoff §5 + Engineer "deviations from spec" item 1.

## Related

- [[2026-05-02-slice-2-loaded-saves-win-cli-seed-fresh-only]]
- [[2026-04-29-deterministic-price-drift]]
- [[2026-05-02-slice-2-log-line-only-no-dump-catalog]]
