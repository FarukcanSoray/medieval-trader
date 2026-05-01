---
title: Tick duration set to 450ms (first-pass committed value)
date: 2026-05-01
status: ratified
tags: [decision, tuning, tempo, travel-mechanics]
---

# Tick duration set to 450ms (first-pass committed value)

## Decision

Visible travel duration is **450ms per tick** (`const TICK_DURATION_SECONDS: float = 0.45` in `godot/shared/world_rules.gd`). On the 3-node slice with 3/4/5-tick edges, this produces journeys of 1.35s / 1.8s / 2.25s. Replaces the prior `await get_tree().process_frame` per-tick yield, which completed entire journeys in ~12ms.

This is a **first-pass committed value**, not a final tuning. The retune band is roughly 350–600ms; symptoms for retuning are documented in the source comment (`[needs playtesting]`).

## Reasoning

The prior frame-rate yield made travel mechanically real (gold debited at departure, ticks emitted) but perceptually invisible. Director ratified the change with the framing that Pillar 2 ("travel cost bites") was mechanically complete via gold-at-departure but not *legible* — the player couldn't perceive having committed to anything. Critic refined: "Pillar 2 is mechanically complete; what's missing is making the pillar legible." Adding visible duration finishes the perceptual half of the pillar.

Designer picked 450ms within Director's directional bound ("err slow for the first pass; few-hundred-ms to ~1s"):
- Above the perceptual floor (~200ms) so each tick is a discrete countable beat, not a flicker.
- Below the next-larger candidate (600ms), where 5-tick journeys climb to 3s and casual route-switchers start feeling the wait.
- Total wall-clock budget: ~150 ticks/hour of travel time for a careful merchant doing ~50 journeys × ~3 ticks/journey, well under the line where ticks eat decision time.

User playtested the slice and confirmed the duration feels right: visible commit, no drag.

A side benefit (and the proximate trigger for the change): B1's manual runbook iterations are now executable. At 12ms there was no "during travel" window for a tester to refresh inside; at 450ms a 5-tick journey gives 2.25s of refreshable window.

## Alternatives considered

- **Keep the frame-rate yield.** Rejected — Pillar 2 lands as accounting, not friction.
- **300ms.** Rejected as first pass — 3-tick journeys at 0.9s are still in the "did anything happen?" range.
- **600ms+.** Rejected as first pass — wall-clock budget gets uncomfortable for long edges; better to start lower and retune up if "felt commit" is missing.
- **A `TravelTuning` Resource.** Rejected — `WorldRules` already houses `TRAVEL_COST_PER_DISTANCE`; adding one more `const` is the cheapest answer until knobs accumulate.

## Confidence

High. Director ratified, Critic priced as Cheap, Designer specced with a number, Engineer implemented, Reviewer cleared, user playtest-confirmed.

## Source

- This session's full pipeline run (Director → Critic → Designer → Architect → Engineer → Reviewer) on the slow-tick tuning change.
- User playtest confirmation immediately before ratification.

## Related

- [[2026-04-29-travel-controller-yields-per-tick]] — the per-tick yield structure this tunes
- [[2026-04-29-tick-on-player-travel]] — travel as the only tick-advancing action
- [[2026-04-29-travel-cost-at-departure]] — the gold-debit rule that pairs with this for Pillar 2
- [[project-brief]] — Pillar 2 (travel costs bite)
- [[2026-05-01-resume-travel-seam-in-main]] — the resume seam needed to pair with longer ticks (refresh-mid-travel becomes reachable)
- [[2026-05-01-b1-sequencing-web-export-before-tuning]] — the slow-tick subset of A runs as a B1 prerequisite (footnote on that decision)
