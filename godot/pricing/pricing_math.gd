## Slice-8 stateless query helper for pool-driven prices.
##
## Pure function over (world, node, good_id) -> int. Reads pool state, applies
## the symmetric two-sided curve (spec §5.1, §5.2), applies a deterministic
## +/-5% perturbation seeded on (world_seed, tick, node_id, good_id, side), and
## clamps to [floor_price, ceiling_price].
##
## No state. Mirrors the project's existing static-helper precedent
## (CargoMath, WorldRules, EncounterResolver). Decision:
## 2026-05-04-slice-8-pricemodel-reshaped-stateless-query.
##
## Call sites: Trade.try_buy / try_sell (verb-time pull), NodePanel._update_row
## (per-render pull), DeathService.is_stranded (predicate-time pull).
class_name PricingMath
extends Object

# Side namespace tokens for the perturbation seed. Shared with the harness's
# determinism replay -- any change here invalidates gate 3.
const SIDE_BUY: String = "buy"
const SIDE_SELL: String = "sell"

# Side-namespace integer mixers fed into the per-call seed (replaces the prior
# String-in-Array hash([...]) form to avoid the Array literal allocation on the
# hot path). The numeric values are arbitrary high-entropy 64-bit-shaped odd
# integers; they only need to be distinct between buy and sell.
const SIDE_MIX_BUY: int = 0x9E3779B97F4A7C15
const SIDE_MIX_SELL: int = 0xBB67AE8584CAA73B

# Single shared RNG reused across all _perturbation calls. .seed is reassigned
# per call from the deterministic mix of (world_seed, tick, node_id, good_id,
# side); randf_range then produces the same value for the same inputs. Cached
# here to eliminate the per-call RandomNumberGenerator.new() allocation that
# the slice-8 review flagged on the hot path (NodePanel paint, Trade verbs,
# state_dirty fan-out, harness inner loop ~5M iterations per run).
static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Buy-side price at `node` for `good_id`. Returns 0 on missing good or missing
## pool entries (defensive: a node without a supply pool for the good cannot be
## bought from). Spec §5.1.
##
## Curve: `base * (1 + (cap - stock) / cap)` -> empty pool = 2x base, full pool
## = 1x base. Multiplied by `(1 + perturbation)` then clamped.
static func buy_price_for(world: WorldState, node: NodeState, good_id: String) -> int:
	if world == null or node == null:
		return 0
	var good: Good = _find_good(good_id)
	if good == null:
		return 0
	if not node.stock_caps.has(good_id) or not node.stocks.has(good_id):
		return 0
	var cap: int = int(node.stock_caps[good_id])
	if cap <= 0:
		return clampi(good.base_price, good.floor_price, good.ceiling_price)
	var stock: int = int(node.stocks[good_id])
	# Defensive clamp: if pool somehow overshoots cap (impossible under §5
	# clamps), the curve bottoms at base_price rather than going negative.
	var fill_gap: int = maxi(0, cap - stock)
	var curve: float = float(good.base_price) * (1.0 + float(fill_gap) / float(cap))
	var perturbation: float = _perturbation(world.world_seed, world.tick, node.id, good_id, SIDE_BUY)
	var raw: float = curve * (1.0 + perturbation)
	return clampi(roundi(raw), good.floor_price, good.ceiling_price)


## Sell-side price at `node` for `good_id`. Returns 0 on missing good or missing
## pool entries. Spec §5.2.
##
## Curve: `base * (1 + demand_pool / demand_cap)` -> drained demand (saturated
## locals) = 1x base, full demand = 2x base. Multiplied by `(1 + perturbation)`
## then clamped. Symmetric to buy: numerator is `demand_pool` (fullness drives
## premium), where buy's numerator is `cap - stock` (emptiness drives premium).
static func sell_price_for(world: WorldState, node: NodeState, good_id: String) -> int:
	if world == null or node == null:
		return 0
	var good: Good = _find_good(good_id)
	if good == null:
		return 0
	if not node.demand_caps.has(good_id) or not node.demand_pools.has(good_id):
		return 0
	var cap: int = int(node.demand_caps[good_id])
	if cap <= 0:
		return clampi(good.base_price, good.floor_price, good.ceiling_price)
	var pool: int = int(node.demand_pools[good_id])
	# Defensive clamp: pool > cap would push curve > 2*base; clamp to cap so the
	# curve tops at 2*base, matching the §5 contract.
	var fill: int = clampi(pool, 0, cap)
	var curve: float = float(good.base_price) * (1.0 + float(fill) / float(cap))
	var perturbation: float = _perturbation(world.world_seed, world.tick, node.id, good_id, SIDE_SELL)
	var raw: float = curve * (1.0 + perturbation)
	return clampi(roundi(raw), good.floor_price, good.ceiling_price)


# Deterministic +/-PERTURBATION_FRACTION sample seeded by tuple. Spec §5.4:
# seed includes tick (re-rolls each tick) and side namespace (buy/sell
# decorrelated); does NOT include pool fill (legibility -- perturbation is the
# world breathing on top of a stable curve, not a per-buy re-roll).
#
# Implementation: integer-mix the inputs into a single 64-bit seed value, then
# drive a process-shared RNG by reassigning its .seed (the documented reset
# path for RandomNumberGenerator). No per-call allocation -- no `new()`, no
# Array literal. Determinism is preserved for any (world_seed, tick, node_id,
# good_id, side) tuple within a process: same inputs -> same seed -> same
# float, which is what the gate-3 round-trip replay measures.
static func _perturbation(world_seed: int, tick: int, node_id: String, good_id: String, side: String) -> float:
	var side_mix: int = SIDE_MIX_BUY if side == SIDE_BUY else SIDE_MIX_SELL
	var seed_value: int = world_seed
	seed_value = _mix64(seed_value, tick)
	seed_value = _mix64(seed_value, node_id.hash())
	seed_value = _mix64(seed_value, good_id.hash())
	seed_value = _mix64(seed_value, side_mix)
	_rng.seed = seed_value
	return _rng.randf_range(-WorldRules.PERTURBATION_FRACTION, WorldRules.PERTURBATION_FRACTION)


# 64-bit integer mixer (xorshift-multiply, splitmix64 finaliser shape). Spreads
# the bits of `incoming` over `accumulator` so the resulting seed is sensitive
# to all five tuple components. GDScript ints are 64-bit; Godot's int math
# wraps on overflow for `*` and `+`, so the constants are interpreted modulo
# 2^64. Pure integer arithmetic -- no allocation.
static func _mix64(accumulator: int, incoming: int) -> int:
	var x: int = accumulator ^ incoming
	x = (x ^ (x >> 30)) * 0xBF58476D1CE4E5B9
	x = (x ^ (x >> 27)) * 0x94D049BB133111EB
	x = x ^ (x >> 31)
	return x


# Game.goods catalogue lookup. Mirrors the slice-3 PriceModel._find_good shape
# so headless tooling that doesn't touch the autoload can still call this -- in
# that case Game.goods is empty and the helper returns null, which both call
# sites handle as "skip this good." Headless harnesses that need pricing call
# this directly via the autoload-bootstrapped Game.
static func _find_good(good_id: String) -> Good:
	if Game.goods.is_empty():
		return null
	# Game.goods_by_id is the O(1) parallel dict (slice-6); fall back to linear
	# scan if it hasn't been populated yet (pre-_ready paths).
	if not Game.goods_by_id.is_empty():
		return Game.goods_by_id.get(good_id)
	for g: Good in Game.goods:
		if g.id == good_id:
			return g
	return null
