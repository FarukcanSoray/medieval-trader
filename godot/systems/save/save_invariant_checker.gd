## Post-load save-blob invariant harness. Runs in Game.bootstrap() after
## SaveService.load_or_init() to catch corruption that survived strict-reject.
class_name SaveInvariantChecker
extends RefCounted

static func check(trader: TraderState, world: WorldState) -> InvariantReport:
	var report: InvariantReport = InvariantReport.new()

	_run(report, "P1", _check_mutex(trader))
	_run(report, "P2", _check_travel_validity(trader, world))
	_run(report, "P3", _check_schema_version(world))
	_run(report, "P4", _check_death_consistency(trader, world))
	_run(report, "P5", _check_non_negative(trader, world))
	_run(report, "P6", _check_history_integrity(world))
	# Slice-7 §9: stock-pool guards. P7 bounds-checks per-(node, good) supply
	# state; P8 enforces key-set parity across the supply quad (stocks, caps,
	# rates, accumulators) so a partial-write or partial-migration surfaces.
	_run(report, "P7", _check_stock_bounds(world))
	_run(report, "P8", _check_supply_key_parity(world))
	# Slice-8 §3 / §9: demand-pool guards. P9 bounds-checks per-(node, good)
	# demand state; P10 enforces key-set parity across the demand quad and
	# against the supply quad so the two pools cannot drift in catalogue
	# coverage.
	_run(report, "P9", _check_demand_bounds(world))
	_run(report, "P10", _check_demand_key_parity(world))

	report.ok = report.violations.is_empty()
	return report

# Single fan-in for the print + violations-append protocol so every predicate
# enters and exits the report through the same shape.
static func _run(report: InvariantReport, tag: String, reason: String) -> void:
	if reason == "":
		print("[B1 harness] PASS %s" % tag)
	else:
		print("[B1 harness] FAIL %s: %s" % [tag, reason])
		report.violations.append("%s: %s" % [tag, reason])

# Each predicate returns "" on pass, or a human-readable reason on fail.

static func _check_mutex(trader: TraderState) -> String:
	var has_travel: bool = trader.travel != null
	var has_location: bool = trader.location_node_id != ""
	if has_travel and has_location:
		return "trader.travel and trader.location_node_id are both set"
	if not has_travel and not has_location:
		return "trader.travel and trader.location_node_id are both unset"
	return ""

static func _check_travel_validity(trader: TraderState, world: WorldState) -> String:
	if trader.travel == null:
		return ""
	var travel: TravelState = trader.travel
	var from_node: NodeState = world.get_node_by_id(travel.from_id)
	if from_node == null:
		return "travel.from_id '%s' not in world.nodes" % travel.from_id
	var to_node: NodeState = world.get_node_by_id(travel.to_id)
	if to_node == null:
		return "travel.to_id '%s' not in world.nodes" % travel.to_id
	var edge: EdgeState = _find_edge(world, travel.from_id, travel.to_id)
	if edge == null:
		return "no edge between '%s' and '%s'" % [travel.from_id, travel.to_id]
	if travel.ticks_remaining <= 0:
		return "ticks_remaining (%d) must be > 0" % travel.ticks_remaining
	if travel.ticks_remaining > edge.distance:
		return "ticks_remaining (%d) exceeds edge.distance (%d)" % [travel.ticks_remaining, edge.distance]
	if travel.cost_paid < 0:
		return "cost_paid (%d) must be >= 0" % travel.cost_paid
	return ""

static func _check_schema_version(world: WorldState) -> String:
	# Second wall after WorldState.from_dict's schema reject -- only fires on
	# regen-fresh worlds, which should always carry SCHEMA_VERSION.
	if world.schema_version != WorldState.SCHEMA_VERSION:
		return "world.schema_version (%d) != %d" % [world.schema_version, WorldState.SCHEMA_VERSION]
	return ""

static func _check_death_consistency(trader: TraderState, world: WorldState) -> String:
	if not world.dead:
		return ""
	if world.death == null:
		return "world.dead is true but world.death is null"
	if trader.gold != world.death.final_gold:
		return "trader.gold (%d) != world.death.final_gold (%d)" % [trader.gold, world.death.final_gold]
	if world.death.cause == "":
		return "world.death.cause is empty"
	return ""

# Slice-8: P5 dropped its `node.prices` clause -- prices are computed via
# PricingMath and structurally clamped to [floor_price, ceiling_price] by the
# helper, so a non-negative-prices invariant is vacuous post-removal. Trader /
# tick / inventory non-negativity stays.
static func _check_non_negative(trader: TraderState, world: WorldState) -> String:
	if trader.gold < 0:
		return "trader.gold (%d) < 0" % trader.gold
	if trader.age_ticks < 0:
		return "trader.age_ticks (%d) < 0" % trader.age_ticks
	if world.tick < 0:
		return "world.tick (%d) < 0" % world.tick
	for good_id: String in trader.inventory.keys():
		var qty: int = trader.inventory[good_id]
		if qty < 0:
			return "trader.inventory['%s'] (%d) < 0" % [good_id, qty]
		if qty == 0:
			return "trader.inventory['%s'] is zero (should have been erased)" % good_id
	return ""

static func _check_history_integrity(world: WorldState) -> String:
	if world.history.size() > WorldState.HISTORY_CAP:
		return "history.size() (%d) > HISTORY_CAP (%d)" % [world.history.size(), WorldState.HISTORY_CAP]
	for h: HistoryEntry in world.history:
		if h == null:
			continue
		if h.kind != "travel":
			continue
		# Wire format authored by TravelController._push_travel_history is "%s->%s"
		# (ASCII arrow) where the parts are display names, not ids.
		var parts: PackedStringArray = h.detail.split("->")
		if parts.size() != 2:
			return "travel history detail '%s' not in 'from->to' form" % h.detail
		var from_name: String = parts[0]
		var to_name: String = parts[1]
		if _find_node_by_display_name(world, from_name) == null:
			return "travel history from_name '%s' not in world.nodes" % from_name
		if _find_node_by_display_name(world, to_name) == null:
			return "travel history to_name '%s' not in world.nodes" % to_name
	return ""

# Slice-7 P7: every (node, good) supply pair must satisfy 0 <= stocks[g] <=
# caps[g] and the float accumulator must satisfy 0.0 <= accumulators[g] < 1.0.
static func _check_stock_bounds(world: WorldState) -> String:
	for node: NodeState in world.nodes:
		for good_id: String in node.stocks.keys():
			var stock: int = int(node.stocks[good_id])
			if stock < 0:
				return "node '%s' stock for '%s' (%d) < 0" % [node.id, good_id, stock]
			if not node.stock_caps.has(good_id):
				return "node '%s' has stock for '%s' but no cap" % [node.id, good_id]
			var cap: int = int(node.stock_caps[good_id])
			if stock > cap:
				return "node '%s' stock for '%s' (%d) > cap (%d)" % [node.id, good_id, stock, cap]
		for good_id: String in node.refill_accumulators.keys():
			var accum: float = float(node.refill_accumulators[good_id])
			if accum < 0.0:
				return "node '%s' refill accumulator for '%s' (%f) < 0.0" % [node.id, good_id, accum]
			if accum >= 1.0:
				return "node '%s' refill accumulator for '%s' (%f) >= 1.0" % [node.id, good_id, accum]
	return ""

# Slice-7/8 P8: supply quad key parity. The four supply dicts (stocks, caps,
# rates, accumulators) must share an identical key set per node. Slice-8 drops
# the prices clause -- the canonical reference is now stock_caps (the gen-time
# author marks every (node, good) pair via _author_supply).
static func _check_supply_key_parity(world: WorldState) -> String:
	for node: NodeState in world.nodes:
		var canonical: Dictionary[String, bool] = {}
		for k: String in node.stock_caps.keys():
			canonical[k] = true
		# Empty-canonical guard: a node with zero authored supply goods is a
		# corruption case (every node must carry the slice-7 _author_supply
		# output). Without this rail the loops below run zero iterations and
		# the predicate vacuously PASSes despite real damage.
		if canonical.is_empty():
			return "node '%s' has empty stock_caps (supply quad missing)" % node.id
		for k: String in node.stocks.keys():
			if not canonical.has(k):
				return "node '%s' has stock for '%s' but no stock_cap" % [node.id, k]
		for k: String in node.refill_rates.keys():
			if not canonical.has(k):
				return "node '%s' has refill_rate for '%s' but no stock_cap" % [node.id, k]
		for k: String in node.refill_accumulators.keys():
			if not canonical.has(k):
				return "node '%s' has refill_accumulator for '%s' but no stock_cap" % [node.id, k]
		for k: String in canonical.keys():
			if not node.stocks.has(k):
				return "node '%s' has stock_cap for '%s' but no stock" % [node.id, k]
			if not node.refill_rates.has(k):
				return "node '%s' has stock_cap for '%s' but no refill_rate" % [node.id, k]
			if not node.refill_accumulators.has(k):
				return "node '%s' has stock_cap for '%s' but no refill_accumulator" % [node.id, k]
	return ""

# Slice-8 P9: every (node, good) demand pair must satisfy 0 <= demand_pools[g]
# <= demand_caps[g], and the float accumulator must satisfy 0.0 <=
# accumulators[g] < 1.0. Mirrors P7's bound-on-state shape.
static func _check_demand_bounds(world: WorldState) -> String:
	for node: NodeState in world.nodes:
		for good_id: String in node.demand_pools.keys():
			var pool: int = int(node.demand_pools[good_id])
			if pool < 0:
				return "node '%s' demand pool for '%s' (%d) < 0" % [node.id, good_id, pool]
			if not node.demand_caps.has(good_id):
				return "node '%s' has demand pool for '%s' but no cap" % [node.id, good_id]
			var cap: int = int(node.demand_caps[good_id])
			if pool > cap:
				return "node '%s' demand pool for '%s' (%d) > cap (%d)" % [node.id, good_id, pool, cap]
		for good_id: String in node.demand_decay_accumulators.keys():
			var accum: float = float(node.demand_decay_accumulators[good_id])
			if accum < 0.0:
				return "node '%s' demand accumulator for '%s' (%f) < 0.0" % [node.id, good_id, accum]
			if accum >= 1.0:
				return "node '%s' demand accumulator for '%s' (%f) >= 1.0" % [node.id, good_id, accum]
	return ""

# Slice-8 P10: demand quad key parity, plus parity against the supply quad.
# The two pools share a catalogue (every (node, good) pair authored by
# _author_supply also gets _author_demand at gen-time and forward-port), so a
# node carrying supply for wool must also carry demand for wool and vice
# versa. Catches partial migrations and partial forward-ports.
static func _check_demand_key_parity(world: WorldState) -> String:
	for node: NodeState in world.nodes:
		var canonical: Dictionary[String, bool] = {}
		for k: String in node.demand_caps.keys():
			canonical[k] = true
		# Empty-canonical guard: mirrors P8's supply rail. A node with zero
		# authored demand goods is a corruption case (every node must carry the
		# slice-8 _author_demand output, which is gen-time paired with
		# _author_supply). Without this rail the loops below run zero
		# iterations and the predicate vacuously PASSes.
		if canonical.is_empty():
			return "node '%s' has empty demand_caps (demand quad missing)" % node.id
		for k: String in node.demand_pools.keys():
			if not canonical.has(k):
				return "node '%s' has demand pool for '%s' but no demand_cap" % [node.id, k]
		for k: String in node.demand_decay_rates.keys():
			if not canonical.has(k):
				return "node '%s' has demand_decay_rate for '%s' but no demand_cap" % [node.id, k]
		for k: String in node.demand_decay_accumulators.keys():
			if not canonical.has(k):
				return "node '%s' has demand_decay_accumulator for '%s' but no demand_cap" % [node.id, k]
		for k: String in canonical.keys():
			if not node.demand_pools.has(k):
				return "node '%s' has demand_cap for '%s' but no demand pool" % [node.id, k]
			if not node.demand_decay_rates.has(k):
				return "node '%s' has demand_cap for '%s' but no demand_decay_rate" % [node.id, k]
			if not node.demand_decay_accumulators.has(k):
				return "node '%s' has demand_cap for '%s' but no demand_decay_accumulator" % [node.id, k]
		# Cross-quad parity: supply and demand must cover the same goods.
		for k: String in node.stock_caps.keys():
			if not canonical.has(k):
				return "node '%s' has stock_cap for '%s' but no demand_cap" % [node.id, k]
		for k: String in canonical.keys():
			if not node.stock_caps.has(k):
				return "node '%s' has demand_cap for '%s' but no stock_cap" % [node.id, k]
	return ""

static func _find_node_by_display_name(world: WorldState, display_name: String) -> NodeState:
	for n: NodeState in world.nodes:
		if n.display_name == display_name:
			return n
	return null

# Mirrors TravelController._find_edge's undirected lookup.
static func _find_edge(world: WorldState, a: String, b: String) -> EdgeState:
	if a == "" or b == "" or a == b:
		return null
	for edge: EdgeState in world.edges:
		if (edge.a_id == a and edge.b_id == b) or (edge.a_id == b and edge.b_id == a):
			return edge
	return null
