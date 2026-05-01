---
date: 2026-04-29
type: session
tags: [session, architect, engineer, tier-1]
---

# Architect pass + Tier 1 data foundation

## Goal

Pick up the slice pipeline at "Designer-complete." Run the Scene Architect on `slice-spec` §9, resolve the open questions it surfaces, and ship Tier 1 (the data Resources) of the Engineer's handoff list — bottom-up, no shortcuts.

## Produced

- [[slice-architecture]] — autoload roster (one: `Game`), annotated scene trees for `main.tscn` and `death_screen.tscn`, signal routing table for the four §9 cross-system signals, state-ownership decisions (Resources held on Game), save lifecycle, folder layout, and the 23-file 7-tier Engineer handoff list.
- [[slice-spec]] patched — death-cause literal changed from `"bankruptcy"` to `"stranded"` (§5, §11); §11 open questions all marked resolved.
- Tier 1 in code: `godot/project.godot` (GL Compatibility renderer, no autoload yet, no main scene yet); the folder skeleton from `slice-architecture` §6; eight `Resource` scripts (`Good`, `NodeState`, `EdgeState`, `HistoryEntry`, `DeathRecord`, `TravelState`, `TraderState`, `WorldState`); two authored goods (`wool.tres`, `cloth.tres`).

## Decisions

**Architecture (Architect → ratified):**
- [[2026-04-29-one-autoload-only-game]]
- [[2026-04-29-resource-not-autoload-state]]
- [[2026-04-29-callable-injection-resource-mutators]]

**Open-question resolutions (Director / Designer):**
- [[2026-04-29-death-cause-stranded]]
- [[2026-04-29-slice-two-goods]]
- [[2026-04-29-tick-granularity-per-step]]

**Engineering contract (surfaced during Tier 1 build + review):**
- [[2026-04-29-strict-reject-from-dict]]
- [[2026-04-29-trader-travel-location-mutex]]
- [[2026-04-29-rename-floor-ceiling-price]]

**Process:**
- [[2026-04-29-bottom-up-no-sanity-scene]]

## Open threads

- **Tier 2 next: `godot/game/world_gen.gd`.** Script-only, static `generate(seed: int, goods: Array[Good]) -> WorldState`. Produces 3 nodes, 3 triangle edges, seeds initial prices per `slice-spec` §5 formula. Asserts edge validity via `EdgeState.is_valid()`. Engineer's natural next pickup.
- **Project not runnable until Tier 7.** `run/main_scene` stays empty until `main.tscn` lands at the end of the bottom-up build. F5 in the editor will fail with "no main scene" — expected, ratified per [[2026-04-29-bottom-up-no-sanity-scene]].
- **`.tres` UID lines deferred.** `wool.tres` and `cloth.tres` were hand-authored without `uid=`; Godot will regenerate them on first editor open. Code Reviewer flagged this as a cleanup pass before Tier 3, not blocking now.
- **Tuning numbers in `slice-spec` §6 still `[needs playtesting]`.** Carried from kickoff. Set during/after first slice run once Tier 7 is live, not from desk.

## Notes

The load-bearing call this session was [[2026-04-29-callable-injection-resource-mutators]] — a deliberate push-back on `slice-spec` §9's implication that signals would come from `TraderState` itself. Resource-declared signals don't survive serialization in Godot 4, and the slice rebuilds `TraderState` from JSON on every load; signals on the resource would force every subscriber to re-connect after every load. The mitigation (signals on `Game`, mutators take `Callable` parameters that `Game` injects) preserves §9's ownership claim while sidestepping the re-wiring footgun. This pattern ripples through the signal routing table, the SaveService coalesce design, and the `setup(trader, world)` injection shape every gameplay node uses. It's the kind of structural call that's easy to lose and expensive to retrofit; logging it now.

The second-most-consequential call was [[2026-04-29-strict-reject-from-dict]] — extending `slice-spec` §8's "schema mismatch → discard, new world" to *all* structural corruption uniformly. The Code Reviewer surfaced the gap (best-effort recovery had crept in); the user ratified the cleaner contract. Two `from_dict` methods, one rule: any corruption returns `null`, SaveService regenerates. The careful-merchant fantasy doesn't have partial recovery, and now neither does the save format.
