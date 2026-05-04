## Per-node trade panel: lists each Good with buy price, sell price, supply bar,
## demand bar, owned qty, and Buy/Sell buttons. Emits buy_requested /
## sell_requested for Tier 7 Main to wire into Trade. Refresh is signal-driven
## on tick_advanced (perturbation re-roll), gold_changed and state_dirty (trade).
## Slice-8: prices are pulled via PricingMath on every refresh -- no stored
## prices on NodeState.
class_name NodePanel
extends Control

signal buy_requested(good_id: String)
signal sell_requested(good_id: String)

# Width of the supply / demand fill bars, in characters. 5 chars resolves the
# 0..cap range into 6 buckets ('.....' through '#####') -- enough granularity
# for at-a-glance reads without crowding the row. ASCII only (web export).
const BAR_WIDTH: int = 5

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
	# render the placeholder and skip cargo compute entirely.
	if Game.goods.is_empty():
		_cart_label.text = "Cart: -/-"
		_title_label.text = "Node: -"
		_set_all_rows_disabled(true)
		return

	# Slice-6 §8.1 / §3: single inventory walk per refresh, shared by the cart
	# label and every row's buy-predicate.
	var current_load: int = CargoMath.compute_load(trader.inventory, Game.goods_by_id)
	var min_good_weight: int = _compute_min_good_weight()
	_cart_label.text = _format_cart_label(current_load, min_good_weight)

	var travelling: bool = trader.travel != null
	var node: NodeState = world.get_node_by_id(trader.location_node_id)

	if travelling or node == null:
		_title_label.text = "Travelling..." if travelling else "Node: -"
		_set_all_rows_disabled(true)
		# Still show last-known prices/owned qty rather than blanking -- predicates only.
		for good: Good in Game.goods:
			_update_row(good, node, trader, world, current_load, true)
		return

	_title_label.text = node.display_name
	for good: Good in Game.goods:
		_update_row(good, node, trader, world, current_load, false)

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
		# Slice-8 §7: row carries B / S prices, tag, supply bar [#####], demand
		# bar <#####>, [N left] integer. Wider min size to fit the new fields
		# without truncation. Web export's default font has wider digits than
		# the editor preview suggests.
		price_label.custom_minimum_size = Vector2(280, 0)

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

func _update_row(good: Good, node: NodeState, trader: TraderState, world: WorldState, current_load: int, force_disabled: bool) -> void:
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
		price_label.text = "B - S -"
		buy_button.disabled = true
		buy_button.tooltip_text = ""
		sell_button.disabled = true
		sell_button.tooltip_text = ""
		return

	# Slice-8 pull-driven prices.
	var buy_price: int = PricingMath.buy_price_for(world, node, good.id)
	var sell_price: int = PricingMath.sell_price_for(world, node, good.id)
	var tag: String = ""
	if good.id in node.produces:
		tag = " (plentiful)"
	elif good.id in node.consumes:
		tag = " (scarce)"
	# Slice-7 §8.1 + slice-8 §7: pool fills as ASCII bars. Supply bar uses
	# square brackets, demand bar uses angle brackets so the two reads are
	# distinguishable at a glance. [N left] retained as the slice-7 precise
	# integer read.
	var stock: int = world.stock_for(node.id, good.id)
	var stock_cap: int = int(node.stock_caps.get(good.id, 0))
	var supply_bar: String = _ascii_bar(stock, stock_cap, "[", "]")
	var demand_pool: int = world.demand_for(node.id, good.id)
	var demand_cap: int = int(node.demand_caps.get(good.id, 0))
	var demand_bar: String = _ascii_bar(demand_pool, demand_cap, "<", ">")
	price_label.text = "B %dg S %dg%s %s%s [%d left]" % [
		buy_price, sell_price, tag, supply_bar, demand_bar, stock,
	]

	if force_disabled:
		buy_button.disabled = true
		buy_button.tooltip_text = ""
		sell_button.disabled = true
		sell_button.tooltip_text = ""
		return

	# Slice-6 §3 / §8.2: predicates evaluated here per slice rule -- never on
	# click. Slice-7: in_stock joins the buy predicate triplet.
	var affordable: bool = buy_price > 0 and trader.gold >= buy_price
	var fits_in_cart: bool = current_load + good.weight <= WorldRules.CARGO_CAPACITY
	var in_stock: bool = stock > 0
	buy_button.disabled = not affordable or not fits_in_cart or not in_stock
	buy_button.tooltip_text = _buy_tooltip(buy_price, trader.gold, good.weight, current_load, affordable, fits_in_cart, in_stock)
	# Slice-8 §7.2: sell button disables when demand pool is saturated. Tooltip
	# names the saturation explicitly so the player reads the refusal cause.
	var has_owned: bool = owned > 0
	var market_open: bool = demand_pool > 0
	sell_button.disabled = not has_owned or not market_open
	sell_button.tooltip_text = _sell_tooltip(has_owned, market_open)

# Slice-7 §8.2 / slice-8 §7.2: tooltip priority order is stock > cart > gold.
# Empty string when the buy is permitted; the refusal string names every
# binding constraint. ASCII only -- no arrows, no em-dashes (CLAUDE.md project
# rule).
func _buy_tooltip(price: int, gold: int, weight: int, current_load: int, affordable: bool, fits_in_cart: bool, in_stock: bool) -> String:
	if affordable and fits_in_cart and in_stock:
		return ""
	var gold_short: int = price - gold
	var space_short: int = weight - (WorldRules.CARGO_CAPACITY - current_load)
	if not in_stock:
		if not affordable and not fits_in_cart:
			return "out of stock; need %dg and %d more cart space" % [gold_short, space_short]
		if not affordable:
			return "out of stock; need %dg more" % gold_short
		if not fits_in_cart:
			return "out of stock; need %d more cart space" % space_short
		return "out of stock"
	if not affordable and not fits_in_cart:
		return "Need %dg and %d more cart space" % [gold_short, space_short]
	if not affordable:
		return "Need %dg more" % gold_short
	return "Need %d more cart space" % space_short

# Slice-8 §7.2: sell tooltip distinguishes "no inventory" from "saturated
# market." The latter is the new failure mode introduced by the demand pool;
# the player needs the explicit text or the disabled button feels like a bug.
func _sell_tooltip(has_owned: bool, market_open: bool) -> String:
	if has_owned and market_open:
		return ""
	if not has_owned:
		return ""
	# has_owned but not market_open -> saturated.
	return "local market saturated"

# Returns a fixed-width ASCII fill bar of BAR_WIDTH chars, surrounded by the
# given open/close characters. cap=0 renders an empty bar. Spec §7.2 -- supply
# uses [#####], demand uses <#####>.
func _ascii_bar(value: int, cap: int, open: String, close: String) -> String:
	if cap <= 0:
		return open + ".".repeat(BAR_WIDTH) + close
	var filled: int = clampi(roundi(float(value) / float(cap) * float(BAR_WIDTH)), 0, BAR_WIDTH)
	return open + "#".repeat(filled) + ".".repeat(BAR_WIDTH - filled) + close

func _set_all_rows_disabled(disabled: bool) -> void:
	for row: Control in _rows.values():
		var buy_button: Button = row.get_node("BuyButton")
		var sell_button: Button = row.get_node("SellButton")
		buy_button.disabled = disabled
		buy_button.tooltip_text = ""
		sell_button.disabled = disabled
		sell_button.tooltip_text = ""

func _on_buy_pressed(good_id: String) -> void:
	buy_requested.emit(good_id)

func _on_sell_pressed(good_id: String) -> void:
	sell_requested.emit(good_id)
