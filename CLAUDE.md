# Project: Medieval Trader

## What this is

A solo, AI-developed game about a travelling trader in medieval times. The player buys and sells goods between cities, towns, and villages with different prices, and pays a cost to travel between them.

The kernel is the collision: arbitrage profit only matters because travel costs bite, and travel only matters because there's profit waiting at the other end. Neither pillar works alone.

This is a portfolio-leaning first serious attempt at AI-driven game development. Scope discipline matters as much as the design itself.

Project Brief: see `docs/project-brief.md` once written. Until then, treat this CLAUDE.md as the working brief.

## What this is NOT

- Not multiplayer (no shared markets, no async leaderboards, no human opponents).
- Not real-time (turn- or step-based travel and trading).
- No story (no narrative arc, no quests, no scripted events with meaning beyond economics).
- No characters (only places — cities, towns, villages — as trading nodes; no named NPCs, no dialogue).

Combat, procedural generation, and meta-progression are deliberately left open for the Director to decide.

## Where things live

- `docs/` — project brief, design notes
- `decisions/` — decision log (populated by Decision Scribe)
- `sessions/` — session notes (populated by Session Summarizer)
- `godot/` — Godot 4.5.1 project root

## Project-specific notes

- Engine: Godot 4.5.1, GDScript only (no C#).
- Target platforms: desktop + web export. Mobile is out.
- No plugins, addons, or art/audio sources committed yet — Director and Architect will surface needs as they arise.
- Web export is a hard target, not "if it works" — system and asset choices should respect HTML5 constraints from day one.

## Workflow

User-level CLAUDE.md at `~/.claude/CLAUDE.md` defines the agent roster and skills.

For this project, run the **full pipeline** — no shortcuts:

- New feature: Director → Critic → Designer → Architect → Engineer → Reviewer.
- Bug: Engineer (own code) → Debugger (cross-system) → Architect (structural).
- End of session: Decision Scribe (ratify) → Session Summarizer.

Every feature goes through Director and Critic before Designer touches it. This is a first serious AI-developed project — the discipline of the pipeline is part of what's being learned.
