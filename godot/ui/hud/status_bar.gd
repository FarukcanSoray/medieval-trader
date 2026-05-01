## HUD top-line readout: gold, age, and current location or in-flight travel.
## Reads Game.trader/Game.world directly; refreshes on gold_changed and tick_advanced.
class_name StatusBar
extends Control

@onready var _gold_label: Label = $HBox/GoldLabel
@onready var _age_label: Label = $HBox/AgeLabel
@onready var _location_label: Label = $HBox/LocationLabel

func _ready() -> void:
	Game.gold_changed.connect(_on_gold_changed)
	Game.tick_advanced.connect(_on_tick_advanced)
	_refresh()

func _on_gold_changed(_new_gold: int, _delta: int) -> void:
	_refresh()

func _on_tick_advanced(_new_tick: int) -> void:
	_refresh()

func _refresh() -> void:
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	if trader == null or world == null:
		_gold_label.text = "Gold: -"
		_age_label.text = "Age: -"
		_location_label.text = "Location: -"
		return
	_gold_label.text = "Gold: %dg" % trader.gold
	# Age display: ticks until Designer rules on years/ticks conversion.
	_age_label.text = "Age: %d ticks" % trader.age_ticks
	if trader.travel != null:
		_location_label.text = "Travelling %s → %s (%d ticks left)" % [
			trader.travel.from_id,
			trader.travel.to_id,
			trader.travel.ticks_remaining,
		]
	else:
		_location_label.text = "Location: %s" % _node_display_name(trader.location_node_id)

func _node_display_name(node_id: String) -> String:
	var node: NodeState = Game.world.get_node_by_id(node_id)
	if node == null:
		return "-"
	return node.display_name
