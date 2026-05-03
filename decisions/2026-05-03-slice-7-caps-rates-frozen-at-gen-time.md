---
title: Stock caps and refill rates frozen at world-gen time; multipliers retune affects new worlds only
date: 2026-05-03
status: ratified
tags: [decision, slice-7, save-semantics, determinism]
---

# Stock caps and refill rates frozen at world-gen time; multipliers retune affects new worlds only

## Decision
Stock caps and refill rates are computed once at world-gen time (from `Good.base_*` * tag multipliers per node) and **persisted in the save** alongside stock levels and accumulators. They are not recomputed on load. Retuning the `WorldRules` tag multiplier table (`STOCK_CAP_MULT_PLENTIFUL`, etc.) affects **new worlds only**; existing saves keep their as-generated caps and rates.

The persisted dict shape per node:

```
"stock_caps":           {good_id: int}
"refill_rates":         {good_id: float}
"stocks":               {good_id: int}
"refill_accumulators":  {good_id: float}
```

## Reasoning
The deterministic-price-drift contract (`2026-04-29-deterministic-price-drift`) says world state is reproducible from seed and tick. Recomputing caps and rates on load would silently change a saved world's behaviour if a multiplier is retuned later, breaking the reproducibility guarantee and creating a class of "save loaded with different stock economy than it was saved with" bugs that are nearly impossible to attribute.

Freezing the stock economy at gen-time gives:
- Determinism: a saved world's stock behaviour is fixed by its seed and the multipliers active at gen-time, not by whatever tuning is current at load-time.
- Tuning safety: bias-spread or refill-rate retuning can land in main without retroactively destabilising live saves.
- Migration path: when the multiplier table changes, new worlds pick up the change at generation; old worlds keep their authored values; players who want the new tuning regenerate (Begin Anew).

## Alternatives considered
- **Recompute caps/rates on load from base values and tags** -- rejected per the determinism argument.
- **Persist only stocks and accumulators; recompute caps and rates** -- same rejection; the recompute would still happen at load-time.
- **Re-derive at load and warn if values change** -- rejected: noisy warnings, plus the warning doesn't fix the determinism break.

## Confidence
High. Architect call ratified explicitly; matches the determinism contract.

## Source
Architect handoff §1 Q3 (cap and rate storage).

## Related
- [[2026-04-29-deterministic-price-drift]] -- the determinism contract this preserves
- [[2026-05-03-slice-7-tag-multipliers-load-bearing]] -- the multipliers whose results are frozen here
- [[2026-05-03-slice-7-schema-bump-coalesces-cargo-capacity]] -- the schema bump that adds these fields to the save
