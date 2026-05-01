## Undirected edge between two nodes; distance is the travel-cost driver.
class_name EdgeState
extends Resource

@export var a_id: String
@export var b_id: String
@export var distance: int

func is_valid() -> bool:
	return distance > 0 and a_id != "" and b_id != "" and a_id != b_id
