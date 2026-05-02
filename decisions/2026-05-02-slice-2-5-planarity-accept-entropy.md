---
title: Planarity threshold not enforced in slice-2.5; readability call defers to MapPanel feedback
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, verdict, planarity, mappanel, generator, deferral]
---

# Planarity threshold not enforced in slice-2.5; readability call defers to MapPanel feedback

## Decision

No planarity (edge-crossing) rejection predicate is added to `godot/game/world_gen.gd` in slice-2.5. Planarity is **accept-entropy** for now. Revisit if and only if MapPanel readability complaints surface in slice-3+ play -- the player struggling to see at a glance which nodes connect to which.

## Reasoning

Per the §7 protocol, each named thread receives one of three verdicts. With no survey data and the §4 default in effect, planarity accepts entropy.

Critic separately flagged planarity as the weakest of the three proxies considered for automation: "planarity is a *readability* call, per §1 -- numbers can't see it." A `crossing_count` metric would be a number; the question is whether the player's eye can parse the topology. That question is felt-experience by definition and lives on the MapPanel side, not the generator side.

If a future revisit is needed, the lever could sit in either the generator (reject high-crossing layouts) or the MapPanel (improve edge rendering -- thicker lines, better z-order, hover affordances). Which lever pulls is a slice-3+ design call once felt complaints exist.

## Alternatives considered

- **Add a `crossing_count <= K` rejection predicate now, defensively.** Rejected per accept-entropy posture.
- **Defer with owe-note to a "MapPanel polish" slice.** Rejected. No such slice is named; creating one pre-emptively is the same precautionary trajectory the posture prohibits. Accept-entropy with a felt-trigger condition is enough.

## Confidence

High. Verdict follows directly from the §4 default firing; supplementary point about readability-as-felt-experience reinforces it.

## Source

This session (2026-05-02, slice-2.5 close turn).

## Related

- [[2026-05-02-slice-2-5-close-via-entropy-default]] -- parent close decision.
- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- posture.
- [[2026-05-02-slice-2-5-named-tuning-pass]] -- charter.
- [[slice-2-5-survey-protocol]] -- §1 planarity definition, §7 verdict types.
