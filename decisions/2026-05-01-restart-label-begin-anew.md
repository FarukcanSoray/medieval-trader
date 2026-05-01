---
title: Restart label is "Begin Anew"
date: 2026-05-01
status: ratified
tags: [decision, design, language, slice-1, restart]
---

# Restart label: "Begin Anew"

## Decision
The death-screen restart button is labeled "Begin Anew." The confirm-modal OK button is also "Begin Anew." Cancel button is "Cancel."

The modal body text is: `"Begin anew? This will erase the current trader and generate a new world. This cannot be undone."`

The modal title bar reads `"Begin Anew"` (matching the existing travel `ConfirmDialog`'s `"Confirm Travel"` titled-modal precedent).

## Reasoning
Director framed the language choice as matching the "story, not a verdict" tone established in intake resolution 4. Death-cause labels in the slice already use narrative framing rather than judgment language (`stranded`, etc.). The restart label should sit honestly inside that frame.

Three candidates were considered:
- **"Try Again"** — rejected as verdict-coded. Implies failure to overcome; converts the death screen into a level-end card.
- **"Respawn"** — rejected as roguelite-coded. Imports the wrong genre and contradicts the careful-merchant fantasy.
- **"New Life"** — considered. Reads slightly clinical against the slice's existing tone register (`stranded` is poetic; "new life" is technical).

"Begin Anew" preserves the narrative framing — past-participle/imperative, no verdict, no genre import.

## Alternatives considered
- "Try Again" (rejected — verdict-coded).
- "Respawn" (rejected — roguelite-coded).
- "New Life" (considered — reads clinical against the existing tone).

## Confidence
High. Tone is consistent with prior decisions; the rejected alternatives each carry a specific failure mode the chosen wording avoids.

## Source
- Director fit-to-pillar verdict (this session).
- Intake resolution 4 (memory: `project_director_intake.md`).

## Related
- [[2026-04-29-no-win-condition]] — "story, not a verdict" framing
- [[2026-04-29-death-cause-stranded]] — death-cause label tone precedent
- Intake resolution 4 (memory: `project_director_intake.md`)
- [[2026-05-01-restart-entry-on-death-screen]] — companion decision
