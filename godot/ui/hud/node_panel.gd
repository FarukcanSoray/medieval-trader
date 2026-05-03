## Per-node trade panel: lists each Good with price, owned qty, and Buy/Sell buttons.
## Emits buy_requested/sell_requested for Tier 7 Main to wire into Trade. Refresh is
## signal-driven on tick_advanced (price change), gold_changed and state_dirty (trade).
class_name NodePanel
extends Control

signal buy_requested(good_id: String)
signal sell_requested(good_id: String)

@onready var _title_label: Label = $VBox/TitleLabel
@onready var _cart_label: Label = $VBox/CartLabel
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
		_cart_label.text = "Cart: -/-"
		_set_all_rows_disabled(true)
		return

	# Build rows lazily so Game.goods is available (populated in Game._ready).
	if _rows.is_empty():
		_build_rows()

	# Slice-6 §8.1: pre-bootstrap defensive path -- if Game.goods is empty,
	# render the placeholder cart label and skip cargo compute entirely.
	# CargoMath needs goods_by_id to be populated; both fill in Game._ready.
	if Game.goods.is_empty():
		_cart_label.text = "Cart: -/-"
		_title_label.text = "Node: -"
		_set_all_rows_disabled(true)
		return

	# Slice-6 §8.1 / §3: single inventory walk per refresh, shared by the cart
	# label and every row's buy-predicate. Per-row recompute would be O(N goods)
	# inside an O(N goods) loop -- N is small but the spec is "compute once."
	var current_load: int = CargoMath.compute_load(trader.inventory, Game.goods_by_id)
	# Min weight is the "does anything fit?" threshold for the (almost full)
	# suffix. Folded once here so _update_row doesn't need to re-derive it.
	var min_good_weight: int = _compute_min_good_weight()
	_cart_label.text = _format_cart_label(current_load, min_good_weight)

	var travelling: bool = trader.travel != null
	var node: NodeState = world.get_node_by_id(trader.location_node_id)

	if travelling or node == null:
		_title_label.text = "Travelling..." if travelling else "Node: -"
		_set_all_rows_disabled(true)
		# Still show last-known prices/owned qty rather than blanking — predicates only.
		for good: Good in Game.goods:
			_update_row(good, node, trader, current_load, true)
		return

	_title_label.text = node.display_name
	for good: Good in Game.goods:
		_update_row(good, node, trader, current_load, false)

# Slice-6 §8.1: cart label suffix is " (full)" at exact cap, " (almost full)"
# when no good in the catalogue fits the remaining capacity, otherwise empty.
func _format_cart_label(current_load: int, min_good_weight: int) -> String:
	var base: String = "Cart: %d/%d" % [current_load, WorldRules.CARGO_CAPACITY]
	if current_load >= WorldRules.CARGO_CAPACITY:
		return base + " (full)"
	var remaining: int = WorldRules.CARGO_CAPACITY - current_load
	if min_good_weight > 0 and remaining < min_good_weight:
		return base + " (almost full)"
	return base

func _compute_min_good_weight() -> int:
	var min_w: int = 0
	for good: Good in Game.goods:
		if min_w == 0 or good.weight < min_w:
			min_w = good.weight
	return min_w

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

func _update_row(good: Good, node: NodeState, trader: TraderState, current_load: int, force_disabled: bool) -> void:
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
		buy_button.tooltip_text = ""
		sell_button.disabled = true
		return

	var price: int = int(node.prices.get(good.id, 0))
	var tag: String = ""
	if good.id in node.produces:
		tag = " (plentiful)"
	elif good.id in node.consumes:
		tag = " (scarce)"
	price_label.text = "Price: %dg%s" % [price, tag]

	if force_disabled:
		buy_button.disabled = true
		buy_button.tooltip_text = ""
		sell_button.disabled = true
		return

	# Slice-6 §3 / §8.2: predicates evaluated here per slice rule -- never on
	# click. fits_in_cart mirrors Trade.try_buy's defensive gate so the UI and
	# runtime predicates stay aligned (the warning fires if they ever diverge).
	var affordable: bool = price > 0 and trader.gold >= price
	var fits_in_cart: bool = current_load + good.weight <= WorldRules.CARGO_CAPACITY
	buy_button.disabled = not affordable or not fits_in_cart
	buy_button.tooltip_text = _buy_tooltip(price, trader.gold, good.weight, current_load, affordable, fits_in_cart)
	sell_button.disabled = owned <= 0

# Slice-6 §8.2: four-case tooltip. Empty string when the buy is permitted; the
# refusal string names the binding constraint(s). ASCII only -- no arrows, no
# em-dashes (CLAUDE.md project rule).
func _buy_tooltip(price: int, gold: int, weight: int, current_load: int, affordable: bool, fits_in_cart: bool) -> String:
	if affordable and fits_in_cart:
		return ""
	var gold_short: int = price - gold
	var space_short: int = weight - (WorldRules.CARGO_CAPACITY - current_load)
	if not affordable and not fits_in_cart:
		return "Need %dg and %d more cart space" % [gold_short, space_short]
	if not affordable:
		return "Need %dg more" % gold_short
	return "Need %d more cart space" % space_short

func _set_all_rows_disabled(disabled: bool) -> void:
	for row: Control in _rows.values():
		var buy_button: Button = row.get_node("BuyButton")
		var sell_button: Button = row.get_node("SellButton")
		buy_button.disabled = disabled
		# Mirror _update_row's disabled-branch tooltip clearing so a future
		# caller hitting this helper post-row-build does not leak stale
		# refusal strings. Sell rows have no tooltip today; clearing is a
		# defensive no-op for parity.
		buy_button.tooltip_text = ""
		sell_button.disabled = disabled
		sell_button.tooltip_text = ""

func _on_buy_pressed(good_id: String) -> void:
	buy_requested.emit(good_id)

func _on_sell_pressed(good_id: String) -> void:
	sell_requested.emit(good_id)
