---
title: Slice-2.5 closes via the protocol's §4 entropy default; survey not run
date: 2026-05-02
status: ratified
tags: [decision, slice-2-5, close, scope, tuning]
---

# Slice-2.5 closes via the protocol's §4 entropy default; survey not run

## Decision

Slice-2.5 closes without running the seed survey in either form (eyeball or automated). All three named threads -- hub-and-spoke, planarity, free-lunch -- close under the protocol's `slice-2-5-survey-protocol.md` §4 default ("enforcement requires affirmative evidence the kernel is breaking, not absence of evidence it's safe").

No rejection predicates are added to `godot/game/world_gen.gd` in this slice. Each thread carries its own verdict decision -- see related entries.

## Reasoning

The user did not have 45-75 minutes for hand inspection. A headless automation alternative was proposed (`tools/survey.gd`, 200 seeds, three numeric proxies, CSV out) and rejected after Director-vs-Critic deliberation.

Critic's killer test landed: "Name the predicate you'd enforce in `world_gen.gd` today if the CSV showed it. If you can't, the tool is theatre." No pre-committable predicate existed; post-hoc threshold-picking from a 200-row distribution would have shifted the judgement (and the sprawl) from per-row eyeball to threshold selection, while the protocol's §4 default already prescribes the no-data outcome explicitly.

Closing via §4 is the protocol's own clean exit -- not a workaround, not a compromise. It is congruent with the project posture in [[2026-05-02-slice-2-5-accept-entropy-default-posture]]: enforcement is opt-in on evidence, not opt-out by default.

## Alternatives considered

- **Run the eyeball survey as originally protocoled.** Rejected. User did not have the time budget; deferring repeatedly would have left the slice silently open.
- **Build the headless `tools/survey.gd`** (200 seeds, max_degree + min_free_lunch_ratio + crossing_count, CSV out). Director endorsed; Critic flagged Hidden-Expensive (interpretation cost > build cost; metric ≠ felt-experience; sprawl risk in threshold-picking). Rejected on Critic's read.
- **Build a tighter version of the headless tool** per Critic's reductions (50 seeds, two metrics, pre-committed thresholds). Rejected -- still required a pre-committable predicate that did not exist.

## Confidence

High. Explicit user binding call ("stick with the critic and close slice 2.5 log the free lunch owe note and move on"). Path is the protocol's own §4 default, not a novel exit.

## Source

This session (2026-05-02, slice-2.5 close turn). Director and Critic outputs in parallel; user binding call adopted Critic's read.

## Related

- [[2026-05-02-slice-2-5-named-tuning-pass]] -- charter this close concludes.
- [[2026-05-02-slice-2-5-accept-entropy-default-posture]] -- posture this close enacts.
- [[2026-05-02-slice-2-5-hub-accept-entropy]] -- per-thread verdict.
- [[2026-05-02-slice-2-5-planarity-accept-entropy]] -- per-thread verdict.
- [[2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice]] -- pre-existing free-lunch verdict, now operative.
- [[2026-05-02-slice-2-5-survey-automation-deferred]] -- the headless tool considered and not built.
- [[slice-2-5-survey-protocol]] -- §4 default invoked.
