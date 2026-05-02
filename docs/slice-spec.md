# Medieval Trader — Vertical Slice Spec

> **Ratified slice decisions (2026-04-29):**
> - **3 nodes** in the slice (lets the player make a choice — closer to the real loop than 2-node A↔B).
> - **Let it ride** on price asymmetry — no enforced guarantee that prices for the same good stay non-identical across nodes. Transient flat-market ticks are accepted; the slice's job is to find out in playtest whether they feel bad.
> - **Zero encounters** in the slice (kernel testable without them; deferred to second pass).
> - **One death cause** in the slice: stranded (out of gold, cannot afford to travel from current node). Director call 2026-04-29: cause label is `"stranded"`, not `"bankruptcy"`.

## 1. Pattern reference

This is a stripped **Offworld Trading Company / Patrician** node-graph arbitrage loop, with the *Sunless Sea* punctuation grammar (one life, ledger-on-death). The slice deviates from all three: no production chains (OTC, Patrician), no narrative tissue (Sunless), no real-time pressure. The closest exact ancestor is the trade subgame inside *Pirates!* — pick port, see prices, sail, pay travel cost, sell — minus the combat and fame layers.

## 2. Core loop (one slice session)

Player spawns at Node A with starting gold. UI shows the prices of the slice's good at A. Player selects "travel to Node B" (one of the available neighbours). A travel cost preview shows gold and tick cost. Confirm. Tick advances by edge length; gold deducted; arrival animation is a label change. Node B's price for the good is now visible. Player buys, travels back to A or onward to C (prices have drifted during the trip), sells, banks the spread. Player ages. Loop repeats until gold hits zero on a travel attempt — death screen.

The kernel is touched on every round trip: profit on the spread minus travel cost. If travel cost > spread, the player learns to wait or pick a different round.

## 3. Save format contract (specified first — every system reads/writes this)

Single JSON blob, written via `FileAccess` to `user://save.json`. On HTML5, Godot maps `user://` to IndexedDB automatically — no extra code, but **flush is not synchronous**; write must complete before any code that assumes durability runs. Wrap writes in `await` of a one-frame yield after `store_string`, then verify on next boot.

```
{
  "schema_version": 2,
  "world_seed": <int>,
  "tick": <int>,
  "trader": {
    "gold": <int>,
    "age_ticks": <int>,
    "location_node_id": <string>,        // null while travelling
    "travel": null | {
      "from_id": <string>,
      "to_id": <string>,
      "ticks_remaining": <int>,
      "cost_paid": <int>
    },
    "inventory": { "<good_id>": <int> }  // ints only, no floats
  },
  "nodes": [
    { "id": <string>, "name": <string>, "pos": [<float>, <float>],
      "prices": { "<good_id>": <int> } }
  ],
  "edges": [ { "a_id": <string>, "b_id": <string>, "distance": <int> } ],
  "history": [                            // ring buffer, max 10
    { "tick": <int>, "kind": "buy"|"sell"|"travel", "detail": <string>, "delta_gold": <int> }
  ],
  "dead": false,
  "death": null | { "tick": <int>, "cause": <string>, "final_gold": <int> }
}
```

Read points: SaveService loads on boot. Write points: end of every tick advancement, on quit (`NOTIFICATION_WM_CLOSE_REQUEST`), and immediately after death. Prices are stored, not regenerated, so a refresh mid-travel doesn't reroll the world. All numbers are integers — no float drift across save/load.

## 4. Inputs/outputs per system

| System | Reads | Writes | Tick events |
|---|---|---|---|
| **Map (gen)** | `world_seed` | `nodes`, `edges` (once at world birth) | none after gen |
| **Goods catalogue** | hardcoded `.tres` files | nothing | none |
| **Price model** | `nodes[].prices`, `tick` | `nodes[].prices` | on every tick |
| **Travel** | `trader.location_node_id`, edge distance, `trader.gold` | `trader.travel`, `trader.gold`, `trader.location_node_id` | advances tick by 1 per step |
| **Save** | full state | full state to `user://save.json` | end of tick, on quit, on death |
| **Aging** | `tick` | `trader.age_ticks` | +1 per tick |
| **Death** | `trader.gold`, `trader.travel.cost_paid` (preview) | `dead`, `death` | checked after every gold mutation |
| **Death screen** | `death`, `history`, `trader.age_ticks` | nothing | terminal state |

There is no encounter system in the slice (see §10).

## 5. Rules

**Travel state machine.** `IDLE` → (player confirms travel, gold ≥ cost) → `TRAVELLING(ticks_remaining = distance)` → on each tick: `ticks_remaining -= 1`. When 0, transition to `IDLE` at destination. Gold is deducted **once at departure**, not per tick — this matches "travel costs bite" and avoids per-tick stranding ambiguity.

**Tick advancement.** Ticks advance only on player-initiated travel. Idle-at-node does not advance ticks. (Slice constraint — keeps the kernel pure; "wait at node" is a deferred verb.)

**Price drift formula.** Per tick, per node, per good:
`new_price = clamp(old_price + round(randf_range(-drift, drift) * old_price), floor, ceiling)`
where `drift` is the per-tick fraction, and `floor`/`ceiling` are per-good identity bounds (set in the good's `.tres`). Seed the RNG with `hash(world_seed, tick, node_id, good_id)` so prices are deterministic on reload.

**Death trigger.** Checked immediately after any gold deduction. If `gold < 0` would result, the deduction is rejected and a softer rule fires: at travel confirm, if `gold < travel_cost`, the travel button is disabled. If `gold == 0` and the player is at a node where they cannot afford to buy and cannot afford to travel anywhere, they are **stranded** — death triggers with cause `"stranded"`. This is the slice's death cause (Director call, 2026-04-29).

**Worked arbitrage example (proves kernel in slice).**
- Good: wool. Floor 5, ceiling 25, base price 12.
- Node A (Hillfarm) start price: 8. Node B (Rivertown) start price: 18. Edge distance: 4. Travel cost: 4 × 3 = 12.
- Round trip: buy 10 wool at A for 80g, travel to B (−12g), sell 10 at 18 → +180g, travel back (−12g). Net: +76g over 8 ticks.
- If drift pushes B's price down to 14 mid-trip, sale yields +140g, net +36g — still profitable but visibly thinner. **The collision is testable.** If both nodes drift to 12, the round trip loses 24g — the player learns to read prices before committing.

## 6. Numbers (tuning ranges)

| Knob | Range | What it tunes / symptoms |
|---|---|---|
| Node count | **3** (ratified) | Triangle topology; first geometry that lets the player make a route choice. |
| Goods in slice | **1–2** | 1 proves the loop; 2 lets you check that the price model isn't accidentally coupling goods. Recommend 2. |
| Starting gold | 50–150 | Too low: instant stranding before learning. Too high: no pressure. |
| Base price per good | 5–25 | Wide enough that drift produces visible spreads. |
| Drift per tick | 5%–15% | Low: no arbitrage windows. High: prices feel random, kernel becomes gambling (violates Pillar 1). |
| Price floor/ceiling | ±50%–±70% of base | Prevents drift collapse to 0 or unbounded growth across long runs. |
| Edge distance | 2–6 ticks | Short enough for fast iteration, long enough that drift matters during travel. |
| Travel cost per distance | 2–5 gold | Must be tunable so cost can chew 20–50% of a typical spread — that's where the kernel lives. |
| Lifespan | 200–500 ticks | Slice doesn't need to test old-age death; cap exists only so the type doesn't overflow. |

`[needs playtesting]` for all of the above except node count and goods count, which are structural slice decisions.

## 7. Feedback (programmer-art budget)

- **Travel confirm:** Modal popup. "Travel A → B. Cost: 12g. Time: 4 ticks. [Confirm] [Cancel]." Greyed Confirm if gold < cost.
- **Tick advance during travel:** A label `Travelling: 3 ticks remaining` updates each tick. No animation.
- **Buy/sell:** Gold counter flashes green/red for 0.2s. Inventory number updates. One short beep (Godot built-in `OS.alert`-style — no audio assets in slice).
- **Price changes:** Prices simply update on the node panel. No tween, no flash. (Polish budget says no.)
- **Death:** Screen fades to black over 1s, death screen appears. Plain text on solid background.

Anything more is out of slice scope.

## 8. Edge cases and failure modes

- **Empty inventory at sell:** Sell button disabled. Not a soft error.
- **Save during travel:** `trader.travel` is non-null, `location_node_id` is null. Load resumes mid-travel with `ticks_remaining` intact. **Test this on day one.**
- **Browser refresh mid-travel:** Same as above; relies on `await` after `store_string` to ensure the IndexedDB flush completed before the player could refresh. If the player refreshes between confirm and flush, they re-emerge at the origin with full gold — acceptable rollback.
- **Gold = 0 at node:** Can't buy. Travel button disabled because cost > 0. Bankruptcy death triggers.
- **Gold = 0 mid-travel:** Can't happen — gold deducted once at departure, never per tick.
- **Distance = 0:** Edge generator must reject. Slice asserts on world gen.
- **All prices identical across nodes:** Possible due to drift symmetry. Kernel collapses, but it's a transient state that resolves on next tick. Player can't wait at a node — they must travel and lose gold to advance time. **Slice decision: let it ride.** Accept transient flat-market ticks; revisit only if playtest shows they feel bad.
- **Schema version mismatch on load:** Save discarded, new world generated. Slice doesn't do migrations.
- **HTML5 IndexedDB unavailable (private mode):** Save silently fails. Show a one-line warning. Slice does not attempt fallback.

## 9. Integration touch points (exhaustive — Critic's section)

This is the section the month-3-sinkhole warning targets. Every pair below names the **owner** of the state.

| Touch point | Systems involved | Owner |
|---|---|---|
| Tick increment | Travel (drives), Aging (consumes), Price model (consumes), Save (writes after) | **Travel** owns the tick advance call. Aging and PriceModel are *subscribers* — both read tick, neither writes it. Wire as a single signal `tick_advanced(new_tick: int)` emitted by the travel system; aging and pricing are pure functions of tick. |
| Gold mutation | Travel (deducts cost), Trade (deducts/adds), Death (checks after) | **Trader resource** owns gold. Mutations go through one method `apply_gold_delta(amount: int) -> bool` that returns false if it would go negative; Death listens to a `gold_changed` signal. No system pokes `trader.gold` directly. |
| Inventory mutation | Trade (the only writer) | **Trader resource** owns inventory. One method `apply_inventory_delta(good_id, qty)`. |
| Price snapshot read for trade UI | UI reads `nodes[location].prices` | **Map/PriceModel** owns. UI is a pure renderer; it never caches prices longer than one frame. |
| Travel cost calculation | Travel system reads edge distance | **Travel** owns formula. Edge owns only `distance`. Multiplier lives in a single tunable on the Travel system. |
| Save trigger | Tick advance, quit, death | **SaveService** subscribes; never called inline by gameplay code except on quit. One signal `state_dirty` from anything that mutates persistent state; SaveService coalesces and writes on tick boundary. |
| Death evaluation | Gold change, future age max | **DeathService** subscribes to `gold_changed`. The check (`stranded`) is one function. Death writes `dead = true` and emits `died(cause)`; everything else (UI, save) reacts. |
| Death screen population | Reads `history`, `death`, `trader` | **DeathScreen** is read-only on the trader resource. It does not mutate. |
| World gen → initial save | MapGen produces nodes/edges, PriceModel seeds initial prices, SaveService writes | **WorldGen** is a one-shot pipeline that returns a fully-populated `WorldState` resource; SaveService writes it. WorldGen never persists itself. |

The pattern: one **TraderState** resource and one **WorldState** resource hold all persistent fields. Systems are pure-ish functions over them. Cross-system communication is signal-based, never via `get_node` lookups.

## 10. Encounter decision

**Zero encounters in the slice.** Justification: the kernel is `arbitrage profit ⊥ travel cost`. Travel cost in the slice is gold-per-distance, which is sufficient to put both sides of the kernel in tension (see §5 worked example). An encounter adds a fifth subsystem (trigger roll, pause-travel screen, choice UI, outcome readback) for **zero kernel value** — the kernel is already testable. Encounters belong in the second pass, after the loop is end-to-end and the integration plumbing is proven on simpler systems first. The Critic's "four mini-systems in one coat" warning lands hard here. Defer.

## 11. Open questions

Resolved on 2026-04-29:
- ~~Enforce a guaranteed price asymmetry on the first N ticks?~~ **Let it ride for the slice.**
- ~~2 nodes or 3 in the slice?~~ **3 nodes.**

Still open:
- `[needs playtesting]` All numbers in §6, especially drift % and travel-cost-per-distance — these are the kernel's tuning surface and cannot be set from desk.
- ~~`[needs Director call]` Is "stranded with insufficient gold to travel" the same as "bankruptcy" for death-cause display, or do we name them separately later? Slice uses one cause label.~~ **Resolved 2026-04-29: cause label is `"stranded"`. Tone precedent for future death causes: single concrete past-participle states (`stranded`, `slain`, `taken by age`, `lost on the pass`), never clinical nouns.**
- `[needs Architect call]` The integration table in §9 prescribes resource-owned state and signal-based coupling. The Architect should confirm this maps cleanly to Godot autoloads vs node-tree services before the Engineer starts.
