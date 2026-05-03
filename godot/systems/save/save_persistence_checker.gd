## Slice-5.x save-persistence harness. Sibling to SaveInvariantChecker; same
## static-check style. Validates the *write protocol* invariants -- did the
## commit-point write fire? did the orphan-sweep clear stale .tmp? did
## rename_absolute leave no residue? -- not blob-shape invariants (those live
## in SaveInvariantChecker). Spec §5.
##
## Each check is self-contained: it sets up state on Game.world / Game.trader,
## runs the action under test, asserts on disk + in-memory state, and prints
## a PASS / FAIL line. Caller (the test scene driver) drives the four checks
## in sequence and reports overall status. Returns bool to make the driver's
## "all-pass" tally trivial.
class_name SavePersistenceChecker
extends RefCounted

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.json.tmp"

# Check 1: a successful buy through Trade.try_buy commits to disk before the
# coroutine returns. The pre-action save is captured, try_buy is awaited, the
# post-action save is read back from disk, and the gold delta + inventory key
# are asserted against the expected mutation.
static func check_buy_writes(trade: Trade, save_service: SaveService, good_id: String, expected_price: int) -> bool:
	var trader: TraderState = Game.trader
	if trader == null or trade == null or save_service == null:
		_fail("check_buy_writes", "missing trader / trade / save_service")
		return false
	var gold_before: int = trader.gold
	var qty_before: int = int(trader.inventory.get(good_id, 0))
	# Action under test: try_buy is a coroutine post-5.x; await its commit.
	var ok: bool = await trade.try_buy(good_id)
	if not ok:
		_fail("check_buy_writes", "try_buy returned false (gold %d, good '%s')" % [gold_before, good_id])
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("check_buy_writes", "save.json missing after try_buy")
		return false
	var blob: Dictionary = _read_save_blob()
	if blob.is_empty():
		_fail("check_buy_writes", "save.json unparseable after try_buy")
		return false
	var trader_dict: Dictionary = blob.get("trader", {}) as Dictionary
	var saved_gold: int = int(trader_dict.get("gold", -1))
	if saved_gold != gold_before - expected_price:
		_fail("check_buy_writes", "saved gold %d != %d" % [saved_gold, gold_before - expected_price])
		return false
	var saved_inv: Dictionary = trader_dict.get("inventory", {}) as Dictionary
	var saved_qty: int = int(saved_inv.get(good_id, 0))
	if saved_qty != qty_before + 1:
		_fail("check_buy_writes", "saved inventory['%s'] %d != %d" % [good_id, saved_qty, qty_before + 1])
		return false
	_pass("check_buy_writes")
	return true

# Check 2: arrival from a 1-tick travel commits to disk before the next tick
# fires. process_tick is awaited; on return, save.json should reflect
# location_node_id == to_id and travel == null.
static func check_travel_arrival_writes(travel_controller: TravelController, save_service: SaveService, to_id: String) -> bool:
	var trader: TraderState = Game.trader
	if trader == null or travel_controller == null or save_service == null:
		_fail("check_travel_arrival_writes", "missing trader / travel_controller / save_service")
		return false
	if trader.travel == null:
		_fail("check_travel_arrival_writes", "trader.travel is null; caller must request_travel first")
		return false
	# Drive the tick loop to completion. process_tick is already a coroutine.
	await travel_controller.process_tick()
	if trader.travel != null:
		_fail("check_travel_arrival_writes", "trader.travel non-null after process_tick")
		return false
	if trader.location_node_id != to_id:
		_fail("check_travel_arrival_writes", "trader.location_node_id '%s' != '%s'" % [trader.location_node_id, to_id])
		return false
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("check_travel_arrival_writes", "save.json missing after arrival")
		return false
	var blob: Dictionary = _read_save_blob()
	if blob.is_empty():
		_fail("check_travel_arrival_writes", "save.json unparseable after arrival")
		return false
	var trader_dict: Dictionary = blob.get("trader", {}) as Dictionary
	var saved_location: Variant = trader_dict.get("location_node_id", null)
	if saved_location == null or String(saved_location) != to_id:
		_fail("check_travel_arrival_writes", "saved location '%s' != '%s'" % [str(saved_location), to_id])
		return false
	var saved_travel: Variant = trader_dict.get("travel", null)
	if saved_travel != null:
		_fail("check_travel_arrival_writes", "saved trader.travel non-null after arrival")
		return false
	_pass("check_travel_arrival_writes")
	return true

# Check 3: a stale .tmp left on disk before load_or_init runs is swept by the
# orphan-sweep. Pre-condition: save.json exists and is valid; we plant a stub
# .tmp alongside, run load_or_init, and assert .tmp is gone after.
static func check_orphan_tmp_sweep(save_service: SaveService, map_rect: Rect2) -> bool:
	if save_service == null:
		_fail("check_orphan_tmp_sweep", "missing save_service")
		return false
	# Plant a stub .tmp. Content is intentionally not a valid save -- the sweep
	# does not validate, only deletes.
	var f: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		_fail("check_orphan_tmp_sweep", "could not open %s for write" % TMP_PATH)
		return false
	f.store_string("{\"stub\": true}")
	f.close()
	if not FileAccess.file_exists(TMP_PATH):
		_fail("check_orphan_tmp_sweep", "stub .tmp not present after planting")
		return false
	# Run load_or_init -- the sweep fires at the top, before file_exists.
	await save_service.load_or_init(-1, map_rect)
	if FileAccess.file_exists(TMP_PATH):
		_fail("check_orphan_tmp_sweep", "stub .tmp still present after load_or_init")
		return false
	_pass("check_orphan_tmp_sweep")
	return true

# Check 4: a normal write_now leaves save.json on disk and no .tmp residue.
# Validates the rename step actually fired (didn't bail) and the .tmp does
# not survive a successful write.
static func check_atomic_rename_no_residue(save_service: SaveService) -> bool:
	if save_service == null:
		_fail("check_atomic_rename_no_residue", "missing save_service")
		return false
	# Pre-clear any stray .tmp from a prior check so the assertion is clean.
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))
	await save_service.write_now()
	if not FileAccess.file_exists(SAVE_PATH):
		_fail("check_atomic_rename_no_residue", "save.json missing after write_now")
		return false
	if FileAccess.file_exists(TMP_PATH):
		_fail("check_atomic_rename_no_residue", "save.json.tmp residue after successful write_now")
		return false
	_pass("check_atomic_rename_no_residue")
	return true

static func _read_save_blob() -> Dictionary:
	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return {}
	return parsed

static func _pass(tag: String) -> void:
	print("[5.x harness] PASS %s" % tag)

static func _fail(tag: String, reason: String) -> void:
	print("[5.x harness] FAIL %s: %s" % [tag, reason])
