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
# Slice-7 stock-cap baseline: per-(node, good) cap is derived at world-gen time
# as base_stock_cap * tag_multiplier (plentiful=4.0, neutral=1.0, scarce=0.25).
# Authored uniformly across goods (4) per spec §6.1; node tags do the
# differentiation. Range 1..100 -- a slice with cap=0 collapses the mechanic.
@export_range(1, 100) var base_stock_cap: int = 4
# Slice-7 refill baseline: per-(node, good) rate is derived as
# base_refill_rate * tag_multiplier (plentiful=5.0, neutral=1.0, scarce=0.2).
# Authored uniformly (0.2 = 1 unit / 5 ticks at neutral) per spec §6.1.
# Range 0.01..10.0 -- 0.0 is the no-refill sanity baseline only.
@export_range(0.01, 10.0) var base_refill_rate: float = 0.2
