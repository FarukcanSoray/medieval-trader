## In-scene driver for the slice-5.x save-persistence harness. Loads the normal
## Game autoload (autoload registration is project-wide, runs for any scene),
## awaits Game.bootstrap with the project's default fallback rect, instantiates
## a Trade + TravelController locally, runs the four static checks in sequence,
## and quits. Print output is the report; no UI. Spec §5.
##
## Run with:
##   godot --path <godot-root> res://systems/save/save_persistence_test.tscn
## or headless:
##   godot --headless --path <godot-root> res://systems/save/save_persistence_test.tscn
extends Node

const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

func _ready() -> void:
	# Game autoload self-bootstraps via _f6_fallback_bootstrap_if_needed on the
	# next idle frame; await its completion before reading Game.world / trader.
	await Game.bootstrap(-1, FALLBACK_RECT)
	if Game.world == null or Game.trader == null:
		print("[5.x harness] FAIL setup: Game.bootstrap did not populate state")
		get_tree().quit(1)
		return

	var save_service: SaveService = Game.get_node("SaveService") as SaveService
	if save_service == null:
		print("[5.x harness] FAIL setup: SaveService missing under Game")
		get_tree().quit(1)
		return

	# Local Trade and TravelController. Same setup() shape Main uses.
	var trade: Trade = Trade.new()
	add_child(trade)
	trade.setup(Game.trader, Game.world)
	var travel_controller: TravelController = TravelController.new()
	add_child(travel_controller)
	travel_controller.setup(Game.trader, Game.world)

	var all_pass: bool = true

	# Check 4 first: a clean write_now leaves no .tmp residue. Run before the
	# others so subsequent .tmp residue (if any) is attributable to a check, not
	# to baseline state.
	if not await SavePersistenceChecker.check_atomic_rename_no_residue(save_service):
		all_pass = false

	# Check 1: buy commit. Pick the first good the trader's current node sells.
	var buy_target: Dictionary = _pick_buyable_good()
	if buy_target.is_empty():
		print("[5.x harness] FAIL setup: no affordable buyable good at trader's node")
		all_pass = false
	else:
		var good_id: String = String(buy_target["good_id"])
		var price: int = int(buy_target["price"])
		if not await SavePersistenceChecker.check_buy_writes(trade, save_service, good_id, price):
			all_pass = false

	# Check 2: travel-arrival commit. Pick any affordable neighbor; process_tick
	# drives the loop to arrival regardless of edge distance, and the checker
	# only asserts post-arrival state, not tick count.
	var arrival_to: String = _pick_neighbor(travel_controller)
	if arrival_to == "":
		print("[5.x harness] SKIP check_travel_arrival_writes: no affordable neighbor available")
	else:
		travel_controller.request_travel(arrival_to)
		if Game.trader.travel == null:
			print("[5.x harness] FAIL setup: request_travel did not populate trader.travel")
			all_pass = false
		else:
			if not await SavePersistenceChecker.check_travel_arrival_writes(travel_controller, save_service, arrival_to):
				all_pass = false

	# Check 3: orphan .tmp sweep. Runs last so a residual .tmp from an earlier
	# failure can't mask the assertion.
	if not await SavePersistenceChecker.check_orphan_tmp_sweep(save_service, FALLBACK_RECT):
		all_pass = false

	# Post-travel B1 re-run: bootstrap-time B1 ran before any history existed, so
	# P6's history-integrity check was vacuous. By now check_travel_arrival_writes
	# has populated a travel history entry; re-run B1 against the post-state to
	# catch P6-shaped regressions. Pull from Game.* in case check_orphan_tmp_sweep
	# reassigned trader/world via load_or_init -- the user lands on the post-state
	# next session, that's what we assert against.
	var post_report: InvariantReport = SaveInvariantChecker.check(Game.trader, Game.world)
	for tag: String in ["P1", "P2", "P3", "P4", "P5", "P6"]:
		var failure: String = ""
		for v: String in post_report.violations:
			if v.begins_with("%s:" % tag):
				failure = v
				break
		if failure == "":
			print("[B1 harness, post-travel] PASS %s" % tag)
		else:
			print("[B1 harness, post-travel] FAIL %s" % failure)
			all_pass = false

	if all_pass:
		print("[5.x harness] ALL PASS")
		get_tree().quit(0)
	else:
		print("[5.x harness] OVERALL FAIL")
		get_tree().quit(1)

# Find a good the trader can afford at the current node. Returns a dict with
# good_id + price, or empty dict if nothing is affordable.
func _pick_buyable_good() -> Dictionary:
	var trader: TraderState = Game.trader
	var node: NodeState = Game.world.get_node_by_id(trader.location_node_id)
	if node == null:
		return {}
	for good_id: String in node.prices.keys():
		var price: int = int(node.prices[good_id])
		if price > 0 and price <= trader.gold:
			return {"good_id": good_id, "price": price}
	return {}

# Find any neighbor reachable from the current node and affordable. process_tick
# drives the loop iteratively until ticks_remaining hits 0; edge distance does
# not affect the assertion shape, only the wall-clock duration of the run.
# Returns "" on no match.
func _pick_neighbor(travel_controller: TravelController) -> String:
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	var from_id: String = trader.location_node_id
	for edge: EdgeState in world.edges:
		var other: String = ""
		if edge.a_id == from_id:
			other = edge.b_id
		elif edge.b_id == from_id:
			other = edge.a_id
		else:
			continue
		var cost: int = travel_controller.compute_cost(other)
		if cost >= 0 and cost <= trader.gold:
			return other
	return ""
