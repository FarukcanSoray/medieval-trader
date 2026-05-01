---
title: Per-generation log line is the only slice-2.5 instrumentation; no dump_catalog helper
date: 2026-05-02
status: ratified
tags: [decision, instrumentation, slice-2, slice-2-5]
---

# Per-generation log line is the only slice-2.5 instrumentation; no dump_catalog helper

## Decision

Every successful run of `WorldGen.generate()` emits **one `print()` line** with this format:

```
worldgen: seed=N nodes=K edges=M starting=<id> min_edge_dist=d max_edge_dist=D
```

If the effective seed differs from the user-supplied seed (placement-failure bump fired), the line includes both: `worldgen: seed=12345 effective=12347 nodes=7 ...`.

**No `WorldGen.dump_catalog(seed_range: Array[int]) -> Array[Dictionary]` helper is implemented.** Slice-2.5 catalog work runs the game against ~20 seeds, captures stdout, and inspects the log lines. No batch API.

## Reasoning

Slice-2.5's only data need is "show me 20 worlds and their summary stats." A single log line per generation covers it. A batch helper would require:

- Calling `WorldGen.generate()` outside the normal boot path (no autoload, no SaveService, no Game)
- Threading 20 seeds through some entry point (CLI flag? In-editor tool button?)
- Aggregating the dictionaries (file dump? In-memory?)

All of which is engineering effort against a use case that the Architect can serve with one line of `print()`. Premature tooling.

If slice-2.5 inspection reveals that 20 worlds isn't enough — say, we need 200 to find a degenerate edge case — the helper earns its keep at that point. Until then, the log line is sufficient.

## Alternatives considered

- **Implement `WorldGen.dump_catalog(seed_range)` static helper.** Rejected. Architect explicitly out-of-scope; Designer agreed.
- **Structured log output (JSON-per-line).** Rejected. Plain text is human-readable for 20 entries; structured parse would be trivial in slice-2.5 if needed.
- **No log line; add a debug overlay in StatusBar.** Rejected. StatusBar already shows the seed; debug overlay adds UI surface for an inspection task that lives outside gameplay.

## Confidence

High. Architect ruled explicitly; Engineer implemented exactly; not contested.

## Source

This session (2026-05-02 PM). Architect handoff §0 decision 5 + §5 emission contract.

## Related

- [[2026-05-02-slice-2-5-named-tuning-pass]]
- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]]
- [[2026-05-02-slice-2-store-effective-seed-as-world-seed]]
