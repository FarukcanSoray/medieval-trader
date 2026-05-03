## Per-tick stock refill system. Walks every (node, good) pair on tick_advanced
## and applies the spec §3.2 refill rule: stock saturates at cap, the float
## accumulator carries fractional remainders so a 0.2/tick rate yields 1 unit
## every 5 ticks deterministically. Mutates node.stocks and node.refill_accumulators.
##
## Sibling to PriceModel; mounted under main.tscn root. Mutations are orthogonal
## to PriceModel's (prices) so listener ordering on Game.tick_advanced does not
## matter (verified by inspection -- spec §3.3).
class_name StockSystem
extends Node

var _world: WorldState

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)

func setup(world: WorldState) -> void:
	_world = world

func _on_tick_advanced(_new_tick: int) -> void:
	if _world == null:
		return
	for node: NodeState in _world.nodes:
		# Iterate the stocks key set rather than Game.goods so a save written
		# under a smaller catalogue refills correctly. forward_port_goods has
		# already mirrored stock authoring for goods added after a save; the
		# stocks/caps/rates/accumulators dicts share a key set per node (B1 P8).
		for good_id: String in node.stocks.keys():
			var cap: int = int(node.stock_caps[good_id])
			var rate: float = float(node.refill_rates[good_id])
			var stock: int = int(node.stocks[good_id])
			var accum: float = float(node.refill_accumulators[good_id])
			# Spec §3.2: at cap, the accumulator is reset to 0. Without this
			# reset the accumulator could grow unbounded while a node sits full
			# (impossible today since the player can only buy 1/click, but the
			# guard keeps the invariant if a multi-buy verb ever lands).
			if stock >= cap:
				node.refill_accumulators[good_id] = 0.0
				continue
			accum += rate
			var whole_units: int = int(accum)
			if whole_units > 0:
				stock = mini(cap, stock + whole_units)
				accum -= float(whole_units)
				node.stocks[good_id] = stock
			node.refill_accumulators[good_id] = accum
	# Mirrors PriceModel: stock mutations are persistent state, so the dirty
	# flag must be raised on the same tick boundary SaveService coalesces on.
	Game.emit_state_dirty.call()
