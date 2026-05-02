---
title: All structural-corruption branches in load_or_init fire the corruption toast
date: 2026-05-02
status: ratified
tags: [decision, save-system, ux, integrity, slice-2-followup]
---

# All load_or_init rejection branches fire the corruption toast

## Decision

All five structural-corruption branches in `SaveService.load_or_init` set `Game._save_corruption_notice_pending = true` before calling `_generate_fresh()`:

1. File unreadable (`FileAccess.open` returns null).
2. JSON unparseable (`JSON.parse_string` does not return a `Dictionary`).
3. Missing trader block (parsed dict has no `"trader"` key).
4. Non-dict trader (`blob["trader"]` is not a `Dictionary`).
5. Structural rejection (`WorldState.from_dict` or `TraderState.from_dict` returns null -- this is where schema-mismatch lands).

The flag is consumed once on the next UI boot via `Game.consume_save_corruption_notice()`; duplicate sets collapse harmlessly because the consumer is one-shot.

## Reasoning

The flag-set was previously located only in `Game.bootstrap`, fired when the post-load B1 invariant harness rejected a corrupted dead-record. After the slice-2-followup schema bump (1 -> 2; see `[[2026-05-02-slice-2-followup-schema-bump-semantic-reinterpretation]]`), schema mismatch became the most common cause of corruption-regen, and it lands in `load_or_init`'s reject branch -- not in the harness. Schema-1 upgraders would get silent regen with no explanation: their saved world is gone, and they're staring at a fresh one with no toast.

Reviewer's framing: "From the player's perspective this is structural corruption -- hiding any of the five would be inconsistent." A player who edits or partially restores a save and gets it wrong should see the same notice as anyone whose save crashed mid-write or whose schema is stale.

## Alternatives considered

- **Treat some branches as developer-only** (e.g. "missing trader block" is unlikely to happen to real players; suppress its toast). Rejected by Reviewer + Engineer consensus on round 1 / round 3: all five are user-facing structural corruption from the player's perspective; partitioning by likelihood would create asymmetric UX without principled criteria.
- **Move the toast to a single late-binding hook** (e.g. emit a signal on regen, let UI subscribe). Considered briefly during the structural pass; rejected as over-engineered for a five-call-site flag-set.

## Confidence

High. Engineer manually edited a save file's `schema_version` to 1 and verified the rejection branch fired and the flag was set; Reviewer round 2 closed cleanly.

## Source

Slice-2 follow-up session (2026-05-02). Reviewer round 1 Q3; Engineer round 3 fix loop; Reviewer round 2 closure.

## Related

- [[2026-05-01-save-corruption-regenerate-release-build]] -- the upstream contract this surfaces
- [[2026-04-29-strict-reject-from-dict]]
- [[2026-05-02-slice-2-followup-schema-bump-semantic-reinterpretation]] -- the upgrade path that motivated extending the toast surface
- [[2026-05-01-save-invariant-checker-harness-no-autoload]] -- the harness whose flag-set was the previous (only) toast site
