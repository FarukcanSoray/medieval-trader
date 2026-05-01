---
title: Strict-reject contract for from_dict on TraderState and WorldState
date: 2026-04-29
status: ratified
tags: [decision, architecture, save-load, contract]
---

# Strict-reject contract for from_dict on TraderState and WorldState

## Decision
`WorldState.from_dict()` and `TraderState.from_dict()` return `null` on **any** structural corruption. There is no best-effort recovery, no field-by-field repair, no silent defaults.

Rejection conditions (binding for both methods, exhaustive at the time of decision):

- Any required top-level key missing.
- `schema_version != 1`.
- Wrong type for any field (`nodes`/`edges`/`history` not an `Array`, etc.).
- `history.size() > HISTORY_CAP` (10).
- Any sub-entry malformed (node missing `id`/`name`/`pos`/`prices`; edge fails `EdgeState.is_valid()`; history `kind` fails `HistoryEntry.is_valid_kind`; etc.).
- `pos` array size != 2.
- `dead == true` with `death == null`, or `dead == false` with `death != null`.
- TraderState: `travel != null` AND `location_node_id != null` (contradictory state) — see [[2026-04-29-trader-travel-location-mutex]].

`SaveService` (Tier 4) handles a `null` return by regenerating the world from a fresh seed.

The user also ratified two related sub-decisions during the same review pass:

- **`HistoryEntry.KINDS` stays as strings** with `is_valid_kind` validation in `from_dict` — rejected enum-ification.
- **`@export` is kept on in-memory-only Resource fields** — Inspector affordance is fine; the dummy-fill footgun isn't real.

## Reasoning
This is a uniform extension of `slice-spec.md` §8: "Schema version mismatch on load: Save discarded, new world generated. Slice doesn't do migrations." The Code Reviewer surfaced that the original Engineer implementation handled schema mismatch correctly but degraded into best-effort recovery for everything else (silently dropping malformed sub-entries, silently defaulting `pos[1]` to 0.0 when the array was size 1, etc.). User ratified the cleaner contract: **a corrupted save is a corrupted save** — don't pretend to fix it.

The careful-merchant fantasy doesn't have "partial recovery" semantics. The all-or-nothing contract simplifies the code, matches §8's stated intent, and makes the save format honest — corruption is loud, not silent.

## Alternatives considered
- **Best-effort recovery** (the original Engineer pass before review) — rejected: encourages partial-save footguns; silent default values masquerade as valid data; users can't tell the difference between "loaded successfully" and "loaded a wrecked save."
- **Field-by-field repair logic** — rejected: too much magic; the player's save was lost the moment it corrupted; pretending otherwise is dishonest.

## Confidence
High. Code Reviewer surfaced the gap; user ratified strict-reject explicitly; Engineer fix pass implemented it. Both `from_dict` methods now exhibit the contract.

## Source
- Code Reviewer Tier 1 verdict, 2026-04-29 evening (one blocking + cluster of cascading non-blockers all pointing at this contract).
- User ratification of strict-reject during the fix pass briefing.
- Implemented in `godot/world/world_state.gd:67` and `godot/trader/trader_state.gd:59`.

## Related
- [[slice-spec]] — §8 "Schema version mismatch on load" (the seed of the contract)
- [[slice-architecture]] — §5 "Save lifecycle" — `SaveService.load_or_init` regenerates on null
- [[2026-04-29-save-format-first]] — the kickoff decision this operationalises
- [[2026-04-29-trader-travel-location-mutex]] — one of the invariants this contract enforces
- [[2026-04-29-resource-not-autoload-state]] — wholesale-swap-on-load works because of this contract
