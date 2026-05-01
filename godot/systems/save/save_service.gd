## Persists the trader+world blob as JSON; loads on boot, coalesces on tick, writes immediately on death.
class_name SaveService
extends Node

const SAVE_PATH: String = "user://save.json"

var _dirty: bool = false
var _warn_once_no_save: bool = false

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)
	Game.state_dirty.connect(_on_state_dirty)
	Game.died.connect(_on_died)

func load_or_init(seed_override: int = -1) -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_generate_fresh(seed_override)
		await write_now()
		return

	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Save unreadable — regenerating world.")
		_generate_fresh(seed_override)
		await write_now()
		return

	var raw: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		# §5 strict-reject: malformed JSON is structural corruption.
		push_warning("Save rejected: unparseable JSON — regenerating world.")
		_generate_fresh(seed_override)
		await write_now()
		return

	var blob: Dictionary = parsed
	if not blob.has("trader"):
		push_warning("Save rejected: missing trader block — regenerating world.")
		_generate_fresh(seed_override)
		await write_now()
		return

	var trader_value: Variant = blob["trader"]
	if not (trader_value is Dictionary):
		push_warning("Save rejected: trader block is not a dictionary — regenerating world.")
		_generate_fresh(seed_override)
		await write_now()
		return

	# Forward-compat: WorldState.from_dict accepts extra keys today, but isolating
	# the schemas means a future tightening to reject-on-extra-keys won't break load.
	var world_data: Dictionary = blob.duplicate()
	world_data.erase("trader")

	var world_loaded: WorldState = WorldState.from_dict(world_data)
	var trader_loaded: TraderState = TraderState.from_dict(trader_value)
	if world_loaded == null or trader_loaded == null:
		# §5 strict-reject: any structural corruption regenerates the world.
		# Slice-2: corruption-regen is a "generating a new world" path, so it
		# DOES consume seed_override -- consistent with the no-save-exists branch
		# above. The "loaded save wins" rule means: if we got past from_dict and
		# the load succeeded, we'd return at line 70-71 without ever consuming
		# seed_override. We only fall through here when the load itself failed.
		push_warning("Save rejected: structural corruption — regenerating world.")
		_generate_fresh(seed_override)
		await write_now()
		return

	Game.world = world_loaded
	Game.trader = trader_loaded

func write_now() -> void:
	assert(Game.world != null and Game.trader != null, "write_now requires populated state")
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		# §8: HTML5 IndexedDB unavailable / write-protected — silent fail, one warning.
		if not _warn_once_no_save:
			_warn_once_no_save = true
			push_warning("Save unavailable — playing without persistence.")
		return

	var blob: Dictionary = Game.world.to_dict()
	blob["trader"] = Game.trader.to_dict()
	f.store_string(JSON.stringify(blob, "\t"))
	f.close()
	# §3 HTML5 flush requires the await — IndexedDB isn't durable until next frame.
	await get_tree().process_frame

# Public regen seam — regen always goes through here so the lifecycle
# (state replace + flush + dirty clear) stays atomic across callers.
# Unlike _on_tick_advanced, no in-flight state_dirty can fire during regen —
# the only writers (Trade/Travel) live in the previous scene which is being
# torn down — so clearing _dirty after the await is sufficient.
func wipe_and_regenerate(seed_override: int = -1) -> void:
	_generate_fresh(seed_override)
	await write_now()
	_dirty = false

func _generate_fresh(seed_override: int = -1) -> void:
	# Slice-2: --seed=N from cmdline override is plumbed here. Negative means
	# "no override"; fall back to wall-clock seed (slice-1 default).
	var world_seed: int = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system())
	Game.world = WorldGen.generate(world_seed, Game.goods)
	var t: TraderState = TraderState.new()
	# [needs playtesting] starting gold; §6 range is 50-150.
	t.gold = 100
	t.age_ticks = 0
	# Slice-2: starting node is the highest-degree node, tie-broken by id. The
	# slice-1 hardcoded "hillfarm" is gone -- node ids are now "node_N".
	t.location_node_id = Game.world.get_starting_node_id()
	t.travel = null
	t.inventory = {} as Dictionary[String, int]
	Game.trader = t

func _on_tick_advanced(_new_tick: int) -> void:
	if not _dirty:
		return
	# Clear before awaiting so a state_dirty fired during the in-flight write
	# (e.g. between store_string and process_frame) is preserved for the next tick.
	_dirty = false
	await write_now()

func _on_state_dirty() -> void:
	_dirty = true

func _on_died(_cause: String) -> void:
	# §5: death writes are immediate, never coalesced — the record must survive a tab close.
	await write_now()
