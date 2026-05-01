## Per-tick trader aging: increments age_ticks on every tick_advanced.
class_name Aging
extends Node

var _trader: TraderState

func _ready() -> void:
	Game.tick_advanced.connect(_on_tick_advanced)

func setup(trader: TraderState) -> void:
	_trader = trader

func _on_tick_advanced(_new_tick: int) -> void:
	if _trader == null:
		return
	# Direct field write: age_ticks is engine-driven, not a player verb, so the
	# apply_*_delta gating (negative-rejection, gold/inventory callbacks) doesn't apply.
	_trader.age_ticks += 1
	Game.emit_state_dirty.call()
