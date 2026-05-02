## Persistent world data: nodes, edges, history ring buffer, and death record.
class_name WorldState
extends Resource

const HISTORY_CAP: int = 10
const SCHEMA_VERSION: int = 4

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
		nodes_array.append({
			"id": n.id,
			"name": n.display_name,
			"pos": [n.pos.x, n.pos.y],
			"prices": prices_dict,
			"bias": bias_dict,
			"produces": produces_array,
			"consumes": consumes_array,
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
	if int(d["schema_version"]) != SCHEMA_VERSION:
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
	var n: NodeState = NodeState.new()
	n.id = String(d["id"])
	n.display_name = String(d["name"])
	n.pos = Vector2(float(pos_arr[0]), float(pos_arr[1]))
	n.prices = prices_typed
	n.bias = bias_typed
	n.produces = produces_typed
	n.consumes = consumes_typed
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
