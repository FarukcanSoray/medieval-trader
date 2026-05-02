---
title: Cost-preview shows `(+0..Ng, bandit road, ~P%)` -- Pillar 1 protection
date: 2026-05-02
status: ratified
tags: [decision, slice-4, hud-legibility, pillar-1, encounters]
---

# Cost-preview shows `(+0..Ng, bandit road, ~P%)` -- Pillar 1 protection

## Decision
The travel-confirm dialog renders bandit-road costs as:
```
Travel Hillfarm -> Rivertown. Cost: 12g (+0..30g, bandit road, ~30%). Time: 4 ticks.
```
Plain edges render as the slice-3 string verbatim:
```
Travel Hillfarm -> Rivertown. Cost: 12g. Time: 4 ticks.
```

Three numbers surface on bandit edges: base cost (already there), the **upper bound of possible additional loss** (`+0..Ng` where N = `EncounterResolver.preview_loss_max(trader_gold)`), and **approximate probability** (`~P%` where P = `roundi(BANDIT_ROAD_PROBABILITY * 100)`).

## Reasoning
Critic flagged this as the slice's biggest design risk: "tag without numbers" is a Pillar 1 violation under cover of legibility. Slice-3's `(plentiful)`/`(scarce)` tags worked because the *price* was always visible — player did the expected-cost math themselves. For encounters, the *outcome* is hidden until arrival, so without bounds + probability the player is guessing a probability-weighted average. That's gambling, not arbitrage.

Surfacing `+0..Ng` (the actual ceiling, computed live from current gold) lets the player compute expected cost as `~0.30 * (loss_min + loss_max)/2`. That's a math problem they can win.

## Alternatives considered
- **Tag only, no numbers** (Director's first frame) — rejected by Critic as Pillar 1 violation.
- **Show full loss range `(+0..30g)` and probability `~30%`** (chosen) — gives expected-cost computability.
- **Show expected cost directly (`~+5g`)** — rejected; pre-chews the math, removes player agency in reasoning.

## Confidence
High. Critic-flagged, Designer-spec'd, Architect-implemented.

## Source
Critic stress-test verdict; Designer spec §5.5; Architect Call 3 (signature ratification).

## Related
- [[2026-05-02-slice-4-bandit-roads-telegraphed]] — the categorical tag this decision adds numbers to
- [[2026-05-02-slice-3-hud-source-sink-syntax-no-numbers]] — slice-3's tags-without-numbers stance, contrasted: slice-3 had a visible underlying observable (price), slice-4 doesn't
