## Persistent world data: nodes, edges, history ring buffer, and death record.
class_name WorldState
extends Resource

const HISTORY_CAP: int = 10
const SCHEMA_VERSION: int = 5

@export var schema_version: int = SCHEMA_VERSION
@export var world_seed: int
@export var tick: int
@export var nodes: Array[NodeState]
@export var edges: Array[EdgeState]
@export var history: Array[HistoryEntry]
@export var dead: bool
@export var death: DeathRecord

func push_history(entry: HistoryEntry) -> void:
	if history.size() >= HISTORY_CAP:
		history.pop_front()
	history.push_back(entry)

## Returns the NodeState with id == node_id, or null if not found (including empty id).
func get_node_by_id(node_id: String) -> NodeState:
	if node_id == "":
		return null
	for n: NodeState in nodes:
		if n.id == node_id:
			return n
	return null

## Player-facing label for node_id. Falls back to the raw id so a missing-node case
## degrades visibly rather than silently. UI surfaces (confirm dialog, history detail)
## must use this; raw ids are internal identity, not display text.
func display_name_of(node_id: String) -> String:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return node_id
	return n.display_name

## Slice-7 stock seam. Read-only accessor mirroring the get_node_by_id
## encapsulation pattern; Trade.try_buy and NodePanel._update_row both call
## this so the per-node dict layout (spec §4.1) stays isolated from call sites.
## Returns 0 on unknown node or unknown good (defensive: a stock-less slot
## reads as out-of-stock, never a key error).
func stock_for(node_id: String, good_id: String) -> int:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return 0
	if not n.stocks.has(good_id):
		return 0
	return int(n.stocks[good_id])

## Slice-7 stock mutator. Defensive no-op on unknown node, unknown good, or
## already-zero stock -- the runtime predicate in Trade.try_buy gates this so
## the no-op branches catch upstream UI/runtime drift without crashing.
## Mirrors WorldState.get_node_by_id encapsulation -- callers must not reach
## into world.nodes[i].stocks directly. See spec §3.4 / §9 ("stock < 0 somehow").
func decrement_stock(node_id: String, good_id: String) -> void:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return
	if not n.stocks.has(good_id):
		return
	var current: int = int(n.stocks[good_id])
	if current <= 0:
		return
	n.stocks[good_id] = current - 1

## Returns all edges incident to node_id (undirected). Empty id → empty array.
func outbound_edges(node_id: String) -> Array[EdgeState]:
	var result: Array[EdgeState] = []
	if node_id == "":
		return result
	for e: EdgeState in edges:
		if e.a_id == node_id or e.b_id == node_id:
			result.append(e)
	return result

## Returns the id of the highest-degree node, tie-broken by lexicographically
## smallest id. Pure function over nodes/edges; returns "" if no nodes exist.
func get_starting_node_id() -> String:
	if nodes.is_empty():
		return ""
	var degree: Dictionary[String, int] = {}
	for n: NodeState in nodes:
		degree[n.id] = 0
	for e: EdgeState in edges:
		if degree.has(e.a_id):
			degree[e.a_id] += 1
		if degree.has(e.b_id):
			degree[e.b_id] += 1
	var best_id: String = ""
	var best_degree: int = -1
	for n: NodeState in nodes:
		var d: int = degree[n.id]
		if d > best_degree or (d == best_degree and n.id < best_id):
			best_degree = d
			best_id = n.id
	return best_id

func to_dict() -> Dictionary:
	var nodes_array: Array = []
	for n: NodeState in nodes:
		var prices_dict: Dictionary = {}
		for good_id: String in n.prices.keys():
			prices_dict[good_id] = int(n.prices[good_id])
		var bias_dict: Dictionary = {}
		for good_id: String in n.bias.keys():
			bias_dict[good_id] = float(n.bias[good_id])
		var produces_array: Array = []
		for good_id: String in n.produces:
			produces_array.append(good_id)
		var consumes_array: Array = []
		for good_id: String in n.consumes:
			consumes_array.append(good_id)
		# Slice-7 schema v5: per-(node, good) stock state. The four parallel
		# dicts persist as-authored at world-gen so retunes of WorldRules
		# multipliers don't retroactively re-cap saved worlds (spec §4.2).
		var stock_caps_dict: Dictionary = {}
		for good_id: String in n.stock_caps.keys():
			stock_caps_dict[good_id] = int(n.stock_caps[good_id])
		var refill_rates_dict: Dictionary = {}
		for good_id: String in n.refill_rates.keys():
			refill_rates_dict[good_id] = float(n.refill_rates[good_id])
		var stocks_dict: Dictionary = {}
		for good_id: String in n.stocks.keys():
			stocks_dict[good_id] = int(n.stocks[good_id])
		var refill_accumulators_dict: Dictionary = {}
		for good_id: String in n.refill_accumulators.keys():
			refill_accumulators_dict[good_id] = float(n.refill_accumulators[good_id])
		nodes_array.append({
			"id": n.id,
			"name": n.display_name,
			"pos": [n.pos.x, n.pos.y],
			"prices": prices_dict,
			"bias": bias_dict,
			"produces": produces_array,
			"consumes": consumes_array,
			"stock_caps": stock_caps_dict,
			"refill_rates": refill_rates_dict,
			"stocks": stocks_dict,
			"refill_accumulators": refill_accumulators_dict,
		})
	var edges_array: Array = []
	for e: EdgeState in edges:
		edges_array.append({
			"a_id": e.a_id,
			"b_id": e.b_id,
			"distance": e.distance,
			"is_bandit_road": e.is_bandit_road,
		})
	var history_array: Array = []
	for h: HistoryEntry in history:
		history_array.append({
			"tick": h.tick,
			"kind": h.kind,
			"detail": h.detail,
			"delta_gold": h.delta_gold,
		})
	var death_dict: Variant = null
	if death != null:
		death_dict = {
			"tick": death.tick,
			"cause": death.cause,
			"final_gold": death.final_gold,
		}
	return {
		"schema_version": schema_version,
		"world_seed": world_seed,
		"tick": tick,
		"nodes": nodes_array,
		"edges": edges_array,
		"history": history_array,
		"dead": dead,
		"death": death_dict,
	}

## Strict reject: returns null on any structural corruption per slice-spec §8.
static func from_dict(d: Dictionary) -> WorldState:
	const REQUIRED_KEYS: Array[String] = [
		"schema_version", "world_seed", "tick",
		"nodes", "edges", "history", "dead", "death",
	]
	for key: String in REQUIRED_KEYS:
		if not d.has(key):
			return null
	# Slice-7 schema bump (4 -> 5). Accept-or-migrate replaces the strict-reject:
	# v5 is the current shape, v4 is the slice-6 shape that lacks per-(node, good)
	# stock state. Anything else stays a strict reject. See spec §5.3 and §5.4.
	var loaded_version: int = int(d["schema_version"])
	if loaded_version == SCHEMA_VERSION:
		pass
	elif loaded_version == 4:
		var migrated: Dictionary = _migrate_v4_to_v5(d)
		if migrated.is_empty():
			return null
		d = migrated
	else:
		return null
	if not (d["nodes"] is Array) or not (d["edges"] is Array) or not (d["history"] is Array):
		return null
	var history_data: Array = d["history"]
	if history_data.size() > HISTORY_CAP:
		return null

	var nodes_typed: Array[NodeState] = []
	for raw: Variant in (d["nodes"] as Array):
		if not (raw is Dictionary):
			return null
		var n: NodeState = _node_from_dict(raw)
		if n == null:
			return null
		nodes_typed.append(n)

	var edges_typed: Array[EdgeState] = []
	for raw: Variant in (d["edges"] as Array):
		if not (raw is Dictionary):
			return null
		var e: EdgeState = _edge_from_dict(raw)
		if e == null:
			return null
		edges_typed.append(e)

	var history_typed: Array[HistoryEntry] = []
	for raw: Variant in history_data:
		if not (raw is Dictionary):
			return null
		var h: HistoryEntry = _history_from_dict(raw)
		if h == null:
			return null
		history_typed.append(h)

	var dead_value: bool = bool(d["dead"])
	var death_data: Variant = d["death"]
	var death_record: DeathRecord = null
	if dead_value:
		if not (death_data is Dictionary):
			return null
		death_record = _death_from_dict(death_data)
		if death_record == null:
			return null
	else:
		if death_data != null:
			return null

	var w: WorldState = WorldState.new()
	w.schema_version = SCHEMA_VERSION
	w.world_seed = int(d["world_seed"])
	w.tick = int(d["tick"])
	w.nodes = nodes_typed
	w.edges = edges_typed
	w.history = history_typed
	w.dead = dead_value
	w.death = death_record
	return w

static func _node_from_dict(d: Dictionary) -> NodeState:
	# Wire format uses "name" (per slice-spec §3); in-memory field is `display_name`.
	if not d.has("id") or not d.has("name") or not d.has("pos") or not d.has("prices"):
		return null
	if not d.has("bias") or not d.has("produces") or not d.has("consumes"):
		return null
	# Slice-7 schema v5: stock state is required on every node. v4 saves are
	# rewritten to v5 shape upstream by _migrate_v4_to_v5 before reaching here.
	if not d.has("stock_caps") or not d.has("refill_rates"):
		return null
	if not d.has("stocks") or not d.has("refill_accumulators"):
		return null
	var pos_value: Variant = d["pos"]
	if not (pos_value is Array):
		return null
	var pos_arr: Array = pos_value
	if pos_arr.size() != 2:
		return null
	var prices_value: Variant = d["prices"]
	if not (prices_value is Dictionary):
		return null
	var prices_dict: Dictionary = prices_value
	var prices_typed: Dictionary[String, int] = {}
	for good_id: Variant in prices_dict.keys():
		prices_typed[String(good_id)] = int(prices_dict[good_id])
	var bias_value: Variant = d["bias"]
	if not (bias_value is Dictionary):
		return null
	var bias_dict: Dictionary = bias_value
	var bias_typed: Dictionary[String, float] = {}
	for good_id: Variant in bias_dict.keys():
		bias_typed[String(good_id)] = float(bias_dict[good_id])
	var produces_value: Variant = d["produces"]
	if not (produces_value is Array):
		return null
	var produces_typed: Array[String] = []
	for raw: Variant in (produces_value as Array):
		if not (raw is String):
			return null
		produces_typed.append(raw)
	var consumes_value: Variant = d["consumes"]
	if not (consumes_value is Array):
		return null
	var consumes_typed: Array[String] = []
	for raw: Variant in (consumes_value as Array):
		if not (raw is String):
			return null
		consumes_typed.append(raw)
	# Slice-7 schema v5: four parallel per-good stock dicts. Strict-reject on
	# wrong shape mirrors prices/bias above. See spec §5.1 wire format.
	var stock_caps_value: Variant = d["stock_caps"]
	if not (stock_caps_value is Dictionary):
		return null
	var stock_caps_typed: Dictionary[String, int] = {}
	for good_id: Variant in (stock_caps_value as Dictionary).keys():
		stock_caps_typed[String(good_id)] = int((stock_caps_value as Dictionary)[good_id])
	var refill_rates_value: Variant = d["refill_rates"]
	if not (refill_rates_value is Dictionary):
		return null
	var refill_rates_typed: Dictionary[String, float] = {}
	for good_id: Variant in (refill_rates_value as Dictionary).keys():
		refill_rates_typed[String(good_id)] = float((refill_rates_value as Dictionary)[good_id])
	var stocks_value: Variant = d["stocks"]
	if not (stocks_value is Dictionary):
		return null
	var stocks_typed: Dictionary[String, int] = {}
	for good_id: Variant in (stocks_value as Dictionary).keys():
		stocks_typed[String(good_id)] = int((stocks_value as Dictionary)[good_id])
	var refill_accumulators_value: Variant = d["refill_accumulators"]
	if not (refill_accumulators_value is Dictionary):
		return null
	var refill_accumulators_typed: Dictionary[String, float] = {}
	for good_id: Variant in (refill_accumulators_value as Dictionary).keys():
		refill_accumulators_typed[String(good_id)] = float((refill_accumulators_value as Dictionary)[good_id])
	var n: NodeState = NodeState.new()
	n.id = String(d["id"])
	n.display_name = String(d["name"])
	n.pos = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	n.prices = prices_typed
	n.bias = bias_typed
	n.produces = produces_typed
	n.consumes = consumes_typed
	n.stock_caps = stock_caps_typed
	n.refill_rates = refill_rates_typed
	n.stocks = stocks_typed
	n.refill_accumulators = refill_accumulators_typed
	return n

static func _edge_from_dict(d: Dictionary) -> EdgeState:
	if not d.has("a_id") or not d.has("b_id") or not d.has("distance") or not d.has("is_bandit_road"):
		return null
	var e: EdgeState = EdgeState.new()
	e.a_id = String(d["a_id"])
	e.b_id = String(d["b_id"])
	e.distance = int(d["distance"])
	e.is_bandit_road = bool(d["is_bandit_road"])
	if not e.is_valid():
		return null
	return e

static func _history_from_dict(d: Dictionary) -> HistoryEntry:
	if not d.has("tick") or not d.has("kind") or not d.has("detail") or not d.has("delta_gold"):
		return null
	var kind_value: String = String(d["kind"])
	if not HistoryEntry.is_valid_kind(kind_value):
		return null
	var h: HistoryEntry = HistoryEntry.new()
	h.tick = int(d["tick"])
	h.kind = kind_value
	h.detail = String(d["detail"])
	h.delta_gold = int(d["delta_gold"])
	return h

static func _death_from_dict(d: Dictionary) -> DeathRecord:
	if not d.has("tick") or not d.has("cause") or not d.has("final_gold"):
		return null
	var r: DeathRecord = DeathRecord.new()
	r.tick = int(d["tick"])
	r.cause = String(d["cause"])
	r.final_gold = int(d["final_gold"])
	return r

## Slice-7 v4 -> v5 migration. Synthesises per-(node, good) stock state from
## the v4 shape (which has produces/consumes tags but no stock dicts). For each
## node, derives caps and rates from the live Goods catalogue via the same
## tag-multiplier table WorldGen._author_stock uses, sets stocks to cap (full
## -- "no save-scumming" rule, spec §5.4), and zeros the accumulators.
##
## Returns {} on irrecoverable shape (non-array nodes, non-dict node entries,
## or unavailable Goods catalogue) so the caller can strict-reject; otherwise
## returns the rewritten v5 dict.
##
## Lifecycle: Game._ready populates Game.goods before bootstrap() awaits
## load_or_init, which is where SaveService calls WorldState.from_dict. Goods
## must be live by the time this static helper runs (verified by inspection of
## Game._ready / bootstrap). See spec §5.4.
##
## The Game autoload is reached via the scene tree (Engine.get_main_loop) rather
## than the Game symbol so this script parses in --script mode (which strips
## autoload globals); the migration itself is no-op in --script mode since v4
## saves never appear there.
static func _migrate_v4_to_v5(d: Dictionary) -> Dictionary:
	if not (d["nodes"] is Array):
		return {}
	var goods: Array[Good] = _resolve_goods_for_migration()
	if goods.is_empty():
		# Without the live catalogue we cannot derive stock state. Strict-reject
		# rather than write a half-formed v5 dict.
		push_warning("WorldState._migrate_v4_to_v5: Goods catalogue unavailable, rejecting v4 save")
		return {}
	var nodes_arr: Array = d["nodes"] as Array
	for raw: Variant in nodes_arr:
		if not (raw is Dictionary):
			return {}
		var node_dict: Dictionary = raw
		var produces_arr: Array = []
		if node_dict.has("produces") and node_dict["produces"] is Array:
			produces_arr = node_dict["produces"] as Array
		var consumes_arr: Array = []
		if node_dict.has("consumes") and node_dict["consumes"] is Array:
			consumes_arr = node_dict["consumes"] as Array
		var caps: Dictionary = {}
		var rates: Dictionary = {}
		var stocks: Dictionary = {}
		var accumulators: Dictionary = {}
		for good: Good in goods:
			var cap_mult: float = 1.0
			var rate_mult: float = 1.0
			if good.id in produces_arr:
				cap_mult = WorldRules.STOCK_CAP_MULT_PLENTIFUL
				rate_mult = WorldRules.REFILL_MULT_PLENTIFUL
			elif good.id in consumes_arr:
				cap_mult = WorldRules.STOCK_CAP_MULT_SCARCE
				rate_mult = WorldRules.REFILL_MULT_SCARCE
			var cap: int = maxi(1, roundi(float(good.base_stock_cap) * cap_mult))
			var rate: float = good.base_refill_rate * rate_mult
			caps[good.id] = cap
			rates[good.id] = rate
			# v4 saves load with every stock at its refill ceiling -- spec §5.4
			# "no save-scumming" rule.
			stocks[good.id] = cap
			accumulators[good.id] = 0.0
		node_dict["stock_caps"] = caps
		node_dict["refill_rates"] = rates
		node_dict["stocks"] = stocks
		node_dict["refill_accumulators"] = accumulators
	d["schema_version"] = SCHEMA_VERSION
	return d

# Looks up the Game autoload's `goods` array via the scene tree. Returns []
# when the autoload is unreachable (--script mode strips autoloads, and tooling
# entry points may run before the tree is up). Callers must treat empty as a
# fatal-for-this-migration condition.
static func _resolve_goods_for_migration() -> Array[Good]:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return [] as Array[Good]
	var tree: SceneTree = loop as SceneTree
	var root: Window = tree.root
	if root == null:
		return [] as Array[Good]
	var game_node: Node = root.get_node_or_null("Game")
	if game_node == null:
		return [] as Array[Good]
	var raw: Variant = game_node.get("goods")
	if raw == null:
		return [] as Array[Good]
	var typed: Array[Good] = []
	for entry: Variant in (raw as Array):
		if entry is Good:
			typed.append(entry as Good)
	return typed
