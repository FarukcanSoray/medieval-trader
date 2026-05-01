## Terminal scene rendered after Game.died. Reads Game.trader / Game.world.history /
## Game.world.death directly — this is the slice's one architect-approved cross-tree
## reach (slice-spec §2.2).
class_name DeathScreen
extends Control

@onready var _color_rect: ColorRect = $ColorRect
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _epitaph_label: Label = $Panel/VBox/EpitaphLabel
@onready var _history_list: VBoxContainer = $Panel/VBox/HistoryList
@onready var _final_ledger: Label = $Panel/VBox/FinalLedger
@onready var _quit_button: Button = $Panel/VBox/QuitButton
@onready var _begin_anew_button: Button = $Panel/VBox/BeginAnewButton
@onready var _begin_anew_confirm: BeginAnewConfirmDialog = $BeginAnewConfirm

func _ready() -> void:
	_quit_button.pressed.connect(_on_quit_pressed)
	_begin_anew_button.pressed.connect(_on_begin_anew_pressed)
	_begin_anew_confirm.confirmed.connect(_on_begin_anew_confirmed)
	_begin_anew_confirm.canceled.connect(_on_begin_anew_canceled)
	_render()
	# fade_in is authored in death_screen.tscn — trust the scene.
	_animation_player.play("fade_in")

func _render() -> void:
	# DeathScreen reading Game directly is the one architect-approved cross-tree reach (§2.2).
	var trader: TraderState = Game.trader
	var world: WorldState = Game.world
	if trader == null or world == null:
		_epitaph_label.text = "..."
		_final_ledger.text = ""
		return

	_epitaph_label.text = _build_epitaph(trader, world)
	_final_ledger.text = _build_ledger(trader, world)
	_populate_history(world)

func _build_epitaph(trader: TraderState, world: WorldState) -> String:
	var years: int = trader.age_ticks
	var death: DeathRecord = world.death
	var cause: String = "unknown" if death == null else death.cause
	var final_gold: int = trader.gold if death == null else death.final_gold
	# Last known location: empty string while travelling, fall back to from_id of the in-flight leg.
	var last_location: String = trader.location_node_id
	if last_location == "" and trader.travel != null:
		last_location = trader.travel.from_id
	var last_location_name: String = _node_display_name(last_location, world)

	# Cause-specific tail per slice-spec §7. Only "stranded" is defined for the slice.
	var tail: String
	match cause:
		"stranded":
			tail = "Stranded at %s with %dg and nowhere to go." % [last_location_name, final_gold]
		_:
			tail = "Cause: %s." % cause
	# Age display: ticks until Designer rules on years/ticks conversion.
	return "Lived %d ticks. %s" % [years, tail]

func _build_ledger(trader: TraderState, world: WorldState) -> String:
	var death: DeathRecord = world.death
	var final_gold: int = trader.gold if death == null else death.final_gold
	var final_tick: int = world.tick if death == null else death.tick
	var last_location: String = trader.location_node_id
	if last_location == "" and trader.travel != null:
		last_location = trader.travel.from_id
	return "Final ledger — gold: %dg | age: %d ticks | last location: %s | tick: %d" % [
		final_gold,
		trader.age_ticks,
		_node_display_name(last_location, world),
		final_tick,
	]

func _populate_history(world: WorldState) -> void:
	for child: Node in _history_list.get_children():
		child.queue_free()
	# Newest-first reads better for an epitaph; ring buffer is chronological so reverse.
	var entries: Array[HistoryEntry] = world.history
	for i: int in range(entries.size() - 1, -1, -1):
		var entry: HistoryEntry = entries[i]
		var line: Label = Label.new()
		line.text = "t=%d  %s  %s  (%+dg)" % [
			entry.tick, entry.kind, entry.detail, entry.delta_gold,
		]
		_history_list.add_child(line)

func _node_display_name(node_id: String, world: WorldState) -> String:
	var node: NodeState = world.get_node_by_id(node_id)
	if node == null:
		return "-"
	return node.display_name

func _on_quit_pressed() -> void:
	# Every quit awaits write_now per §5; no exception for the death-screen path.
	var save_service: SaveService = _save_service()
	if save_service != null:
		await save_service.write_now()
	get_tree().quit()

func _on_begin_anew_pressed() -> void:
	_begin_anew_button.disabled = true
	_begin_anew_confirm.popup_centered()

func _on_begin_anew_canceled() -> void:
	_begin_anew_button.disabled = false

func _on_begin_anew_confirmed() -> void:
	# Order rule: null Game refs BEFORE await, change scene AFTER await.
	# Subscribers don't observe a populated dead world during the flush, and the
	# scene swap can't race the write because change_scene_to_file follows the
	# resolved await. See decision 2026-05-01-begin-anew-order-rule.
	assert(Game.world != null and Game.trader != null, "Begin Anew confirmed in null-world state")
	var save_service: SaveService = _save_service()
	assert(save_service != null, "SaveService missing from Game tree")
	Game.world = null
	Game.trader = null
	await save_service.wipe_and_regenerate()
	get_tree().change_scene_to_file("res://main.tscn")

# SaveService is a child of the Game autoload (slice-spec §5). Same architect-
# approved cross-tree reach Main uses; centralised here to keep one site per file.
func _save_service() -> SaveService:
	return Game.get_node("SaveService") as SaveService
