---
title: Member ordering — lifecycle methods come before private methods
date: 2026-05-02
status: ratified
tags: [decision, conventions, code-review, feedback]
---

# Member ordering — lifecycle methods come before private methods

## Decision

Confirming the canonical GDScript member order from the `gdscript-conventions` skill:

```
1. constants
2. exports
3. public methods
4. lifecycle / virtual methods (_init, _ready, _process, _draw, _notification, etc.)
5. private methods (_underscore-prefixed helpers, including _on_* signal handlers)
6. signal declarations (or in their own region near the top, per skill)
```

**Lifecycle methods come BEFORE private methods.** This is the order the existing project codebase follows (e.g. `status_bar.gd` puts `_ready` before `_on_*` handlers).

A Code Reviewer round in this session asked for the inverted order (lifecycle last). Engineer pushed back, citing the skill and the existing codebase. User accepted Engineer's reading. **`map_view.gd` was already compliant; no code change.**

## Reasoning

The convention exists so a reader skimming a file finds the boot-time behaviour (`_ready`) early, after the public API but before the implementation details. Inverting it (lifecycle last) buries the boot-time behaviour at the bottom of the file, which is harder to scan.

Capturing this as a decision because the Reviewer's nit is the kind of thing that re-surfaces every review round if not pinned down. Future Reviewer runs that ask for the inverted order should be pushed back on with a link to this note.

## Alternatives considered

- **Reorder `map_view.gd` to match the Reviewer's suggestion (private before lifecycle).** Rejected. Contradicts the skill and the rest of the codebase; inverts the readability rationale.
- **Treat as a project-specific override (lifecycle last in this project).** Rejected. No project-level reason to deviate from the standing skill.

## Confidence

High. Skill text is explicit; existing codebase already follows this pattern; Engineer's pushback was correct.

## Open threads carried forward

- If the same Reviewer nit surfaces in a future round, link to this note. If it surfaces twice more, the `code-reviewer` agent prompt or the skill description may need a clarification pass.

## Source

This session (2026-05-02 PM). Code Reviewer nit 3, Engineer fix-loop pushback, user accepted ("acceptable" on the recap).

## Related

- [[CLAUDE]]
- (gdscript-conventions skill at `~/.claude/skills/gdscript-conventions/`)
