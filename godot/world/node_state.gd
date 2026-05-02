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

## True iff at least one listed good is purchasable at `gold`. Empty prices → false.
func has_affordable_good(gold: int) -> bool:
	for good_id: String in prices.keys():
		if gold >= prices[good_id]:
			return true
	return false
