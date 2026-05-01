## One-shot world generator: builds three nodes, a triangle of edges, and tick-0 prices.
class_name WorldGen

# Tick-0 drift fraction. Slice-spec §6 calls for 5%-15%; 10% is the midpoint.
# [needs playtesting] — tier-5 PriceModel will own this knob in its own file.
const DRIFT_FRACTION: float = 0.10

const _NODE_HILLFARM_ID: String = "hillfarm"
const _NODE_RIVERTOWN_ID: String = "rivertown"
const _NODE_THORNHOLD_ID: String = "thornhold"

static func generate(world_seed: int, goods: Array[Good]) -> WorldState:
	var nodes: Array[NodeState] = [
		_make_node(_NODE_HILLFARM_ID, "Hillfarm", Vector2(20.0, 80.0), world_seed, goods),
		_make_node(_NODE_RIVERTOWN_ID, "Rivertown", Vector2(80.0, 70.0), world_seed, goods),
		_make_node(_NODE_THORNHOLD_ID, "Thornhold", Vector2(50.0, 15.0), world_seed, goods),
	]
	var edges: Array[EdgeState] = [
		_make_edge(_NODE_HILLFARM_ID, _NODE_RIVERTOWN_ID, 4),
		_make_edge(_NODE_RIVERTOWN_ID, _NODE_THORNHOLD_ID, 5),
		_make_edge(_NODE_THORNHOLD_ID, _NODE_HILLFARM_ID, 3),
	]
	var world: WorldState = WorldState.new()
	world.schema_version = 1
	world.world_seed = world_seed
	world.tick = 0
	world.nodes = nodes
	world.edges = edges
	world.history = [] as Array[HistoryEntry]
	world.dead = false
	world.death = null
	return world

static func _make_node(id: String, display_name: String, pos: Vector2, world_seed: int, goods: Array[Good]) -> NodeState:
	var prices: Dictionary[String, int] = {}
	for good: Good in goods:
		prices[good.id] = _seed_price(world_seed, id, good)
	var node: NodeState = NodeState.new()
	node.id = id
	node.display_name = display_name
	node.pos = pos
	node.prices = prices
	return node

static func _make_edge(a_id: String, b_id: String, distance: int) -> EdgeState:
	var edge: EdgeState = EdgeState.new()
	edge.a_id = a_id
	edge.b_id = b_id
	edge.distance = distance
	assert(edge.is_valid())
	return edge

# Slice-spec §5: clampi(old_price + roundi(rng_value * old_price), floor, ceiling),
# RNG seeded by hash(world_seed, tick, node_id, good_id) for reload determinism.
# [verify on Tier 7] Confirm hash([int, int, String, String]) is byte-stable across
# desktop and HTML5 export by running the save → reload → prices-identical check.
static func _seed_price(world_seed: int, node_id: String, good: Good) -> int:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([world_seed, 0, node_id, good.id])
	var drift_sample: float = rng.randf_range(-DRIFT_FRACTION, DRIFT_FRACTION)
	var old_price: int = good.base_price
	var drifted: int = old_price + roundi(drift_sample * old_price)
	return clampi(drifted, good.floor_price, good.ceiling_price)
