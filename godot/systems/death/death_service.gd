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
# any outbound edge. Mid-travel never strands — gold is deducted once at
# departure. The boundary is `gold >= price` / `gold >= edge_cost` (strict ≥).
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
	if node != null and node.has_affordable_good(trader.gold):
		return
	for e: EdgeState in world.outbound_edges(trader.location_node_id):
		if trader.gold >= WorldRules.edge_cost(e):
			return

	# No productive action available → stranded.
	var record: DeathRecord = DeathRecord.new()
	record.tick = world.tick
	record.cause = "stranded"
	record.final_gold = trader.gold
	world.death = record
	world.dead = true
	Game.died.emit("stranded")
