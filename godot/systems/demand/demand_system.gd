## Per-tick demand-pool system. Walks every (node, good) pair on tick_advanced
## and applies two composed updates to the demand pool: (1) decay-toward-cap,
## the slice-8 refill leg, then (2) proportional drain, the slice-8.2 leg that
## pulls the pool toward a tag-differentiated steady-state ratio. Together they
## form a leaky-integrator equilibrium with pool*/cap = decay_rate / drain_rate
## (spec §3 / §5.6). Mutates node.demand_pools, node.demand_decay_accumulators,
## node.demand_drain_accumulators.
##
## "Decay" remains colloquial: the pool grows toward cap (steady-state demand
## reasserts itself between visits). Drain pulls it back down so saturation
## never sticks. Symmetric to StockSystem's refill but on the demand side.
## Decisions: 2026-05-04-slice-8-demandsystem-node-placement; slice-8.2 reshape
## ratified in docs/slice-8-2-demand-reshape-spec.md.
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
		# extends to the demand sextet in WorldGen; all six demand dicts share a
		# key set per node (B1 P10, extended for slice-8.2).
		for good_id: String in node.demand_pools.keys():
			var cap: int = int(node.demand_caps[good_id])
			var rate: float = float(node.demand_decay_rates[good_id])
			var pool: int = int(node.demand_pools[good_id])
			var decay_accum: float = float(node.demand_decay_accumulators[good_id])
			var drain_rate: float = float(node.demand_drain_rates[good_id])
			var drain_accum: float = float(node.demand_drain_accumulators[good_id])
			# --- Step 1: decay (refill toward cap), unchanged from 8.0/8.1. ---
			# Spec §5.6: at cap, accumulator reset to 0 -- mirrors StockSystem
			# §3.2. Without this reset the accumulator could grow unbounded
			# while a node sits saturated. Note: conservation may have lowered
			# cap below pool on the previous tick; this branch then re-clamps
			# pool implicitly via the at-cap reset path on the next iteration
			# (E3 in spec). Defensive clampi here keeps the post-decay value
			# valid even on the same-tick window.
			if pool >= cap:
				decay_accum = 0.0
				pool = cap
			else:
				decay_accum += rate
				var whole_units: int = int(decay_accum)
				if whole_units > 0:
					pool = mini(cap, pool + whole_units)
					decay_accum -= float(whole_units)
			# --- Step 2: drain (proportional to fill), slice-8.2. ---
			# Drain accum increment uses post-decay pool. No at-zero reset
			# needed because the drain-rate increment is proportional to
			# pool/cap and naturally zeros at pool == 0 (E2 in spec).
			# `cap > 0` guard is defensive; _author_demand's maxi(1, ...) and
			# the conservation floor of 2 already keep cap >= 1, but the guard
			# keeps the division safe under any future loosening.
			if cap > 0:
				drain_accum += drain_rate * (float(pool) / float(cap))
				var whole_drain: int = int(drain_accum)
				if whole_drain > 0:
					pool = maxi(0, pool - whole_drain)
					drain_accum -= float(whole_drain)
			# --- Write back. One write per field per (node, good). ---
			node.demand_pools[good_id] = pool
			node.demand_decay_accumulators[good_id] = decay_accum
			node.demand_drain_accumulators[good_id] = drain_accum
	# Mirrors StockSystem: demand mutations are persistent state, raise the
	# dirty flag on the same tick boundary SaveService coalesces on.
	Game.emit_state_dirty.call()
