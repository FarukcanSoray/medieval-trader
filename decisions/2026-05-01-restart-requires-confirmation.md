---
title: Restart requires a confirmation step
date: 2026-05-01
status: ratified
tags: [decision, design, friction, slice-1, restart]
---

# Restart requires confirmation

## Decision
Clicking "Begin Anew" on the death screen does not immediately wipe the save. It opens a modal confirmation dialog. The wipe-and-regenerate sequence runs only after the player confirms (a second click). Cancel returns to the death screen unchanged.

The Begin Anew button disables on first press and re-enables only on modal cancel.

## Reasoning
Director cited intake resolution 1 ("death rare and earned, not roguelite reset cadence"). Frictionless restart only erodes that pillar if death itself becomes cheap. Stranded death already requires compounded bad decisions, so the cost of dying isn't changing — but the cost of *restarting* shapes the loop's grammar.

The structural answer: friction lives in the modal, not the architecture. The path exists but is deliberately one beat slower than Quit. Without the confirm step, restart would be one click — faster than Quit-and-relaunch — and would erode the deliberate weight of choosing to begin again.

The button-disable rule (re-enable only on cancel) is the structural answer to double-click guards: one source of truth, no `_regen_in_flight` bool.

## Alternatives considered
- **One-click restart, no confirmation.** Rejected — frictionless restart erodes intake resolution 1.
- **Confirmation as a typed phrase ("type RESTART to continue").** Not seriously considered; over-engineered for the slice's punctuation tone. A modal-with-Cancel matches the existing travel-confirm precedent and the death-screen register.

## Confidence
High.

## Source
- Director fit-to-pillar verdict (this session).
- Architect specified the button-disable rule and modal contract (this session).
- User playtest confirmed feel.

## Related
- [[2026-04-29-death-rare-and-earned]] — the tension this decision protects
- Intake resolution 1 (memory: `project_director_intake.md`)
- [[2026-05-01-begin-anew-confirm-dialog-separate-class]] — implementation of the modal
- [[2026-05-01-restart-label-begin-anew]] — what the buttons say
