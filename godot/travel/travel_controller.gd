## Travel verb: cost preview, departure (gold-once), and per-step tick driver.
class_name TravelController
extends Node

var _trader: TraderState
var _world: WorldState

func setup(trader: TraderState, world: WorldState) -> void:
	_trader = trader
	_world = world

# Cost preview for HUD/TravelPanel (Tier 6). Returns 0 for invalid edges so the
# UI can grey out the button on no-edge / same-node / missing-deps cases.
func compute_cost(to_id: String) -> int:
	if _world == null or _trader == null:
		return 0
	var edge: EdgeState = _find_edge(_trader.location_node_id, to_id)
	if edge == null:
		return 0
	return WorldRules.edge_cost(edge)

# Validate + initiate travel. Deducts gold ONCE, sets trader.travel, clears location.
# Caller (Main, after confirm-dialog accept) then calls process_tick() to drive the loop.
func request_travel(to_id: String) -> void:
	if _trader == null or _world == null or _world.dead:
		return
	# Re-entry guard: refuse to start a new leg while one is in flight.
	if _trader.travel != null:
		return
	var edge: EdgeState = _find_edge(_trader.location_node_id, to_id)
	if edge == null:
		return
	var cost: int = WorldRules.edge_cost(edge)
	# §5: travel cost deducted ONCE at departure, never per tick.
	if not _trader.apply_gold_delta(-cost, Game.emit_gold_changed, Game.emit_state_dirty):
		# UI's compute_cost greying should prevent this; warn loud if it fires.
		push_warning("request_travel: gold < cost (%d) — UI gating broken." % cost)
		return
	var travel: TravelState = TravelState.new()
	travel.from_id = _trader.location_node_id
	travel.to_id = to_id
	travel.ticks_remaining = edge.distance
	travel.cost_paid = cost
	_trader.travel = travel
	# Mutex: exactly one of {travel, location_node_id} non-null at save boundaries.
	_trader.location_node_id = ""
	# Encounter roll uses POST-cost-deduction trader.gold so the loss percentage is
	# computed against what the trader actually carries onto the road (spec §5.3).
	# Inventory + origin-node prices feed the day-2 goods-loss target selection
	# (spec §5.7); both are pure value snapshots — resolver doesn't mutate them.
	var outcome: EncounterOutcome = EncounterResolver.try_resolve(
		_world.world_seed,
		_world.tick,
		edge,
		_trader.gold,
		_trader.inventory,
		_origin_prices_for_leg(travel.from_id),
	)
	if outcome != null:
		travel.encounter = outcome
	# History push reads _trader.travel.from_id, so it must run before any clear.
	_push_travel_history(to_id, cost)
	Game.emit_state_dirty.call()

# Drives the per-step tick loop until arrival. Per the tick-granularity-per-step
# decision: N tick_advanced for N-tick travel, not batched. The per-iteration yield
# below is wall-clock pacing, not a save-ordering primitive — see comment at the await.
func process_tick() -> void:
	if _trader == null or _world == null:
		return
	if _trader.travel == null:
		return
	while _trader.travel != null:
		# 1. Mutate world.tick + travel.ticks_remaining.
		_world.tick += 1
		_trader.travel.ticks_remaining -= 1
		# 2. Arrival: restore the {travel, location} mutex on the location side
		#    BEFORE emitting any signal, so SaveService never sees both non-null.
		if _trader.travel.ticks_remaining <= 0:
			# Snapshot from/to and the encounter before clearing travel; the
			# history detail in _format_encounter_detail reads both ids.
			var arrived_encounter: EncounterOutcome = _trader.travel.encounter
			var arrived_from_id: String = _trader.travel.from_id
			var arrived_to_id: String = _trader.travel.to_id
			_trader.location_node_id = arrived_to_id
			if arrived_encounter != null:
				_apply_encounter(arrived_encounter, arrived_from_id, arrived_to_id)
			_trader.travel = null
		# 3. state_dirty first: SaveService._dirty := true.
		Game.emit_state_dirty.call()
		# 4. tick_advanced: SaveService handler runs synchronously, awaits write_now.
		# Order load-bearing: an encounter loss above fires gold_changed while
		# trader.travel != null, so DeathService._check_stranded short-circuits at
		# its travel-guard. The tick_advanced emit below is what re-runs the
		# stranded predicate after travel is cleared. Do not reorder without
		# updating DeathService's gating.
		Game.tick_advanced.emit(_world.tick)
		# 5. Wall-clock pacing so a journey is perceptible rather than instant.
		#    SaveService's write_now completes well before the next tick at this
		#    duration; re-entry guard on SaveService._on_tick_advanced covers the
		#    future-shorter-tick case if this ever tightens.
		await get_tree().create_timer(WorldRules.TICK_DURATION_SECONDS).timeout
		# Post-await freed-state guard: scene swap or save reload between iterations
		# can tear down our deps. Mirrors entry guards above.
		if _trader == null or _world == null or not is_inside_tree():
			return

# Post-refresh resume seam. SaveService restores trader.travel correctly, but the
# process_tick() coroutine that drives ticks_remaining to zero died with the old
# scene tree — without this, every UI predicate stays gated on travel == null forever.
func resume_if_in_flight() -> void:
	if _trader != null and _trader.travel != null:
		process_tick()

func _find_edge(a: String, b: String) -> EdgeState:
	if a == "" or b == "" or a == b:
		return null
	for edge: EdgeState in _world.edges:
		if (edge.a_id == a and edge.b_id == b) or (edge.a_id == b and edge.b_id == a):
			return edge
	return null

# Snapshot helper for the encounter-roll call (spec §5.7 -- "origin price" reads
# world.nodes[from_id].prices at roll time). Returns the dict directly; the
# resolver only reads from it. Empty dict on missing node is a defensive fallback
# (the caller already validated the edge exists, so the from_id node should too).
func _origin_prices_for_leg(from_id: String) -> Dictionary[String, int]:
	var node: NodeState = _world.get_node_by_id(from_id)
	if node == null:
		return {} as Dictionary[String, int]
	return node.prices

func _push_travel_history(to_id: String, cost: int) -> void:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.tick = _world.tick
	entry.kind = "travel"
	entry.detail = "%s->%s" % [
		_world.display_name_of(_trader.travel.from_id),
		_world.display_name_of(to_id),
	]
	entry.delta_gold = -cost
	_world.push_history(entry)

# Single mutator path preserved (slice-1 contract). DeathService listens to
# gold_changed; if the loss empties gold AND no affordable outbound edge exists
# from the arrival node, DeathService fires died("stranded"). `slain` is deferred
# to slice-4.x.
func _apply_encounter(outcome: EncounterOutcome, from_id: String, to_id: String) -> void:
	if outcome.gold_loss > 0:
		_trader.apply_gold_delta(-outcome.gold_loss, Game.emit_gold_changed, Game.emit_state_dirty)
	# Day-2 goods loss; day-1 leaves these at default empty/0 so the branch is dead.
	if outcome.goods_loss_id != "" and outcome.goods_loss_qty > 0:
		_trader.apply_inventory_delta(outcome.goods_loss_id, -outcome.goods_loss_qty, Game.emit_state_dirty)
	var entry: HistoryEntry = HistoryEntry.new()
	entry.tick = _world.tick
	entry.kind = "encounter"
	entry.delta_gold = -outcome.gold_loss
	entry.detail = _format_encounter_detail(outcome, from_id, to_id)
	_world.push_history(entry)

func _format_encounter_detail(outcome: EncounterOutcome, from_id: String, to_id: String) -> String:
	var from_name: String = _world.display_name_of(from_id)
	var to_name: String = _world.display_name_of(to_id)
	# Day-1: "Hillfarm->Rivertown (bandit road, -24g)"
	# Day-2 extension: append ", -1 cloth" inside the parens if goods loss present.
	var base: String = "%s->%s (bandit road, -%dg)" % [from_name, to_name, outcome.gold_loss]
	if outcome.goods_loss_id != "" and outcome.goods_loss_qty > 0:
		base = base.left(base.length() - 1) + ", -%d %s)" % [outcome.goods_loss_qty, outcome.goods_loss_id]
	return base
