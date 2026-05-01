---
title: B1 Test Protocol — HTML5 Refresh-Mid-Travel Smoke Test
date: 2026-05-01
type: runbook
tags: [b1, web-export, save-system, test-protocol, slice-1]
---

# B1 Test Protocol — HTML5 Refresh-Mid-Travel Smoke Test

**Purpose.** B1 verifies that a browser refresh during travel on the HTML5 export resumes the slice's save state to one of two acceptable post-refresh states without corrupting world or trader data.

This runbook is the human half of B1. The Architect has finalized a split harness: in-code predicates catch 5 of the 12 enumerated failure modes (plus partial coverage of FM7 tick-desync — see §1 caveat); the remaining modes are caught by the tester via pre/post-refresh comparison against the snapshot table in §4.

---

## 1. Pass criteria summary

A B1 iteration **passes** if and only if the post-refresh state matches **exactly one** of:

- **(A) Mid-travel resume.** `trader.travel` is non-null with the same `from_id`, `to_id`, and `cost_paid` as pre-refresh; `ticks_remaining` ≤ pre-refresh value; `trader.location_node_id` is `null`; `trader.gold` is the post-departure value; `world_seed`, node prices, and edges are byte-identical to pre-refresh snapshot.
- **(B) Origin rollback.** `trader.travel` is `null`; `trader.location_node_id` equals pre-refresh `travel.from_id`; `trader.gold` is the pre-departure value (cost refunded because the departure tick never durably flushed); `world_seed`, node prices, and edges are byte-identical to pre-refresh snapshot.

Anything else — partial state, regenerated world, ghost gold, kept inventory with reverted location, etc. — is a **fail**.

> **Caveat re: FM7 (tick desync).** Monotonic-tick enforcement was deferred to B2 by Director ruling. As a result, FM7 is now **partial harness coverage**: P5 catches negative ticks, but the harness does not enforce strict monotonicity across the boundary. Tick-consistency-with-branch is checked manually in §6 item 4.

---

## 2. Step 0 — COOP/COEP verification

This step gates whether the rest of B1 is even meaningful. SharedArrayBuffer (used by Godot's HTML5 export) requires cross-origin isolation. If the served HTML lacks the right headers, the canvas may still render but threading/IndexedDB behavior diverges from the reference and B1 results will not generalize.

**Procedure:**

1. Start the HTML5 build from the local server used for B1 (the one configured by web-deployer; do not open the `.html` file directly via `file://`).
2. Open the page in a desktop browser. Open DevTools (F12 or Ctrl+Shift+I).
3. Switch to the **Network** panel. Tick "Disable cache". Hard-reload the page (Ctrl+F5).
4. Click the top-level HTML document request (the one ending in `.html` or `/`).
5. In the Headers tab, scroll to **Response Headers**. Confirm both:
   - `Cross-Origin-Opener-Policy: same-origin`
   - `Cross-Origin-Embedder-Policy: require-corp`
6. Wait for the Godot canvas to reach the **main menu**. The boot sequence must complete; a frozen splash means iteration is invalid even if headers were correct.

**Pass condition for Step 0:** both headers present AND main menu reached.

**If Step 0 fails** (either header missing or canvas does not reach main menu): **stop.** Do not run iterations 1–6. Route to web-deployer with a note specifying which condition failed (header name(s) absent or boot stall) and the exact server config used. B1 cannot proceed until Step 0 is green.

---

## 3. Pre-test setup (do once before iterations)

1. From a fresh incognito window (to ensure clean IndexedDB), boot the HTML5 build. Complete world gen so a save exists.
2. Open DevTools → Application → IndexedDB → `/userfs` (Godot's HTML5 mount). Confirm `save.json` is present.
3. Note the `world_seed` and the three node ids + their wool prices from the in-game UI or via DevTools Console (`Game.world.nodes` if exposed in debug). Record these in the §4 table.
4. Keep the DevTools Console panel visible during all iterations — the harness writes there.

---

## 4. Pre-refresh snapshot table

Fill one row per iteration before pressing F5 / closing tab. Compact form for inventory: `wool:N` (slice has 1–2 goods per spec §6; if the slice has both wool and a second good, use `wool:N,good2:N`).

| # | Refresh timing                | Pre-refresh `gold` | Pre-refresh `inventory` | Pre-refresh location or `travel.from→to` | Pre-refresh `tick` | Pre-refresh `travel.cost_paid` | `world_seed` | Node A id : wool price | Node B id : wool price | Node C id : wool price |
|---|-------------------------------|--------------------|-------------------------|------------------------------------------|--------------------|--------------------------------|--------------|------------------------|------------------------|------------------------|
| 1 | F5 at tick 0 of travel        |                    |                         |                                          |                    |                                |              |                        |                        |                        |
| 2 | F5 at mid-window (~half ticks)|                    |                         |                                          |                    |                                |              |                        |                        |                        |
| 3 | F5 at tick N-1 of travel      |                    |                         |                                          |                    |                                |              |                        |                        |                        |
| 4 | Tab close (X), reopen tab     |                    |                         |                                          |                    |                                |              |                        |                        |                        |
| 5 | F5 in incognito window        |                    |                         |                                          |                    |                                |              |                        |                        |                        |
| 6 | F5 while idle at node (control)|                   |                         | (location, no travel)                    |                    | —                              |              |                        |                        |                        |

**Note.** Iteration 6 is an idle-at-node control. It anchors that "ordinary" refresh (no travel in progress) is non-destructive; without it, a passing iterations-1–5 result cannot distinguish "travel resume works" from "refresh always wipes to a benign state".

---

## 5. Per-iteration test protocol

For each iteration row, follow the four phases below. The harness predicates referenced by `[Pn]` are the Architect's six in-code predicates (numbering: P1–P6 in execution order on boot). Failure modes referenced by `[FMn]` are the Designer's twelve from the prior B1 spec.

### Phase 1 — Stage the pre-refresh state

| Iter | Stage action |
|------|--------------|
| 1    | Start from idle at Node A. Press "Travel to B". Confirm. Do **not** wait for any tick. Refresh immediately (target: durable save reflects either pre-departure or first-tick state). |
| 2    | Start travel A→B. Wait until `ticks_remaining` ≈ `distance/2`. Refresh. |
| 3    | Start travel A→B. Wait until `ticks_remaining == 1` (display: `Travelling: 1 tick remaining`). Refresh. |
| 4    | Start travel A→B. Wait to mid-window. Close the browser tab via the X button (do **not** F5). Reopen the same URL in a new tab of the same browser profile. |
| 5    | In an incognito window: start a fresh game (will generate a new world; record its seed in row 5). Travel A→B to mid-window. F5. (Incognito IndexedDB is per-session — this iteration verifies that "no durable save" is handled cleanly, not that a prior save survives.) |
| 6    | Idle at Node A (no travel). F5. |

### Phase 2 — Record pre-refresh observables

Before triggering the refresh, fill the row in §4 by reading from the in-game UI (gold, inventory, current location or travel destination) and from DevTools Console (`Game.world.trader.travel.cost_paid`, `Game.world.world_seed`, `Game.world.tick`, `Game.world.nodes[i].prices.wool`). Confirm row is complete; an unfilled cell is a tester error, not a system failure.

### Phase 3 — Trigger the refresh

Per Phase-1 column. F5 for iters 1, 2, 3, 5, 6; tab-close-and-reopen for iter 4.

### Phase 4 — Read post-refresh observables and judge

After the canvas reaches main menu / in-game UI:

1. **Read post-refresh state** from in-game UI and Console: `gold`, `inventory`, `location_node_id`, `travel` (whole object or `null`), `tick`, `world_seed`, all three node prices.

2. **Watch the Console for harness output.** The harness runs on `world_loaded` and prints one line per predicate.

3. **Apply harness predicates [P1–P6].** These are checked automatically by the harness; tester only confirms which ones flagged in the browser console. The expected predicates, in order, are:
   - **P1 — Mutex.** Exactly one of `trader.travel`, `trader.location_node_id != ""` is set. Catches **FM5** (limbo: trader is simultaneously in-travel and at a node, or neither).
   - **P2 — Travel state validity.** If `trader.travel != null`: `from_id` and `to_id` both exist in `world.nodes`, the edge between them exists, `0 < ticks_remaining ≤ edge.distance`, and `cost_paid ≥ 0`. Catches **FM6** (phantom travel: travel record points at non-existent nodes/edges or has impossible counters).
   - **P3 — Schema version.** `world.schema_version == 1`. Catches **FM11** (silent schema bump: save loaded under a version mismatch the migration layer didn't trip).
   - **P4 — Death-state consistency.** If `world.dead == true`: `world.death != null`, `trader.gold == world.death.final_gold`, and `world.death.cause` is non-empty. Catches **FM12** (death-state injection: dead flag without a coherent death record, or final_gold drift between trader and death record).
   - **P5 — Non-negative integers, no zero-quantity inventory.** All ints non-negative (`gold`, `age_ticks`, `tick`, every `inventory[good]`, every `nodes[].prices[good]`); `inventory` contains no keys whose value is zero. Catches **FM7 partial** — negatives only. Tick-consistency aspects of FM7 are handled in §6 item 4.
   - **P6 — History integrity.** `history.size() ≤ 10` AND every `node_id` referenced in any `history[].detail` (parsed from arrow-form strings like `"hillfarm→rivertown"`) resolves in `world.nodes`. Catches **FM8** (history referential integrity + history cap exceeded).

4. **Apply manual checklist (§6).** The harness covers single-boot invariants only. §6 covers FM1, FM2, FM3, FM4, FM9, FM10 (fundamentally pre/post comparisons), plus FM7 tick-consistency-with-branch and FM10 seed-level world regen.

5. **Verdict per iteration.** Pass = state matches branch (A) or branch (B) from §1, AND no harness violations, AND no manual-checklist violations. Otherwise fail; record which mode(s) tripped.

---

## 6. Manual-comparison checklist (the modes the harness cannot catch)

The harness in §5 evaluates only the post-refresh state in isolation. Several failure modes only manifest as a *change* between pre-refresh and post-refresh state and must be checked manually against the §4 snapshot table.

For each item below, compare the value recorded in the §4 snapshot (pre-refresh) against the value visible in-game or in the DevTools Console (post-refresh). Record PASS/FAIL and notes in the §9 outcome table.

1. **Location continuity (branch-dependent).**
   - Branch (A) resume: post-refresh either still in-travel on the same edge (with `ticks_remaining` consistent with elapsed time), or arrived at `to_id` from snapshot.
   - Branch (B) rollback: post-refresh located at the snapshot's `travel.from_id`, with no active travel.
   - Anything else (e.g. teleported to a third node, in-travel on a different edge) is FAIL.
   - **FM coverage:** FAIL is FM1/FM2-adjacent depending on direction.

2. **Gold continuity.** Reconstruct `pre_departure_gold` from the snapshot row as `pre-refresh gold + pre-refresh travel.cost_paid` (per slice spec §5: gold is deducted exactly once at departure, so when travel is non-null at snapshot time, the recorded gold is post-departure; adding `cost_paid` back yields the pre-departure value). Then:
   - Branch (A): post-refresh gold equals pre-refresh gold (the post-departure value persisted).
   - Branch (B): post-refresh gold equals the reconstructed pre-departure value (`pre-refresh gold + pre-refresh travel.cost_paid`); gold rolls back because the departure deduction never durably flushed.
   - Any other value is FAIL.
   - **FM coverage:** FAIL is FM2 (free travel-back: refunded more than `cost_paid`) or FM4 (cost-keep rollback: refunded less than `cost_paid`).

3. **Inventory continuity.** The slice has no buy-during-travel verb, so pre-departure inventory equals pre-refresh inventory in iters 1–5. Post-refresh inventory must match pre-refresh inventory exactly for both branches. Any new or missing goods, or quantity drift, is FAIL.
   - **FM coverage:** FAIL is FM3 (goods-keep rollback).

4. **Tick consistency.** Compare pre-refresh `tick` (from §4 snapshot) against post-refresh `tick`.
   - Branch (A) resume: post-refresh tick equals pre-refresh tick (the snapshot is taken between tick boundaries; the durable tick on disk reflects the most recent tick advance, and resuming mid-travel does not re-advance it).
   - Branch (B) rollback: post-refresh tick also equals pre-refresh tick — but for a different reason: per save format §3, the IndexedDB flush is bound to the tick-advance write point, and in branch (B) the very tick advance that would have made the post-departure state durable is the one that did not flush, so the durable tick is unchanged from the pre-confirm state. Both branches therefore predict `post-refresh tick == pre-refresh tick`; any drift is FAIL.
   - (Note: this analysis assumes the slice's flush model writes only at tick-advance boundaries, not on travel-confirm. If the Engineer adds a flush on confirm — making the post-departure state durable before the first travel tick — `pre_departure_tick` becomes a distinct reconstructible value, and the tester must additionally record the pre-confirm durable tick by reading `user://save.json` immediately before pressing Confirm. Flag this to the Architect if the implementation diverges.)
   - **FM coverage:** FAIL here is FM7-adjacent (tick state inconsistent with chosen recovery branch).

5. **World seed equality.** Compare pre-refresh `world_seed` (from §4 snapshot) against post-refresh `world_seed`. Any inequality is FAIL.
   - **FM coverage:** FAIL here is FM10-adjacent (world regen at the seed level — the deserializer or recovery path silently re-rolled the world). **Note:** Architect's P-list does not cover seed equality in the harness at all. This manual check is the only line of defense for FM10 at the seed level.

6. **Node graph stability (spot check).** For each of the three node IDs from the §4 snapshot, confirm post-refresh existence and same wool prices. In branch (B) iterations and iter 6 (idle), prices must be byte-identical. In branch (A) iterations where ticks have advanced post-load, prices may have drifted per the deterministic formula in slice spec §5 — confirm the seeded RNG output matches; any divergence is FAIL.
   - **FM coverage:** FAIL is FM10 (regen preserving IDs but mutating topology or prices).

If any of items 1–6 FAIL, the B1 run FAILS regardless of harness output.

**FM9 (selective revert)** is implicitly caught by 1–5 together: if some fields look like branch (A) and others like branch (B), the union of checks 1, 2, 3 will flag it. Record selective-revert observations in §9 notes for clarity.

---

## 7. Interpreting harness output

The harness build prints one line per predicate to the JS console after every world load, in the form:

```
[B1 harness] PASS P1
[B1 harness] PASS P2
[B1 harness] FAIL P3: schema_version == 2, expected 1
...
```

Expected output on a clean PASS run: six lines, all `PASS P1` through `PASS P6`, in order.

On any FAIL, the line takes the form `[B1 harness] FAIL Pn: <reason>` where `<reason>` is the harness's short diagnostic. Record the full FAIL line verbatim in the §9 outcome notes — do not paraphrase, the diagnostic text is the bug report.

**FAIL → user-facing behavior.** When any predicate fails, the harness build also surfaces a toast in the running game with the text:

> Save was corrupted — beginning anew

and re-initializes a fresh world. The tester should confirm this toast appears on every harness FAIL and that the post-toast world is in fact a fresh-start state (no inventory, starting gold, default location). Absence of the toast on a FAIL is itself a secondary bug — log it in §9.

**Mapping to FMs (recap from §5):** P1→FM5, P2→FM6, P3→FM11, P4→FM12, P5→FM7-partial (negatives), P6→FM8. FMs not covered by the harness (FM1, FM2, FM3, FM4, FM7-tick-consistency, FM9, FM10) are the §6 manual checklist's responsibility. If a §5 harness run is all-PASS but a §6 manual item FAILs, the B1 run still FAILS — the harness is not the sole arbiter.

Multiple simultaneous FAILs are possible and should all be recorded; do not stop at the first FAIL.

---

## 8. What B1 explicitly does NOT verify

Reproduced from the prior B1 spec deferral list:

- Hash byte-stability across HTML5/desktop builds (deferred — verified separately in a future protocol).
- FIFO ordering of the `history` ring buffer on resume (deferred).
- Multi-tab behavior — two tabs of the same origin sharing IndexedDB (deferred).
- Long-session IndexedDB quota exhaustion (deferred — slice save is far below any reasonable quota).
- Mid-trade refresh (refresh during the buy/sell modal between the gold debit and the inventory credit — slice trade is synchronous and atomic, but cross-browser reality may differ; deferred).
- Cross-browser parity — B1 is run on one browser on desktop. Firefox/Safari/mobile-browser parity is a separate sweep, not part of B1.

---

## 9. Outcome recording

Append the B1 result to the session note for the session that runs B1. The Session Summarizer will produce that note at end-of-session per the standing workflow; do not create a separate B1-results artifact.

Format for the appended block (paste into the session note's "Notes" or a new "B1 results" subsection):

```
## B1 results — <YYYY-MM-DD>

Step 0: pass / fail (if fail, route + halt)

| Iter | Branch (A/B/—) | Harness verdict | Manual checklist verdict | Overall |
|------|----------------|-----------------|--------------------------|---------|
| 1    |                |                 |                          |         |
| 2    |                |                 |                          |         |
| 3    |                |                 |                          |         |
| 4    |                |                 |                          |         |
| 5    |                |                 |                          |         |
| 6    |                |                 |                          |         |

Failure notes: <FMn / Pn references and observed values, or "none">
Build under test: <release | debug>, commit <sha>
Browser: <name + version>
```

If any iteration fails, the session note's "Open threads" should carry the failure forward; B1 is not "done" until a clean pass run is recorded.
