## Undirected edge between two nodes; distance is the travel-cost driver.
class_name EdgeState
extends Resource

@export var a_id: String
@export var b_id: String
@export var distance: int
@export var is_bandit_road: bool = false

func is_valid() -> bool:
	return distance > 0 and a_id != "" and b_id != "" and a_id != b_id
