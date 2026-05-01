## Per-tick price drift: applies the §5 formula against current node prices.
class_name PriceModel
extends Node

# Per-tick drift fraction. Slice-spec §6 calls for 5%-15%; 10% is the midpoint.
# [needs playtesting] — independent of WorldGen.DRIFT_FRACTION; the tick-0 init drift
# and per-tick drift are separately tunable as the slice plays.
const DRIFT_FRACTION: float = 0.10

var _world: WorldState

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)

func setup(world: WorldState) -> void:
	_world = world

func _on_tick_advanced(new_tick: int) -> void:
	if _world == null:
		return
	for node: NodeState in _world.nodes:
		_drift_node_prices(node, new_tick)
	# Mutating prices is persistent state — emit dirty so SaveService picks it up
	# on the same tick boundary it's about to coalesce on.
	Game.emit_state_dirty.call()

func _drift_node_prices(node: NodeState, tick: int) -> void:
	for good_id: String in node.prices.keys():
		# §5: same hash schema as WorldGen._seed_price — (world_seed, tick, node_id, good_id).
		# RNG-per-draw mirrors WorldGen; at slice scale (3 nodes × 2 goods = 6 allocs/tick,
		# only on player-driven travel ticks) the alloc cost is negligible.
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([_world.world_seed, tick, node.id, good_id])
		var drift_sample: float = rng.randf_range(-DRIFT_FRACTION, DRIFT_FRACTION)
		# §5: drift compounds — old_price is the CURRENT price, not good.base_price.
		var old_price: int = int(node.prices[good_id])
		var drifted: int = old_price + roundi(drift_sample * old_price)
		var good: Good = _find_good(good_id)
		if good == null:
			continue
		node.prices[good_id] = clampi(drifted, good.floor_price, good.ceiling_price)

func _find_good(good_id: String) -> Good:
	for g: Good in Game.goods:
		if g.id == good_id:
			return g
	return null
