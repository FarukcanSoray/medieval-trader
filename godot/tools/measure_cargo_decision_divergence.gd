## Headless measurement tool: for each (weight assignment, capacity, gold-cap)
## tuple, sweeps N=1000 seeds, brute-forces the optimal bounded knapsack on every
## directed edge of the generated world, and reports per-good weight-share +
## mix-richness against slice-6-weight-cargo-spec §7.2's pass criterion.
##
## Run with:
##   godot --headless --path godot/ --script res://tools/measure_cargo_decision_divergence.gd
##
## Process gate (spec §7.5): Engineer authors candidate weights (4,3,2,10), runs
## this harness, and only commits the .tres weight values + CARGO_CAPACITY when
## the verdict at the desired tuple reads PASS. The verdict log is the source of
## truth; the per-good rationale in spec §5 is the *why*.
##
## Why iterate generated edges instead of the spec's "3-node triangle":
##   The spec text (§7.1) was written against the slice-6 ratification frame;
##   actual WorldGen produces NODE_COUNT=7 nodes with MST + 2 extra edges (~8
##   undirected, ~16 directed). The harness mirrors production by enumerating
##   what generate() actually produced -- a denser sampling of routes per seed
##   than the spec's triangle, but identical pass-criterion semantics.
##
## Why brute force, not DP:
##   N=4 goods, cap=80 max, weight=2 min -> worst-case |q_g| <= 40 per axis.
##   Tightest bound: prod(cap/w_g + 1) for (4,3,2,10) at cap=60 = 16*21*31*7
##   = ~73k tuples per directed edge. ~16 directed edges per seed * 1000 seeds
##   * 5 caps * 3 gold tiers * 7 weight tuples = ~2.5e10 tuples total worst-case
##   if we fully sweep -- harness chops the sweep down (see WEIGHT_SWEEP /
##   CAPACITY_SWEEP). Per the brief: budget the import round-trip and let the
##   harness take a few minutes.

extends SceneTree

const N: int = 1000
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

# Per spec §7.3. The (4,3,2,10) tuple is the Designer call; the rest are
# plausible neighbours, the iron-too-light failure mode, and the all-ones
# degenerate baseline. Order matches goods order: (wool, cloth, salt, iron).
const WEIGHT_SWEEP: Array[Array] = [
	[4, 3, 2, 10],
	[4, 4, 2, 10],
	[5, 3, 2, 10],
	[4, 3, 2, 6],
	[4, 3, 2, 12],
	[3, 2, 1, 8],
	[1, 1, 1, 1],
]
# Per spec §7.3.
const CAPACITY_SWEEP: Array[int] = [40, 48, 60, 72, 80]
# Per spec §7.3 -- early/mid/late game.
const GOLD_SWEEP: Array[int] = [120, 200, 400]

# Pass criterion thresholds, spec §7.2 (revised 2026-05-03 -- see §7.5 for the
# rationale on why the original 60% multi-good gate was wrong and replaced).
const MAX_GOOD_SHARE: float = 0.50
const MIN_GOOD_SHARE: float = 0.10
# Multi-good floor at the canonical ratification tier (gold=200). Down from the
# original 60% target -- see §7.5 / §13 for why per-leg portfolio composition
# is structurally impossible at this slice's scope.
const MIN_MULTI_GOOD_FLOOR: float = 0.10
# The gating gold tier (clauses 1 + 2 evaluated here). gold=120 is treated as a
# starvation-regime diagnostic and gold=400 is the unconstrained-gold reference
# point used only by clause 3 (gold-cap sanity).
const GATING_GOLD: int = 200
# Reference tier for clause 3 (gold-cap sanity check).
const REFERENCE_GOLD: int = 400
# Diagnostic tier (printed for transparency, not a gate).
const DIAGNOSTIC_GOLD: int = 120

# Goods order is load-bearing -- the WEIGHT_SWEEP tuples are positional.
const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
	"res://goods/iron.tres",
]

func _initialize() -> void:
	var goods: Array[Good] = _load_goods()
	# Pass 1: sweep all (weights, cap, gold) tuples, collect raw stats. Verdicts
	# deferred because clause 3 (spec §7.2) needs gold=200 vs gold=400 rows for
	# the same (weights, cap), which is only available after the inner loop
	# completes. See spec §7.5 / §13 for why the original per-tuple-only verdict
	# was structurally insufficient.
	var sweep_results: Array[Dictionary] = []
	for weight_tuple: Array in WEIGHT_SWEEP:
		for cap: int in CAPACITY_SWEEP:
			for gold: int in GOLD_SWEEP:
				var assignment: Dictionary[String, int] = _assignment_from_tuple(goods, weight_tuple)
				var result: Dictionary = _run_sweep(goods, assignment, cap, gold)
				sweep_results.append({
					"weights": weight_tuple,
					"cap": cap,
					"gold": gold,
					"assignment": assignment,
					"result": result,
				})
	# Pass 2: apply revised §7.2 verdict logic, including the cross-gold sanity
	# check (clause 3). Mutates sweep_results entries to add verdict + reason.
	_finalise_verdicts(sweep_results)
	# Pass 3: print per-tuple blocks (now with verdicts) and summary.
	for entry: Dictionary in sweep_results:
		_print_sweep_block(goods, entry)
	_print_summary(sweep_results)
	quit()

func _load_goods() -> Array[Good]:
	var goods: Array[Good] = []
	for path: String in GOOD_PATHS:
		var good: Good = load(path) as Good
		assert(good != null, "measure: failed to load %s" % path)
		goods.append(good)
	return goods

# Apply a weight tuple to the in-memory goods (overrides the .tres weight for
# the duration of the sweep). The WEIGHT_SWEEP runs BEFORE the .tres files are
# committed -- the harness is the gate -- so the .tres weight value is whatever
# the .tres file currently has on disk (may be the default 1, may be the
# candidate). The override here makes the harness self-sufficient.
func _assignment_from_tuple(goods: Array[Good], weight_tuple: Array) -> Dictionary[String, int]:
	assert(weight_tuple.size() == goods.size(),
			"measure: weight tuple size %d != goods size %d" % [weight_tuple.size(), goods.size()])
	var d: Dictionary[String, int] = {}
	for i: int in range(goods.size()):
		d[goods[i].id] = int(weight_tuple[i])
	return d

func _run_sweep(goods: Array[Good], weights: Dictionary[String, int], cap: int, gold_cap: int) -> Dictionary:
	# Per-good total weight across the cart-of-cart (sum of weight committed to
	# each good across all routes across all seeds). Divided by the
	# total-weight-committed at the end gives the weight-share.
	var per_good_weight_sum: Dictionary[String, int] = {}
	for good: Good in goods:
		per_good_weight_sum[good.id] = 0
	# Mix-richness: count of routes whose optimal mix has 1, 2, 3, 4 distinct goods.
	var mix_richness: Dictionary[int, int] = {1: 0, 2: 0, 3: 0, 4: 0}
	var total_weight_used: int = 0
	var total_routes_evaluated: int = 0
	# Skipped routes: optimal mix is empty (no profitable trade). These are not
	# decisions to weigh; excluding them from the mix-richness denominator
	# matches the spec's "evaluate cargo composition decisions, not no-ops".
	var skipped_no_profit: int = 0
	# Skipped seeds: WorldGen.generate returned null (predicate exhaustion).
	# These contribute nothing; tracked so the verdict denominator is honest.
	var skipped_worldgen: int = 0

	for seed_value: int in range(N):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			skipped_worldgen += 1
			continue
		# Directed edges: each undirected EdgeState is two routes (a->b, b->a).
		for edge: EdgeState in world.edges:
			for direction: int in [0, 1]:
				var from_id: String = edge.a_id if direction == 0 else edge.b_id
				var to_id: String = edge.b_id if direction == 0 else edge.a_id
				var from_node: NodeState = world.get_node_by_id(from_id)
				var to_node: NodeState = world.get_node_by_id(to_id)
				assert(from_node != null and to_node != null,
						"measure: edge references missing node in seed %d" % seed_value)
				var optimal: Dictionary = _optimal_mix(goods, weights, cap, gold_cap, from_node, to_node)
				var profit: int = int(optimal["profit"])
				if profit <= 0:
					skipped_no_profit += 1
					continue
				total_routes_evaluated += 1
				var qty_by_good: Dictionary[String, int] = optimal["qty_by_good"]
				var distinct_goods: int = 0
				for good: Good in goods:
					var q: int = int(qty_by_good.get(good.id, 0))
					if q > 0:
						distinct_goods += 1
						var w: int = q * weights[good.id]
						per_good_weight_sum[good.id] = per_good_weight_sum[good.id] + w
						total_weight_used += w
				assert(distinct_goods >= 1 and distinct_goods <= 4,
						"measure: mix-richness out of range: %d" % distinct_goods)
				mix_richness[distinct_goods] = mix_richness[distinct_goods] + 1

	# Compute per-good weight-shares.
	var per_good_share: Dictionary[String, float] = {}
	for good: Good in goods:
		if total_weight_used == 0:
			per_good_share[good.id] = 0.0
		else:
			per_good_share[good.id] = float(per_good_weight_sum[good.id]) / float(total_weight_used)

	# Mix-richness as fractions of routes evaluated.
	var mix_richness_pct: Dictionary[int, float] = {1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0}
	if total_routes_evaluated > 0:
		for k: int in mix_richness.keys():
			mix_richness_pct[k] = float(mix_richness[k]) / float(total_routes_evaluated)

	# Per-tuple stats only (clauses 1 + 2). Clause 3 (gold-cap sanity) needs the
	# gold=200 vs gold=400 cross-row comparison and is applied downstream in
	# _finalise_verdicts(). gold=120 is diagnostic only -- not gated.
	var max_share: float = 0.0
	var max_share_good: String = ""
	var min_share: float = 1.0
	var min_share_good: String = ""
	for good: Good in goods:
		var s: float = per_good_share[good.id]
		if s > max_share:
			max_share = s
			max_share_good = good.id
		if s < min_share:
			min_share = s
			min_share_good = good.id
	var multi_good_pct: float = mix_richness_pct[2] + mix_richness_pct[3] + mix_richness_pct[4]

	return {
		"per_good_share": per_good_share,
		"mix_richness_pct": mix_richness_pct,
		"total_routes_evaluated": total_routes_evaluated,
		"skipped_no_profit": skipped_no_profit,
		"skipped_worldgen": skipped_worldgen,
		"max_share": max_share,
		"max_share_good": max_share_good,
		"min_share": min_share,
		"min_share_good": min_share_good,
		"multi_good_pct": multi_good_pct,
	}

# Brute-force bounded knapsack per spec §7.1: enumerate (qty_g) tuples subject
# to sum(qty_g * weight_g) <= cap AND sum(qty_g * buy_price_g) <= gold_cap;
# objective is sum(qty_g * (sell_price_g - buy_price_g)). Returns the optimal
# qty_by_good and the resulting profit. Ties broken by lex-min over goods order
# (the first feasible mix of equal profit wins -- deterministic).
func _optimal_mix(
	goods: Array[Good],
	weights: Dictionary[String, int],
	cap: int,
	gold_cap: int,
	from_node: NodeState,
	to_node: NodeState,
) -> Dictionary:
	# Per-good buy/sell snapshot. Use 0 as "not for sale here" sentinel; spread
	# of 0 means "never bring this good." A buy_price > sell_price means the
	# good is unprofitable; the knapsack will never put qty > 0 of it (spread
	# negative -> contributes negative to objective, dropping qty improves profit).
	var buy_prices: Array[int] = []
	var spreads: Array[int] = []
	var weights_arr: Array[int] = []
	var max_qty: Array[int] = []
	for good: Good in goods:
		var bp: int = int(from_node.prices.get(good.id, 0))
		var sp: int = int(to_node.prices.get(good.id, 0))
		var w: int = weights[good.id]
		buy_prices.append(bp)
		spreads.append(sp - bp)
		weights_arr.append(w)
		# Per-good upper bound: tighter of (cap/weight, gold/buy_price).
		# Skip unbuyable (bp <= 0) and unprofitable (spread <= 0): max_qty=0.
		if bp <= 0 or sp - bp <= 0:
			max_qty.append(0)
		else:
			var by_cap: int = cap / w
			var by_gold: int = gold_cap / bp
			max_qty.append(mini(by_cap, by_gold))
	# Brute force enumeration. With at most 4 goods, write the loops out (faster
	# than recursion in GDScript and trivially typed).
	var best_profit: int = 0
	var best_qty: Array[int] = [0, 0, 0, 0]
	var n: int = goods.size()
	# Defensive: if a future good count != 4, fall back to recursion. For now,
	# specialise to N=4 -- the hot path.
	assert(n == 4, "measure: knapsack specialised for N=4 goods, got %d" % n)
	for q0: int in range(max_qty[0] + 1):
		var w0: int = q0 * weights_arr[0]
		var c0: int = q0 * buy_prices[0]
		if w0 > cap or c0 > gold_cap:
			break
		for q1: int in range(max_qty[1] + 1):
			var w1: int = w0 + q1 * weights_arr[1]
			var c1: int = c0 + q1 * buy_prices[1]
			if w1 > cap or c1 > gold_cap:
				break
			for q2: int in range(max_qty[2] + 1):
				var w2: int = w1 + q2 * weights_arr[2]
				var c2: int = c1 + q2 * buy_prices[2]
				if w2 > cap or c2 > gold_cap:
					break
				for q3: int in range(max_qty[3] + 1):
					var w3: int = w2 + q3 * weights_arr[3]
					var c3: int = c2 + q3 * buy_prices[3]
					if w3 > cap or c3 > gold_cap:
						break
					var profit: int = (q0 * spreads[0] + q1 * spreads[1]
							+ q2 * spreads[2] + q3 * spreads[3])
					if profit > best_profit:
						best_profit = profit
						best_qty = [q0, q1, q2, q3]
	var qty_by_good: Dictionary[String, int] = {}
	for i: int in range(n):
		qty_by_good[goods[i].id] = best_qty[i]
	return {"qty_by_good": qty_by_good, "profit": best_profit}

# Apply revised §7.2 criterion across sweep_results. Clauses 1 and 2 are
# evaluated row-local; clause 3 (gold-cap sanity) requires the matching gold=200
# and gold=400 rows for the same (weights, cap) and is computed by indexing into
# sweep_results. gold=120 rows are tagged DIAG and never gate.
func _finalise_verdicts(sweep_results: Array[Dictionary]) -> void:
	# Index by (weights-as-string, cap, gold) for clause-3 cross-row lookup.
	var by_key: Dictionary[String, Dictionary] = {}
	for entry: Dictionary in sweep_results:
		var key: String = _verdict_key(entry["weights"], int(entry["cap"]), int(entry["gold"]))
		by_key[key] = entry
	for entry: Dictionary in sweep_results:
		var weights: Array = entry["weights"]
		var cap: int = int(entry["cap"])
		var gold: int = int(entry["gold"])
		var result: Dictionary = entry["result"]
		var max_share: float = float(result["max_share"])
		var max_share_good: String = str(result["max_share_good"])
		var min_share: float = float(result["min_share"])
		var min_share_good: String = str(result["min_share_good"])
		var multi_good_pct: float = float(result["multi_good_pct"])

		var verdict: String = "PASS"
		var reasons: Array[String] = []

		# Clause 1: per-good aggregate share inside [10%, 50%] band. Always
		# evaluated -- catches pathological tuples regardless of gold tier.
		if max_share > MAX_GOOD_SHARE:
			verdict = "FAIL"
			reasons.append("max share %.1f%% (%s) > %.0f%%" % [max_share * 100.0, max_share_good, MAX_GOOD_SHARE * 100.0])
		else:
			reasons.append("max share %.1f%% (%s) <= %.0f%%: OK" % [max_share * 100.0, max_share_good, MAX_GOOD_SHARE * 100.0])
		if min_share < MIN_GOOD_SHARE:
			verdict = "FAIL"
			reasons.append("min share %.1f%% (%s) < %.0f%%" % [min_share * 100.0, min_share_good, MIN_GOOD_SHARE * 100.0])
		else:
			reasons.append("min share %.1f%% (%s) >= %.0f%%: OK" % [min_share * 100.0, min_share_good, MIN_GOOD_SHARE * 100.0])

		# Clause 2: multi-good floor at the gating tier (gold=200) only.
		# gold=120 is diagnostic (starvation regime, see §7.5 footnote).
		# gold=400 is the reference for clause 3, not a gate itself.
		if gold == GATING_GOLD:
			if multi_good_pct < MIN_MULTI_GOOD_FLOOR:
				verdict = "FAIL"
				reasons.append("multi-good %.1f%% < %.0f%% floor at gold=%d" % [multi_good_pct * 100.0, MIN_MULTI_GOOD_FLOOR * 100.0, GATING_GOLD])
			else:
				reasons.append("multi-good %.1f%% >= %.0f%% floor at gold=%d: OK" % [multi_good_pct * 100.0, MIN_MULTI_GOOD_FLOOR * 100.0, GATING_GOLD])
			# Clause 3: gold-cap sanity. multi-good at gold=200 must be strictly
			# greater than at gold=400 -- proves both caps bite (mid-game players
			# see more mixed carts than late-game players).
			var ref_key: String = _verdict_key(weights, cap, REFERENCE_GOLD)
			if by_key.has(ref_key):
				var ref_entry: Dictionary = by_key[ref_key]
				var ref_multi: float = float(ref_entry["result"]["multi_good_pct"])
				if multi_good_pct > ref_multi:
					reasons.append("gold-cap sanity: multi-good %.1f%% (gold=%d) > %.1f%% (gold=%d): OK" % [multi_good_pct * 100.0, GATING_GOLD, ref_multi * 100.0, REFERENCE_GOLD])
				else:
					verdict = "FAIL"
					reasons.append("gold-cap sanity: multi-good %.1f%% (gold=%d) not > %.1f%% (gold=%d)" % [multi_good_pct * 100.0, GATING_GOLD, ref_multi * 100.0, REFERENCE_GOLD])
			else:
				# Sweep didn't include the reference tier; clause 3 is
				# inevaluable. Flag as FAIL so the operator notices the gap
				# rather than silently passing.
				verdict = "FAIL"
				reasons.append("gold-cap sanity: missing gold=%d row for cross-check" % REFERENCE_GOLD)
		elif gold == DIAGNOSTIC_GOLD:
			# Print the multi-good number for transparency; not a gate.
			reasons.append("multi-good %.1f%% (gold=%d): diagnostic, not gated" % [multi_good_pct * 100.0, DIAGNOSTIC_GOLD])
			# gold=120 rows do not contribute PASS/FAIL on multi-good -- but the
			# per-good band (clause 1) above may have already failed them. Honor
			# that, but tag the row as diagnostic in the verdict label so the
			# operator does not read clause-1 failures here as gating.
			if verdict == "FAIL":
				verdict = "FAIL-DIAG"
		else:
			# gold=400 reference tier. Used by clause 3 above; this row itself
			# is reference-only.
			reasons.append("multi-good %.1f%% (gold=%d): reference for gold-cap sanity, not gated" % [multi_good_pct * 100.0, gold])
			if verdict == "FAIL":
				verdict = "FAIL-DIAG"

		entry["verdict"] = verdict
		entry["verdict_reason"] = "; ".join(reasons)

func _verdict_key(weights: Array, cap: int, gold: int) -> String:
	return "(%d,%d,%d,%d)|%d|%d" % [int(weights[0]), int(weights[1]), int(weights[2]), int(weights[3]), cap, gold]

func _print_sweep_block(goods: Array[Good], entry: Dictionary) -> void:
	var weights_assignment: Dictionary[String, int] = entry["assignment"]
	var cap: int = int(entry["cap"])
	var gold_cap: int = int(entry["gold"])
	var result: Dictionary = entry["result"]
	var weights_label: Array[String] = []
	for good: Good in goods:
		weights_label.append("%s=%d" % [good.id, weights_assignment[good.id]])
	print("=== slice-6 cargo decision-divergence (weights=(%s), cap=%d, gold=%d) ===" %
			[", ".join(weights_label), cap, gold_cap])
	print("seeds=%d, routes_evaluated=%d, skipped_no_profit=%d, skipped_worldgen=%d" % [
		N,
		int(result["total_routes_evaluated"]),
		int(result["skipped_no_profit"]),
		int(result["skipped_worldgen"]),
	])
	print("")
	print("per-good weight-share (mean across all routes, all seeds):")
	var per_good_share: Dictionary = result["per_good_share"]
	for good: Good in goods:
		print("  %s: %5.1f%%" % [good.id, float(per_good_share[good.id]) * 100.0])
	print("")
	print("mix-richness distribution (fraction of routes):")
	var mix_richness_pct: Dictionary = result["mix_richness_pct"]
	for k: int in [1, 2, 3, 4]:
		print("  %d-good carts: %5.1f%%" % [k, float(mix_richness_pct[k]) * 100.0])
	print("")
	print("verdict (revised criterion, see spec sec 7.2): %s" % str(entry["verdict"]))
	print("  %s" % str(entry["verdict_reason"]))
	print("")

func _print_summary(sweep_results: Array[Dictionary]) -> void:
	print("=== sweep summary ===")
	print("(weights, cap, gold) -> verdict")
	for r: Dictionary in sweep_results:
		var weights: Array = r["weights"]
		var cap: int = int(r["cap"])
		var gold: int = int(r["gold"])
		var verdict: String = str(r["verdict"])
		var reason: String = str(r["verdict_reason"])
		print("((%d,%d,%d,%d), %d, %d) -> %s  [%s]" % [
			int(weights[0]), int(weights[1]), int(weights[2]), int(weights[3]),
			cap, gold, verdict, reason,
		])
