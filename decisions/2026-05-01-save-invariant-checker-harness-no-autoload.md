---
title: SaveInvariantChecker as RefCounted static harness, called from Game.bootstrap()
date: 2026-05-01
status: ratified
tags: [decision, architecture, save-system, b1]
---

# SaveInvariantChecker as RefCounted static harness, called from Game.bootstrap()

## Decision

Save-invariant checking ships as a thin in-code harness:

- **`SaveInvariantChecker`** — `class_name SaveInvariantChecker extends RefCounted`, with `static func check(trader: TraderState, world: WorldState) -> InvariantReport`. Pure function, no Node, no scene.
- **`InvariantReport`** — `class_name InvariantReport extends Resource`, with `@export var ok: bool` and `@export var violations: Array[String]`.
- **Invocation site**: inside `Game.bootstrap()`, immediately after `_save_service.load_or_init()` returns, before `_bootstrapping = false` and before `Main._ready()` paints panels.
- **No new autoload, no new signals, no new exports, no schema bump.** One-autoload rule preserved (`Game` remains the only autoload).

The harness covers six predicates (P1–P6): mutex, travel state validity, schema version, death-state consistency, non-negative ints, history referential integrity (parsing arrow-form strings in `history[].detail`).

## Reasoning

The harness exists to catch a kernel-level invariant on every boot, not as one-off bug hunting. Architect framed it: manual-only would mean every future Engineer touch to save/load re-runs the predicates by eyeball; an in-code harness converts B1 from a smoke test into a regression-resistant invariant gate.

The shape choices follow from the load: the function takes two Resources and returns a Resource, so a `RefCounted` with a static method is the right footprint — no lifecycle, no children, no signals. A Node would force a tree-placement question for zero benefit. A new autoload violates the one-autoload standing rule. A `Resource` for the report is correct because typed `Array[String]` survives serialization if reports are ever captured across boots.

The invocation site is load-bearing: putting the check inside `Game.bootstrap()` (before `await Game.bootstrap()` returns to `Main._ready`) means a corrupted dead-record is caught before the death-screen branch fires on it. Moving the call into `Main._ready` "for cleanliness" would break this property.

P6 (history referential integrity) parses arrow-form strings (`"hillfarm→rivertown"`) out of `history[].detail` rather than schema-bumping to add `from_id`/`to_id` fields. Brittle is acceptable here because exactly one writer (`TravelController._push_travel_history`) authors the format.

## Alternatives considered

- **Manual-only (no harness)**: rejected. Repeats every save/load touch as eyeball checks; B1 would not be regression-resistant.
- **Node-based or scene-based harness**: rejected. Nothing about the function needs lifecycle or tree placement.
- **New autoload**: rejected. Violates one-autoload standing rule.
- **Schema bump to add structured fields to history entries**: rejected. The slice's "discard and regenerate on schema mismatch" posture depends on not doing migrations; arrow-string parsing avoids the bump.

## Confidence

High. Shape and site are both load-bearing; alternatives have explicit rejection reasons.

## Source

- Architect's first pass (harness shape, invocation site, boundary).
- Architect's revision (P6 arrow-string parsing in lieu of schema bump).

## Related

- [[2026-04-29-one-autoload-only-game]] — preserved
- [[2026-04-29-resource-not-autoload-state]] — TraderState/WorldState as Resources, the harness's inputs
- [[2026-05-01-save-corruption-regenerate-release-build]] — the harness's failure-handling branch
- [[2026-05-01-b1-runbook-no-schema-bump]] — schema-stability constraint that drives P6's parsing approach
- [[slice-architecture]]
