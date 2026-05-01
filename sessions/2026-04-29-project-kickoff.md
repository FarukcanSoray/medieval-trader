---
date: 2026-04-29
type: session
tags: [session, kickoff, pipeline]
---

# Project kickoff: Director → Critic → Designer pipeline

## Goal

Run the full opening pipeline (Director → Critic → Designer) in one session to establish the project brief, scope boundaries, and vertical slice specification.

## Produced

- [[project-brief]] — kernel, player fantasy, three pillars, scope frame, four tensions resolved during intake.
- [[slice-spec]] — vertical slice spec: 3-node loop, save format contract, integration touch points, tuning ranges, edge cases.

## Decisions

**Intake answers (foundational):**
- [[2026-04-29-fantasy-careful-merchant]]
- [[2026-04-29-scope-small-complete-game]]
- [[2026-04-29-open-questions-combat-procgen-meta]]
- [[2026-04-29-no-win-condition]]

**Director's tension resolutions (brief-level):**
- [[2026-04-29-death-rare-and-earned]]
- [[2026-04-29-procgen-world-authored-vocabulary]]
- [[2026-04-29-one-of-each-system]]

**Process — the most consequential call of the session:**
- [[2026-04-29-no-cuts-slice-first]] — full design scope holds; build via slice-first with DecisionScribe + SessionSummarizer carrying state across sessions.

**Slice architecture:**
- [[2026-04-29-save-format-first]]
- [[2026-04-29-signal-based-integration]]
- [[2026-04-29-deterministic-price-drift]]
- [[2026-04-29-travel-cost-at-departure]]
- [[2026-04-29-tick-on-player-travel]]

**Slice ratifications:**
- [[2026-04-29-slice-three-nodes]]
- [[2026-04-29-slice-let-asymmetry-ride]]
- [[2026-04-29-slice-zero-encounters]]
- [[2026-04-29-slice-one-death-cause-bankruptcy]]

## Open threads

- **Scene Architect handoff** is the next pipeline step. Architect's job per `slice-spec` §11: take the integration table in §9 and decide whether `TraderState` / `WorldState` live as autoloads or node-tree services, then confirm signal routing.
- **Brief timeline drift.** `project-brief.md` says "3–6 months evening work" but with full scope held, the realistic shape is 9–12 months per the Scope Critic. The brief is unchanged; flag for the next Director pass.
- **Death-cause label** open question: is "bankruptcy" distinct from "stranded with insufficient gold" on the death screen, or one label? Director call, deferred.
- **Tuning numbers** in `slice-spec` §6 are all `[needs playtesting]` — set during/after first slice run, not from desk.

## Notes

The session's load-bearing call was [[2026-04-29-no-cuts-slice-first]]. It moves the "month 3 sinkhole" risk (integration tax between AI-generated systems) from a deferred surprise to a front-loaded constraint: the slice spec's §9 integration table is now exhaustive and signal-based by design, and the save format is a binding contract before any system is built. The bet is that this discipline keeps the longer timeline (full scope) manageable.
