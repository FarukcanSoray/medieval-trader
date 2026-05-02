## Procgen world: places NODE_COUNT points, builds an MST + extra edges, names them, seeds tick-0 prices.
## Uses a seed-bump retry loop when placement starves; the bumped seed becomes the canonical world_seed.
class_name WorldGen

# Tick-0 drift fraction. Slice-spec §6 calls for 5%-15%; 10% is the midpoint.
# [needs playtesting] -- tier-5 PriceModel will own this knob in its own file.
const DRIFT_FRACTION: float = 0.10

const NODE_COUNT: int = 7
const MIN_NODE_SPACING: float = 80.0
const MAX_PLACEMENT_RETRIES_PER_NODE: int = 50
const MAX_SEED_BUMPS: int = 5
const EXTRA_EDGE_COUNT: int = 2
const DISTANCE_DIVISOR: float = 50.0
const MIN_EDGE_DISTANCE: int = 2

# 40 medieval-fantasy ASCII names; first 16 Designer-authored, remaining 24 in
# the same village/town/city register. No apostrophes, no numerals, no diacritics.
const NAME_POOL: Array[String] = [
	"Hillfarm", "Rivertown", "Thornhold", "Oxmere",
	"Brackenford", "Stoneholt", "Ashbridge", "Greycastle",
	"Highmarch", "Foxdale", "Marrowfen", "Saltkeep",
	"Coldcairn", "Wytham", "Belford", "Ravensreach",
	"Eldermoor", "Westwatch", "Ironvale", "Blackwell",
	"Northgate", "Southkeep", "Mosswood", "Tallrook",
	"Briarholt", "Duskmere", "Fairhollow", "Cragstone",
	"Goldcombe", "Hartwood", "Larkford", "Pinemarch",
	"Redmarsh", "Sablecairn", "Thrushdale", "Underhill",
	"Vellhorn", "Whitecliff", "Yarrowbridge", "Brindlemoor",
]

static func generate(world_seed: int, goods: Array[Good], map_rect: Rect2) -> WorldState:
	for bump: int in range(MAX_SEED_BUMPS):
		var effective_seed: int = world_seed + bump
		var positions: Array[Vector2] = _place_positions(effective_seed, map_rect)
		if positions.is_empty():
			continue
		var mst_edges: Array[Vector2i] = _build_mst(positions)
		var extra_edges: Array[Vector2i] = _add_extra_edges(positions, mst_edges)
		var all_edges: Array[Vector2i] = mst_edges + extra_edges
		var names: Array[String] = _assign_names(effective_seed)
		# Architect handoff: store effective_seed as the canonical world_seed in
		# JSON. Reproducibility wins -- a saved world should be replayable from
		# the seed it actually used. Prices use effective_seed for the same
		# reason: internally consistent, no "original vs effective" footgun.
		var node_states: Array[NodeState] = _materialize_nodes(positions, names, effective_seed, goods)
		var edge_states: Array[EdgeState] = _materialize_edges(node_states, all_edges, positions)
		assert(_is_connected(node_states, edge_states), "worldgen: connectivity assert failed")
		var world: WorldState = WorldState.new()
		world.schema_version = 2
		world.world_seed = effective_seed
		world.tick = 0
		world.nodes = node_states
		world.edges = edge_states
		world.history = [] as Array[HistoryEntry]
		world.dead = false
		world.death = null
		var starting_id: String = world.get_starting_node_id()
		_emit_log_line(world_seed, effective_seed, node_states, edge_states, starting_id)
		return world
	push_error("worldgen: %d seed-bumps exhausted from base seed %d" % [MAX_SEED_BUMPS, world_seed])
	assert(false, "worldgen: seed-bumps exhausted")
	return null

# Returns NODE_COUNT positions inside the inner-margin shrink of map_rect, all
# pairwise >= MIN_NODE_SPACING. Returns [] when any node hits the retry cap --
# caller should bump the seed.
static func _place_positions(effective_seed: int, map_rect: Rect2) -> Array[Vector2]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([effective_seed, "place"])
	var positions: Array[Vector2] = []
	# Inner-margin shrink: 16px top/left so node circles don't clip the panel
	# border; right margin is NODE_RADIUS (16) + NAME_OFFSET.x (20) + max plausible
	# name width (~60) so the rightmost node's name label stays inside the panel.
	# Bottom margin is 16 (top) + 16 (radius) = 32.
	var inner: Rect2 = Rect2(map_rect.position + Vector2(16, 16), map_rect.size - Vector2(96, 32))
	var min_x: float = inner.position.x
	var max_x: float = inner.end.x
	var min_y: float = inner.position.y
	var max_y: float = inner.end.y
	var min_spacing_sq: float = MIN_NODE_SPACING * MIN_NODE_SPACING
	for i: int in range(NODE_COUNT):
		var placed: bool = false
		for attempt: int in range(MAX_PLACEMENT_RETRIES_PER_NODE):
			var candidate: Vector2 = Vector2(
				rng.randf_range(min_x, max_x),
				rng.randf_range(min_y, max_y),
			)
			var ok: bool = true
			for prior: Vector2 in positions:
				if candidate.distance_squared_to(prior) < min_spacing_sq:
					ok = false
					break
			if ok:
				positions.append(candidate)
				placed = true
				break
		if not placed:
			return [] as Array[Vector2]
	return positions

# Prim's MST starting from index 0. Returns NODE_COUNT-1 edges as Vector2i(i, j)
# with i < j (canonical order).
static func _build_mst(positions: Array[Vector2]) -> Array[Vector2i]:
	var n: int = positions.size()
	var in_tree: Array[bool] = []
	var dist_to_tree: Array[float] = []
	var parent: Array[int] = []
	in_tree.resize(n)
	dist_to_tree.resize(n)
	parent.resize(n)
	for i: int in range(n):
		in_tree[i] = false
		dist_to_tree[i] = INF
		parent[i] = -1
	in_tree[0] = true
	dist_to_tree[0] = 0.0
	for j: int in range(1, n):
		dist_to_tree[j] = positions[0].distance_to(positions[j])
		parent[j] = 0
	var mst: Array[Vector2i] = []
	for _step: int in range(n - 1):
		var best: int = -1
		var best_dist: float = INF
		for k: int in range(n):
			if not in_tree[k] and dist_to_tree[k] < best_dist:
				best = k
				best_dist = dist_to_tree[k]
		# Defensive: positions are connected by construction (a complete metric
		# graph), so best is always >= 0 here.
		assert(best >= 0, "worldgen: MST stalled, no candidate found")
		in_tree[best] = true
		var a: int = parent[best]
		var b: int = best
		var lo: int = mini(a, b)
		var hi: int = maxi(a, b)
		mst.append(Vector2i(lo, hi))
		for m: int in range(n):
			if not in_tree[m]:
				var d: float = positions[best].distance_to(positions[m])
				if d < dist_to_tree[m]:
					dist_to_tree[m] = d
					parent[m] = best
	return mst

# EXTRA_EDGE_COUNT shortest non-MST edges, in canonical (i < j) form.
static func _add_extra_edges(positions: Array[Vector2], mst: Array[Vector2i]) -> Array[Vector2i]:
	var mst_lookup: Dictionary[Vector2i, bool] = {}
	for e: Vector2i in mst:
		mst_lookup[e] = true
	var n: int = positions.size()
	var candidates: Array = []
	for i: int in range(n):
		for j: int in range(i + 1, n):
			var key: Vector2i = Vector2i(i, j)
			if mst_lookup.has(key):
				continue
			var d: float = positions[i].distance_to(positions[j])
			candidates.append([d, key])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var extras: Array[Vector2i] = []
	for k: int in range(min(EXTRA_EDGE_COUNT, candidates.size())):
		extras.append(candidates[k][1])
	return extras

# Fisher-Yates shuffle of NAME_POOL, take first NODE_COUNT.
static func _assign_names(effective_seed: int) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([effective_seed, "names"])
	var pool: Array[String] = NAME_POOL.duplicate()
	for i: int in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var picked: Array[String] = []
	for i: int in range(NODE_COUNT):
		picked.append(pool[i])
	return picked

static func _materialize_nodes(positions: Array[Vector2], names: Array[String], effective_seed: int, goods: Array[Good]) -> Array[NodeState]:
	# `effective_seed` is the canonical world_seed stored in JSON.
	# Prices reuse it so reload determinism holds: hash([effective_seed, 0, node_id, good.id])
	# matches whatever PriceModel will read from world.world_seed at tick 1.
	var nodes: Array[NodeState] = []
	for i: int in range(NODE_COUNT):
		var node: NodeState = NodeState.new()
		node.id = "node_%d" % i
		node.display_name = names[i]
		node.pos = positions[i]
		node.prices = _seed_prices(effective_seed, node.id, goods)
		nodes.append(node)
	return nodes

# Mirrors slice-1 _seed_price contract: hash([world_seed, 0, node_id, good.id]),
# uniform drift in [-DRIFT_FRACTION, +DRIFT_FRACTION], clamped to good bounds.
static func _seed_prices(effective_seed: int, node_id: String, goods: Array[Good]) -> Dictionary[String, int]:
	var prices: Dictionary[String, int] = {}
	for good: Good in goods:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([effective_seed, 0, node_id, good.id])
		var drift_sample: float = rng.randf_range(-DRIFT_FRACTION, DRIFT_FRACTION)
		var old_price: int = good.base_price
		var drifted: int = old_price + roundi(drift_sample * old_price)
		prices[good.id] = clampi(drifted, good.floor_price, good.ceiling_price)
	return prices

static func _materialize_edges(nodes: Array[NodeState], pairs: Array[Vector2i], positions: Array[Vector2]) -> Array[EdgeState]:
	var edges: Array[EdgeState] = []
	for pair: Vector2i in pairs:
		var i: int = pair.x
		var j: int = pair.y
		var raw: float = positions[i].distance_to(positions[j]) / DISTANCE_DIVISOR
		var distance: int = maxi(MIN_EDGE_DISTANCE, roundi(raw))
		var edge: EdgeState = EdgeState.new()
		# pairs are canonical (i < j); a_id is the lower-index node.
		edge.a_id = nodes[i].id
		edge.b_id = nodes[j].id
		edge.distance = distance
		assert(edge.distance > 0, "worldgen: edge distance must be > 0")
		assert(edge.is_valid())
		edges.append(edge)
	return edges

# Defensive invariant -- MST construction guarantees connectivity, this catches
# regressions in the generator pipeline (e.g. an edge filter introduced upstream).
# Returns bool so the caller can wrap in assert(), which compiles out in release.
static func _is_connected(nodes: Array[NodeState], edges: Array[EdgeState]) -> bool:
	if nodes.is_empty():
		return true
	var visited: Dictionary[String, bool] = {}
	var queue: Array[String] = [nodes[0].id]
	visited[nodes[0].id] = true
	while not queue.is_empty():
		var current: String = queue.pop_front()
		for e: EdgeState in edges:
			var neighbour: String = ""
			if e.a_id == current:
				neighbour = e.b_id
			elif e.b_id == current:
				neighbour = e.a_id
			else:
				continue
			if not visited.has(neighbour):
				visited[neighbour] = true
				queue.append(neighbour)
	return visited.size() == nodes.size()

static func _emit_log_line(requested_seed: int, effective_seed: int, nodes: Array[NodeState], edges: Array[EdgeState], starting_id: String) -> void:
	var min_dist: int = -1
	var max_dist: int = -1
	for e: EdgeState in edges:
		if min_dist < 0 or e.distance < min_dist:
			min_dist = e.distance
		if max_dist < 0 or e.distance > max_dist:
			max_dist = e.distance
	if requested_seed == effective_seed:
		print("worldgen: seed=%d nodes=%d edges=%d starting=%s min_edge_dist=%d max_edge_dist=%d" % [
			requested_seed, nodes.size(), edges.size(), starting_id, min_dist, max_dist,
		])
	else:
		print("worldgen: seed=%d effective=%d nodes=%d edges=%d starting=%s min_edge_dist=%d max_edge_dist=%d" % [
			requested_seed, effective_seed, nodes.size(), edges.size(), starting_id, min_dist, max_dist,
		])
