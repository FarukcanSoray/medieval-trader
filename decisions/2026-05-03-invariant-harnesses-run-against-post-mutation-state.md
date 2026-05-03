---
title: Invariant harnesses must run against post-mutation state, not bootstrap state
date: 2026-05-03
status: ratified
tags: [decision, testing, invariants, pattern]
---

# Invariant harnesses must run against post-mutation state, not bootstrap state

## Decision
Invariant harnesses (B1 in this project; future ones will follow) must run their checks against the state the invariants are *meant to validate*, not just against the state immediately after `Game.bootstrap`. When an invariant depends on accumulated state (travel history, encounter outcomes, dirty flags, anything that gets populated *during* gameplay rather than *at* boot), running the harness only at boot makes that invariant vacuous and the bug it's meant to catch invisible.

Concretely:

1. **Bootstrap-time runs catch boot-shape bugs.** Schema mismatches, structural corruption, freshly-generated invariants -- these are validated correctly at the boot site.
2. **Post-mutation runs catch interaction bugs.** Invariants on accumulated state -- history integrity, mutex preservation across travel arrival, encounter-outcome consistency -- need to run after a representative mutation has occurred. Otherwise the check passes vacuously and the bug ships.
3. **The harness driver is the layering seam.** When a slice ships a new invariant harness (or extends an existing one), the harness driver -- not the production bootstrap -- decides which invariants run at which lifecycle points. Layered runs (bootstrap + post-mutation) are the right shape; never collapse into one site.

For B1 specifically, this means the slice-5.x test driver re-runs `SaveInvariantChecker.check(Game.trader, Game.world)` after the 5.x checks have populated travel history via simulated buy + travel-arrival. The post-travel run catches P6-shaped regressions where the bootstrap-time run was vacuous.

## Reasoning
The slice-5.x case made this concrete. P6 (`_check_history_integrity`) had been broken since slice-3 or slice-4 introduced display-name detail strings, but no one noticed because:

1. B1 ran in `Game.bootstrap`, immediately after `SaveService.load_or_init` populated `Game.world` from disk.
2. At that moment, `world.history` was either empty (fresh game) or the freshly-loaded history from disk -- but in the slice-5 era, save corruption was so common (Bug B) that travel history rarely persisted across loads.
3. P6 only checks travel-kind history entries (`if h.kind != "travel": continue`). With no travel history present, P6 was vacuous.
4. The check *was* there; it just had nothing to check against.
5. Once slice-5.x's atomic write + discrete commit points reliably persisted travel history on every load, P6 finally had something to validate -- and immediately tripped on the broken lookup.

The fix isn't just "fix P6" -- it's also "make sure invariants like P6 run when their inputs exist." The harness driver now re-runs B1 after the 5.x checks complete (which by then have driven a buy + travel-arrival, populating the history). The post-run is non-vacuous; future regressions of P6-shaped bugs (invariants on accumulated state) get caught immediately.

This is a testing principle, not just a slice-5.x patch. Future slices that add invariants on accumulated state must:

- Identify what state the invariant validates.
- Confirm the harness drives a representative mutation that exercises that state.
- Re-run the invariant check after the mutation, not just at bootstrap.

If the invariant validates *only* freshly-generated state (e.g., schema_version, fresh-world structural shape), bootstrap-time runs are sufficient. The discriminator is "does the invariant's pass/fail depend on what happened *between* boot and now?"

## Alternatives considered
- **Move B1 entirely to post-mutation, drop the bootstrap-time run.** Rejected: B1 also catches schema and structural bugs that should fire *before* the player gets any time on the world. Bootstrap-time is the right site for those checks; post-mutation is the right site for accumulated-state checks; both layers are needed.
- **Run B1 every tick during gameplay (continuous validation).** Rejected: prohibitive runtime cost (B1 scans all nodes/edges/history each call). Layered checkpoints (bootstrap + post-key-action) capture the value at a fraction of the cost.
- **Add a separate "post-mutation invariant harness" class.** Rejected: B1 already has the right predicates; the issue is *where* it runs, not *what* it checks. A new class would duplicate predicates and create drift.
- **Defer the lesson to a documentation-only entry, no code change.** Rejected: the lesson without the codified harness pattern leaves future slices to re-derive it. The slice-5.x harness driver now demonstrates the pattern in code; this decision documents *why*.

## Confidence
High. The principle is concrete and testable: vacuous invariant checks ship undetected bugs; post-mutation runs catch them. The slice-5.x case is the empirical proof. The pattern (layered runs at lifecycle checkpoints) is small enough to apply to every future invariant harness without ceremony.

## Source
Slice-5.x harness extension (`godot/systems/save/save_persistence_test.gd`): driver re-runs `SaveInvariantChecker.check` after the four 5.x checks populate accumulated state. P6 specifically validated by the post-travel run; bootstrap-time run remains for schema/structural shape.

## Related
- [[2026-05-03-slice-5x-ships-save-persistence-restored]] -- the slice this pattern was first applied to
- [[2026-05-01-save-invariant-checker-harness-no-autoload]] -- the prior decision that put B1 at boot site only; this decision adds the *post-mutation* run as a second layer, not a replacement
- [[2026-05-01-b1-scope-12-failure-modes-5-harness-catchable]] -- B1's original scope; this decision tightens *when* the catchable predicates fire
