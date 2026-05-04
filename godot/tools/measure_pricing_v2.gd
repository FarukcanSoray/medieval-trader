## Headless measurement tool for slice-8 pool-driven prices. Three gates:
##
##   Gate 1 (pool-motion):   >= 40% of (route, tick, direction) tuples have
##                           either supply OR demand pool fill in the middle
##                           60% of capacity at gating-gold (=200).
##   Gate 2 (spread vs noise): >= 30% of profitable routes show
##                             |buy_price_at_source - sell_price_at_destination|
##                             >= 2 * PERTURBATION_FRACTION * base_price.
##   Gate 3 (determinism):   100% of save -> load -> save round-trips
##                           byte-identical (key set + value equality on every
##                           dict; PricingMath outputs identical pre/post load).
##
## Spec: docs/slice-8-pricing-v2-spec.md §10. Decisions:
## 2026-05-04-slice-8-harness-gate-floors, -pool-curve-formula-locked,
## -prices-field-dropped-pull-driven.
##
## Run with:
##   godot --path godot/ res://tools/measure_pricing_v2.tscn
## Headless:
##   godot --headless --path godot/ res://tools/measure_pricing_v2.tscn
##
## Why a tscn (not --script): pull-driven prices need PricingMath, which calls
## Game.goods. --script mode strips autoloads. The driver scene runs under the
## normal autoload registration and quits on completion, mirroring
## save_persistence_test.tscn / measure_*-style tools that need autoloads.

extends Node

# Seed budget: 200 keeps statistical weight while bounding total runtime.
# Matches slice-7's harness budget. Gate 3 uses 100 seeds (subset).
const N_SEEDS: int = 200
const N_DETERMINISM_SEEDS: int = 100
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

# Spec §10.6: warm-up drives pools away from initial-full state (both supply
# and demand start at cap). 20 ticks is the default; demand pools especially
# need time to drain.
const WARMUP_TICKS: int = 20
const MEASUREMENT_TICKS: int = 8

# Spec §10.6 sweep parameters. To keep runtime bounded we hold supply caps and
# demand caps at the spec §6 defaults and sweep only the two demand decay
# multipliers (the load-bearing tuning surface for gate 1 / gate 2). Engineer's
# call per spec §10.6 final paragraph.
const DEMAND_DECAY_PRODUCER_SWEEP: Array[float] = [0.1, 0.2, 0.4, 0.8]
const DEMAND_DECAY_CONSUMER_SWEEP: Array[float] = [3.0, 5.0, 8.0, 12.0]
const GOLD_SWEEP: Array[int] = [120, 200, 400]

# Gate floors per 2026-05-04-slice-8-harness-gate-floors.
const GATE_1_FLOOR: float = 0.40
const GATE_2_FLOOR: float = 0.30
const GATING_GOLD: int = 200

const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
	"res://goods/iron.tres",
]
const CART_CAP: int = 60

# Pool-fill bracket boundaries: drained = 0..0.20, mid = 0.20..0.80, saturated
# = 0.80..1.00. Spec §10.3.
const MID_BAND_LOW: float = 0.20
const MID_BAND_HIGH: float = 0.80

# Output path. Architect's call per spec §10.8.
const VERDICT_PATH: String = "res://tools/pricing_v2_verdict.txt"

var _verdict_lines: Array[String] = []

func _ready() -> void:
	# Mirror save_persistence_test.tscn: bootstrap Game so PricingMath can
	# resolve goods. The harness runs a custom sweep and quits.
	await Game.bootstrap(-1, FALLBACK_RECT)
	if Game.world == null:
		_emit("[slice-8 harness] FAIL setup: Game.bootstrap did not populate state")
		_write_verdict_file()
		get_tree().quit(1)
		return

	var goods: Array[Good] = _load_goods()

	_emit("=== slice-8 pricing-v2 harness ===")
	_emit("seeds=%d, warmup=%d, measurement_ticks=%d" % [N_SEEDS, WARMUP_TICKS, MEASUREMENT_TICKS])
	_emit("gates: gate-1 (pool-motion) >= %.0f%%; gate-2 (spread) >= %.0f%%; gate-3 (determinism) 100%%" % [
		GATE_1_FLOOR * 100.0, GATE_2_FLOOR * 100.0,
	])
	_emit("")

	# Gate 3 first: independent of the multiplier sweep (gate 3 only depends on
	# the seed function, not on tunings), and a hard stop if it fails.
	var gate_3_pass: bool = _run_gate_3(goods)

	# Sweep + per-block gate 1 / gate 2.
	var sweep_results: Array[Dictionary] = []
	for decay_producer: float in DEMAND_DECAY_PRODUCER_SWEEP:
		for decay_consumer: float in DEMAND_DECAY_CONSUMER_SWEEP:
			for gold: int in GOLD_SWEEP:
				var result: Dictionary = _run_sweep(goods, decay_producer, decay_consumer, gold)
				sweep_results.append({
					"decay_producer": decay_producer,
					"decay_consumer": decay_consumer,
					"gold": gold,
					"result": result,
				})
	_finalise_verdicts(sweep_results)
	for entry: Dictionary in sweep_results:
		_print_sweep_block(entry)

	# Sanity baselines per spec §10.5 -- only at the gating-gold tier so the
	# harness output stays readable. Each baseline is a single-block run with
	# overrides; not part of the sweep.
	_emit("=== sanity baselines (gold=%d) ===" % GATING_GOLD)
	_run_sanity_baseline(goods, "pools frozen at cap (decay=0, no warm-up trade)", 0.0, 0.0, GATING_GOLD, false)
	_run_sanity_baseline(goods, "pools drained instantly (decay=999, full warm-up trade)", 999.0, 999.0, GATING_GOLD, true)

	_print_summary(sweep_results, gate_3_pass)
	_write_verdict_file()
	get_tree().quit(0)

func _emit(line: String) -> void:
	print(line)
	_verdict_lines.append(line)

func _write_verdict_file() -> void:
	var f: FileAccess = FileAccess.open(VERDICT_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("measure_pricing_v2: could not open %s for write" % VERDICT_PATH)
		return
	for line: String in _verdict_lines:
		f.store_line(line)
	f.close()

func _load_goods() -> Array[Good]:
	var goods: Array[Good] = []
	for path: String in GOOD_PATHS:
		var good: Good = load(path) as Good
		assert(good != null, "measure: failed to load %s" % path)
		goods.append(good)
	return goods

# Override demand decay rates on every (node, good) pair to the sweep value.
# Mirrors slice-7 measure_production_caps._override_stock. Cap multipliers held
# at the spec §6 defaults via the WorldGen authoring; only decay rates change.
func _override_demand_decay(world: WorldState, goods: Array[Good], rate_producer: float, rate_consumer: float) -> void:
	for node: NodeState in world.nodes:
		for good: Good in goods:
			var rate: float = good.base_demand_decay_rate * WorldRules.DEMAND_DECAY_MULT_NEUTRAL
			if good.id in node.produces:
				rate = good.base_demand_decay_rate * rate_producer
			elif good.id in node.consumes:
				rate = good.base_demand_decay_rate * rate_consumer
			node.demand_decay_rates[good.id] = rate

# Per spec §10.2: warm-up phase drives pools away from full. We simulate a
# round of optimal trade per directed edge per tick, decrementing both supply
# (on buy) and demand (on sell), then refill supply / decay-grow demand.
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
				# Drain supply at source (mirrors Trade.try_buy).
				var stock: int = int(from_node.stocks.get(good.id, 0))
				from_node.stocks[good.id] = maxi(0, stock - q)
				# Drain demand at destination (mirrors Trade.try_sell).
				var pool: int = int(to_node.demand_pools.get(good.id, 0))
				var pool_cap: int = int(to_node.demand_caps.get(good.id, 0))
				to_node.demand_pools[good.id] = clampi(pool - q, 0, pool_cap)
	# Tick advance: bump tick so perturbations re-roll, then refill / decay.
	world.tick += 1
	_apply_supply_refill(world)
	_apply_demand_decay(world)

# Mirrors StockSystem._on_tick_advanced.
func _apply_supply_refill(world: WorldState) -> void:
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

# Mirrors DemandSystem._on_tick_advanced.
func _apply_demand_decay(world: WorldState) -> void:
	for node: NodeState in world.nodes:
		for good_id: String in node.demand_pools.keys():
			var cap: int = int(node.demand_caps[good_id])
			var rate: float = float(node.demand_decay_rates[good_id])
			var pool: int = int(node.demand_pools[good_id])
			var accum: float = float(node.demand_decay_accumulators[good_id])
			if pool >= cap:
				node.demand_decay_accumulators[good_id] = 0.0
				continue
			accum += rate
			var whole_units: int = int(accum)
			if whole_units > 0:
				pool = mini(cap, pool + whole_units)
				accum -= float(whole_units)
				node.demand_pools[good_id] = pool
			node.demand_decay_accumulators[good_id] = accum

# Knapsack with cargo, gold, and per-good source-stock caps. Returns
# qty_by_good and profit. Mirrors slice-7 production_caps' brute force.
func _optimal_mix(goods: Array[Good], gold_cap: int, world: WorldState, from_node: NodeState, to_node: NodeState) -> Dictionary:
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
		var demand_pool: int = int(to_node.demand_pools.get(good.id, 0))
		# Sell cap: demand pool (saturated demand caps the sellable qty).
		# This mirrors Trade.try_sell's demand-pool gate.
		if bp <= 0 or sp - bp <= 0 or stock <= 0 or demand_pool <= 0:
			max_qty.append(0)
		else:
			var by_cap: int = CART_CAP / w
			var by_gold: int = gold_cap / bp
			max_qty.append(mini(stock, mini(demand_pool, mini(by_cap, by_gold))))
	return _bruteforce(goods, weights_arr, buy_prices, spreads, max_qty, gold_cap)

func _bruteforce(goods: Array[Good], weights_arr: Array[int], buy_prices: Array[int], spreads: Array[int], max_qty: Array[int], gold_cap: int) -> Dictionary:
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

# Per-block sweep. For each seed: gen world, override decay rates, warm up K
# ticks, then sample M ticks of (per-edge per-good) pool fills + spreads.
func _run_sweep(goods: Array[Good], decay_producer: float, decay_consumer: float, gold_cap: int) -> Dictionary:
	var samples: int = 0
	var pool_motion_hits: int = 0
	var profitable_routes: int = 0
	var spread_above_noise: int = 0
	var supply_drained: int = 0
	var supply_mid: int = 0
	var supply_saturated: int = 0
	var demand_drained: int = 0
	var demand_mid: int = 0
	var demand_saturated: int = 0
	var spread_lt5: int = 0
	var spread_5_10: int = 0
	var spread_10_20: int = 0
	var spread_gt20: int = 0
	var skipped_worldgen: int = 0

	for seed_value: int in range(N_SEEDS):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			skipped_worldgen += 1
			continue
		_override_demand_decay(world, goods, decay_producer, decay_consumer)
		# Warm up: drain pools through repeated optimal trade.
		for _w: int in range(WARMUP_TICKS):
			_simulate_tick(world, goods, gold_cap)
		# Measurement: sample BEFORE the tick mutation so the pool fills are
		# the pre-buy state that PricingMath.buy/sell prices read against.
		for _m: int in range(MEASUREMENT_TICKS):
			for edge: EdgeState in world.edges:
				for direction: int in [0, 1]:
					var from_id: String = edge.a_id if direction == 0 else edge.b_id
					var to_id: String = edge.b_id if direction == 0 else edge.a_id
					var from_node: NodeState = world.get_node_by_id(from_id)
					var to_node: NodeState = world.get_node_by_id(to_id)
					for good: Good in goods:
						samples += 1
						# Pool-motion check: source supply OR destination
						# demand in the middle 60% of capacity.
						var src_supply_frac: float = _frac(from_node.stocks.get(good.id, 0), from_node.stock_caps.get(good.id, 0))
						var dst_demand_frac: float = _frac(to_node.demand_pools.get(good.id, 0), to_node.demand_caps.get(good.id, 0))
						if _in_mid_band(src_supply_frac) or _in_mid_band(dst_demand_frac):
							pool_motion_hits += 1
						# Histogram: supply at source, demand at destination.
						if _in_mid_band(src_supply_frac):
							supply_mid += 1
						elif src_supply_frac < MID_BAND_LOW:
							supply_drained += 1
						else:
							supply_saturated += 1
						if _in_mid_band(dst_demand_frac):
							demand_mid += 1
						elif dst_demand_frac < MID_BAND_LOW:
							demand_drained += 1
						else:
							demand_saturated += 1
						# Spread check: only on profitable routes.
						var bp: int = PricingMath.buy_price_for(world, from_node, good.id)
						var sp: int = PricingMath.sell_price_for(world, to_node, good.id)
						var spread: int = sp - bp
						if spread > 0:
							profitable_routes += 1
							var spread_pct: float = float(spread) / float(good.base_price)
							var noise_threshold: float = 2.0 * WorldRules.PERTURBATION_FRACTION
							if spread_pct >= noise_threshold:
								spread_above_noise += 1
							if spread_pct < 0.05:
								spread_lt5 += 1
							elif spread_pct < 0.10:
								spread_5_10 += 1
							elif spread_pct < 0.20:
								spread_10_20 += 1
							else:
								spread_gt20 += 1
			_simulate_tick(world, goods, gold_cap)

	var pool_motion_rate: float = 0.0
	if samples > 0:
		pool_motion_rate = float(pool_motion_hits) / float(samples)
	var spread_above_noise_rate: float = 0.0
	if profitable_routes > 0:
		spread_above_noise_rate = float(spread_above_noise) / float(profitable_routes)

	return {
		"samples": samples,
		"profitable_routes": profitable_routes,
		"pool_motion_rate": pool_motion_rate,
		"spread_above_noise_rate": spread_above_noise_rate,
		"supply_drained": supply_drained,
		"supply_mid": supply_mid,
		"supply_saturated": supply_saturated,
		"demand_drained": demand_drained,
		"demand_mid": demand_mid,
		"demand_saturated": demand_saturated,
		"spread_lt5": spread_lt5,
		"spread_5_10": spread_5_10,
		"spread_10_20": spread_10_20,
		"spread_gt20": spread_gt20,
		"skipped_worldgen": skipped_worldgen,
	}

# Gate 3 (determinism replay). For each of N_DETERMINISM_SEEDS seeds: gen
# world, warm up, save, load, save again. Compare wire dicts and a sample of
# PricingMath outputs. Returns true iff all seeds pass.
func _run_gate_3(goods: Array[Good]) -> bool:
	var pass_count: int = 0
	var fail_examples: Array[String] = []
	for seed_value: int in range(N_DETERMINISM_SEEDS):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			continue
		# Warm up to drive pools off-cap before serialisation -- a full-pool
		# world is the easy case; the harder case is partial-fill state.
		for _w: int in range(WARMUP_TICKS):
			_simulate_tick(world, goods, GATING_GOLD)
		var save_dict_1: Dictionary = world.to_dict()
		var world_2: WorldState = WorldState.from_dict(save_dict_1.duplicate(true))
		if world_2 == null:
			fail_examples.append("seed %d: from_dict returned null" % seed_value)
			continue
		var save_dict_2: Dictionary = world_2.to_dict()
		if not _dicts_equal(save_dict_1, save_dict_2):
			fail_examples.append("seed %d: save_dict_1 != save_dict_2 round-trip" % seed_value)
			continue
		# Pricing replay: every (node, good) buy / sell price must match
		# byte-for-byte across the two worlds at the same tick.
		var pricing_ok: bool = true
		for node_idx: int in range(world.nodes.size()):
			var n1: NodeState = world.nodes[node_idx]
			var n2: NodeState = world_2.nodes[node_idx]
			for good: Good in goods:
				var b1: int = PricingMath.buy_price_for(world, n1, good.id)
				var b2: int = PricingMath.buy_price_for(world_2, n2, good.id)
				var s1: int = PricingMath.sell_price_for(world, n1, good.id)
				var s2: int = PricingMath.sell_price_for(world_2, n2, good.id)
				if b1 != b2 or s1 != s2:
					fail_examples.append("seed %d: pricing replay mismatch at node %s good %s (buy %d vs %d, sell %d vs %d)" % [
						seed_value, n1.id, good.id, b1, b2, s1, s2,
					])
					pricing_ok = false
					break
			if not pricing_ok:
				break
		if pricing_ok:
			pass_count += 1
	var pass_rate: float = float(pass_count) / float(N_DETERMINISM_SEEDS)
	var verdict: String = "PASS" if pass_count == N_DETERMINISM_SEEDS else "FAIL"
	_emit("=== gate 3 (determinism replay) ===")
	_emit("seeds=%d, passed=%d, rate=%.1f%%, verdict=%s" % [N_DETERMINISM_SEEDS, pass_count, pass_rate * 100.0, verdict])
	if not fail_examples.is_empty():
		for ex: String in fail_examples.slice(0, 5):
			_emit("  %s" % ex)
		if fail_examples.size() > 5:
			_emit("  ... %d more" % (fail_examples.size() - 5))
	_emit("")
	return pass_count == N_DETERMINISM_SEEDS

# Sanity baseline: forces an extreme decay configuration and reports gate 1.
# Spec §10.5: pools-frozen-at-cap should fail gate 1 (no motion);
# pools-drained-instantly should also fail (pinned at corners).
func _run_sanity_baseline(goods: Array[Good], label: String, decay_producer: float, decay_consumer: float, gold: int, force_drain: bool) -> void:
	var samples: int = 0
	var pool_motion_hits: int = 0
	for seed_value: int in range(50):  # Smaller sample for sanity.
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			continue
		_override_demand_decay(world, goods, decay_producer, decay_consumer)
		if force_drain:
			# Drain every pool to 0 to model the "pinned at corner" sanity.
			for node: NodeState in world.nodes:
				for good: Good in goods:
					node.stocks[good.id] = 0
					node.demand_pools[good.id] = 0
			# Also zero the supply refill rates so refill doesn't undo the drain.
			for node: NodeState in world.nodes:
				for good: Good in goods:
					node.refill_rates[good.id] = 0.0
		else:
			# Freeze: zero the supply refill so pools stay at cap.
			for node: NodeState in world.nodes:
				for good: Good in goods:
					node.refill_rates[good.id] = 0.0
		# A couple measurement ticks at this regime.
		for _m: int in range(3):
			for edge: EdgeState in world.edges:
				for direction: int in [0, 1]:
					var from_id: String = edge.a_id if direction == 0 else edge.b_id
					var to_id: String = edge.b_id if direction == 0 else edge.a_id
					var from_node: NodeState = world.get_node_by_id(from_id)
					var to_node: NodeState = world.get_node_by_id(to_id)
					for good: Good in goods:
						samples += 1
						var src_frac: float = _frac(from_node.stocks.get(good.id, 0), from_node.stock_caps.get(good.id, 0))
						var dst_frac: float = _frac(to_node.demand_pools.get(good.id, 0), to_node.demand_caps.get(good.id, 0))
						if _in_mid_band(src_frac) or _in_mid_band(dst_frac):
							pool_motion_hits += 1
			# Don't decay-grow on pinned baselines -- the sanity is about the
			# "no motion / pinned corner" read, not about realistic dynamics.
	var rate: float = 0.0
	if samples > 0:
		rate = float(pool_motion_hits) / float(samples)
	_emit("--- sanity baseline: %s ---" % label)
	_emit("  pool-motion %.1f%% (gold=%d, samples=%d) -- expect FAIL gate 1 (< %.0f%%)" % [
		rate * 100.0, gold, samples, GATE_1_FLOOR * 100.0,
	])
	_emit("")

func _frac(value_v: Variant, cap_v: Variant) -> float:
	var cap: int = int(cap_v)
	if cap <= 0:
		return 0.0
	return clampf(float(int(value_v)) / float(cap), 0.0, 1.0)

func _in_mid_band(f: float) -> bool:
	return f >= MID_BAND_LOW and f <= MID_BAND_HIGH


func _finalise_verdicts(sweep_results: Array[Dictionary]) -> void:
	for entry: Dictionary in sweep_results:
		var gold: int = int(entry["gold"])
		var result: Dictionary = entry["result"]
		var motion_rate: float = float(result["pool_motion_rate"])
		var spread_rate: float = float(result["spread_above_noise_rate"])
		var verdict: String = "DIAG"
		var gate_1_pass: bool = false
		var gate_2_pass: bool = false
		var reasons: Array[String] = []
		if gold == GATING_GOLD:
			gate_1_pass = motion_rate >= GATE_1_FLOOR
			gate_2_pass = spread_rate >= GATE_2_FLOOR
			if gate_1_pass:
				reasons.append("gate 1 pool-motion %.1f%% >= %.0f%%: PASS" % [motion_rate * 100.0, GATE_1_FLOOR * 100.0])
			else:
				reasons.append("gate 1 pool-motion %.1f%% < %.0f%%: FAIL" % [motion_rate * 100.0, GATE_1_FLOOR * 100.0])
			if gate_2_pass:
				reasons.append("gate 2 spread-vs-noise %.1f%% >= %.0f%%: PASS" % [spread_rate * 100.0, GATE_2_FLOOR * 100.0])
			else:
				reasons.append("gate 2 spread-vs-noise %.1f%% < %.0f%%: FAIL" % [spread_rate * 100.0, GATE_2_FLOOR * 100.0])
			verdict = "PASS" if (gate_1_pass and gate_2_pass) else "FAIL"
		else:
			reasons.append("pool-motion %.1f%%, spread-above-noise %.1f%% (gold=%d, diagnostic)" % [
				motion_rate * 100.0, spread_rate * 100.0, gold,
			])
		entry["verdict"] = verdict
		entry["verdict_reason"] = "; ".join(reasons)
		entry["gate_1_pass"] = gate_1_pass
		entry["gate_2_pass"] = gate_2_pass

func _print_sweep_block(entry: Dictionary) -> void:
	var dp: float = float(entry["decay_producer"])
	var dc: float = float(entry["decay_consumer"])
	var gold: int = int(entry["gold"])
	var result: Dictionary = entry["result"]
	_emit("=== slice-8 pricing-v2 measurement (decay=(producer=%.1f, consumer=%.1f), gold=%d) ===" % [dp, dc, gold])
	_emit("samples=%d, profitable_routes=%d, skipped_worldgen=%d" % [
		int(result["samples"]), int(result["profitable_routes"]), int(result["skipped_worldgen"]),
	])
	_emit("")
	_emit("gate 1 (pool-motion):       %.1f%%   [floor: >= %.0f%%]" % [
		float(result["pool_motion_rate"]) * 100.0, GATE_1_FLOOR * 100.0,
	])
	_emit("gate 2 (spread > 2*perturb): %.1f%%   [floor: >= %.0f%%]" % [
		float(result["spread_above_noise_rate"]) * 100.0, GATE_2_FLOOR * 100.0,
	])
	_emit("")
	# Histograms.
	var samples: int = int(result["samples"])
	if samples > 0:
		_emit("pool fill histogram:")
		_emit("  supply: drained %.0f%%, mid %.0f%%, saturated %.0f%%" % [
			float(result["supply_drained"]) / float(samples) * 100.0,
			float(result["supply_mid"]) / float(samples) * 100.0,
			float(result["supply_saturated"]) / float(samples) * 100.0,
		])
		_emit("  demand: drained %.0f%%, mid %.0f%%, saturated %.0f%%" % [
			float(result["demand_drained"]) / float(samples) * 100.0,
			float(result["demand_mid"]) / float(samples) * 100.0,
			float(result["demand_saturated"]) / float(samples) * 100.0,
		])
	var prof: int = int(result["profitable_routes"])
	if prof > 0:
		_emit("spread histogram (%% of base_price, profitable routes only):")
		_emit("  < 5%%   : %.0f%%" % (float(result["spread_lt5"]) / float(prof) * 100.0))
		_emit("  5-10%%  : %.0f%%" % (float(result["spread_5_10"]) / float(prof) * 100.0))
		_emit("  10-20%% : %.0f%%" % (float(result["spread_10_20"]) / float(prof) * 100.0))
		_emit("  > 20%%  : %.0f%%" % (float(result["spread_gt20"]) / float(prof) * 100.0))
	_emit("verdict: %s" % str(entry["verdict"]))
	_emit("  %s" % str(entry["verdict_reason"]))
	_emit("")

func _print_summary(sweep_results: Array[Dictionary], gate_3_pass: bool) -> void:
	_emit("=== sweep summary (gold=%d gating only) ===" % GATING_GOLD)
	_emit("(decay_producer, decay_consumer) -> verdict")
	var any_pass: bool = false
	for entry: Dictionary in sweep_results:
		if int(entry["gold"]) != GATING_GOLD:
			continue
		var dp: float = float(entry["decay_producer"])
		var dc: float = float(entry["decay_consumer"])
		var result: Dictionary = entry["result"]
		_emit("(producer=%.1f, consumer=%.1f) -> %s  [pool-motion %.1f%%, spread-above-noise %.1f%%]" % [
			dp, dc, str(entry["verdict"]),
			float(result["pool_motion_rate"]) * 100.0,
			float(result["spread_above_noise_rate"]) * 100.0,
		])
		if str(entry["verdict"]) == "PASS":
			any_pass = true
	_emit("")
	_emit("=== overall ===")
	_emit("gate 3 (determinism): %s" % ("PASS" if gate_3_pass else "FAIL"))
	_emit("any sweep tuple PASS at gold=%d: %s" % [GATING_GOLD, "YES" if any_pass else "NO"])
	if gate_3_pass and any_pass:
		_emit("verdict: PASS (slice ships at any sweep tuple marked PASS above)")
	elif not gate_3_pass:
		_emit("verdict: HARD FAIL on gate 3 -- determinism contract broken")
	else:
		_emit("verdict: FAIL -- no multiplier set passes both gate 1 and gate 2 at gold=%d" % GATING_GOLD)

func _dicts_equal(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary and b is Dictionary:
		var ad: Dictionary = a
		var bd: Dictionary = b
		if ad.size() != bd.size():
			return false
		for k: Variant in ad.keys():
			if not bd.has(k):
				return false
			if not _dicts_equal(ad[k], bd[k]):
				return false
		return true
	if a is Array and b is Array:
		var aa: Array = a
		var ba: Array = b
		if aa.size() != ba.size():
			return false
		for i: int in range(aa.size()):
			if not _dicts_equal(aa[i], ba[i]):
				return false
		return true
	if a is float and b is float:
		# Float strict-equality: both came from the same path; bit-identical
		# is what determinism requires. Use absolute tolerance only as a
		# defensive guard against JSON serialisation float precision quirks.
		# JSON round-trip preserves doubles exactly in Godot 4.x; strict
		# equality holds.
		return float(a) == float(b)
	return a == b
