---
title: Scope expansion when a discovered bug blocks the slice's stated purpose
date: 2026-05-03
status: ratified
tags: [decision, workflow, process, scope, slicing]
---

# Scope expansion when a discovered bug blocks the slice's stated purpose

## Decision
When a bug is discovered during a slice's playtest validation that **blocks the slice's stated purpose** -- i.e., the user cannot verify the slice delivered what it set out to do because the discovered bug masks the slice's behavior -- the slice's scope expands to include fixing that bug. This applies even when the bug is pre-existing (not introduced by the slice's own work) and even when Director's anti-goals had named adjacent areas as out-of-scope.

The scope-expansion bar is high and narrow:

1. The bug must be discovered during the slice's *validation* phase (playtest, harness regression, etc.), not during fresh design surface scanning.
2. The bug must *demonstrably block the slice's stated purpose*, not merely reveal an adjacent issue. The chain "without fixing this, the slice's deliverable is invisible / unverifiable / misleading" must be load-bearing.
3. The fix must be *small* relative to the slice's other work. If the discovered bug needs its own design pass (Designer + Architect), it gets sequenced to the next slice with proper pipeline ceremony, not bundled.
4. Director's *other* anti-goals stay binding. Expanding scope to fix the blocker doesn't open a license for "while we're in here" cleanups.

If all four conditions hold, the discovered bug is in scope. If any condition fails, defer it to the next slice.

## Reasoning
Slicing discipline (carried by [[feedback_critic_stance]] and [[2026-04-29-no-cuts-slice-first]]) defaults to *holding scope*. New work surfaced mid-slice gets sequenced, not bundled. This default works because most mid-slice discoveries are scope creep ("while we're in here, let's also...") rather than blocking dependencies.

But a discovered bug that *blocks the slice's stated purpose* is a different shape. The slice's purpose is its contract with the rest of the project; if the slice's deliverable can't be verified due to the discovered bug, the slice ships *unverifiably broken*. That's worse than scope expansion: it's a slice that pretends to deliver but doesn't. Sequencing the blocker to the next slice means the current slice ships in this unverifiable state.

The slice-5.x case made this concrete. Slice-5.x's named bugs (A, B, C) all had clean code fixes that passed headless harness checks. But user playtest revealed a pre-existing P6 invariant bug that fired on every load with travel history -- triggering wipe-and-regen, which masked all of slice-5.x's behavior. Without fixing P6, the user could not observe whether slice-5.x's named bugs were fixed. Sequencing P6 to slice-5.y would have meant slice-5.x ships with code-correct fixes that look exactly like the broken pre-slice behavior to the player. The slice's *stated purpose* ("save persistence survives refresh") would not deliver.

The expansion was bounded: P6's fix was ~5 lines (single predicate change in `_check_history_integrity`), the harness extended by ~15 lines (re-run B1 after slice-5.x checks populate history). No new design pass, no schema bump, no UI work. The four conditions above all held.

The pattern is: **scope holds, unless the slice's stated purpose can't deliver without expansion**. The "unless" is rare and demands all four conditions; the default remains hold.

## Alternatives considered
- **Hard rule: defer all mid-slice discoveries to the next slice, no exceptions.** Rejected: ships slices that don't actually deliver their stated purpose, which corrodes trust in the slicing model. The Critic's slicing-discipline argument applies to *scope creep*, not to *blocking dependencies for the slice's own purpose*.
- **Soft rule: expand scope whenever the bug is "small enough."** Rejected: too vague, opens drift. The four conditions above tighten "small enough" with explicit gates.
- **Treat the discovered bug as evidence the slice should be rolled back and re-pipelined.** Rejected: P6 was pre-existing, not introduced by the slice. Rolling back slice-5.x's correct fixes wouldn't help; the bug would still be there. The pre-existing bug exposed by correct slice work is exactly the case where expansion is right.

## Confidence
Medium. The pattern is clear and the four conditions are explicit, but this is the first explicit codification. The slice-5.x case fit cleanly; future cases may surface edge conditions:

- A bug whose fix needs Designer involvement (condition 3 fails) -- defer per the rule.
- A bug that *partially* blocks the slice's purpose (some symptoms visible, some masked) -- needs judgment on whether condition 2 holds.
- A bug discovered during user-acceptance testing weeks later, after the slice was already declared shipped -- doesn't fit; the slice already shipped, this becomes a defect in a closed slice and goes to the next slice or a hotfix.

Revisit if the rule produces a "we should have deferred that" regret. The four conditions are deliberately narrow to make false-positive expansions rare.

## Source
Today's slice-5.x session. P6 was discovered during user playtest validation (event 7-8). I framed the scope expansion explicitly with the four conditions implicit (event 9, "slice-5.x's stated purpose isn't actually delivered without fixing it"). User approved. The conditions above are the explicit codification of what the user approved.

## Related
- [[feedback_critic_stance]] -- the user's standing pattern of holding scope; this decision is the narrow exception, not a rebuttal
- [[feedback_carryover_check_protocol]] -- the adjacent rule about checking governing protocols before promoting carryover; same family
- [[2026-04-29-no-cuts-slice-first]] -- the broader slicing stance this decision sits inside
- [[2026-05-03-slice-5-save-bugs-deferred-to-5x]] -- the prior precedent (defer A/B/C to slice-5.x) that this decision contrasts with: there, the bugs were carryover *before* slice-5 closure; here, P6 was discovered *during* slice-5.x validation
- [[2026-05-03-slice-5x-ships-save-persistence-restored]] -- the slice this precedent first applied to
