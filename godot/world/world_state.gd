## Persistent world data: nodes, edges, history ring buffer, and death record.
class_name WorldState
extends Resource

const HISTORY_CAP: int = 10
const SCHEMA_VERSION: int = 6

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
## this so the per-node dict layout stays isolated from call sites.
## Returns 0 on unknown node or unknown good.
func stock_for(node_id: String, good_id: String) -> int:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return 0
	if not n.stocks.has(good_id):
		return 0
	return int(n.stocks[good_id])

## Slice-7 stock mutator. Defensive no-op on unknown node, unknown good, or
## already-zero stock -- the runtime predicate in Trade.try_buy gates this.
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

## Slice-8 demand seam. Read-only accessor mirroring stock_for. NodePanel and
## any caller that needs demand-pool fill (UI bar, sell-disable predicate)
## reads through this so the per-node dict layout stays isolated.
## Returns 0 on unknown node or unknown good (defensive: a demand-less slot
## reads as fully-saturated, never a key error).
func demand_for(node_id: String, good_id: String) -> int:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return 0
	if not n.demand_pools.has(good_id):
		return 0
	return int(n.demand_pools[good_id])

## Slice-8 demand mutator. Defensive no-op on unknown node, unknown good, or
## already-zero pool. Mirrors decrement_stock; called by Trade.try_sell so the
## verb is the ground truth, not the disabled button.
func decrement_demand(node_id: String, good_id: String) -> void:
	var n: NodeState = get_node_by_id(node_id)
	if n == null:
		return
	if not n.demand_pools.has(good_id):
		return
	var current: int = int(n.demand_pools[good_id])
	if current <= 0:
		return
	n.demand_pools[good_id] = current - 1

## Returns all edges incident to node_id (undirected). Empty id -> empty array.
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
		var bias_dict: Dictionary = {}
		for good_id: String in n.bias.keys():
			bias_dict[good_id] = float(n.bias[good_id])
		var produces_array: Array = []
		for good_id: String in n.produces:
			produces_array.append(good_id)
		var consumes_array: Array = []
		for good_id: String in n.consumes:
			consumes_array.append(good_id)
		# Slice-7 schema v5+: per-(node, good) supply pool (4 parallel dicts).
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
		# Slice-8 schema v6: per-(node, good) demand pool (4 parallel dicts).
		# Mirrors the supply quad above. `prices` is dropped from the wire
		# format -- pull-driven via PricingMath. Spec §3.4.
		var demand_pools_dict: Dictionary = {}
		for good_id: String in n.demand_pools.keys():
			demand_pools_dict[good_id] = int(n.demand_pools[good_id])
		var demand_caps_dict: Dictionary = {}
		for good_id: String in n.demand_caps.keys():
			demand_caps_dict[good_id] = int(n.demand_caps[good_id])
		var demand_decay_rates_dict: Dictionary = {}
		for good_id: String in n.demand_decay_rates.keys():
			demand_decay_rates_dict[good_id] = float(n.demand_decay_rates[good_id])
		var demand_decay_accumulators_dict: Dictionary = {}
		for good_id: String in n.demand_decay_accumulators.keys():
			demand_decay_accumulators_dict[good_id] = float(n.demand_decay_accumulators[good_id])
		nodes_array.append({
			"id": n.id,
			"name": n.display_name,
			"pos": [n.pos.x, n.pos.y],
			"bias": bias_dict,
			"produces": produces_array,
			"consumes": consumes_array,
			"stock_caps": stock_caps_dict,
			"refill_rates": refill_rates_dict,
			"stocks": stocks_dict,
			"refill_accumulators": refill_accumulators_dict,
			"demand_pools": demand_pools_dict,
			"demand_caps": demand_caps_dict,
			"demand_decay_rates": demand_decay_rates_dict,
			"demand_decay_accumulators": demand_decay_accumulators_dict,
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
## Slice-8: accept v5 (via _migrate_v5_to_v6) or v6. v4 and earlier are
## strict-rejected. Decision: 2026-05-04-slice-8-v4-saves-strict-rejected.
static func from_dict(d: Dictionary) -> WorldState:
	const REQUIRED_KEYS: Array[String] = [
		"schema_version", "world_seed", "tick",
		"nodes", "edges", "history", "dead", "death",
	]
	for key: String in REQUIRED_KEYS:
		if not d.has(key):
			return null
	# Slice-8 schema bump (5 -> 6). v5 carries supply pool but no demand pool;
	# the migration synthesises demand state from tags via the §5.7 multiplier
	# table. v6 is the current shape. See spec §3.5, §3.6.
	var loaded_version: int = int(d["schema_version"])
	if loaded_version == SCHEMA_VERSION:
		pass
	elif loaded_version == 5:
		var migrated: Dictionary = _migrate_v5_to_v6(d)
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
	if not d.has("id") or not d.has("name") or not d.has("pos"):
		return null
	if not d.has("bias") or not d.has("produces") or not d.has("consumes"):
		return null
	# Slice-7 schema v5+: supply pool quad required on every node.
	if not d.has("stock_caps") or not d.has("refill_rates"):
		return null
	if not d.has("stocks") or not d.has("refill_accumulators"):
		return null
	# Slice-8 schema v6: demand pool quad required on every node. v5 saves are
	# rewritten upstream by _migrate_v5_to_v6 before reaching here.
	if not d.has("demand_pools") or not d.has("demand_caps"):
		return null
	if not d.has("demand_decay_rates") or not d.has("demand_decay_accumulators"):
		return null
	var pos_value: Variant = d["pos"]
	if not (pos_value is Array):
		return null
	var pos_arr: Array = pos_value
	if pos_arr.size() != 2:
		return null
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
	# Slice-7 supply pool quad.
	var stock_caps_typed: Dictionary[String, int] = _typed_int_dict(d["stock_caps"])
	if stock_caps_typed.is_empty() and not (d["stock_caps"] is Dictionary):
		return null
	if not (d["stock_caps"] is Dictionary):
		return null
	var refill_rates_typed: Dictionary[String, float] = _typed_float_dict(d["refill_rates"])
	if not (d["refill_rates"] is Dictionary):
		return null
	var stocks_typed: Dictionary[String, int] = _typed_int_dict(d["stocks"])
	if not (d["stocks"] is Dictionary):
		return null
	var refill_accumulators_typed: Dictionary[String, float] = _typed_float_dict(d["refill_accumulators"])
	if not (d["refill_accumulators"] is Dictionary):
		return null
	# Slice-8 demand pool quad.
	if not (d["demand_pools"] is Dictionary):
		return null
	var demand_pools_typed: Dictionary[String, int] = _typed_int_dict(d["demand_pools"])
	if not (d["demand_caps"] is Dictionary):
		return null
	var demand_caps_typed: Dictionary[String, int] = _typed_int_dict(d["demand_caps"])
	if not (d["demand_decay_rates"] is Dictionary):
		return null
	var demand_decay_rates_typed: Dictionary[String, float] = _typed_float_dict(d["demand_decay_rates"])
	if not (d["demand_decay_accumulators"] is Dictionary):
		return null
	var demand_decay_accumulators_typed: Dictionary[String, float] = _typed_float_dict(d["demand_decay_accumulators"])
	var n: NodeState = NodeState.new()
	n.id = String(d["id"])
	n.display_name = String(d["name"])
	n.pos = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	n.bias = bias_typed
	n.produces = produces_typed
	n.consumes = consumes_typed
	n.stock_caps = stock_caps_typed
	n.refill_rates = refill_rates_typed
	n.stocks = stocks_typed
	n.refill_accumulators = refill_accumulators_typed
	n.demand_pools = demand_pools_typed
	n.demand_caps = demand_caps_typed
	n.demand_decay_rates = demand_decay_rates_typed
	n.demand_decay_accumulators = demand_decay_accumulators_typed
	return n

static func _typed_int_dict(value: Variant) -> Dictionary[String, int]:
	var out: Dictionary[String, int] = {}
	if not (value is Dictionary):
		return out
	for good_id: Variant in (value as Dictionary).keys():
		out[String(good_id)] = int((value as Dictionary)[good_id])
	return out

static func _typed_float_dict(value: Variant) -> Dictionary[String, float]:
	var out: Dictionary[String, float] = {}
	if not (value is Dictionary):
		return out
	for good_id: Variant in (value as Dictionary).keys():
		out[String(good_id)] = float((value as Dictionary)[good_id])
	return out

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

## Slice-8 v5 -> v6 migration. Synthesises per-(node, good) demand pool state
## from the v5 shape (which has supply pool but no demand pool). For each node,
## derives demand caps and decay rates from the live Goods catalogue via the
## §5.7 multiplier table (inverse of supply: producer = low demand,
## consumer = high demand), sets demand_pools to demand_caps (full unmet demand
## at the migration boundary -- spec §3.6 / Director Q1 ratification:
## 2026-05-04-slice-8-initial-demand-pool-fill-on-migration), and zeros the
## accumulators. Drops the legacy `prices` key (no-op on absent key; v5 saves
## carrying it pass through silently per spec §3.6).
##
## Returns {} on irrecoverable shape so the caller can strict-reject.
##
## Per 2026-05-03-slice-7-caps-rates-frozen-at-gen-time precedent (extended to
## demand by 2026-05-04-slice-8-demand-rates-frozen-at-gen-time): the derived
## caps/rates are written to the save once and never recomputed on load.
static func _migrate_v5_to_v6(d: Dictionary) -> Dictionary:
	if not (d["nodes"] is Array):
		return {}
	var goods: Array[Good] = _resolve_goods_for_migration()
	if goods.is_empty():
		# Without the live catalogue we cannot derive demand state. Strict-reject
		# rather than write a half-formed v6 dict. Mirrors v4->v5.
		push_warning("WorldState._migrate_v5_to_v6: Goods catalogue unavailable, rejecting v5 save")
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
		var demand_caps: Dictionary = {}
		var demand_decay_rates: Dictionary = {}
		var demand_pools: Dictionary = {}
		var demand_accumulators: Dictionary = {}
		for good: Good in goods:
			var cap_mult: float = WorldRules.DEMAND_CAP_MULT_NEUTRAL
			var rate_mult: float = WorldRules.DEMAND_DECAY_MULT_NEUTRAL
			if good.id in produces_arr:
				cap_mult = WorldRules.DEMAND_CAP_MULT_PRODUCER
				rate_mult = WorldRules.DEMAND_DECAY_MULT_PRODUCER
			elif good.id in consumes_arr:
				cap_mult = WorldRules.DEMAND_CAP_MULT_CONSUMER
				rate_mult = WorldRules.DEMAND_DECAY_MULT_CONSUMER
			var cap: int = maxi(1, roundi(float(good.base_demand_cap) * cap_mult))
			var rate: float = good.base_demand_decay_rate * rate_mult
			demand_caps[good.id] = cap
			demand_decay_rates[good.id] = rate
			# Director Q1: migrate at target. First post-update leg reads as
			# broadly favorable for selling (acceptable upgrade-UX cost).
			demand_pools[good.id] = cap
			demand_accumulators[good.id] = 0.0
		node_dict["demand_caps"] = demand_caps
		node_dict["demand_decay_rates"] = demand_decay_rates
		node_dict["demand_pools"] = demand_pools
		node_dict["demand_decay_accumulators"] = demand_accumulators
		# Spec §3.6 step 3: drop the v5 `prices` key. Erase is no-op on absent
		# key, so the migration is forward-tolerant of partial v5 dicts.
		node_dict.erase("prices")
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
