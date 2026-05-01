---
title: Bottom-up tier construction — no sanity-test scene, no main.tscn stub
date: 2026-04-29
status: ratified
tags: [decision, process, pipeline]
---

# Bottom-up tier construction — no sanity-test scene, no main.tscn stub

## Decision
The Engineer builds the slice strictly bottom-up by tier, in the order specified by `slice-architecture.md` §7: **Resources → WorldGen → Game autoload → Service nodes → Gameplay nodes → UI scenes → Main + entry wiring**.

The project will **not be runnable** in the Godot editor until Tier 7 lands the `main.tscn` and sets `run/main_scene`. We accept that. We do not build:

- A throwaway "Tier 1 sanity test scene" that instantiates Resources and prints round-trip results.
- A stub `main.tscn` early just so the editor has something to open.

## Reasoning
The user asked at the end of Tier 1 why the project wouldn't launch in Godot. After hearing three options (continue bottom-up; add a sanity scene; stub main.tscn), the user picked **continue bottom-up**. Reasoning that supports the choice:

- Services need Resources. UI needs Services. `Main` needs all of them. Building integration upward in dependency order means every wired-up tier exercises real (not mocked) dependencies.
- A stub `main.tscn` would either (a) fork wiring work — bits of `Main`'s logic written twice, once with stubs, once with real services — or (b) hide the bottom-up discipline and tempt code into `Main` before the architecture supports it.
- A sanity-check scene would be throwaway work; the same verification happens naturally when Tier 3 lands `Game.bootstrap()` and Tier 4 lands `SaveService.load_or_init()`.
- This is a first serious AI-developed project. The pipeline discipline itself is part of what's being learned. Per project CLAUDE.md: "run the **full pipeline** — no shortcuts."

## Alternatives considered
- **Add a Tier 1 sanity-test scene** (option 2) — rejected: throwaway work; the same verification happens when the autoload lands.
- **Stub main.tscn early** (option 3) — rejected: forks wiring; tempts ad-hoc code into `Main` before the architecture supports it.

## Confidence
High. User's explicit choice; reinforces the kickoff session's slice-first commitment with a concrete in-the-moment refusal of a shortcut.

## Source
- User choice at end of Tier 1, 2026-04-29 evening, after I surfaced the three options.

## Related
- [[CLAUDE]] — project-level: "run the full pipeline — no shortcuts"
- [[2026-04-29-no-cuts-slice-first]] — the kickoff decision that this operationalises in-the-small
- [[slice-architecture]] — §7 "Engineer handoff list" defines the tier order this discipline preserves
