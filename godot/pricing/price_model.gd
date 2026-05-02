## Per-tick price drift: applies the slice-3 §5.4 biased-anchor + mean-revert formula.
class_name PriceModel
extends Node

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
	# Mutating prices is persistent state -- emit dirty so SaveService picks it up
	# on the same tick boundary it's about to coalesce on.
	Game.emit_state_dirty.call()

func _drift_node_prices(node: NodeState, tick: int) -> void:
	for good_id: String in node.prices.keys():
		var good: Good = _find_good(good_id)
		if good == null:
			continue
		assert(good.volatility > 0.0, "pricing: good '%s' has zero volatility" % good_id)
		assert(node.bias.has(good_id), "pricing: node '%s' missing bias for good '%s'" % [node.id, good_id])
		# §5.4: hash([world_seed, tick, node_id, good_id]) -- determinism contract;
		# byte-identical to slice-2. Do not reorder, do not add salts.
		# RNG-per-draw mirrors WorldGen; at slice scale (7 nodes x 2 goods = 14
		# allocs/tick on player-driven ticks only) the alloc cost is negligible.
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = hash([_world.world_seed, tick, node.id, good_id])
		var anchor: int = roundi(good.base_price * (1.0 + node.bias[good_id]))
		var delta: int = roundi(rng.randf_range(-good.volatility, good.volatility) * anchor)
		var old_price: int = int(node.prices[good_id])
		var mean_revert: int = roundi((anchor - old_price) * WorldRules.MEAN_REVERT_RATE)
		node.prices[good_id] = clampi(old_price + delta + mean_revert, good.floor_price, good.ceiling_price)

func _find_good(good_id: String) -> Good:
	for g: Good in Game.goods:
		if g.id == good_id:
			return g
	return null
