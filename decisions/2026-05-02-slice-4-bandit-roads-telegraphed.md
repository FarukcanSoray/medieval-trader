---
title: Bandit-road edges are telegraphed before the player commits to travel
date: 2026-05-02
status: ratified
tags: [decision, slice-4, hud-legibility, pillar-1, encounters]
---

# Bandit-road edges are telegraphed before the player commits to travel

## Decision
Edges flagged `is_bandit_road = true` are surfaced in the travel-confirm dialog as `(bandit road)`. Risk is not hidden from the player at decision time.

## Reasoning
Same legibility commitment slice-3 made with `(plentiful)`/`(scarce)` tags ([[2026-05-02-slice-3-hud-tags-plentiful-scarce]]) — hidden risk converts the route decision from arithmetic to gambling and breaks Pillar 1 ("every trade decision is a math problem the player can win"). Bandit-road tagging is a world-gen output, deterministic from `world_seed`; same edge, same tag, every load. No hidden state.

## Alternatives considered
- **Pure surprise (no tag)** — rejected as direct Pillar 1 violation.

## Confidence
High. Director rooted in Pillar 1; inherits the slice-3 tag-syntax pattern wholesale.

## Source
Director scoping pass; Designer spec §5.1, §7.

## Related
- [[2026-05-02-slice-3-hud-tags-plentiful-scarce]] — the syntax precedent this inherits
- [[2026-05-02-slice-4-cost-preview-with-expected-loss-hint]] — the day-2 numeric layer that completes legibility
