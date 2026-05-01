## Player trade verbs at the current node: try_buy and try_sell, with history logging.
class_name Trade
extends Node

var _trader: TraderState
var _world: WorldState

func setup(trader: TraderState, world: WorldState) -> void:
	_trader = trader
	_world = world

func try_buy(good_id: String) -> bool:
	if _trader == null or _world == null or _world.dead:
		return false
	# §2 / §5: trade is node-only; mid-travel trade is not a slice verb.
	if _trader.travel != null:
		return false
	var node: NodeState = _world.get_node_by_id(_trader.location_node_id)
	if node == null or not node.prices.has(good_id):
		return false
	var price: int = int(node.prices[good_id])
	# Gold first: apply_gold_delta rejects (returns false) when gold < price,
	# so we never touch inventory on a failed buy.
	if not _trader.apply_gold_delta(-price, Game.emit_gold_changed, Game.emit_state_dirty):
		return false
	_trader.apply_inventory_delta(good_id, 1, Game.emit_state_dirty)
	_push_history("buy", good_id, -price)
	return true

func try_sell(good_id: String) -> bool:
	if _trader == null or _world == null or _world.dead:
		return false
	if _trader.travel != null:
		return false
	var node: NodeState = _world.get_node_by_id(_trader.location_node_id)
	if node == null or not node.prices.has(good_id):
		return false
	# Gating check: refuse to sell what we don't have.
	if int(_trader.inventory.get(good_id, 0)) <= 0:
		return false
	var price: int = int(node.prices[good_id])
	# Inventory first, then gold: matches the file-contract ordering. The pre-gating
	# above makes the inventory delta infallible; the assert fails loud if a future
	# edit drops the gate, instead of silently swallowing the rejection.
	var inv_ok: bool = _trader.apply_inventory_delta(good_id, -1, Game.emit_state_dirty)
	assert(inv_ok, "try_sell: pre-gate violated — apply_inventory_delta rejected after qty > 0 check")
	_trader.apply_gold_delta(price, Game.emit_gold_changed, Game.emit_state_dirty)
	_push_history("sell", good_id, price)
	return true

func _push_history(kind: String, good_id: String, delta_gold: int) -> void:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.tick = _world.tick
	entry.kind = kind
	entry.detail = good_id
	entry.delta_gold = delta_gold
	_world.push_history(entry)
