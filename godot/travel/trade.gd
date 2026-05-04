## Player trade verbs at the current node: try_buy and try_sell, with history logging.
class_name Trade
extends Node

var _trader: TraderState
var _world: WorldState

func setup(trader: TraderState, world: WorldState) -> void:
	_trader = trader
	_world = world

# Slice-5.x Bug A: try_buy is a coroutine (it awaits write_now after the history
# push). Bool return is preserved.
func try_buy(good_id: String) -> bool:
	if _trader == null or _world == null or _world.dead:
		return false
	# §2 / §5: trade is node-only; mid-travel trade is not a slice verb.
	if _trader.travel != null:
		return false
	var node: NodeState = _world.get_node_by_id(_trader.location_node_id)
	if node == null:
		return false
	# Slice-8: pool key parity is the catalogue gate (was `node.prices.has`).
	# A node without a stock_caps entry for the good is not a buy target.
	if not node.stock_caps.has(good_id):
		return false
	# Slice-7 §3.4: stock gate. Read-only check before gold deduction so a
	# refusal here costs nothing. Mutation happens after the cargo gate passes.
	if _world.stock_for(node.id, good_id) <= 0:
		return false
	# Slice-8: pull-driven price via PricingMath.
	var price: int = PricingMath.buy_price_for(_world, node, good_id)
	if price <= 0:
		return false
	# Gold first: apply_gold_delta rejects (returns false) when gold < price.
	if not _trader.apply_gold_delta(-price, Game.emit_gold_changed, Game.emit_state_dirty):
		return false
	# Slice-6 §3: defensive cargo gate. UI predicates can drift from runtime
	# predicates; the buy verb is the ground truth, not the disabled button.
	var good: Good = Game.goods_by_id.get(good_id)
	if good == null:
		_trader.apply_gold_delta(price, Game.emit_gold_changed, Game.emit_state_dirty)
		push_warning("try_buy: orphan good_id %s -- catalogue/inventory drift" % good_id)
		return false
	var weight: int = good.weight
	var current_load: int = CargoMath.compute_load(_trader.inventory, Game.goods_by_id)
	if current_load + weight > WorldRules.CARGO_CAPACITY:
		_trader.apply_gold_delta(price, Game.emit_gold_changed, Game.emit_state_dirty)
		push_warning("try_buy: cart-overflow defensive gate fired -- UI predicate drift")
		return false
	# Slice-7 §3.4: re-read stock after gold/cargo gates as a belt-and-braces
	# check. Single-threaded coroutine means stock cannot change between checks,
	# but the verb closes its own contract rather than relying on upstream
	# sequencing.
	if _world.stock_for(node.id, good_id) <= 0:
		_trader.apply_gold_delta(price, Game.emit_gold_changed, Game.emit_state_dirty)
		push_warning("try_buy: stock-race defensive gate fired -- node %s good %s" % [node.id, good_id])
		return false
	# Slice-7 §3.4: stock decrement BEFORE inventory increment. If
	# apply_inventory_delta ever became fallible, decrementing stock first is
	# the lossy direction we explicitly accept.
	_world.decrement_stock(node.id, good_id)
	_trader.apply_inventory_delta(good_id, 1, Game.emit_state_dirty)
	_push_history("buy", good_id, -price)
	# Slice-5.x Bug A commit point.
	var save_service: SaveService = Game.get_node("SaveService") as SaveService
	if save_service != null:
		await save_service.write_now()
	return true

# Slice-5.x Bug A: see try_buy header.
func try_sell(good_id: String) -> bool:
	if _trader == null or _world == null or _world.dead:
		return false
	if _trader.travel != null:
		return false
	var node: NodeState = _world.get_node_by_id(_trader.location_node_id)
	if node == null:
		return false
	# Slice-8: demand pool is the sell-side catalogue gate. A node without a
	# demand_caps entry for the good cannot be sold to.
	if not node.demand_caps.has(good_id):
		return false
	# Gating check: refuse to sell what we don't have.
	if int(_trader.inventory.get(good_id, 0)) <= 0:
		return false
	# Slice-8 §7.2: demand-pool gate. Selling into a saturated market is
	# disabled in the UI; the verb mirrors that as the ground truth.
	if _world.demand_for(node.id, good_id) <= 0:
		return false
	# Slice-8: pull-driven price via PricingMath.
	var price: int = PricingMath.sell_price_for(_world, node, good_id)
	if price <= 0:
		return false
	# Inventory first, then gold: matches the file-contract ordering. The
	# pre-gating above makes the inventory delta infallible.
	var inv_ok: bool = _trader.apply_inventory_delta(good_id, -1, Game.emit_state_dirty)
	assert(inv_ok, "try_sell: pre-gate violated -- apply_inventory_delta rejected after qty > 0 check")
	# Slice-8: drain the demand pool symmetric to try_buy draining stocks. The
	# decrement happens after inventory because demand-pool drain is the
	# world-side mutation analogous to try_buy's decrement_stock.
	_world.decrement_demand(node.id, good_id)
	_trader.apply_gold_delta(price, Game.emit_gold_changed, Game.emit_state_dirty)
	_push_history("sell", good_id, price)
	# Slice-5.x Bug A commit point.
	var save_service: SaveService = Game.get_node("SaveService") as SaveService
	if save_service != null:
		await save_service.write_now()
	return true

func _push_history(kind: String, good_id: String, delta_gold: int) -> void:
	var entry: HistoryEntry = HistoryEntry.new()
	entry.tick = _world.tick
	entry.kind = kind
	entry.detail = good_id
	entry.delta_gold = delta_gold
	_world.push_history(entry)
