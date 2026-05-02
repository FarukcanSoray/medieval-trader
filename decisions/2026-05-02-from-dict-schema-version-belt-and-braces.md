---
title: WorldState.from_dict retains explicit schema_version assignment as belt-and-braces
date: 2026-05-02
status: ratified
tags: [decision, save-system, defensive-coding, conventions]
---

# WorldState.from_dict retains explicit schema_version assignment as belt-and-braces

## Decision

In `WorldState.from_dict`, `w.schema_version = SCHEMA_VERSION` is kept on the freshly-constructed `WorldState` even though `@export var schema_version: int = SCHEMA_VERSION` already initialises every `WorldState.new()` to the same constant.

The assignment is redundant today. It is intentionally retained.

## Reasoning

The redundancy guards against a class of silent decay. Two future scenarios:

1. A developer edits the `@export` default (e.g. drops the const reference, hardcodes a number, or changes the default to a sentinel) without realising `from_dict` also implicitly depends on it. With the explicit assignment in place, `from_dict` continues to produce a correctly-versioned `WorldState`. Without it, loaded saves silently carry whatever the new default is.

2. A cleanup-minded reader spots the assignment as "dead code" and removes it. The explicit assignment is the only signal that `from_dict` is the authoritative place to set `schema_version` on a loaded world; deleting it leaves the contract implicit and easier to break next time.

Capturing this as a decision because the assignment looks deletable in isolation. A Reviewer flagged it as redundant during the cleanup pass; without a paper trail, the next reviewer-or-engineer round may delete it on the same reasoning and lose the guard.

## Alternatives considered

- **Remove the redundant assignment as dead code.** Rejected. Removes the guard against `@export` default drift; turns an explicit contract into an implicit one.
- **Drop the `@export` default and rely solely on `from_dict`'s explicit assignment.** Rejected. `WorldState.new()` is also called by `WorldGen.generate()` (which sets `schema_version` itself) and by future call sites; the `@export` default is the right safety floor for those paths.

## Confidence

High. The cost is one line of "redundant" code; the benefit is a small but real guard against a future silent failure mode.

## Source

Cleanup-pass session (2026-05-02). Code Reviewer flagged the redundancy as a non-blocking finding ("dead but defensible"); user chose to keep it as belt-and-braces.

## Related

- [[2026-05-02-slice-2-followup-schema-bump-semantic-reinterpretation]]
- [[2026-05-02-slice-2-no-schema-bump-trigger-named]]
- [[CLAUDE]]
