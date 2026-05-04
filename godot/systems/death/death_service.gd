## Evaluates the stranded predicate on every gold change and tick advance;
## writes the death record and emits Game.died.
class_name DeathService
extends Node

func _ready() -> void:
	# Both signals reach the same predicate. gold_changed catches buy/sell-driven
	# stranding; tick_advanced catches mid-travel arrivals where gold doesn't
	# move but the trader's location (and thus the affordable set) does.
	Game.gold_changed.connect(_on_gold_changed)
	Game.tick_advanced.connect(_on_tick_advanced)

func _on_gold_changed(_new_gold: int, _delta: int) -> void:
	_check_stranded()

func _on_tick_advanced(_new_tick: int) -> void:
	_check_stranded()

# Stranded := no productive action available. Per slice-spec §5 + Designer §2:
# can't sell (inventory empty), can't buy any listed good here, can't afford
# any outbound edge. Mid-travel never strands -- gold is deducted once at
# departure. The boundary is `gold >= price` / `gold >= edge_cost` (strict >=).
#
# Slice-8: affordability check now reads pull-driven buy prices via PricingMath.
# The check is gated by an in-stock probe so the price helper is only called
# for goods that could actually be purchased -- a stocked-out good cannot
# rescue the player from stranding regardless of price.
func _check_stranded() -> void:
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	if trader == null or world == null:
		return
	if world.dead:
		return
	# §5: gold is deducted once at departure; mid-travel can't strand.
	if trader.travel != null:
		return
	# §5: holding goods means a sell is still a productive action.
	if not trader.inventory.is_empty():
		return
	var node: NodeState = world.get_node_by_id(trader.location_node_id)
	if node != null and _node_has_affordable_buy(world, node, trader.gold):
		return
	for e: EdgeState in world.outbound_edges(trader.location_node_id):
		if trader.gold >= WorldRules.edge_cost(e):
			return

	# No productive action available -> stranded.
	var record: DeathRecord = DeathRecord.new()
	record.tick = world.tick
	record.cause = "stranded"
	record.final_gold = trader.gold
	world.death = record
	world.dead = true
	Game.died.emit("stranded")

# Slice-8 §8 (stranded predicate re-validation): replaces NodeState.has_affordable_good
# (removed when `prices` field dropped). True iff at least one good at `node` is
# in stock and its current pull-driven buy price is <= gold. Iterates the
# stock_caps key set (the catalogue marker for "this node sells this good").
static func _node_has_affordable_buy(world: WorldState, node: NodeState, gold: int) -> bool:
	for good_id: String in node.stock_caps.keys():
		if int(node.stocks.get(good_id, 0)) <= 0:
			continue
		var price: int = PricingMath.buy_price_for(world, node, good_id)
		if price > 0 and gold >= price:
			return true
	return false
