---
title: Hub-and-spoke threshold not enforced in slice-2.5; revisit in slice-3+ play
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, verdict, hub-and-spoke, generator, deferral]
---

# Hub-and-spoke threshold not enforced in slice-2.5; revisit in slice-3+ play

## Decision

No hub-and-spoke rejection predicate is added to `godot/game/world_gen.gd` in slice-2.5. Hub-and-spoke degeneracy is **accept-entropy** for now. Revisit if and only if slice-3+ play surfaces a felt hub problem -- one node so central that route choice collapses into "go through the hub."

## Reasoning

Per the §7 protocol, each named thread receives one of three verdicts: enforce, accept, defer. With no survey data and no pre-committable predicate, the §4 default fires: accept entropy.

Critic separately raised that `max_degree` (the obvious numeric proxy) is not "hub-and-spoke" on its own -- a degree-4 node in a 7-node mesh may be fine; an obvious hub may emerge from edge weighting rather than degree. The proxy would have needed normalization, weighting, and likely a second metric to disambiguate. That work is deferred along with the verdict.

If slice-3+ play -- where the player actually traverses these worlds -- shows route choice collapsing, a rejection predicate (or a generator constraint elsewhere, e.g., bias the extra-edge step away from already-high-degree nodes) becomes a real candidate. Ground-truth data for that decision will be felt-experience, not metrics.

## Alternatives considered

- **Add a `max_degree <= 3` (or similar) rejection predicate now, defensively.** Rejected per [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- precautionary enforcement is exactly what the posture prohibits.
- **Defer with explicit owe-note (like free-lunch).** Rejected. Hub-and-spoke does not require a system not yet built; it can be evaluated from felt play. Accept-entropy is the cleaner verdict.

## Confidence

High. Verdict follows directly from the §4 default firing.

## Source

This session (2026-05-02, slice-2.5 close turn).

## Related

- [[2026-05-02-slice-2-5-close-via-entropy-default]] -- parent close decision.
- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- posture this verdict enacts.
- [[2026-05-02-slice-2-5-named-tuning-pass]] -- charter.
- [[slice-2-5-survey-protocol]] -- §1 hub-and-spoke definition, §7 verdict types.
