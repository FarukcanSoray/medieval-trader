---
date: 2026-05-01
type: session
tags: [session, b1-prerequisite, travel-tuning, save-resume]
---

# Slow travel tick to 450ms and implement refresh-mid-travel resume seam

## Goal

Unblock B1's manual test protocol. Playtest revealed that travel completed in ~12ms, making the protocol's precondition — a manually-timed refresh window during travel — imperceptible. Full pipeline run (Director → Critic → Designer → Architect → Engineer → Reviewer → Engineer fix-up) on slowing per-tick yield to 450ms. A follow-up Debugger pass during second playtest fixed a stuck-travel bug surfaced by the slower tick.

## Produced

- `godot/shared/world_rules.gd` — added `const TICK_DURATION_SECONDS: float = 0.45` with `[needs playtesting]` tag.
- `godot/travel/travel_controller.gd` — replaced `await get_tree().process_frame` with `await get_tree().create_timer(WorldRules.TICK_DURATION_SECONDS).timeout`; added post-await freed-state guard; added `resume_if_in_flight()` method for restart seam; reconciled two yield-ordering comments.
- `godot/main.gd` — added `_travel_controller.resume_if_in_flight()` call at end of `_ready()` with ordering justification comment.
- `docs/b1-test-protocol.md` — added stuck-mid-travel caveat in §1; flagged §5 protocol for explicit `ticks_remaining` decrement check when B1 Engineer round runs.
- Footnote edit on [[2026-05-01-b1-sequencing-web-export-before-tuning]] noting that the tick-duration subset of A ran as a B1 prerequisite.

## Decisions

- [[2026-05-01-tick-duration-450ms-first-pass]]
- [[2026-05-01-resume-travel-seam-in-main]]
- [[2026-05-01-travel-non-cancellable]]

## Open threads

- **B1 Engineer round still unstarted.** Architect parts list from [[2026-05-01-b1-pipeline]] remains intact. With slow-tick and resume seams now in place, B1's manual runbook is finally executable end-to-end.

- **Pre-existing Unicode ellipsis at `godot/ui/hud/node_panel.gd:47`** (`"Travelling…"`) — same class as recent ASCII-arrow fixes. Deliberately deferred as a separate Unicode sweep, not B1 blocking.

- **`[needs playtesting]` tag on `TICK_DURATION_SECONDS = 0.45`** — first-pass committed; retune band (350–600ms) remains open pending extended hands-on use. Symptoms for retune documented in source comments.

- **Confirm-modal UX divergence** (carried from [[2026-05-01-boot-fix-and-begin-anew]]) — travel ConfirmDialog lacks Cancel button; BeginAnewConfirmDialog has OK + Cancel. Flagged for Designer post-playtest.

- **Tier 7 deferred markers** ([[2026-04-30-tier7-deferred-followups]]) still open. FIFO ordering re-stress concern is structurally weaker per Architect analysis, but not formally closed.

## Notes

The most instructive finding wasn't the tick-duration value itself — it was **why B1's design was incomplete until the tick was slow enough to observe manually.** The original sequencing argument framed B1 as smoke-test-before-tuning; this session showed that B1's *manual* protocol had a hard prerequisite (a refreshable travel window) masked by 12ms collapse. Slowing the system made that prerequisite visible, and in doing so surfaced a real B1-class bug (stuck-mid-travel after refresh) that the harness alone couldn't catch. The pipeline did its job in advance of the harness even shipping.

Critic also sharpened the generalization Director landed on: "Pillar 2 is mechanically complete; what's missing is making the pillar legible." Any pillar whose mechanics work but whose effects are imperceptible to the player is half-implemented, code-correct or not. Worth carrying forward when other pillars come up for similar review.
