---
title: Buy-gate cargo overflow refunds gold; mirrors slice-1 trade-verb atomicity
date: 2026-05-03
status: ratified
tags: [decision, slice-6, trade, atomicity]
---

# Buy-gate cargo overflow refunds gold; mirrors slice-1 trade-verb atomicity

## Decision
In `Trade.try_buy`, the defensive cargo-overflow check fires **after** the gold deduction succeeds, not before. If the cart would overflow, gold is refunded via `apply_gold_delta(+price, ...)` and the trade returns false. The same shape applies to the orphan-good-id refund (Reviewer-flagged defensive symmetry, applied in Engineer round 4). The trade either completes fully or rewinds to its pre-call state -- no partial mutations.

## Reasoning
The slice-1 trade-verb contract establishes the atomicity boundary: a buy is "deduct gold, mutate inventory, push history." If any step fails after gold is already deducted (cart overflow, orphan id, future failure modes), the verb must rewind via gold refund. The verb's external contract is "either you bought one and lost N gold, or you didn't and your state is unchanged."

Placing the cargo check **after** gold deduction is intentional:

1. **The defensive gate is a safety net, not the primary predicate.** UI predicates (NodePanel's disabled buy-button) are the primary gate -- they refuse the click before `try_buy` is ever called. The defensive gate exists for "UI predicate drift" -- if NodePanel computes `current_load` differently from `try_buy`, or if a future caller invokes `try_buy` directly without UI, the gate catches it.
2. **The `push_warning` on gate-fire is a drift-detection signal.** Logging only fires when the UI predicate has already failed; ordering the check after deduction doesn't change correctness, but it surfaces the drift via the refund path explicitly rather than via silent disagreement.
3. **The refund cannot fail.** `apply_gold_delta` only rejects negatives that would drive `gold` below zero. A positive delta on a non-negative trader is unrejectable. The discarded `bool` from the refund is intentional, not a bug; documented in the code.

## Alternatives considered
- **Check cart space before deducting gold** -- rejected: breaks the slice-1 atomicity contract by introducing a "check-then-act" pattern with two failure modes (gold rejection vs cart rejection), each requiring different rollback shapes. The post-deduction-check + refund pattern keeps the rollback shape uniform.
- **Skip the defensive gate entirely, trust the UI predicate** -- rejected: UI-vs-runtime predicate drift is exactly the failure mode `CargoMath` exists to prevent. The gate's `push_warning` is the drift detector.

## Confidence
High. The atomicity contract is explicit in slice-1's spec and reinforced by slice-4's encounter-resolver pattern (resolve-then-apply, never partial). The Reviewer confirmed the refund safety analysis ("positive delta on non-negative trader cannot fail") on round 4.

## Source
`godot/travel/trade.gd:30-46` (the gate + refund block); `docs/slice-6-weight-cargo-spec.md` §3 (mechanic) and §10 (edge cases).

## Related
- [[2026-04-29-callable-injection-resource-mutators]] -- the mutator-callback pattern that makes the refund safe
- [[2026-05-02-slice-4-store-only-when-it-bites]] -- adjacent atomicity precedent (slice-4 encounter resolution)
