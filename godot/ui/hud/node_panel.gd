## Per-node trade panel: lists each Good with price, owned qty, and Buy/Sell buttons.
## Emits buy_requested/sell_requested for Tier 7 Main to wire into Trade. Refresh is
## signal-driven on tick_advanced (price change), gold_changed and state_dirty (trade).
class_name NodePanel
extends Control

signal buy_requested(good_id: String)
signal sell_requested(good_id: String)

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _rows_container: VBoxContainer = $VBox/Rows

# Reused row widgets keyed by good.id, rebuilt once on first refresh.
var _rows: Dictionary[String, Control] = {}

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)
	Game.gold_changed.connect(_on_gold_changed)
	Game.state_dirty.connect(_on_state_dirty)
	_refresh()

func _on_tick_advanced(_new_tick: int) -> void:
	_refresh()

func _on_gold_changed(_new_gold: int, _delta: int) -> void:
	_refresh()

func _on_state_dirty() -> void:
	_refresh()

func _refresh() -> void:
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	if trader == null or world == null:
		_title_label.text = "Node: -"
		_set_all_rows_disabled(true)
		return

	# Build rows lazily so Game.goods is available (populated in Game._ready).
	if _rows.is_empty():
		_build_rows()

	var travelling: bool = trader.travel != null
	var node: NodeState = world.get_node_by_id(trader.location_node_id)

	if travelling or node == null:
		_title_label.text = "Travelling…" if travelling else "Node: -"
		_set_all_rows_disabled(true)
		# Still show last-known prices/owned qty rather than blanking — predicates only.
		for good: Good in Game.goods:
			_update_row(good, node, trader, true)
		return

	_title_label.text = node.display_name
	for good: Good in Game.goods:
		_update_row(good, node, trader, false)

func _build_rows() -> void:
	for good: Good in Game.goods:
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Row_%s" % good.id

		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.custom_minimum_size = Vector2(96, 0)

		var price_label: Label = Label.new()
		price_label.name = "PriceLabel"
		price_label.custom_minimum_size = Vector2(96, 0)

		var owned_label: Label = Label.new()
		owned_label.name = "OwnedLabel"
		owned_label.custom_minimum_size = Vector2(96, 0)

		var buy_button: Button = Button.new()
		buy_button.name = "BuyButton"
		buy_button.text = "Buy"
		buy_button.pressed.connect(_on_buy_pressed.bind(good.id))

		var sell_button: Button = Button.new()
		sell_button.name = "SellButton"
		sell_button.text = "Sell"
		sell_button.pressed.connect(_on_sell_pressed.bind(good.id))

		row.add_child(name_label)
		row.add_child(price_label)
		row.add_child(owned_label)
		row.add_child(buy_button)
		row.add_child(sell_button)
		_rows_container.add_child(row)
		_rows[good.id] = row

func _update_row(good: Good, node: NodeState, trader: TraderState, force_disabled: bool) -> void:
	var row: Control = _rows.get(good.id)
	if row == null:
		return
	var name_label: Label = row.get_node("NameLabel")
	var price_label: Label = row.get_node("PriceLabel")
	var owned_label: Label = row.get_node("OwnedLabel")
	var buy_button: Button = row.get_node("BuyButton")
	var sell_button: Button = row.get_node("SellButton")

	name_label.text = good.display_name
	var owned: int = int(trader.inventory.get(good.id, 0))
	owned_label.text = "x%d" % owned

	if node == null:
		price_label.text = "Price: -"
		buy_button.disabled = true
		sell_button.disabled = true
		return

	var price: int = int(node.prices.get(good.id, 0))
	price_label.text = "Price: %dg" % price

	if force_disabled:
		buy_button.disabled = true
		sell_button.disabled = true
		return

	# Predicates evaluated here per slice rule — never on click.
	buy_button.disabled = price <= 0 or trader.gold < price
	sell_button.disabled = owned <= 0

func _set_all_rows_disabled(disabled: bool) -> void:
	for row: Control in _rows.values():
		var buy_button: Button = row.get_node("BuyButton")
		var sell_button: Button = row.get_node("SellButton")
		buy_button.disabled = disabled
		sell_button.disabled = disabled

func _on_buy_pressed(good_id: String) -> void:
	buy_requested.emit(good_id)

func _on_sell_pressed(good_id: String) -> void:
	sell_requested.emit(good_id)
