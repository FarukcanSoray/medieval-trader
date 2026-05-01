## Lists neighbours of the current node with their travel cost; emits travel_requested
## for Tier 7 Main to wire into the confirm dialog. TravelController is injected via
## setup() — no cross-tree lookup. Refresh on tick_advanced (cost can move) and
## state_dirty (location/travel changes).
class_name TravelPanel
extends Control

signal travel_requested(to_id: String)

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _rows_container: VBoxContainer = $VBox/Rows

var _controller: TravelController
# Built once on first refresh once the world is available; one row per neighbour id.
var _rows: Dictionary[String, Control] = {}

func setup(controller: TravelController) -> void:
	_controller = controller

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)
	Game.state_dirty.connect(_on_state_dirty)
	_refresh()

func _on_tick_advanced(_new_tick: int) -> void:
	_refresh()

func _on_state_dirty() -> void:
	_refresh()

func _refresh() -> void:
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	if trader == null or world == null or _controller == null:
		_title_label.text = "Travel:"
		_clear_rows()
		return

	var travelling: bool = trader.travel != null
	var current_id: String = trader.location_node_id
	_title_label.text = "Travel:" if not travelling else "Travel: (in transit)"

	var neighbour_ids: Array[String] = []
	if not travelling and current_id != "":
		neighbour_ids = _neighbours_of(current_id, world)

	# Drop rows whose neighbour is no longer present (location changed).
	# Snapshot keys before iterating: we mutate _rows inside the loop.
	for existing_id: String in _rows.keys().duplicate():
		if not neighbour_ids.has(existing_id):
			var stale: Control = _rows[existing_id]
			stale.queue_free()
			_rows.erase(existing_id)

	for to_id: String in neighbour_ids:
		var row: Control = _rows.get(to_id)
		if row == null:
			row = _build_row(to_id, world)
			_rows_container.add_child(row)
			_rows[to_id] = row
		_update_row(row, to_id, trader, travelling)

func _build_row(to_id: String, world: WorldState) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row_%s" % to_id

	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	name_label.custom_minimum_size = Vector2(160, 0)
	name_label.text = _node_display_name(to_id, world)

	var cost_label: Label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.custom_minimum_size = Vector2(96, 0)

	var go_button: Button = Button.new()
	go_button.name = "GoButton"
	go_button.text = "Go"
	go_button.pressed.connect(_on_go_pressed.bind(to_id))

	row.add_child(name_label)
	row.add_child(cost_label)
	row.add_child(go_button)
	return row

func _update_row(row: Control, to_id: String, trader: TraderState, travelling: bool) -> void:
	var cost_label: Label = row.get_node("CostLabel")
	var go_button: Button = row.get_node("GoButton")
	var cost: int = _controller.compute_cost(to_id)
	cost_label.text = "Cost: %dg" % cost
	# Predicates evaluated here per slice rule — never on click.
	go_button.disabled = travelling or cost <= 0 or trader.gold < cost

func _clear_rows() -> void:
	for row: Control in _rows.values():
		row.queue_free()
	_rows.clear()

func _neighbours_of(node_id: String, world: WorldState) -> Array[String]:
	var result: Array[String] = []
	for edge: EdgeState in world.edges:
		if edge.a_id == node_id and not result.has(edge.b_id):
			result.append(edge.b_id)
		elif edge.b_id == node_id and not result.has(edge.a_id):
			result.append(edge.a_id)
	return result

func _node_display_name(node_id: String, world: WorldState) -> String:
	var node: NodeState = world.get_node_by_id(node_id)
	if node == null:
		return node_id
	return node.display_name

func _on_go_pressed(to_id: String) -> void:
	travel_requested.emit(to_id)
