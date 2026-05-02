## Procgen world: places NODE_COUNT points, builds an MST + extra edges, names them, authors per-good bias, seeds tick-0 prices.
## Uses a seed-bump retry loop when placement starves or bias generation fails the free-lunch predicate; the bumped seed becomes the canonical world_seed.
class_name WorldGen

const NODE_COUNT: int = 7
const MIN_NODE_SPACING: float = 80.0
const MAX_PLACEMENT_RETRIES_PER_NODE: int = 50
const MAX_SEED_BUMPS: int = 5
const EXTRA_EDGE_COUNT: int = 2
const DISTANCE_DIVISOR: float = 50.0
# Pulled forward from slice-3.x carryover (2026-05-02-slice-2-5-free-lunch-deferred-to-pricing-slice).
# Floor of 3 makes the bias predicate satisfiable on every generated graph
# (verified via tools/measure_bias_aborts.gd: 70% abort rate at floor=2; ~0% at floor=3).
const MIN_EDGE_DISTANCE: int = 3

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
		var node_states: Array[NodeState] = _materialize_nodes_unpriced(positions, names)
		var edge_states: Array[EdgeState] = _materialize_edges(node_states, all_edges, positions)
		# Bias must be authored after edges (predicate reads shortest edge) but
		# before prices (seed-price formula reads bias). Soft-fail on free-lunch
		# unsatisfiable: bump seed and retry, mirroring the placement-starves case.
		if not _author_bias(effective_seed, node_states, edge_states, goods):
			continue
		for node: NodeState in node_states:
			node.prices = _seed_prices(effective_seed, node, goods)
		assert(_is_connected(node_states, edge_states), "worldgen: connectivity assert failed")
		var world: WorldState = WorldState.new()
		world.schema_version = WorldState.SCHEMA_VERSION
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

static func _materialize_nodes_unpriced(positions: Array[Vector2], names: Array[String]) -> Array[NodeState]:
	# Bias and prices are populated by later pipeline stages; this stage only
	# fixes identity, name, and position so _author_bias has a node list to
	# iterate without yet committing to good-keyed dicts.
	var nodes: Array[NodeState] = []
	for i: int in range(NODE_COUNT):
		var node: NodeState = NodeState.new()
		node.id = "node_%d" % i
		node.display_name = names[i]
		node.pos = positions[i]
		nodes.append(node)
	return nodes

# Tick-0 seed: anchor the price at the biased anchor and apply one drift sample.
# Mirrors the per-tick formula's centring (anchor not base_price), with no
# mean-reversion term because there is no prior old_price -- the seed IS the
# starting point. Seed namespace hash([effective_seed, 0, node_id, good.id])
# preserved so PriceModel determinism replays byte-identically post-load.
static func _seed_prices(effective_seed: int, node: NodeState, goods: Array[Good]) -> Dictionary[String, int]:
	var prices: Dictionary[String, int] = {}
	for good: Good in goods:
		assert(good.volatility > 0.0, "worldgen: good '%s' has zero volatility" % good.id)
		assert(node.bias.has(good.id), "worldgen: node '%s' missing bias for good '%s'" % [node.id, good.id])
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([effective_seed, 0, node.id, good.id])
		var anchor: int = roundi(good.base_price * (1.0 + node.bias[good.id]))
		var delta: int = roundi(rng.randf_range(-good.volatility, good.volatility) * anchor)
		prices[good.id] = clampi(anchor + delta, good.floor_price, good.ceiling_price)
	return prices

# Authors per-good per-node bias under the free-lunch predicate (spec §5.5).
# Returns false when the predicate cannot be satisfied with allowed_range >=
# MIN_BIAS_RANGE for any good -- caller bumps the seed and retries. Sub-seed
# namespace "bias" is sibling to "place"/"names"; it must not collide with the
# per-tick PriceModel hash([world_seed, tick, node_id, good_id]).
static func _author_bias(effective_seed: int, nodes: Array[NodeState], edges: Array[EdgeState], goods: Array[Good]) -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([effective_seed, "bias"])
	var min_edge_distance: int = _shortest_edge_distance(edges)
	var max_spread_gold: int = min_edge_distance * WorldRules.TRAVEL_COST_PER_DISTANCE
	var allowed_ranges: Dictionary[String, float] = {}
	for good: Good in goods:
		var allowed_range: float = _solve_bias_range(good, max_spread_gold)
		if allowed_range < WorldRules.MIN_BIAS_RANGE:
			return false
		allowed_ranges[good.id] = allowed_range
		var half: float = allowed_range / 2.0
		for node: NodeState in nodes:
			node.bias[good.id] = rng.randf_range(-half, half)
	# Tag derivation: produces/consumes are immutable post-gen labels (spec §5.6).
	for good: Good in goods:
		var allowed_range: float = allowed_ranges[good.id]
		var producer_threshold: float = -WorldRules.PRODUCER_THRESHOLD_FRACTION * (allowed_range / 2.0)
		var consumer_threshold: float = WorldRules.CONSUMER_THRESHOLD_FRACTION * (allowed_range / 2.0)
		for node: NodeState in nodes:
			var b: float = node.bias[good.id]
			if b <= producer_threshold:
				node.produces.append(good.id)
			elif b >= consumer_threshold:
				node.consumes.append(good.id)
	for good: Good in goods:
		for node: NodeState in nodes:
			assert(not (node.produces.has(good.id) and node.consumes.has(good.id)),
					"bias: node '%s' both produces and consumes good '%s'" % [node.id, good.id])
	return true

# Maximum range R such that R * base_price + 2 * volatility * ceiling_price
# < max_spread_gold (spec §5.5). Clamped to [0.0, BIAS_MAX - BIAS_MIN].
static func _solve_bias_range(good: Good, max_spread_gold: int) -> float:
	assert(good.volatility > 0.0, "worldgen: good '%s' has zero volatility" % good.id)
	assert(good.base_price > 0, "worldgen: good '%s' has non-positive base_price" % good.id)
	var volatility_term: float = 2.0 * good.volatility * float(good.ceiling_price)
	var headroom: float = float(max_spread_gold) - volatility_term
	if headroom <= 0.0:
		return 0.0
	var raw: float = headroom / float(good.base_price)
	var envelope: float = WorldRules.BIAS_MAX - WorldRules.BIAS_MIN
	return clampf(raw, 0.0, envelope)

static func _shortest_edge_distance(edges: Array[EdgeState]) -> int:
	assert(not edges.is_empty(), "worldgen: shortest-edge query on empty edge list")
	var shortest: int = edges[0].distance
	for e: EdgeState in edges:
		if e.distance < shortest:
			shortest = e.distance
	return shortest

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
