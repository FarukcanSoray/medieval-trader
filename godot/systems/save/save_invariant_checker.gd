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
	if world.schema_version != 1:
		return "world.schema_version (%d) != 1" % world.schema_version
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
	for node: NodeState in world.nodes:
		for good_id: String in node.prices.keys():
			var price: int = node.prices[good_id]
			if price < 0:
				return "node '%s' price for '%s' (%d) < 0" % [node.id, good_id, price]
	return ""

static func _check_history_integrity(world: WorldState) -> String:
	if world.history.size() > WorldState.HISTORY_CAP:
		return "history.size() (%d) > HISTORY_CAP (%d)" % [world.history.size(), WorldState.HISTORY_CAP]
	for h: HistoryEntry in world.history:
		# Defensive: WorldState.from_dict filters nulls today, but the harness is
		# the second wall — a future loosening of the loader shouldn't null-deref here.
		if h == null:
			continue
		if h.kind != "travel":
			continue
		# Wire format authored by TravelController._push_travel_history is "%s->%s"
		# (ASCII arrow). Runbook prose still shows the Unicode arrow but is stale
		# per the 2026-05-01 ASCII-arrows decision; trust the code, not the prose.
		var parts: PackedStringArray = h.detail.split("->")
		if parts.size() != 2:
			return "travel history detail '%s' not in 'from->to' form" % h.detail
		var from_id: String = parts[0]
		var to_id: String = parts[1]
		if world.get_node_by_id(from_id) == null:
			return "travel history from_id '%s' not in world.nodes" % from_id
		if world.get_node_by_id(to_id) == null:
			return "travel history to_id '%s' not in world.nodes" % to_id
	return ""

# Mirrors TravelController._find_edge's undirected lookup. Kept private here
# because TravelController's copy is private too; promoting to WorldState is a
# refactor outside B1's scope.
static func _find_edge(world: WorldState, a: String, b: String) -> EdgeState:
	if a == "" or b == "" or a == b:
		return null
	for edge: EdgeState in world.edges:
		if (edge.a_id == a and edge.b_id == b) or (edge.a_id == b and edge.b_id == a):
			return edge
	return null
