## Per-tick demand-pool decay system. Walks every (node, good) pair on
## tick_advanced and applies the spec §5.6 decay rule: demand pool grows toward
## demand_cap at demand_decay_rates[good_id] units per tick, with a float
## accumulator carrying fractional remainders. Mutates node.demand_pools and
## node.demand_decay_accumulators.
##
## "Decay" here is colloquial: the pool grows toward cap (steady-state demand
## reasserts itself between visits). Symmetric to StockSystem's refill but on
## the demand side. Decision: 2026-05-04-slice-8-demandsystem-node-placement.
##
## Sibling to StockSystem under main.tscn root. Mutations are orthogonal to
## StockSystem's (disjoint dict key sets) so listener ordering on
## Game.tick_advanced does not matter (verified by inspection -- spec §4 / §9).
class_name DemandSystem
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
		# Iterate the demand_pools key set rather than Game.goods so a save
		# written under a smaller catalogue decays correctly. forward_port_goods
		# extends to the demand quad in WorldGen; the four demand dicts share a
		# key set per node (B1 P10).
		for good_id: String in node.demand_pools.keys():
			var cap: int = int(node.demand_caps[good_id])
			var rate: float = float(node.demand_decay_rates[good_id])
			var pool: int = int(node.demand_pools[good_id])
			var accum: float = float(node.demand_decay_accumulators[good_id])
			# Spec §5.6: at cap, accumulator reset to 0 -- mirrors StockSystem
			# §3.2. Without this reset the accumulator could grow unbounded
			# while a node sits saturated.
			if pool >= cap:
				node.demand_decay_accumulators[good_id] = 0.0
				continue
			accum += rate
			var whole_units: int = int(accum)
			if whole_units > 0:
				pool = mini(cap, pool + whole_units)
				accum -= float(whole_units)
				node.demand_pools[good_id] = pool
			node.demand_decay_accumulators[good_id] = accum
	# Mirrors StockSystem: demand mutations are persistent state, raise the
	# dirty flag on the same tick boundary SaveService coalesces on.
	Game.emit_state_dirty.call()
