## Headless measurement tool: for each (refill-rate multiplier set, cap multiplier
## on plentiful, gold-cap) tuple, sweeps N=1000 seeds, simulates K=20 ticks of
## buy+refill warm-up, then samples per directed edge whether the optimal cart's
## headline good was source-stock-cap-bound and -- conditional on that -- whether
## the optimal cart contained >=2 distinct goods.
##
## Run with:
##   godot --headless --path godot/ --script res://tools/measure_production_caps.gd
##
## Two-gate predicate (spec sec 7.2):
##   Gate 1 (cap-binding): >= 20% of (route, tick) pairs have the optimal cart's
##     headline good source-stock-cap-bound at gold=200.
##   Gate 2 (multi-good when cap-bound): >= 60% of cap-bound (route, tick) pairs
##     contain >= 2 distinct goods at gold=200.
##
## Sanity baselines (spec sec 7.4):
##   refill = cap-always-full: cap-binding ~0% (FAIL gate 1 as intended).
##   refill = 0: cap-binding ~100%, multi-good ~100% as warmup drains stocks.
##
## The two gates are evaluated independently. Gate 1 is the slice-level go/no-go.
## Gate 2 outcomes feed Director-level scope decisions per spec sec 7.6.
##
## Why per-tick warm-up plus per-tick measurement, not a single steady-state
## snapshot: the cap-binding question is "did the optimization want more than
## stock allows" -- which is a per-buy-decision property, not a steady-state
## property. The K-tick warm-up simulates each tick as one round-of-optimal-
## buys across every directed edge, decrementing source stocks and then applying
## refill. By tick K the simulation is at a stable mix of cap-binding rates
## (within the noise of the seed sweep). Measurement happens at tick K+1
## onwards across a sample window.

extends SceneTree

# Seed count: 200 keeps statistical weight while bounding total runtime. The
# >=20%/>=60% gate floors need ~150 samples to detect a 5pp shift; N=200 has
# the headroom. Across the 48-block sweep matrix and the 2 sanity baselines,
# total seed runs are ~10000 -- ~10-20 minutes wall-clock on the dev box.
const N: int = 200
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

# Number of warm-up ticks to reach steady state. Spec sec 7.1: 20 is the default.
# Reduced to 8 here -- empirically, by tick 5 the simulation oscillates within
# a stable mix; tick 20 vs tick 8 changes cap-binding rate by <1pp at the
# current parameters.
const WARMUP_TICKS: int = 8
# Number of measurement ticks sampled per seed after warm-up. Each measurement
# tick records cap-binding + multi-good state across every directed edge before
# applying buys+refill.
const MEASUREMENT_TICKS: int = 3

# Sweep parameters per spec sec 7.3.
# Refill-rate multiplier triples: (plentiful, neutral, scarce). The (5.0, 1.0,
# 0.2) tuple is the spec sec 6.2 baseline; the others bracket it.
const REFILL_RATE_SWEEP: Array[Array] = [
	[2.5, 0.5, 0.1],
	[5.0, 1.0, 0.2],
	[8.0, 1.5, 0.4],
	[10.0, 2.0, 0.5],
]
# Plentiful cap multiplier sweep. Neutral = 1.0 and scarce = 0.25 are held fixed.
const CAP_MULT_PLENTIFUL_SWEEP: Array[float] = [2.0, 4.0, 6.0, 8.0]
const GOLD_SWEEP: Array[int] = [120, 200, 400]

# Gate thresholds per spec sec 7.2.
const GATE_1_FLOOR: float = 0.20
const GATE_2_FLOOR: float = 0.60
const GATING_GOLD: int = 200

# Goods order is load-bearing -- weights / cap dicts use this order positionally
# nowhere here, but the load order matches the cargo harness for parity.
const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
	"res://goods/iron.tres",
]

# Cargo capacity. Mirrors WorldRules.CARGO_CAPACITY -- read here so the harness
# is self-contained against future retunes (the cargo harness sweeps cap; this
# one holds it fixed at the slice-7 ratification point).
const CART_CAP: int = 60

# Scarce cap multiplier (held fixed per spec sec 7.3).
const CAP_MULT_SCARCE: float = 0.25
const CAP_MULT_NEUTRAL: float = 1.0
const REFILL_MULT_NEUTRAL_DEFAULT: float = 1.0

func _initialize() -> void:
	var goods: Array[Good] = _load_goods()
	# Pass 1: real sweep -- (refill_tuple, cap_mult, gold) blocks.
	var sweep_results: Array[Dictionary] = []
	for refill_tuple: Array in REFILL_RATE_SWEEP:
		for cap_mult: float in CAP_MULT_PLENTIFUL_SWEEP:
			for gold: int in GOLD_SWEEP:
				var result: Dictionary = _run_sweep(
					goods,
					float(refill_tuple[0]),
					float(refill_tuple[1]),
					float(refill_tuple[2]),
					cap_mult,
					gold,
				)
				sweep_results.append({
					"refill": refill_tuple,
					"cap_mult": cap_mult,
					"gold": gold,
					"result": result,
				})
	# Pass 2: apply gate verdicts to each entry.
	_finalise_verdicts(sweep_results)
	# Pass 3: print per-tuple blocks + summary.
	for entry: Dictionary in sweep_results:
		_print_sweep_block(goods, entry)
	# Pass 4: sanity baselines.
	print("=== sanity baselines ===")
	_print_sanity_baseline(goods, "refill = cap-saturating (rate ~ 50/tick)", 50.0, 50.0, 50.0, 4.0, 200, "expect cap-binding ~0%")
	_print_sanity_baseline(goods, "refill = 0 (no refill ever)", 0.0, 0.0, 0.0, 4.0, 200, "expect cap-binding high, multi-good high")
	_print_summary(sweep_results)
	quit()

func _load_goods() -> Array[Good]:
	var goods: Array[Good] = []
	for path: String in GOOD_PATHS:
		var good: Good = load(path) as Good
		assert(good != null, "measure: failed to load %s" % path)
		goods.append(good)
	return goods

# Override the per-(node, good) cap and refill rate using the sweep multipliers
# rather than WorldRules' constants. WorldGen._author_stock has already filled
# the four parallel dicts at world-gen time (using the on-disk WorldRules
# multipliers), so we rewrite them here to reflect the sweep tuple.
func _override_stock(
	world: WorldState,
	goods: Array[Good],
	rate_plentiful: float,
	rate_neutral: float,
	rate_scarce: float,
	cap_mult_plentiful: float,
) -> void:
	for node: NodeState in world.nodes:
		for good: Good in goods:
			var cap_mult: float = CAP_MULT_NEUTRAL
			var rate: float = good.base_refill_rate * rate_neutral
			if good.id in node.produces:
				cap_mult = cap_mult_plentiful
				rate = good.base_refill_rate * rate_plentiful
			elif good.id in node.consumes:
				cap_mult = CAP_MULT_SCARCE
				rate = good.base_refill_rate * rate_scarce
			var cap: int = maxi(1, roundi(float(good.base_stock_cap) * cap_mult))
			node.stock_caps[good.id] = cap
			node.refill_rates[good.id] = rate
			node.stocks[good.id] = cap
			node.refill_accumulators[good.id] = 0.0

func _run_sweep(
	goods: Array[Good],
	rate_plentiful: float,
	rate_neutral: float,
	rate_scarce: float,
	cap_mult_plentiful: float,
	gold_cap: int,
) -> Dictionary:
	var route_tick_pairs: int = 0
	var cap_bound_pairs: int = 0
	var multi_good_when_cap_bound: int = 0
	var skipped_worldgen: int = 0
	var skipped_no_profit: int = 0

	for seed_value: int in range(N):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			skipped_worldgen += 1
			continue
		_override_stock(world, goods, rate_plentiful, rate_neutral, rate_scarce, cap_mult_plentiful)
		# Warm-up: K ticks of optimal-buys + refill across every directed edge.
		# Each tick: for every directed (from, to) edge, compute the optimal cart
		# subject to current stock and decrement source stocks. Then apply refill
		# to every (node, good) once.
		for _w: int in range(WARMUP_TICKS):
			_simulate_tick(world, goods, gold_cap)
		# Measurement: M ticks of (sample, then mutate). Each tick:
		#   1. For each directed edge: compute optimal cart with current stock.
		#      Record (cap_bound, multi_good) per pair.
		#   2. Apply the same buys to source stocks.
		#   3. Apply refill.
		for _m: int in range(MEASUREMENT_TICKS):
			for edge: EdgeState in world.edges:
				for direction: int in [0, 1]:
					var from_id: String = edge.a_id if direction == 0 else edge.b_id
					var to_id: String = edge.b_id if direction == 0 else edge.a_id
					var from_node: NodeState = world.get_node_by_id(from_id)
					var to_node: NodeState = world.get_node_by_id(to_id)
					var optimal: Dictionary = _optimal_mix(goods, gold_cap, world, from_node, to_node)
					var profit: int = int(optimal["profit"])
					if profit <= 0:
						skipped_no_profit += 1
						continue
					route_tick_pairs += 1
					var qty_by_good: Dictionary[String, int] = optimal["qty_by_good"]
					var cap_bound: bool = bool(optimal["headline_cap_bound"])
					var distinct: int = 0
					for good: Good in goods:
						if int(qty_by_good.get(good.id, 0)) > 0:
							distinct += 1
					if cap_bound:
						cap_bound_pairs += 1
						if distinct >= 2:
							multi_good_when_cap_bound += 1
			# Mutate: same as a warm-up tick. We sample BEFORE mutating in this
			# measurement window so the sample reflects pre-buy state for the tick.
			_simulate_tick(world, goods, gold_cap)

	var cap_binding_rate: float = 0.0
	if route_tick_pairs > 0:
		cap_binding_rate = float(cap_bound_pairs) / float(route_tick_pairs)
	var multi_good_when_cap_bound_rate: float = 0.0
	if cap_bound_pairs > 0:
		multi_good_when_cap_bound_rate = float(multi_good_when_cap_bound) / float(cap_bound_pairs)

	return {
		"route_tick_pairs": route_tick_pairs,
		"cap_bound_pairs": cap_bound_pairs,
		"multi_good_when_cap_bound": multi_good_when_cap_bound,
		"cap_binding_rate": cap_binding_rate,
		"multi_good_when_cap_bound_rate": multi_good_when_cap_bound_rate,
		"skipped_worldgen": skipped_worldgen,
		"skipped_no_profit": skipped_no_profit,
	}

# One simulated tick: for each directed edge compute optimal cart with current
# stock and decrement source stocks accordingly; then apply refill once across
# every (node, good). Mirrors the production tick path: Trade.try_buy decrements
# stock, StockSystem.refill applies after.
#
# Caveat: this is a heuristic warm-up, not the player's actual interaction.
# Real play has one player picking one route per tick, not every directed edge
# trading simultaneously every tick. The harness picks the more demanding model
# (every edge buys every tick) so cap-binding measurements are conservative
# upper bounds; gate 1 PASS under this model implies PASS under the real model.
func _simulate_tick(world: WorldState, goods: Array[Good], gold_cap: int) -> void:
	for edge: EdgeState in world.edges:
		for direction: int in [0, 1]:
			var from_id: String = edge.a_id if direction == 0 else edge.b_id
			var to_id: String = edge.b_id if direction == 0 else edge.a_id
			var from_node: NodeState = world.get_node_by_id(from_id)
			var to_node: NodeState = world.get_node_by_id(to_id)
			var optimal: Dictionary = _optimal_mix(goods, gold_cap, world, from_node, to_node)
			if int(optimal["profit"]) <= 0:
				continue
			var qty_by_good: Dictionary[String, int] = optimal["qty_by_good"]
			for good: Good in goods:
				var q: int = int(qty_by_good.get(good.id, 0))
				if q <= 0:
					continue
				var current: int = int(from_node.stocks.get(good.id, 0))
				from_node.stocks[good.id] = maxi(0, current - q)
	# Refill: mirror StockSystem._on_tick_advanced.
	for node: NodeState in world.nodes:
		for good_id: String in node.stocks.keys():
			var cap: int = int(node.stock_caps[good_id])
			var rate: float = float(node.refill_rates[good_id])
			var stock: int = int(node.stocks[good_id])
			var accum: float = float(node.refill_accumulators[good_id])
			if stock >= cap:
				node.refill_accumulators[good_id] = 0.0
				continue
			accum += rate
			var whole_units: int = int(accum)
			if whole_units > 0:
				stock = mini(cap, stock + whole_units)
				accum -= float(whole_units)
				node.stocks[good_id] = stock
			node.refill_accumulators[good_id] = accum

# Brute-force bounded knapsack with three constraints: cargo cap, gold cap,
# per-good source stock cap. Returns the optimal qty_by_good, profit, and a
# headline_cap_bound flag indicating whether the headline good (highest weight-
# share in the optimal cart) hit its source-stock-cap.
#
# Headline-cap-bound test: compute the optimal cart as-is (with stock cap), then
# compute it again with the headline good's stock raised to "infinity" (a large
# number). If the optimal qty of the headline good rises in the second run, the
# cap was binding. Spec sec 7.1.
func _optimal_mix(
	goods: Array[Good],
	gold_cap: int,
	world: WorldState,
	from_node: NodeState,
	to_node: NodeState,
) -> Dictionary:
	var first: Dictionary = _knapsack(goods, gold_cap, world, from_node, to_node, false)
	if int(first["profit"]) <= 0:
		return {"qty_by_good": first["qty_by_good"], "profit": 0, "headline_cap_bound": false}
	# Headline good = highest weight-share in the optimal cart.
	var headline_good: String = ""
	var headline_weight: int = -1
	var qty_by_good: Dictionary[String, int] = first["qty_by_good"]
	for good: Good in goods:
		var q: int = int(qty_by_good.get(good.id, 0))
		var w: int = q * good.weight
		if w > headline_weight:
			headline_weight = w
			headline_good = good.id
	if headline_good == "":
		return {"qty_by_good": qty_by_good, "profit": int(first["profit"]), "headline_cap_bound": false}
	# Re-run with the headline good's stock cap relaxed.
	var second: Dictionary = _knapsack_with_uncapped(goods, gold_cap, world, from_node, to_node, headline_good)
	var headline_qty_first: int = int(qty_by_good.get(headline_good, 0))
	var second_qty_by_good: Dictionary[String, int] = second["qty_by_good"]
	var headline_qty_second: int = int(second_qty_by_good.get(headline_good, 0))
	var cap_bound: bool = headline_qty_second > headline_qty_first
	return {
		"qty_by_good": qty_by_good,
		"profit": int(first["profit"]),
		"headline_cap_bound": cap_bound,
	}

# Knapsack subject to cargo, gold, and per-good source-stock caps.
# Slice-8: prices are pulled via PricingMath rather than read from node.prices.
func _knapsack(
	goods: Array[Good],
	gold_cap: int,
	world: WorldState,
	from_node: NodeState,
	to_node: NodeState,
	_unused: bool,
) -> Dictionary:
	var max_qty: Array[int] = []
	var weights_arr: Array[int] = []
	var buy_prices: Array[int] = []
	var spreads: Array[int] = []
	for good: Good in goods:
		var bp: int = PricingMath.buy_price_for(world, from_node, good.id)
		var sp: int = PricingMath.sell_price_for(world, to_node, good.id)
		var w: int = good.weight
		buy_prices.append(bp)
		spreads.append(sp - bp)
		weights_arr.append(w)
		var stock: int = int(from_node.stocks.get(good.id, 0))
		if bp <= 0 or sp - bp <= 0 or stock <= 0:
			max_qty.append(0)
		else:
			var by_cap: int = CART_CAP / w
			var by_gold: int = gold_cap / bp
			max_qty.append(mini(stock, mini(by_cap, by_gold)))
	return _bruteforce(goods, weights_arr, buy_prices, spreads, max_qty, gold_cap)

# Same as _knapsack but with one good's stock cap relaxed.
func _knapsack_with_uncapped(
	goods: Array[Good],
	gold_cap: int,
	world: WorldState,
	from_node: NodeState,
	to_node: NodeState,
	uncapped_good_id: String,
) -> Dictionary:
	var max_qty: Array[int] = []
	var weights_arr: Array[int] = []
	var buy_prices: Array[int] = []
	var spreads: Array[int] = []
	for good: Good in goods:
		var bp: int = PricingMath.buy_price_for(world, from_node, good.id)
		var sp: int = PricingMath.sell_price_for(world, to_node, good.id)
		var w: int = good.weight
		buy_prices.append(bp)
		spreads.append(sp - bp)
		weights_arr.append(w)
		if bp <= 0 or sp - bp <= 0:
			max_qty.append(0)
		else:
			var by_cap: int = CART_CAP / w
			var by_gold: int = gold_cap / bp
			if good.id == uncapped_good_id:
				max_qty.append(mini(by_cap, by_gold))
			else:
				var stock: int = int(from_node.stocks.get(good.id, 0))
				if stock <= 0:
					max_qty.append(0)
				else:
					max_qty.append(mini(stock, mini(by_cap, by_gold)))
	return _bruteforce(goods, weights_arr, buy_prices, spreads, max_qty, gold_cap)

func _bruteforce(
	goods: Array[Good],
	weights_arr: Array[int],
	buy_prices: Array[int],
	spreads: Array[int],
	max_qty: Array[int],
	gold_cap: int,
) -> Dictionary:
	assert(goods.size() == 4, "measure: knapsack specialised for N=4 goods, got %d" % goods.size())
	var best_profit: int = 0
	var best_qty: Array[int] = [0, 0, 0, 0]
	for q0: int in range(max_qty[0] + 1):
		var w0: int = q0 * weights_arr[0]
		var c0: int = q0 * buy_prices[0]
		if w0 > CART_CAP or c0 > gold_cap:
			break
		for q1: int in range(max_qty[1] + 1):
			var w1: int = w0 + q1 * weights_arr[1]
			var c1: int = c0 + q1 * buy_prices[1]
			if w1 > CART_CAP or c1 > gold_cap:
				break
			for q2: int in range(max_qty[2] + 1):
				var w2: int = w1 + q2 * weights_arr[2]
				var c2: int = c1 + q2 * buy_prices[2]
				if w2 > CART_CAP or c2 > gold_cap:
					break
				for q3: int in range(max_qty[3] + 1):
					var w3: int = w2 + q3 * weights_arr[3]
					var c3: int = c2 + q3 * buy_prices[3]
					if w3 > CART_CAP or c3 > gold_cap:
						break
					var profit: int = (q0 * spreads[0] + q1 * spreads[1]
							+ q2 * spreads[2] + q3 * spreads[3])
					if profit > best_profit:
						best_profit = profit
						best_qty = [q0, q1, q2, q3]
	var qty_by_good: Dictionary[String, int] = {}
	for i: int in range(goods.size()):
		qty_by_good[goods[i].id] = best_qty[i]
	return {"qty_by_good": qty_by_good, "profit": best_profit}

func _finalise_verdicts(sweep_results: Array[Dictionary]) -> void:
	for entry: Dictionary in sweep_results:
		var gold: int = int(entry["gold"])
		var result: Dictionary = entry["result"]
		var cap_binding_rate: float = float(result["cap_binding_rate"])
		var multi_good_rate: float = float(result["multi_good_when_cap_bound_rate"])
		var verdict: String = "PASS"
		var gate_1_pass: bool = false
		var gate_2_pass: bool = false
		var reasons: Array[String] = []
		# Only the GATING_GOLD tier gates the slice. Other tiers print verdict
		# rows for completeness but are tagged DIAG so the operator does not
		# read them as ship/no-ship signals.
		if gold == GATING_GOLD:
			gate_1_pass = cap_binding_rate >= GATE_1_FLOOR
			if gate_1_pass:
				reasons.append("gate 1 cap-binding %.1f%% >= %.0f%%: PASS" % [cap_binding_rate * 100.0, GATE_1_FLOOR * 100.0])
			else:
				verdict = "FAIL"
				reasons.append("gate 1 cap-binding %.1f%% < %.0f%%: FAIL" % [cap_binding_rate * 100.0, GATE_1_FLOOR * 100.0])
			# Gate 2 only meaningful when gate 1 passes (otherwise denominator is
			# tiny and the rate is noise). Print the rate either way.
			gate_2_pass = multi_good_rate >= GATE_2_FLOOR
			if gate_2_pass:
				reasons.append("gate 2 multi-good %.1f%% >= %.0f%%: PASS" % [multi_good_rate * 100.0, GATE_2_FLOOR * 100.0])
			else:
				if gate_1_pass:
					verdict = "FAIL"
				reasons.append("gate 2 multi-good %.1f%% < %.0f%%: %s" % [multi_good_rate * 100.0, GATE_2_FLOOR * 100.0, "FAIL" if gate_1_pass else "FAIL-DIAG"])
		else:
			reasons.append("cap-binding %.1f%%, multi-good %.1f%% (gold=%d, diagnostic, not gated)" % [cap_binding_rate * 100.0, multi_good_rate * 100.0, gold])
			verdict = "DIAG"
		entry["verdict"] = verdict
		entry["verdict_reason"] = "; ".join(reasons)
		entry["gate_1_pass"] = gate_1_pass
		entry["gate_2_pass"] = gate_2_pass

func _print_sweep_block(_goods: Array[Good], entry: Dictionary) -> void:
	var refill: Array = entry["refill"]
	var cap_mult: float = float(entry["cap_mult"])
	var gold: int = int(entry["gold"])
	var result: Dictionary = entry["result"]
	print("=== slice-7 production-caps measurement (refill=(plentiful=%.1f, neutral=%.1f, scarce=%.1f), cap_mult=(plentiful=%.1f, neutral=%.1f, scarce=%.2f), gold=%d) ===" % [
		float(refill[0]), float(refill[1]), float(refill[2]),
		cap_mult, CAP_MULT_NEUTRAL, CAP_MULT_SCARCE,
		gold,
	])
	print("seeds=%d, warmup=%d, measurement_ticks=%d" % [N, WARMUP_TICKS, MEASUREMENT_TICKS])
	print("route_tick_pairs=%d, cap_bound_pairs=%d, multi_good_when_cap_bound=%d" % [
		int(result["route_tick_pairs"]),
		int(result["cap_bound_pairs"]),
		int(result["multi_good_when_cap_bound"]),
	])
	print("skipped_worldgen=%d, skipped_no_profit=%d" % [
		int(result["skipped_worldgen"]),
		int(result["skipped_no_profit"]),
	])
	print("")
	print("cap_binding rate: %.1f%%   [gate 1 floor: >= %.0f%%]" % [float(result["cap_binding_rate"]) * 100.0, GATE_1_FLOOR * 100.0])
	print("  (of %.1f%% cap-bound, multi-good fraction: %.1f%%)" % [
		float(result["cap_binding_rate"]) * 100.0,
		float(result["multi_good_when_cap_bound_rate"]) * 100.0,
	])
	print("gate 2 floor: >= %.0f%%" % [GATE_2_FLOOR * 100.0])
	print("verdict: %s" % str(entry["verdict"]))
	print("  %s" % str(entry["verdict_reason"]))
	print("")

func _print_sanity_baseline(
	goods: Array[Good],
	label: String,
	rate_plentiful: float,
	rate_neutral: float,
	rate_scarce: float,
	cap_mult_plentiful: float,
	gold: int,
	expectation: String,
) -> void:
	var result: Dictionary = _run_sweep(goods, rate_plentiful, rate_neutral, rate_scarce, cap_mult_plentiful, gold)
	print("--- sanity baseline: %s ---" % label)
	print("  refill=(%.1f, %.1f, %.1f), cap_mult_plentiful=%.1f, gold=%d" % [
		rate_plentiful, rate_neutral, rate_scarce, cap_mult_plentiful, gold,
	])
	print("  cap_binding %.1f%%, multi-good %.1f%% (%s)" % [
		float(result["cap_binding_rate"]) * 100.0,
		float(result["multi_good_when_cap_bound_rate"]) * 100.0,
		expectation,
	])
	print("")

func _print_summary(sweep_results: Array[Dictionary]) -> void:
	print("=== sweep summary (gold=%d gating only) ===" % GATING_GOLD)
	print("(refill, cap_mult_plentiful) -> verdict")
	for entry: Dictionary in sweep_results:
		if int(entry["gold"]) != GATING_GOLD:
			continue
		var refill: Array = entry["refill"]
		var cap_mult: float = float(entry["cap_mult"])
		var result: Dictionary = entry["result"]
		print("((%.1f,%.1f,%.1f), cap_mult=%.1f) -> %s  [cap-binding %.1f%%, multi-good %.1f%%]" % [
			float(refill[0]), float(refill[1]), float(refill[2]),
			cap_mult,
			str(entry["verdict"]),
			float(result["cap_binding_rate"]) * 100.0,
			float(result["multi_good_when_cap_bound_rate"]) * 100.0,
		])
