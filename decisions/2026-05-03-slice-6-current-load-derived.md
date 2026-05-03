---
title: current_load is derived from inventory, not stored
date: 2026-05-03
status: ratified
tags: [decision, slice-6, architecture, state-shape]
---

# current_load is derived from inventory, not stored

## Decision
`current_load: int` is **never** a field on `TraderState` or any node. Whenever the value is needed (UI refresh, buy gate check), `CargoMath.compute_load(inventory, goods_by_id)` is called. The function is deterministic; the inputs are pure; no field mutation is required.

## Reasoning
Critic framing weighed four concerns (spec §4.3):

1. **Migration cost.** Derive has zero migration. Memo on `TraderState` is a schema bump. Combined with `cargo_capacity` already a code constant (no per-trader varying), the schema bump pays twice for the same slice: once now, once when slice-6.1 actually introduces varying capacity.

2. **Debug cost.** Desync is impossible by construction in the derive shape (the function is `(inventory, goods) -> int`, both pure inputs). Memo introduces the desync surface (forget to recompute on `apply_inventory_delta`, save the stale value, load it next session, gate disagrees with reality). Derive eliminates this entire bug class.

3. **Performance.** The loop is O(goods-in-inventory) -- at most 4 dict reads + 4 multiplies per refresh, called on signal-driven UI refresh, not per-frame. HTML5 budget impact negligible.

4. **Storage.** Derive adds zero bytes. Memo adds 4 bytes plus amortised schema-bump cost.

Slice-6.1 may flip this if capacity becomes per-trader and the recompute moves into a tighter loop -- but that's slice-6.1's call to make with its own data.

## Alternatives considered
- **Store as `current_load: int` field on `TraderState`** -- rejected: unnecessary schema bump, introduces desync surface, no perf win at N=4 goods on signal-driven refresh.

## Confidence
High. The four concerns all line up in the same direction (derive wins on each axis); the spec author explicitly ratifies derive in §4.3.

## Source
`docs/slice-6-weight-cargo-spec.md` §4.3 (derive vs memo, four-axis comparison).

## Related
- [[2026-05-03-slice-6-cargo-math-static-helper]] -- the function that computes the value
- [[2026-05-03-slice-6-cargo-cap-as-code-constant]] -- the parallel decision keeping `cargo_capacity` out of TraderState
