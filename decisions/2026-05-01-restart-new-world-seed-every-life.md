---
title: Restart regenerates a new world seed every life
date: 2026-05-01
status: ratified
tags: [decision, design, procgen, slice-1, restart]
---

# New world seed every life

## Decision
When the player selects "Begin Anew" after dying, the map, prices, and event seeds all regenerate. The world is not reused. Each new life gets a new procgen seed (`int(Time.get_unix_time_from_system())`, matching first-launch behavior).

## Reasoning
Director cited two pillar-level constraints:

1. **Pillar 2 (procgen world, authored vocabulary).** Map, prices, and event seeds regenerate per world; goods catalogue, encounter types, and cost structures stay stable. See [[2026-04-29-procgen-world-authored-vocabulary]]. Reusing the map across lives would contradict the pillar.

2. **Intake resolution 2: mastery transfers as procedural reasoning, not memorized geography.** Re-using the map silently converts the game into a roguelite-with-memorized-route — the player learns "the wool node is north of the cheap-food node" instead of "wool nodes tend to be in farming areas." That is exactly the failure mode the intake resolution rejected.

Practical consequence: the wipe must be total. `SaveService.wipe_and_regenerate()` overwrites `Game.world` and `Game.trader` and writes a fresh save. No preserved fields, no carryover.

## Alternatives considered
- **Reuse the same map, regenerate only prices.** Rejected on both pillar 2 and intake resolution 2. Memorized geography is the failure mode.
- **Persist a graveyard / past-trader's ledger across lives.** Rejected by Director — reopens intake tensions 1 (death rare and earned, not roguelite cadence) and 3 (post-death meta-layer).
- **Inherited gold or any carryover.** Rejected — same tensions.

## Confidence
High. Pillar 2 is unambiguous and the intake resolution names this exact failure mode.

## Source
- Director fit-to-pillar verdict (this session).
- Intake resolution 2 (2026-04-29; memory: `project_director_intake.md`).
- Architect verified `WorldGen.generate(seed, goods)` produces clean defaults (`dead=false`, `death=null`, `history=[]`).
- User playtest confirmed.

## Related
- [[2026-04-29-procgen-world-authored-vocabulary]] — pillar 2
- Intake resolution 2 (memory: `project_director_intake.md`)
- [[2026-05-01-wipe-and-regenerate-ownership]] — implementation of this decision
- [[2026-05-01-restart-entry-on-death-screen]] — companion decision
