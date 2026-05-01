# Medieval Trader — Slice Architecture

## 0. Decisions summary

1. **One autoload only: `Game`** (the slice's root service node, hosting `SaveService` and acting as the EventBus for the four §9 signals). Everything else is plain `Resource` or scene-tree node — no global gameplay state.
2. **`TraderState` and `WorldState` are `Resource` subclasses**, owned by `Game` (held as plain references on the autoload). Systems get them by injection (`@export` or constructor-style `setup()`), never by `get_node` lookup.
3. **Signals fan out via `Game` (the autoload)** for the four cross-system signals named in §9. Intra-system signals stay direct. This is the EventBus pattern, scoped tightly — it earns its keep because seven systems all touch the tick.
4. **Confirming §9's resource-owned + signal-based design.** It maps cleanly to Godot. The only nuance: `Resource` cannot emit signals to nodes cleanly across save/load boundaries without re-wiring, so signals live on `Game`, not on the resources themselves. (See "Signal routing" for the cost and the mitigation.)
5. **Scene tree is two scenes: `main.tscn`** (the running game) and **`death_screen.tscn`** (terminal). Switched via `get_tree().change_scene_to_packed()` triggered by `Game` on `died`.
6. **Save lifecycle:** `SaveService` is a child node of `Game`, subscribes to `state_dirty`, coalesces, and writes once per `tick_advanced`. Quit and death writes are direct calls from `Game`, not signals.
7. **Folder structure:** feature folders under `godot/` — `world/`, `trader/`, `travel/`, `pricing/`, `goods/`, `ui/`, `systems/save/`, `systems/death/`, `shared/`.

---

## 1. Autoload roster

**Default is "no autoload."** I am adding exactly one.

| Autoload | Justification (one sentence) |
|---|---|
| `Game` (`game.gd` on a `Node`) | The slice's seven subsystems all read/write the same `TraderState`/`WorldState` and all four cross-system signals must reach them globally; one root service is the smallest expression of that. |

**Rejected autoloads and why:**

- **`SaveService` as autoload** — rejected. It only ever talks to `Game`. It is a child node of `Game` instead. No second global needed.
- **`EventBus` as standalone autoload** — rejected. Folded into `Game`. A separate EventBus would just be `Game` with extra import friction.
- **`WorldState` / `TraderState` as autoloads** — rejected. They are pure `Resource` data. Making them autoloads would mean either (a) a wrapper node holding a Resource, which is just `Game`, or (b) singleton gameplay state, which is the anti-pattern in the idioms skill. They are held as `@export var trader: TraderState` and `@export var world: WorldState` on `Game`.
- **`DeathService` as autoload** — rejected. It's a child node of `Game` next to `SaveService`. Death evaluation runs on `gold_changed` and emits `died`; that is in-tree subscription work.

**Result: one new autoload (`Game`), justified.**

---

## 2. Scene trees

### 2.1 `main.tscn` — the running game

```
Main (Node)                                          ← root, owns layout
├── World (Node2D)                                   ← visual placeholder; can be Node if no draw
│   └── (programmer-art labels per node, optional in slice)
├── TravelController (Node)            → tick_advanced(new_tick: int)
│                                       responsibilities: owns travel state machine
│                                       (IDLE/TRAVELLING), ticks the world, computes
│                                       travel cost, deducts gold once at departure.
│   [exports: trader → /root/Game.trader, world → /root/Game.world via setup()]
├── PriceModel (Node)                                ← pure subscriber to tick
│                                       responsibilities: on tick_advanced, drifts
│                                       prices on every node deterministically
│                                       (hash(world_seed, tick, node_id, good_id)).
│   [exports: world → injected via setup()]
├── Aging (Node)                                     ← pure subscriber to tick
│                                       responsibilities: on tick_advanced, +1 to
│                                       trader.age_ticks. That's it.
│   [exports: trader → injected via setup()]
└── HUD (CanvasLayer)
    ├── NodePanel (Control)                          ← shows current node + prices
    │   └── (Label, Button per good for buy/sell)    → buy_requested(good_id)
    │                                                  sell_requested(good_id)
    ├── TravelPanel (Control)                        ← lists neighbours, shows cost
    │   └── (Buttons per neighbour)                  → travel_requested(to_id)
    ├── ConfirmDialog (AcceptDialog)                 → confirmed
    │                                       responsibilities: travel confirm modal
    │                                       per §7 ("Travel A → B. Cost: 12g. Time: 4 ticks.")
    └── StatusBar (Control)                          ← gold, age, current location/travel
```

**Wiring at `_ready` on `Main`:**

- `Main._ready()` is `async`. It **`await`s `Game.bootstrap()`** (idempotent — handles editor F6; bootstrap awaits SaveService.load_or_init internally and is silent re: the four cross-system signals, so no panel sees a flash of stale state).
- After bootstrap returns, `Main` calls `setup(Game.trader, Game.world)` on `TravelController`, `PriceModel`, `Aging`, and `setup(controller)` on `TravelPanel`. (StatusBar / NodePanel / DeathScreen read `Game.trader`/`Game.world` directly per their Tier 6 contracts; ConfirmDialog needs no setup.) This is the explicit dependency injection that replaces `get_node` reaches.
- `Main` connects HUD signals (`buy_requested`, `sell_requested`, `travel_requested`, `ConfirmDialog.confirmed`) to `Trade` and `TravelController`. `Trade` is a sibling node of `TravelController` (see Engineer handoff) since trade is "deduct gold, mutate inventory" and has no children.
- `Main` connects `Game.died` to its own `_on_died` handler, which `await`s `SaveService.write_now()` then calls `get_tree().change_scene_to_packed(_DEATH_SCENE)`. The death scene is **`@export var _death_scene: PackedScene`** (Inspector-wired in `main.tscn` to `res://ui/death_screen/death_screen.tscn`); `preload()` is rejected because it creates a circular boot dependency in some editor F6 paths, and `load()` by path string defeats static typing. The `@export` is the cleanest fit.
- HUD greyout-during-travel is **handled inside the panels**: NodePanel/TravelPanel both self-subscribe to `tick_advanced` and `state_dirty` and predicate on `trader.travel != null` inside `_refresh()`. Main does NOT need to drive a refresh after each tick. Confirmed sufficient.

### 2.2 `death_screen.tscn` — terminal state

```
DeathScreen (Control)                                ← read-only on Game.trader / Game.world
├── ColorRect                                        ← solid background, fade-in via AnimationPlayer
├── AnimationPlayer                                  ← 1s fade per §7
└── Panel (Control)
    ├── EpitaphLabel                                 ← "Lived 47 years. Stranded at Rivertown with 0 gold and nowhere to go."
    ├── HistoryList (VBoxContainer)                  ← reads world.history (ring buffer, max 10)
    ├── FinalLedger (Label)                          ← final_gold, age_ticks, last_location
    └── QuitButton (Button)                          → pressed → get_tree().quit()
```

**Wiring at `_ready` on `DeathScreen`:**

- Reads `Game.trader` and `Game.world.history` directly. This is the one acceptable cross-tree reach in the slice — `DeathScreen` is read-only on a known global service and the alternative (passing the data through scene change params) is more friction than the coupling earns. Note this in the Engineer handoff so it's a deliberate exception, not a habit.

---

## 3. Signal routing

§9 names four cross-system signals. All four live on `Game` (the autoload). Within a system, signals stay direct and untouched. The table below is binding for the Engineer.

| Signal | Defined on | Emitted by | Subscribers | Wired in |
|---|---|---|---|---|
| `tick_advanced(new_tick: int)` | `Game` | `TravelController` calls `Game.tick_advanced.emit(new_tick)` after advancing `world.tick` | `PriceModel`, `Aging`, `SaveService` | Each subscriber's `_ready()` connects to `Game.tick_advanced`. |
| `gold_changed(new_gold: int, delta: int)` | `Game` | `TraderState.apply_gold_delta()` → mutates, then `Game.gold_changed.emit(...)` (via a callback `Game` injects, see note below) | `DeathService`, `HUD.StatusBar`, `SaveService` (via `state_dirty`) | `_ready()` of subscribers. |
| `state_dirty()` | `Game` | `TravelController` (post-travel-step), `Trade` (post-buy/sell), `TraderState` mutators (after gold/inventory delta) | `SaveService` only | `SaveService._ready()`. |
| `died(cause: String)` | `Game` | `DeathService` after the stranded check fires | `Main` (triggers scene change), `SaveService` (writes immediately, not coalesced) | `Main._ready()`, `SaveService._ready()`. |

**The `Resource`-cannot-easily-emit problem and how we sidestep it.**

`Resource` *can* declare signals, but resources persist via `ResourceSaver`/serialization and connections do not survive load. For the slice, mutations on `TraderState` go through methods (`apply_gold_delta`, `apply_inventory_delta`) that take a callback — `Game` passes `Game.gold_changed.emit` and `Game.state_dirty.emit` as `Callable`s on bootstrap, and `TraderState` invokes them after the mutation. Equivalent to a signal, no connection re-wiring on load, no `Resource` signal declarations needed. (The Engineer should treat this as the seam: only `TraderState` methods mutate `TraderState`, and they always notify via the injected callbacks.)

**Connection style:** all wires are code-side `signal.connect(method)` in `_ready()`. No editor-wired signals in the slice — every system needs `Game` references that aren't editor-resolvable. Use `Callable`s, not strings.

---

## 4. State ownership (Resource vs Node)

### 4.1 `TraderState` — `Resource` subclass

Lives at `godot/trader/trader_state.gd`. Held as `@export var trader: TraderState` on `Game`. **Not** a `.tres` instance on disk — instantiated in code by `WorldGen` (or rehydrated from save JSON). It exists in memory only; persistence is JSON via `SaveService`, not `ResourceSaver`.

Why `Resource` and not `Node`:
- It's pure data + small mutation methods. No children, no lifecycle.
- `@export` typing on `Game` gives the Engineer a typed handle without `get_node`.
- Custom Inspector if it ever helps; doesn't matter for slice.

Fields (mirrors §3 save contract):
- `@export var gold: int`
- `@export var age_ticks: int`
- `@export var location_node_id: String` (empty string when travelling — JSON `null` maps to `""` to keep type integrity)
- `@export var travel: TravelState` (nullable; sub-Resource — see below)
- `@export var inventory: Dictionary[String, int]` (typed dict; ints only)

Methods:
- `apply_gold_delta(amount: int) -> bool` — mutates, returns false if it would go negative; on success, invokes injected `_on_gold_changed` and `_on_state_dirty` callbacks.
- `apply_inventory_delta(good_id: String, qty: int) -> bool` — mutates, invokes `_on_state_dirty`.
- `to_dict() / from_dict(d: Dictionary)` — JSON ferry methods; SaveService is the only caller.

### 4.2 `TravelState` — `Resource` subclass (nested under TraderState)

Why a separate Resource: it's nullable in §3, so it cannot be inlined as plain fields on `TraderState` without ambiguity. As a Resource, `null` cleanly means "not travelling."

Fields: `from_id: String`, `to_id: String`, `ticks_remaining: int`, `cost_paid: int`.

### 4.3 `WorldState` — `Resource` subclass

Lives at `godot/world/world_state.gd`. Held as `@export var world: WorldState` on `Game`. Same reasoning as `TraderState`.

Fields:
- `@export var schema_version: int = 1`
- `@export var world_seed: int`
- `@export var tick: int`
- `@export var nodes: Array[NodeState]` (3 entries in slice)
- `@export var edges: Array[EdgeState]` (slice has 3 edges for the triangle)
- `@export var history: Array[HistoryEntry]` (ring buffer, cap 10)
- `@export var dead: bool`
- `@export var death: DeathRecord` (nullable)

`NodeState`, `EdgeState`, `HistoryEntry`, `DeathRecord` are each tiny `Resource` subclasses for typing. Don't fight Godot's typed arrays.

### 4.4 `Good` — `Resource` subclass with `.tres` instances on disk

Hand-authored vocabulary (Director resolution 2). Lives at `godot/goods/good.gd` with `.tres` instances at `godot/goods/wool.tres`, `godot/goods/cloth.tres` (slice has 1–2 goods per §6).

Fields: `id: String`, `display_name: String`, `base_price: int`, `floor_price: int`, `ceiling_price: int`. (Renamed from `floor`/`ceiling` during Tier 1 to avoid shadowing GDScript's global `floor()` function.)

Goods catalogue is loaded by `WorldGen` from a directory scan or a fixed list in `Game`.

### 4.5 How systems get to state without `get_node` lookups

`Main._ready()` is the wiring point. It calls `setup(trader, world)` on every system node that needs state. Each system stores typed references locally:

```
# inside TravelController, conceptually
var _trader: TraderState
var _world: WorldState
func setup(trader: TraderState, world: WorldState) -> void:
    _trader = trader
    _world = world
```

(Engineer writes the actual code — Architect just specifies the shape.)

This satisfies the idioms skill's "dependencies flow inward, no `get_node('../../..')`."

---

## 5. Save lifecycle

`SaveService` is a `Node`, child of `Game`. Path: `/root/Game/SaveService`.

| Event | Trigger | Behaviour |
|---|---|---|
| **Boot** | `Game._ready()` | `SaveService.load_or_init()` — try `FileAccess.open("user://save.json", READ)`. On success, parse, validate `schema_version == 1`, populate `Game.trader` and `Game.world`. On any failure (missing, schema mismatch, parse error), call `WorldGen.generate_new(seed)` and write the result immediately. |
| **Tick boundary** | `Game.tick_advanced` | `SaveService` checks a `_dirty: bool` flag (set by `state_dirty`); if dirty, writes and clears flag. **Coalesced** per §9 — multiple `state_dirty` between ticks become one write. |
| **State mutation between ticks** | `Game.state_dirty` | Sets `_dirty = true`. Does **not** write. |
| **Quit** | `Main._notification(NOTIFICATION_WM_CLOSE_REQUEST)` | Calls `SaveService.write_now()` synchronously, then `get_tree().quit()`. |
| **Death** | `Game.died` | `SaveService.write_now()` — synchronous, before scene change. Writes `dead = true` and the `death` record. |

**HTML5 IndexedDB flush.** Per §3, `store_string` returns before IndexedDB has actually flushed. `SaveService.write_now()` is `async`:

```
# conceptual shape only
func write_now() -> void:
    var f := FileAccess.open("user://save.json", FileAccess.WRITE)
    f.store_string(_serialize())
    f.close()
    await get_tree().process_frame    # one-frame yield per §3
```

Quit handler must `await SaveService.write_now()` before calling `get_tree().quit()`. Death handler must `await SaveService.write_now()` before `change_scene_to_packed(death_screen)`. Engineer: do not skip the `await`.

**The save trigger owner is `SaveService`**, which sits under `Game`. No gameplay code calls `FileAccess` directly. This honours §9's "never called inline by gameplay code except on quit" — and even quit goes through `SaveService.write_now()`, not raw `FileAccess`.

---

## 6. Folder layout under `godot/`

Feature folders, per the project-structure-conventions skill.

```
godot/
├── project.godot
├── main.tscn                                        ← entry scene
├── main.gd
├── game/
│   ├── game.gd                                      ← the autoload (no class_name; autoload name "Game" is global)
│   └── world_gen.gd                                 ← one-shot generator, script-only
├── trader/
│   ├── trader_state.gd                              ← Resource
│   └── travel_state.gd                              ← Resource
├── world/
│   ├── world_state.gd                               ← Resource
│   ├── node_state.gd                                ← Resource
│   ├── edge_state.gd                                ← Resource
│   ├── history_entry.gd                             ← Resource
│   └── death_record.gd                              ← Resource
├── goods/
│   ├── good.gd                                      ← Resource definition
│   ├── wool.tres                                    ← authored data
│   └── cloth.tres                                   ← authored data (if 2 goods)
├── travel/
│   ├── travel_controller.gd                         ← Node, tick driver
│   └── trade.gd                                     ← Node or script-only, buy/sell
├── pricing/
│   └── price_model.gd                               ← Node, drift on tick
├── aging/
│   └── aging.gd                                     ← Node, age++ on tick
├── systems/
│   ├── save/
│   │   └── save_service.gd                          ← Node child of Game
│   └── death/
│       └── death_service.gd                         ← Node child of Game
├── ui/
│   ├── hud/
│   │   ├── node_panel.tscn / node_panel.gd
│   │   ├── travel_panel.tscn / travel_panel.gd
│   │   ├── status_bar.tscn / status_bar.gd
│   │   └── confirm_dialog.tscn / confirm_dialog.gd
│   └── death_screen/
│       ├── death_screen.tscn
│       └── death_screen.gd
└── shared/
    └── (empty for slice — populated as cross-feature needs arise)
```

**Notes on placement choices:**

- `game/` is a feature folder for the autoload + world gen, not a `/systems/` cross-cutter, because `Game` *is* gameplay state in this slice. World gen sits next to it because they boot together.
- `aging/` is its own folder despite being one file — it grows in later slices (old-age death, lifespan tuning) and the precedent is set now.
- `trade.gd` lives in `travel/` because trade and travel are the two verbs that mutate `TraderState`; keeping them adjacent reflects that. If trade grows, it earns its own folder.
- No `/scripts`, `/scenes`, `/resources` folders. Per the skill.

---

## 7. Engineer handoff list

Files to create, in dependency order. Each entry: `class_name`, `extends`, key exports, key signals/methods. Engineer should read top-to-bottom and type.

### Tier 1 — Resources (no dependencies between them; alphabetical)

1. **`godot/goods/good.gd`** — `class_name Good extends Resource`. Exports: `id: String`, `display_name: String`, `base_price: int`, `floor_price: int`, `ceiling_price: int`. Then create `wool.tres` and `cloth.tres` as instances (Designer ratified 2 goods, 2026-04-29).
2. **`godot/world/node_state.gd`** — `class_name NodeState extends Resource`. Exports: `id: String`, `display_name: String`, `pos: Vector2`, `prices: Dictionary[String, int]`.
3. **`godot/world/edge_state.gd`** — `class_name EdgeState extends Resource`. Exports: `a_id: String`, `b_id: String`, `distance: int`. Assert `distance > 0` per §8.
4. **`godot/world/history_entry.gd`** — `class_name HistoryEntry extends Resource`. Exports: `tick: int`, `kind: String` (one of "buy"/"sell"/"travel"), `detail: String`, `delta_gold: int`.
5. **`godot/world/death_record.gd`** — `class_name DeathRecord extends Resource`. Exports: `tick: int`, `cause: String`, `final_gold: int`.
6. **`godot/trader/travel_state.gd`** — `class_name TravelState extends Resource`. Exports: `from_id: String`, `to_id: String`, `ticks_remaining: int`, `cost_paid: int`.
7. **`godot/trader/trader_state.gd`** — `class_name TraderState extends Resource`. Exports: `gold: int`, `age_ticks: int`, `location_node_id: String`, `travel: TravelState` (nullable), `inventory: Dictionary[String, int]`. Methods:
   - `apply_gold_delta(amount: int, on_changed: Callable, on_dirty: Callable) -> bool`
   - `apply_inventory_delta(good_id: String, qty: int, on_dirty: Callable) -> bool`
   - `to_dict() -> Dictionary` / `static func from_dict(d: Dictionary) -> TraderState`
8. **`godot/world/world_state.gd`** — `class_name WorldState extends Resource`. Exports: `schema_version: int = 1`, `world_seed: int`, `tick: int`, `nodes: Array[NodeState]`, `edges: Array[EdgeState]`, `history: Array[HistoryEntry]` (ring-buffer cap 10), `dead: bool`, `death: DeathRecord` (nullable). Methods: `to_dict()`, `from_dict()`, `push_history(entry: HistoryEntry)` (handles ring buffer cap).

### Tier 2 — World generation

9. **`godot/game/world_gen.gd`** — `class_name WorldGen` (script-only, static methods). `static func generate(seed: int, goods: Array[Good]) -> WorldState`. Generates 3 nodes, 3 edges (triangle), seeds initial prices per §5 formula. Asserts `distance > 0` on every edge.

### Tier 3 — Autoload

10. **`godot/game/game.gd`** — `extends Node` (no `class_name` — would collide with the autoload singleton in Godot 4). **Register as autoload `Game`** in `project.godot`; the autoload name is the global identifier. Children (added in `_ready()`): `SaveService`, `DeathService`. Exports/fields: `trader: TraderState`, `world: WorldState`, `goods: Array[Good]` (loaded from `godot/goods/*.tres`). Signals:
    - `signal tick_advanced(new_tick: int)`
    - `signal gold_changed(new_gold: int, delta: int)`
    - `signal state_dirty()`
    - `signal died(cause: String)`
    Methods: `bootstrap() -> void` (idempotent — calls SaveService.load_or_init, populates trader/world, ensures goods loaded). Provides `emit_gold_changed` and `emit_state_dirty` `Callable`s for `TraderState` mutators. (Public — externally consumed by Tier 4–5 systems; `_` prefix would misread these as private.)

### Tier 4 — Service nodes (children of Game)

11. **`godot/systems/save/save_service.gd`** — `class_name SaveService extends Node`. Methods: `load_or_init() -> void`, `write_now() -> void` (async, awaits one process_frame after store_string). On `_ready()`: connects to `Game.tick_advanced` (coalesced write), `Game.state_dirty` (sets `_dirty`), `Game.died` (forces immediate write). No editor-wired signals.
12. **`godot/systems/death/death_service.gd`** — `class_name DeathService extends Node`. Subscribes to `Game.gold_changed` in `_ready()`. On gold change, evaluates the stranded condition (per §5: gold == 0 AND no affordable travel from current node). On trigger: writes `Game.world.dead = true`, populates `Game.world.death`, emits `Game.died.emit("stranded")`. **Lifecycle note: `died` must be emitted before any `queue_free` of trader-side state** — SaveService and Main both need to read `Game.world.death` after `died`. In the slice, nothing is freed; just be aware for future slices.

### Tier 5 — Gameplay nodes (children of Main)

13. **`godot/pricing/price_model.gd`** — `class_name PriceModel extends Node`. Method: `setup(world: WorldState) -> void`. On `_ready()`: connects to `Game.tick_advanced`. On tick: drifts every node's prices per §5 formula with deterministic RNG seeded by `hash(world_seed, tick, node_id, good_id)`.
14. **`godot/aging/aging.gd`** — `class_name Aging extends Node`. Method: `setup(trader: TraderState) -> void`. On tick: `trader.age_ticks += 1`. Emit `state_dirty` via `Game.emit_state_dirty`.
15. **`godot/travel/trade.gd`** — `class_name Trade extends Node`. Method: `setup(trader: TraderState, world: WorldState) -> void`. Public methods: `try_buy(good_id: String) -> bool`, `try_sell(good_id: String) -> bool`. Reads price from `world.nodes[trader.location_node_id].prices`. Calls `trader.apply_gold_delta` and `trader.apply_inventory_delta`. Pushes `HistoryEntry` on success.
16. **`godot/travel/travel_controller.gd`** — `class_name TravelController extends Node`. Method: `setup(trader: TraderState, world: WorldState) -> void`. Public methods: `compute_cost(to_id: String) -> int`, `request_travel(to_id: String) -> void` (validates gold ≥ cost, sets `trader.travel`, deducts gold once). Drives ticks: a `_process_tick()` method called by Main on confirm-dialog acceptance — advances `world.tick` by 1, decrements `trader.travel.ticks_remaining`, emits `Game.tick_advanced`. Loops until arrival.

### Tier 6 — UI

17. **`godot/ui/hud/status_bar.tscn` + `.gd`** — reads `Game.trader`, listens to `Game.gold_changed` and `Game.tick_advanced`.
18. **`godot/ui/hud/node_panel.tscn` + `.gd`** — signals `buy_requested(good_id: String)`, `sell_requested(good_id: String)`. Reads current node from `Game.world` + `Game.trader.location_node_id`.
19. **`godot/ui/hud/travel_panel.tscn` + `.gd`** — signal `travel_requested(to_id: String)`. Reads neighbours + costs from `TravelController` (injected) and `Game.world`.
20. **`godot/ui/hud/confirm_dialog.tscn` + `.gd`** — `AcceptDialog` subclass; signal `confirmed`. Disables Confirm button if `gold < cost` per §7.
21. **`godot/ui/death_screen/death_screen.tscn` + `.gd`** — `class_name DeathScreen extends Control`. Reads `Game.trader`, `Game.world.history`, `Game.world.death` directly. Quit button → `get_tree().quit()`.

### Tier 7 — Main + entry wiring

22. **`godot/main.gd` + `main.tscn`** — `class_name Main extends Node`. `@export var _death_scene: PackedScene` (wired in `main.tscn` to `res://ui/death_screen/death_screen.tscn`). On `_ready()` (async — see canonical call list in §2.1): `await Game.bootstrap()`, then `setup(Game.trader, Game.world)` on `TravelController` / `PriceModel` / `Aging`, `setup(travel_controller)` on `TravelPanel`, then connects HUD signals (`NodePanel.buy_requested` → `Trade.try_buy`, `sell_requested` → `Trade.try_sell`, `TravelPanel.travel_requested` → opens `ConfirmDialog`, `ConfirmDialog.confirmed` → `TravelController.request_travel` followed by `TravelController.process_tick`), and connects `Game.died` to `_on_died`. `_on_died(cause)` is async: `await SaveService.write_now()` then `get_tree().change_scene_to_packed(_death_scene)`. `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` calls a private async helper (`_quit_with_save()`) that `await`s `SaveService.write_now()` then `get_tree().quit()` — `_notification` itself cannot `await`, but it can fire-and-forget the helper because the engine doesn't tear down between the call and the next process frame.

### Project settings

23. **`project.godot`** — register autoload: `Game = "*res://game/game.gd"` (note the `*` for autoload). Set `main.tscn` as the main scene.

---

## 8. Open questions — all resolved 2026-04-29

1. ~~**Death-screen label for bankruptcy.**~~ **Director call: `"stranded"`.** Tone precedent for future death-cause labels: single concrete past-participle states (`stranded`, `slain`, `taken by age`, `lost on the pass`), never clinical nouns. Engineer literal: `Game.died.emit("stranded")` and `world.death.cause = "stranded"`.
2. ~~**Number of goods in slice (1 or 2).**~~ **Designer call: 2 goods (`wool`, `cloth`).** 2 goods forces the actual kernel decision (which spread beats which travel cost) and tests the price model's good-independence. If playtest shows it's overwhelming at programmer-art fidelity, drop to 1.
3. ~~**Tick driver granularity for travel.**~~ **Designer call: per-step (Architect's choice ratified).** Per-step drift mid-trip is the kernel — batched ticks erase the bite and read as luck. `tick_advanced` fires N times for an N-tick travel. SaveService coalesce window stays as specified.

---

## 9. Where I pushed back on §9 (and where I didn't)

§9 is sound and largely confirmed. One nuance:

- §9 says signals like `gold_changed` come from "the Trader resource." `Resource` *can* declare signals in Godot 4, but connections don't survive serialization, and the slice's save/load cycle re-creates `TraderState` from JSON on every boot — meaning every subscriber would need to re-connect after every load. That's a footgun. **Mitigation: the signals live on `Game` (stable across loads) and `TraderState` mutators receive injected `Callable`s.** Equivalent semantics, no re-wiring on load. The §9 ownership claim ("Trader resource owns gold") is preserved — only `TraderState.apply_gold_delta` mutates gold. The signal just fires from `Game` instead of from the resource itself.

Everything else in §9 maps cleanly. Resource-owned state holds. Signal-based coupling holds. No `get_node` reaches across the tree (one exception: `DeathScreen` reads `Game` directly, called out above).

---

**Engineer is unblocked.** Start at Tier 1 (Resources), work down. Wiring questions go back to Architect; tuning numbers go to Designer; death-cause label goes to Director.
