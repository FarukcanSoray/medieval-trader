---
title: B1 (HTML5 smoke-test) runs before A (tuning playtest); B split into B1/B2; C folded
date: 2026-05-01
status: ratified
tags: [decision, sequencing, web-export, save-system, b1]
---

# B1 (HTML5 smoke-test) runs before A (tuning playtest); B split into B1/B2; C folded

## Decision

The next development round is **B1 — a minimal HTML5 export smoke-test for refresh-mid-travel**, sized to one session. B1 gates A (the §6 tuning playtest); A may run in parallel with B2 once B1 ships. The Tier 7 cleanup pass (C) is split: the `_quitting: bool` re-entry guard folds into B2 (lifecycle-await family); the final-statement comment on `change_scene_to_packed` and the typed `save_service` accessor become drive-by Engineer items in a future round.

Final sequencing: **B1 → A ∥ B2.**

## Reasoning

Director ruled B-before-A on the basis that every pillar is encoded in the save format and tick model, so tuning A on a desktop-only artifact risks re-tuning if the in-browser save lifecycle diverges. Critic narrowed this from "every pillar" to a single load-bearing concern: refresh-mid-travel as a kernel-level Pillar-2 exploit surface. If a player can refresh mid-travel to undo an unprofitable trip, no amount of A-tuning closes the gap. Critic also flagged that B as originally framed ("verify the whole save model") was nine concerns across three families — pure plumbing, determinism verification, lifecycle hardening — and split it into B1 (one-session smoke-test, the single load-bearing concern) and B2 (deeper determinism: hash byte-stability, FIFO ordering, save-during-travel, multi-tab, plus the `_quitting` guard).

Drift % and travel-cost tuning are not save-format-dependent, so re-tuning cost on web is near-zero — Critic noted this undercuts the "B-first prevents re-tuning" framing for tuning-knob A. The narrower exploit-surface argument is what carries the sequencing.

## Alternatives considered

- **Strict B → A** (Director's first framing): rejected by Critic on the smear/cost-overstatement grounds above.
- **A first, B later**: rejected. The refresh-mid-travel exploit is a kernel concern, not a tuning concern, and tuning against an exploitable model is misdirected.
- **Tier 7 cleanup (C) as its own round**: rejected. Of the three items, only the `_quitting` guard is in the lifecycle-await family that B2 already touches; the other two are five-minute drive-bys that don't earn a dedicated round.

## Confidence

High. Director and Critic agree on the sequencing; the disagreement was on framing, not order.

## Source

- This session's Director verdict (first ruling on next-round candidates A/B/C).
- This session's Critic pressure-test on Director's B → A ordering.

## Related

- [[2026-04-29-no-cuts-slice-first]] — slice-first stance; B1/B2 split is sequencing under that stance, not scope reduction
- [[2026-04-30-tier7-deferred-followups]] — the three C items being split here
- [[slice-spec]] — §6 tuning knobs that A operates against
