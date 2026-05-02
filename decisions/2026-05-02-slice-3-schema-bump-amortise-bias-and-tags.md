---
title: Bias and tags ship together to amortise the schema-bump cost once
date: 2026-05-02
status: ratified
tags: [decision, slice-3, schema-management, sequencing]
---

# Bias and tags ship together to amortise the schema-bump cost once

## Decision
The schema bump from version 2 to version 3 carries both `bias` and `produces`/`consumes` field additions to `NodeState` simultaneously. Tags are not deferred to a later schema version.

## Reasoning
Critic's compression check flagged that bias and tags both extend the same Resource (`NodeState`). Splitting them across two slices (and two schema versions) would force two `from_dict` migrations and two save-discard events for testers. Doing them together pays the schema-bump cost once. The named trigger per [[2026-05-02-slice-2-no-schema-bump-trigger-named]] precedent is "regional bias and producer/consumer tags added to NodeState."

## Alternatives considered
- Schema-bump bias in slice-3, tags in a later schema-bump -- rejected as paying the migration cost twice.

## Confidence
Medium. Rationale is comparative ("twice is worse than once"); no quantified data, but the logic is sound and the operational cost is real.

## Source
Critic stress-test, hidden-cost section ("schema-bump-once-and-pay-the-cost").

## Related
- [[2026-05-02-slice-3-day-1-day-2-split]]
- [[2026-05-02-slice-3-schema-3-discard-via-toast]]
- [[2026-05-02-slice-2-no-schema-bump-trigger-named]]
