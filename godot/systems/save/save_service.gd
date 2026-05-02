## Persists the trader+world blob as JSON; loads on boot, coalesces on tick, writes immediately on death.
class_name SaveService
extends Node

const SAVE_PATH: String = "user://save.json"
# Fallback rect used when callers (e.g. game.gd autoload F6, death_screen Begin
# Anew) drive a regen without a live MapPanel to read sizing from. Matches the
# previous slice-2 POS_BOUNDS extent so node placement stays within bounds even
# under fallback.
const _FALLBACK_MAP_RECT: Rect2 = Rect2(0, 0, 640, 380)

var _dirty: bool = false
var _warn_once_no_save: bool = false

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)
	Game.state_dirty.connect(_on_state_dirty)
	Game.died.connect(_on_died)

func load_or_init(seed_override: int = -1, map_rect: Rect2 = Rect2()) -> void:
	# Trust the caller's rect and forward as-is. The two load-bearing fallbacks
	# live at bootstrap() (public-API entry warning identifies bypassing call sites)
	# and _generate_fresh() (last line of defense for callers that bypass us too).
	if not FileAccess.file_exists(SAVE_PATH):
		_generate_fresh(seed_override, map_rect)
		await write_now()
		return

	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Save unreadable — regenerating world.")
		# Structural-corruption regen path: flag the toast for the next UI boot.
		# Mirror in every reject branch below; Game.consume_save_corruption_notice()
		# is one-shot so duplicates collapse harmlessly.
		Game._save_corruption_notice_pending = true
		_generate_fresh(seed_override, map_rect)
		await write_now()
		return

	var raw: String = f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		# §5 strict-reject: malformed JSON is structural corruption.
		push_warning("Save rejected: unparseable JSON — regenerating world.")
		Game._save_corruption_notice_pending = true
		_generate_fresh(seed_override, map_rect)
		await write_now()
		return

	var blob: Dictionary = parsed
	if not blob.has("trader"):
		push_warning("Save rejected: missing trader block — regenerating world.")
		Game._save_corruption_notice_pending = true
		_generate_fresh(seed_override, map_rect)
		await write_now()
		return

	var trader_value: Variant = blob["trader"]
	if not (trader_value is Dictionary):
		push_warning("Save rejected: trader block is not a dictionary — regenerating world.")
		Game._save_corruption_notice_pending = true
		_generate_fresh(seed_override, map_rect)
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
		# Schema mismatch (e.g. schema-1 -> schema-2 bump) lands here via from_dict
		# returning null; from the player's perspective this is structural corruption,
		# so the toast must fire on next UI boot.
		push_warning("Save rejected: structural corruption — regenerating world.")
		Game._save_corruption_notice_pending = true
		_generate_fresh(seed_override, map_rect)
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

# Delete the save file. Used by Begin Anew to ensure the next Main scene
# generates fresh: with no save on disk, load_or_init takes the no-save branch
# and calls _generate_fresh with Main's real MapPanel rect.
func delete_save() -> void:
	# Clear unconditionally so a future caller hitting delete_save() with no file
	# on disk still drops any stale _dirty carried over from the dead world.
	_dirty = false
	# remove_absolute no-ops on missing files, so no file_exists() guard needed.
	# Capture the return so a web-IDB hiccup is visible in the console rather
	# than silently leaving the dead save behind for the next Main load.
	var err: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_warning("delete_save: remove_absolute(%s) failed with error %d" % [SAVE_PATH, err])

# Public regen seam — regen always goes through here so the lifecycle
# (state replace + flush + dirty clear) stays atomic across callers.
# Unlike _on_tick_advanced, no in-flight state_dirty can fire during regen —
# the only writers (Trade/Travel) live in the previous scene which is being
# torn down — so clearing _dirty after the await is sufficient.
func wipe_and_regenerate(seed_override: int = -1, map_rect: Rect2 = Rect2()) -> void:
	# Trust the caller's rect and forward to _generate_fresh — the last-line-of-
	# defense fallback lives there.
	_generate_fresh(seed_override, map_rect)
	await write_now()
	_dirty = false

func _generate_fresh(seed_override: int = -1, map_rect: Rect2 = Rect2()) -> void:
	# Slice-2: --seed=N from cmdline override is plumbed here. Negative means
	# "no override"; fall back to wall-clock seed (slice-1 default).
	var world_seed: int = seed_override if seed_override >= 0 else int(Time.get_unix_time_from_system())
	# Slice-2 follow-up: map_rect tells WorldGen the panel-local coordinate space
	# to place nodes in. Empty rect = caller bypassed bootstrap (the public-API
	# entry point that substitutes its own fallback first); warn and substitute
	# here too as a last line of defense.
	var effective_rect: Rect2 = map_rect
	if effective_rect.size == Vector2.ZERO:
		push_warning("_generate_fresh called with empty map_rect; falling back to default")
		effective_rect = _FALLBACK_MAP_RECT
	Game.world = WorldGen.generate(world_seed, Game.goods, effective_rect)
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
