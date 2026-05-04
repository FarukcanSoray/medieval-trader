## Persistent per-node trading data: identity, position, bias/tags, and the two
## pool dicts (supply + demand). Slice-8 dropped `prices` -- prices are computed
## pull-driven via PricingMath.buy_price_for / sell_price_for. Decision:
## 2026-05-04-slice-8-prices-field-dropped-pull-driven.
class_name NodeState
extends Resource

@export var id: String
@export var display_name: String
@export var pos: Vector2
@export var bias: Dictionary[String, float]
@export var produces: Array[String]
@export var consumes: Array[String]
# Slice-7 per-(node, good) supply pool. Authored at world-gen time by
# WorldGen._author_supply; mutated by Trade.try_buy (decrement) and StockSystem
# (per-tick refill toward cap). Save schema v6 persists all four. See
# docs/slice-7-production-caps-spec.md §3 (mechanic) and
# docs/slice-8-pricing-v2-spec.md §3.1 (the four-dict shape mirrored on demand side).
@export var stocks: Dictionary[String, int]
@export var stock_caps: Dictionary[String, int]
@export var refill_rates: Dictionary[String, float]
@export var refill_accumulators: Dictionary[String, float]
# Slice-8 per-(node, good) demand pool. Authored at world-gen time by
# WorldGen._author_demand; mutated by Trade.try_sell (decrement) and DemandSystem
# (per-tick decay toward cap -- "decay" here means recovery to steady-state, not
# loss). Decision: 2026-05-04-slice-8-nodestate-demand-dicts-shape. The four
# dicts mirror the supply quad above for the symmetric pool curve.
@export var demand_pools: Dictionary[String, int]
@export var demand_caps: Dictionary[String, int]
@export var demand_decay_rates: Dictionary[String, float]
@export var demand_decay_accumulators: Dictionary[String, float]
