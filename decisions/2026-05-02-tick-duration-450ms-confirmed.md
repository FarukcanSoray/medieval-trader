---
title: Tick duration 450ms confirmed after extended playtest
date: 2026-05-02
status: ratified
tags: [decision, tuning, tempo, travel-mechanics, confirmation]
---

# Tick duration 450ms confirmed after extended playtest

## Decision

`TICK_DURATION_SECONDS = 0.45` in `godot/shared/world_rules.gd` is no longer "first pass" — it is the committed tuning value. The `[needs playtesting]` tag on this constant has been removed; the source comment now records the validation date (2026-05-02).

The retune band (350-600ms) is closed for now. If symptoms surface later (drag on long edges, or commit feeling weak on short ones) the band can be reopened, but the default position shifts from "tentative, expect retune" to "settled, retune only on evidence".

## Reasoning

Original first-pass landing in [[2026-05-01-tick-duration-450ms-first-pass]] was explicit that the slice playtest was short and the band stayed open. User has now run an extended playtest at 450ms and reports it feels right — no drag, no "did anything happen?" The two failure modes the band was hedging against did not materialize.

This does not promote `TICK_DURATION_SECONDS` to a final tuning forever; it promotes it to "default position is keep, change requires evidence." Same status as `TRAVEL_COST_PER_DISTANCE = 3` would reach after its own playtest pass.

`TRAVEL_COST_PER_DISTANCE` retains its `[needs playtesting]` tag — only the tick duration was validated this session.

## Alternatives considered

- **Leave the `[needs playtesting]` tag in place indefinitely.** Rejected — the tag's purpose is to flag tentative values awaiting validation; once validated, leaving it on muddies the signal for genuinely tentative constants like `TRAVEL_COST_PER_DISTANCE`.
- **Promote silently (edit the comment without a decision entry).** Rejected — the original "first pass" decision is explicit, so its closure should be explicit too. A pointer decision keeps the trail readable.

## Confidence

High. User playtest-confirmed; no implementation change, only a status promotion and a comment edit.

## Source

- User confirmation in conversation on 2026-05-02 ("I did the extended playtest it is fine").
- Comment edit at `godot/shared/world_rules.gd:15` removing `[needs playtesting]` tag and recording the validation date.

## Related

- [[2026-05-01-tick-duration-450ms-first-pass]] — the first-pass decision this confirms
- [[2026-04-29-travel-controller-yields-per-tick]] — the per-tick yield structure this tunes
- [[project-brief]] — Pillar 2 (travel costs bite)
