## Resolved-at-departure encounter result; lives on TravelState.encounter only when
## the encounter actually fires. Null on TravelState means "no encounter this leg" --
## we never store a not-fired outcome (store-only-when-it-bites, per Architect call A2).
class_name EncounterOutcome
extends Resource

@export var kind: String = "bandits"
@export var gold_loss: int = 0
@export var goods_loss_id: String = ""
@export var goods_loss_qty: int = 0
# Pre-empted in slice-4 schema so the slice-4.x resolution modal lands without
# triggering another schema bump and discard-toast (Architect call A4).
@export var readback_consumed: bool = false

func to_dict() -> Dictionary:
	return {
		"kind": kind,
		"gold_loss": gold_loss,
		"goods_loss_id": goods_loss_id,
		"goods_loss_qty": goods_loss_qty,
		"readback_consumed": readback_consumed,
	}

## Strict reject: returns null on any required key missing per slice-spec §8.
## Type-checks structural containers (mirrors the codebase pattern in TraderState/
## WorldState); scalars are coerced via int()/String()/bool() per the same precedent.
static func from_dict(d: Dictionary) -> EncounterOutcome:
	const REQUIRED_KEYS: Array[String] = [
		"kind", "gold_loss", "goods_loss_id", "goods_loss_qty", "readback_consumed",
	]
	for key: String in REQUIRED_KEYS:
		if not d.has(key):
			return null
	var o: EncounterOutcome = EncounterOutcome.new()
	o.kind = String(d["kind"])
	o.gold_loss = int(d["gold_loss"])
	o.goods_loss_id = String(d["goods_loss_id"])
	o.goods_loss_qty = int(d["goods_loss_qty"])
	o.readback_consumed = bool(d["readback_consumed"])
	return o
