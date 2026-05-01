---
title: Restart entry point on death screen, not title screen
date: 2026-05-01
status: ratified
tags: [decision, design, scope, slice-1, restart]
---

# Restart entry on death screen

## Decision
The "Begin Anew" path — restarting with a fresh world after death — is accessed from a button on the death screen, not from a separate title or start screen.

## Reasoning
Director's fit-to-pillar verdict gave two reasons:

1. **A title screen would add a second entry-point system, violating "one of each system"** ([[2026-04-29-one-of-each-system]]). The slice already commits to one map generator, one price model, one event system, one save, one death screen. Adding a title screen as a second entry point pays no slice cost it doesn't already cover; the death screen is already the entry point on a dead-state launch (per [[2026-05-01-boot-terminal-state-branch-in-main]]).

2. **Death-screen entry preserves the punctuation grammar.** Per intake resolution 4 ("sandbox with one terminal punctuation"), the death screen *is* the punctuation. Inserting a neutral title-screen lobby between death and new run dilutes that punctuation by giving the player a transition beat that scores neither end nor beginning. Death-screen entry keeps run-end → run-start as one continuous beat: ledger read, trader named, player chooses to begin again.

## Alternatives considered
- **Separate title screen with Continue / New Life branches** on every launch. Rejected: introduces a second entry-point system (violates "one of each"); inserts neutral lobby that dilutes the death-screen punctuation.

## Confidence
High. Both reasons compose cleanly with prior pillar decisions; no countervailing argument surfaced.

## Source
- Director fit-to-pillar verdict (this session).
- Critic confirmed sequencing (this session).
- User playtest confirmed feel.

## Related
- [[2026-04-29-one-of-each-system]] — the "one of each" rule this decision honors
- [[2026-04-29-no-win-condition]] — "sandbox with one terminal punctuation" framing
- Intake resolution 4 (memory: `project_director_intake.md`)
- [[2026-05-01-restart-requires-confirmation]] — companion decision about the friction step
- [[2026-05-01-restart-label-begin-anew]] — companion decision about the wording
