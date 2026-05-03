---
title: Slice-6.0 per-good weights -- wool=4, cloth=3, salt=2, iron=10
date: 2026-05-03
status: ratified
tags: [decision, slice-6, goods, tuning]
---

# Slice-6.0 per-good weights -- wool=4, cloth=3, salt=2, iron=10

## Decision
Per-good weight values for the four-good catalogue:

- wool: 4 (3.0 g/wt at base price 12)
- cloth: 3 (3.7 g/wt at base price 11)
- salt: 2 (3.5 g/wt at base price 7)
- iron: 10 (2.2 g/wt at base price 22)

These ship with the slice-6.0 commit and pass the revised §7.2 harness criterion at the canonical ratification tier (cap=60, gold=200).

## Reasoning
Per-good rationale (spec §5):

- **wool=4** -- median anchor; 3.0 g/wt parity with the kernel-trainer feel from slice-3
- **cloth=3** -- light-and-chatty; lowest weight relative to value lets cloth's volatility have surface area
- **salt=2** -- the bulk floor; lightest, lowest base, fills cargo when no big spreads exist
- **iron=10** -- the density gate; deliberately heavy. One iron eats 60% of a typical mid-game row. iron=6 was rejected because it lets all-iron carts dominate; iron=10 forces real allocation between iron and the rest.

The harness validated the choice but does not strongly fine-tune within the PASS region: (4,3,2,10), (4,3,2,12), and (4,3,2,6) all pass the revised criterion at gold=200. The choice between iron=10 and iron=12 is feel-driven (Designer call); the harness is a guard against pathological tuples like (1,1,1,1), not a fine-tuner. (1,1,1,1) correctly FAILs (salt eats 64% mean share, iron drops below 10%, multi-good hits 0% at gold=400).

At the chosen tuple (4,3,2,10) cap=60 gold=200: wool 24.1%, cloth 14.4%, salt 44.6%, iron 16.9% mean weight-share -- all four goods inside the [10%, 50%] band. Multi-good carts 14.6% (>= 10% floor at gold=200). Sanity passes (gold=200 14.6% > gold=400 0.0%).

## Alternatives considered
- **iron=6** -- rejected: cap-60 makes 10-iron all-iron carts feasible and high-profit; allocation tension collapses
- **iron=12** -- not rejected, functionally equivalent to 10 within the harness PASS region; choice is feel-driven
- **uniform weights (1,1,1,1)** -- rejected: harness FAILs explicitly (salt dominates aggregate, no role identity)

## Confidence
High on the chosen values passing the harness; medium on the choice of 10 over 12 (feel-driven, will be retuned post-playtest if needed).

## Source
`docs/slice-6-weight-cargo-spec.md` §5 (per-good rationale); `godot/tools/cargo_divergence_verdict.txt` lines 27-43 (gold=200 detailed data).

## Related
- [[2026-05-03-slice-5-four-good-role-taxonomy]] -- the role taxonomy these weights operationalize
- [[feedback_measurement_before_tuning]] -- standing rule applied (harness validated before commit)
- [[2026-05-03-slice-6-revised-harness-criterion]] -- the criterion these weights pass
