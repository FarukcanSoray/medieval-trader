## Single ledger row in the trader's recent-action ring buffer.
class_name HistoryEntry
extends Resource

const KINDS: Array[String] = ["buy", "sell", "travel"]

@export var tick: int
@export var kind: String
@export var detail: String
@export var delta_gold: int

static func is_valid_kind(k: String) -> bool:
	return KINDS.has(k)
