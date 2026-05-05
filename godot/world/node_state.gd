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
# loss). Decision: 2026-05-04-slice-8-nodestate-demand-dicts-shape.
#
# Slice-8.2 reshape: the demand quad becomes a sextet. drain_rates and
# drain_accumulators are written at gen time alongside decay; DemandSystem's
# tick loop applies decay then a proportional drain (pool/cap) per tick so the
# pool converges to a tag-differentiated steady-state ratio rather than
# saturating at cap. Spec: docs/slice-8-2-demand-reshape-spec.md.
@export var demand_pools: Dictionary[String, int]
@export var demand_caps: Dictionary[String, int]
@export var demand_decay_rates: Dictionary[String, float]
@export var demand_decay_accumulators: Dictionary[String, float]
@export var demand_drain_rates: Dictionary[String, float]
@export var demand_drain_accumulators: Dictionary[String, float]
# Slice-8.2 partial-conservation seed disambiguator. Incremented by Trade.try_sell
# after each conservation hash so two sells in the same tick at the same node do
# not collide on the RNG seed. Persisted across save/load -- restoring this
# field is what keeps the conservation roll deterministic on replay.
@export var sell_seed_counter: int = 0
