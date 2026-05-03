## Hand-authored good definition; identity bounds for the price drift formula.
class_name Good
extends Resource

@export var id: String
@export var display_name: String
@export var base_price: int
@export var floor_price: int
@export var ceiling_price: int
@export var volatility: float
# Slice-6 cargo-weight: units of cart consumed per 1 unit of good. Range 1..20.
# Forward-port: slice-5 saves load with no weight stored (saves carry only the
# inventory dict); on slice-6 boots the weight is read off the on-disk .tres at
# Game._ready, never serialised. See slice-6-weight-cargo-spec §4.1.
@export_range(1, 20) var weight: int = 1
