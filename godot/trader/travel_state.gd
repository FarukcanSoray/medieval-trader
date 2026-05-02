## Active travel leg; null on TraderState when the trader is idle at a node.
class_name TravelState
extends Resource

@export var from_id: String
@export var to_id: String
@export var ticks_remaining: int
@export var cost_paid: int
# Null when the encounter did not fire this leg (or the edge isn't a bandit road).
# A populated outcome means the encounter fired and is awaiting application at arrival.
@export var encounter: EncounterOutcome = null
