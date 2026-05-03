## Persistent per-node trading data: identity, position, and current good prices.
class_name NodeState
extends Resource

@export var id: String
@export var display_name: String
@export var pos: Vector2
@export var prices: Dictionary[String, int]
@export var bias: Dictionary[String, float]
@export var produces: Array[String]
@export var consumes: Array[String]
# Slice-7 per-(node, good) stock state. Authored at world-gen time by
# WorldGen._author_stock; mutated by Trade.try_buy (decrement) and StockSystem
# (per-tick refill). Save schema v5 persists all four. See
# docs/slice-7-production-caps-spec.md §3 (mechanic), §4 (data model).
@export var stocks: Dictionary[String, int]
@export var stock_caps: Dictionary[String, int]
@export var refill_rates: Dictionary[String, float]
@export var refill_accumulators: Dictionary[String, float]

## True iff at least one listed good is purchasable at `gold`. Empty prices → false.
func has_affordable_good(gold: int) -> bool:
	for good_id: String in prices.keys():
		if gold >= prices[good_id]:
			return true
	return false
