## Entry scene root: bootstraps Game, injects state into systems, wires HUD signals,
## and owns the death/quit save-then-exit flow per slice-spec §2.1 and §5.
class_name Main
extends Node

# Inspector-wired in main.tscn to res://ui/death_screen/death_screen.tscn.
# preload() rejected (class-load cycle risk on editor F6); load(path) rejected
# (defeats static typing). @export PackedScene is the slice-spec §2.1 choice.
@export var _death_scene: PackedScene

@onready var _travel_controller: TravelController = $TravelController
@onready var _price_model: PriceModel = $PriceModel
@onready var _aging: Aging = $Aging
@onready var _trade: Trade = $Trade
@onready var _node_panel: NodePanel = $HUD/NodePanel
@onready var _travel_panel: TravelPanel = $HUD/TravelPanel
@onready var _confirm_dialog: ConfirmDialog = $HUD/ConfirmDialog
@onready var _status_bar: StatusBar = $HUD/StatusBar

# Cached between travel_requested (TravelPanel) and confirmed (ConfirmDialog) so
# the destination survives the modal round-trip without re-reading the panel.
var _pending_travel_to: String = ""

func _ready() -> void:
	# Slice-spec §5: quit handler must await SaveService.write_now() before quit;
	# auto-accept-quit would tear us down before the await resolves.
	get_tree().set_auto_accept_quit(false)

	# Architect's canonical ordering — binding. No code between bootstrap() and
	# the setup() calls; panels self-refresh on bootstrap-completion signals.
	# MapPanel anchors are resolved during scene load (before _ready), so its
	# size is non-zero by the time we read it. WorldGen places nodes in this
	# panel-local space; MapView is parented to the panel and inherits transform.
	var map_rect: Rect2 = Rect2(Vector2.ZERO, $HUD/MapPanel.size)
	await Game.bootstrap(_parse_seed_override(), map_rect)
	# Game.died only fires on the alive→dead transition; a dead-state boot never
	# re-emits, so Main must branch to DeathScreen itself. No write_now() needed —
	# the death write completed in the previous session via _on_died.
	assert(Game.world != null, "bootstrap() must populate Game.world")
	if Game.world.dead:
		get_tree().change_scene_to_packed(_death_scene)
		return
	_travel_controller.setup(Game.trader, Game.world)
	_price_model.setup(Game.world)
	_aging.setup(Game.trader)
	_trade.setup(Game.trader, Game.world)
	_travel_panel.setup(_travel_controller)
	# StatusBar / NodePanel / ConfirmDialog / DeathScreen need no setup() call —
	# they read Game.trader / Game.world directly per their Tier 6 contracts.

	# HUD → systems. Code-side Callables only — slice-spec §3 forbids editor wires.
	_node_panel.buy_requested.connect(_trade.try_buy)
	_node_panel.sell_requested.connect(_trade.try_sell)
	_travel_panel.travel_requested.connect(_on_travel_requested)
	_confirm_dialog.confirmed.connect(_on_travel_confirmed)

	Game.died.connect(_on_died)

	# Bootstrap is silent re: the four cross-system signals (slice-spec §2.1), so
	# panels that connected in their own _ready() have not seen state yet. Their
	# initial _refresh() ran with trader/world == null. Now that bootstrap is
	# complete, nudge them once so they paint the populated state.
	# Boot paint nudge per Tier 7 Debugger — order is load-bearing, see comments.
	# tick_advanced first: StatusBar reads it, SaveService gates writes on _dirty
	# (false at boot, so no-op write).
	Game.tick_advanced.emit(Game.world.tick)
	# gold_changed second: StatusBar's other source of truth; delta=0 = synthetic.
	Game.gold_changed.emit(Game.trader.gold, 0)
	# state_dirty last: paints NodePanel/TravelPanel and flips SaveService._dirty.
	# Next real tick_advanced will then write — boot stays quiet on disk.
	Game.state_dirty.emit()

	# After boot-paint so the resume's first tick_advanced -> SaveService.write_now
	# captures the freshly-painted state instead of racing the boot-paint emits.
	_travel_controller.resume_if_in_flight()

	# Toast read last so its appearance can't race the boot-paint emits or the
	# resume's first tick. One-shot consume — if no regen happened, this is a no-op.
	if Game.consume_save_corruption_notice():
		_status_bar.show_corruption_toast()

func _on_travel_requested(to_id: String) -> void:
	var from_id: String = Game.trader.location_node_id
	var cost: int = _travel_controller.compute_cost(to_id)
	var ticks: int = _distance_to(to_id)
	# UI gating in TravelPanel should prevent this, but bail rather than prompt
	# for a no-edge / same-node travel.
	if ticks <= 0:
		return
	_pending_travel_to = to_id
	_confirm_dialog.prompt(from_id, to_id, cost, ticks)

func _on_travel_confirmed() -> void:
	if _pending_travel_to == "":
		return
	var to_id: String = _pending_travel_to
	_pending_travel_to = ""
	_travel_controller.request_travel(to_id)
	# Per Architect handoff (§7 item 22): confirm → request_travel → process_tick.
	# request_travel already returned early on validation failure, so process_tick
	# is a no-op when trader.travel is null.
	_travel_controller.process_tick()

func _on_died(_cause: String) -> void:
	# Slice-spec §5: synchronous-from-the-caller's-view write before scene change.
	# SaveService also handles death writes via Game.died, but Main awaiting
	# write_now() is what the spec mandates here — the redundancy is intentional
	# because the death-side handler in SaveService isn't awaited from the emit.
	var save_service: SaveService = _save_service()
	if save_service != null:
		await save_service.write_now()
	get_tree().change_scene_to_packed(_death_scene)

func _notification(what: int) -> void:
	# _notification cannot itself await — Godot does not await its return value.
	# Fire-and-forget the async helper; set_auto_accept_quit(false) in _ready
	# keeps the engine alive long enough for write_now → quit to complete.
	# Slice-spec §7 item 22 (Architect's short-pass) ratifies this pattern.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_with_save()

func _quit_with_save() -> void:
	var save_service: SaveService = _save_service()
	if save_service != null:
		await save_service.write_now()
	get_tree().quit()

# Distance from current node to to_id, read from world.edges. Matches the
# undirected lookup pattern used in TravelController._edge_distance — kept
# private here rather than promoted to WorldState because TravelPanel and
# TravelController already each carry their own neighbour walks; one more
# tiny user is below the threshold for adding a shared helper.
func _distance_to(to_id: String) -> int:
	var world: WorldState = Game.world
	var trader: TraderState = Game.trader
	if world == null or trader == null:
		return 0
	var from_id: String = trader.location_node_id
	if from_id == "" or to_id == "" or from_id == to_id:
		return 0
	for edge: EdgeState in world.edges:
		if (edge.a_id == from_id and edge.b_id == to_id) or (edge.a_id == to_id and edge.b_id == from_id):
			return edge.distance
	return 0

# SaveService is a child of the Game autoload (slice-spec §5). game.gd does not
# expose a typed accessor — it stores the reference as a private _save_service.
# get_node("SaveService") on Game is the slice's documented reach for this one
# wire; cast to recover static typing.
func _save_service() -> SaveService:
	return Game.get_node("SaveService") as SaveService

# Slice-2: --seed=N as the first matching cmdline user arg overrides the
# wall-clock seed for fresh worlds. Per spec, regex accepts negative ints;
# downstream `seed_override >= 0` check filters them back to the wall-clock
# fallback. Returns -1 on no match or parse failure -- load-branch ignores
# this; only _generate_fresh consumes it.
func _parse_seed_override() -> int:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		return -1
	var regex: RegEx = RegEx.new()
	regex.compile("^--seed=(-?\\d+)$")
	for arg: String in args:
		var result: RegExMatch = regex.search(arg)
		if result != null:
			var parsed: int = int(result.get_string(1))
			if parsed < 0:
				push_warning("--seed=%d ignored: negative seeds use wall-clock fallback" % parsed)
				return -1
			return parsed
	return -1
