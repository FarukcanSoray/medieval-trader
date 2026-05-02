---
title: New `HistoryEntry.kind = "encounter"`; two-row pattern on fired bandit leg
date: 2026-05-02
status: ratified
tags: [decision, slice-4, design, history, encounters]
---

# New `HistoryEntry.kind = "encounter"`; two-row pattern on fired bandit leg

## Decision
`HistoryEntry.KINDS` extended to `["buy", "sell", "travel", "encounter"]`. On a bandit leg:

- **Roll fires:** **two history rows** — one `kind = "travel"` (cost paid), one `kind = "encounter"` (loss applied). Encounter row format: `Hillfarm->Rivertown (bandit road, -24g)` or with day-2 goods: `Hillfarm->Rivertown (bandit road, -24g, -1 cloth)`.
- **Roll misses (lucky leg):** **one history row** (`kind = "travel"` only). The *absence* of an encounter row is the signal the road was risky but kind today.

## Reasoning
Two-row pattern makes the event explicit in history without adding a UI surface (modal deferred). The asymmetry — fired = 2 rows, missed = 1 row — is information-bearing: the player can scroll back through history and see "I took 4 bandit roads this run; 2 fired, 2 missed." Single-row collapses lose that signal.

`HistoryEntry.is_valid_kind` already walks `KINDS`, so the strict-reject `from_dict` path covers the new value with zero extra code.

## Alternatives considered
- **Single unified row** (encounter detail in the travel row's `detail` field) — rejected; loses the "lucky bandit leg" signal.
- **Resolution modal** — deferred to slice-4.x.

## Confidence
Medium-high. The pattern is clear; the "absence-as-signal" framing depends on the player's actually scanning history (which playtest hasn't verified).

## Source
Designer spec §5.8.

## Related
- [[2026-05-02-slice-4-readback-consumed-preempted]] — the schema field reserved for the eventual modal
