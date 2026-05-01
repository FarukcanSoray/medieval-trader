---
title: Travel is non-cancellable once confirmed
date: 2026-05-01
status: ratified
tags: [decision, design, travel-mechanics, pillar-2]
---

# Travel is non-cancellable once confirmed

## Decision

Once the player accepts the travel-confirm dialog, the journey commits and cannot be cancelled. There is no abort verb, no "cancel for a partial refund," no mid-route interrupt. The journey runs to arrival or, in the future, to a terminal state imposed by another system (death, bankruptcy mid-travel if such a path is ever added).

Today the UX enforces this implicitly: TravelPanel disables travel buttons during `trader.travel != null`, NodePanel disables buy/sell during travel, and there is no cancel-travel button in any scene. This decision names the implicit constraint explicitly so future systems work doesn't accidentally relax it.

## Reasoning

Derives from `2026-04-29-travel-cost-at-departure` (gold deducted once at departure) plus Pillar 2 (travel cost bites). If travel were cancellable with any gold returned (full or partial), the player would have a free preview of the time cost with no commitment, which collapses the bite. Cancellable-for-zero-refund is mechanically equivalent to a delayed-arrival button — it removes the commitment dimension Pillar 2 depends on.

Director surfaced this during the slow-tick ratification: with travel now visible (450ms per tick), the question "is travel cancellable?" becomes a real player question for the first time. At 12ms it didn't exist. The Director's framing: travel is a commitment; once confirmed, it resolves. Designer treated this as constraint, not open question.

Naming this preemptively (rather than waiting for a future feature request) follows the same posture as `2026-05-01-begin-anew-order-rule` — write defensive contracts against subscribers that don't yet exist.

## Alternatives considered

- **Cancellable with full refund.** Rejected — turns travel into a free preview of time cost, collapses Pillar 2.
- **Cancellable with partial refund (e.g., refund unspent ticks proportionally).** Rejected — same problem in a softer form; the bite of an unprofitable trip becomes "lose a fraction" instead of "commit fully."
- **Cancellable but non-refundable.** Rejected — mechanically equivalent to a "skip arrival" button; the commitment dimension is what Pillar 2 wants felt, not the wall-clock duration alone.
- **Leave the rule implicit.** Rejected — works today because no one is asking for cancellation, but a future Designer round on visual animation or journey events will face the question and could relax it without realizing it's load-bearing.

## Confidence

High. Director ratified during slow-tick pipeline; derives cleanly from existing pillar and gold-debit rule; mechanically already enforced.

## Source

- Director's ratification of the slow-tick change (this session) — explicit "travel is a commitment; once confirmed, it resolves."
- Designer treated as settled constraint, not open question.
- Mechanically already enforced by TravelPanel button disable and the absence of any cancel verb in the codebase.

## Related

- [[2026-04-29-travel-cost-at-departure]] — the gold-debit rule this derives from
- [[project-brief]] — Pillar 2 (travel costs bite)
- [[2026-05-01-tick-duration-450ms-first-pass]] — the change that made this question salient for the first time
- [[2026-05-01-begin-anew-order-rule]] — same posture (preemptive contract for future systems)
