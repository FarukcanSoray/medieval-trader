---
title: Accept entropy by default; rejection requires affirmative kernel-break evidence
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, posture, scope, tuning, principle]
---

# Accept entropy by default; rejection requires affirmative kernel-break evidence

## Decision

For slice-2.5 -- and as a default posture for tuning passes generally -- the default disposition toward observed generator entropy is **accept**. Enforcement of a rejection threshold requires affirmative evidence that the kernel is breaking, not absence of evidence that it is safe.

A degeneracy that appears 0-1 times in 20 seeds is **tail entropy**, not a kernel break. A degeneracy that appears but doesn't break the kernel on inspection is a misleading visual heuristic, not a kernel break. Only when a degeneracy is both common and visibly kernel-breaking does enforcement land.

## Reasoning

Director framed this directly: "The default posture is accept the entropy. Enforcement requires affirmative evidence that the kernel is breaking, not absence of evidence that it's safe."

Without this posture, the survey produces defensive enforcement: "we saw a hub-y world once in 20, let's add a max-degree predicate just in case." That trajectory adds generator constraints faster than gameplay evidence justifies, accumulates code surface, and contradicts the thin-slice stance that underlies the project's scope discipline.

The posture also implicitly governs the four "no, unless" cut conditions: rare entropy, misleading-visual, pricing-coupling, retry-edge-cases. Each is a structured reason to **not** enforce. They share one root: the burden of proof sits on enforcement, not entropy.

This generalises beyond slice-2.5. Future tuning passes -- pricing, encounter rates, UI feedback timing -- inherit the same default. Logging it as a project posture rather than a slice-2.5-only frame matches the user's standing slice-first + full-scope-held stance: thresholds wait until evidence demands them.

## Alternatives considered

- **Precautionary enforcement** (any observed degeneracy becomes a rejection predicate). Rejected. Ratchet effect; generator constraints accumulate without gameplay grounding.
- **No principled posture** (decide threshold-by-threshold, ad hoc). Rejected. Without a default, every threshold debate restarts from zero and the bias drifts toward "do something."
- **Slice-2.5-only framing** (don't elevate to a project posture). Rejected. The same logic applies to every tuning pass; naming it once is cheaper than re-deriving it per slice.

## Confidence

High. Director named it in the frame; the four cut conditions all express it; user accepted the conditions; the posture is consistent with the slice-first + accept-entropy stance recorded in standing memory.

## Source

This session (2026-05-02 PM, slice-2.5 framing). Director output, "no, unless" frame and cut conditions; user binding call B.

## Related

- [[2026-05-02-slice-2-5-named-tuning-pass]] -- slice that operates under this posture.
- [[2026-05-02-slice-2-generator-connectivity-only-defer-rejection]] -- prior expression of the same posture.
- [[2026-04-29-no-cuts-slice-first]] -- foundational user stance this posture sits inside.
- [[slice-2-5-survey-protocol]] -- where the four cut conditions are codified.
