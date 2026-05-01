## HUD top-line readout: gold, age, and current location or in-flight travel.
## Reads Game.trader/Game.world directly; refreshes on gold_changed and tick_advanced.
class_name StatusBar
extends Control

const CORRUPTION_TOAST_SECONDS: float = 4.0
# Decision 2026-05-01-save-corruption-regenerate-release-build authored this
# string with an em-dash. Downgraded to "--" to comply with the standing
# ASCII-only rule (CLAUDE.md / 2026-05-01-ascii-arrows-in-ui-strings) — the
# em-dash glyph isn't in Godot's HTML5 default font and tofus out on web.
const CORRUPTION_TOAST_TEXT: String = "Save was corrupted -- beginning anew"

@onready var _gold_label: Label = $HBox/GoldLabel
@onready var _age_label: Label = $HBox/AgeLabel
@onready var _location_label: Label = $HBox/LocationLabel
@onready var _corruption_toast: Label = $CorruptionToast

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
		_location_label.text = "Travelling %s -> %s (%d ticks left)" % [
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

func show_corruption_toast() -> void:
	_corruption_toast.text = CORRUPTION_TOAST_TEXT
	_corruption_toast.show()
	await get_tree().create_timer(CORRUPTION_TOAST_SECONDS).timeout
	# Post-await guard: scene swap (e.g., into death screen) can free us.
	if not is_instance_valid(_corruption_toast):
		return
	_corruption_toast.hide()
