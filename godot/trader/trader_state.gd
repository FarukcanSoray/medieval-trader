## Persistent trader data plus the only sanctioned mutators for gold and inventory.
class_name TraderState
extends Resource

@export var gold: int
@export var age_ticks: int
@export var location_node_id: String
@export var travel: TravelState
@export var inventory: Dictionary[String, int]

func apply_gold_delta(amount: int, on_changed: Callable, on_dirty: Callable) -> bool:
	var new_gold: int = gold + amount
	if new_gold < 0:
		return false
	gold = new_gold
	if on_changed.is_valid():
		on_changed.call(gold, amount)
	if on_dirty.is_valid():
		on_dirty.call()
	return true

func apply_inventory_delta(good_id: String, qty: int, on_dirty: Callable) -> bool:
	var current: int = int(inventory.get(good_id, 0))
	var new_qty: int = current + qty
	if new_qty < 0:
		return false
	if new_qty == 0:
		inventory.erase(good_id)
	else:
		inventory[good_id] = new_qty
	if on_dirty.is_valid():
		on_dirty.call()
	return true

func to_dict() -> Dictionary:
	var travel_dict: Variant = null
	if travel != null:
		var encounter_dict: Variant = null
		if travel.encounter != null:
			encounter_dict = travel.encounter.to_dict()
		travel_dict = {
			"from_id": travel.from_id,
			"to_id": travel.to_id,
			"ticks_remaining": travel.ticks_remaining,
			"cost_paid": travel.cost_paid,
			"encounter": encounter_dict,
		}
	var location_value: Variant = null
	if location_node_id != "":
		location_value = location_node_id
	var inventory_dict: Dictionary = {}
	for good_id: String in inventory.keys():
		inventory_dict[good_id] = int(inventory[good_id])
	return {
		"gold": gold,
		"age_ticks": age_ticks,
		"location_node_id": location_value,
		"travel": travel_dict,
		"inventory": inventory_dict,
	}

## Strict reject: returns null on any structural corruption per slice-spec §8.
static func from_dict(d: Dictionary) -> TraderState:
	const REQUIRED_KEYS: Array[String] = [
		"gold", "age_ticks", "location_node_id", "travel", "inventory",
	]
	for key: String in REQUIRED_KEYS:
		if not d.has(key):
			return null
	var inv_value: Variant = d["inventory"]
	if not (inv_value is Dictionary):
		return null
	var travel_value: Variant = d["travel"]
	var travel_resource: TravelState = null
	if travel_value != null:
		if not (travel_value is Dictionary):
			return null
		travel_resource = _travel_from_dict(travel_value)
		if travel_resource == null:
			return null
	var loc_value: Variant = d["location_node_id"]
	# Slice-spec §3: location_node_id is null while travelling, otherwise a string.
	# The two states are mutually exclusive — exactly one of {travel, location} is non-null.
	if travel_resource != null and loc_value != null:
		return null
	if travel_resource == null and loc_value == null:
		return null
	var inv_typed: Dictionary[String, int] = {}
	for good_id: Variant in (inv_value as Dictionary).keys():
		inv_typed[String(good_id)] = int((inv_value as Dictionary)[good_id])
	var t: TraderState = TraderState.new()
	t.gold = int(d["gold"])
	t.age_ticks = int(d["age_ticks"])
	t.location_node_id = "" if loc_value == null else String(loc_value)
	t.travel = travel_resource
	t.inventory = inv_typed
	return t

static func _travel_from_dict(d: Dictionary) -> TravelState:
	if not d.has("from_id") or not d.has("to_id") or not d.has("ticks_remaining") or not d.has("cost_paid"):
		return null
	if not d.has("encounter"):
		return null
	var encounter_value: Variant = d["encounter"]
	var encounter_resource: EncounterOutcome = null
	if encounter_value != null:
		if not (encounter_value is Dictionary):
			return null
		encounter_resource = EncounterOutcome.from_dict(encounter_value)
		if encounter_resource == null:
			return null
	var ts: TravelState = TravelState.new()
	ts.from_id = String(d["from_id"])
	ts.to_id = String(d["to_id"])
	ts.ticks_remaining = int(d["ticks_remaining"])
	ts.cost_paid = int(d["cost_paid"])
	ts.encounter = encounter_resource
	return ts
