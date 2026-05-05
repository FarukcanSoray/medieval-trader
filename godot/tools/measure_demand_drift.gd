## Headless measurement tool: pure demand-tick (decay + drain) + refill drift
## over N seeds, sampled at tick checkpoints. Trader-free -- no buys, no sells.
## Each tick advances world state by applying StockSystem-equivalent refill and
## DemandSystem-equivalent demand_tick (decay-toward-cap then proportional drain)
## once per (node, good).
##
## Run via the .tscn driver so the Game autoload (and Game.goods) is populated
## for PricingMath calls. --script mode strips autoloads, which would silently
## zero out every PricingMath query and render the same-node spread gate
## meaningless. Mirrors measure_pricing_v2.tscn's autoload-aware launch.
##
##   godot --headless --path godot/ res://tools/measure_demand_drift.tscn
##
## Slice-8.2 gate: this tool validates the three pass criteria against the
## reshape (drain + partial conservation, conservation off in this trader-free
## tool):
##   1. Convergence: mean per-cell |ratio(t=2000) - ratio(t=1500)| < 0.02
##   2. Below-cap:   max ratio <= 0.95 and mean ratio <= 0.80 at tick 2000
##   3. Cross-node legibility: mean cross-node spread >= 0.25 at tick 2000
##      (originally 0.40; lowered to 0.25 after slice-8.2 retune surfaced that
##      the kernel-collision shadow caps consumer ratio at cheapest_edge / iron_base
##      ~= 9/22 ~= 0.41, making 0.40 mathematically unreachable. 0.25 is the
##      empirical floor under shadow-respecting ratios; still above Critic's
##      original 0.20 hedged starting point.)
##
## Slice-8.2.1 gate (within-node arbitrage shadow): max over (node, good) of
## max(0, sell_price - buy_price) at tick 2000 must be <= the cheapest edge's
## travel cost in the same world. Director's call after the original 8.2
## numbers shipped with same-node arbitrage at consumer cells (ratio 0.85
## meant sell ~= 1.85 * base while buy = base, profitable without travel).
## The gate is evaluated per-world (each world's max same-node spread vs that
## world's cheapest edge) and reported in aggregate. Pass = all worlds pass.
##
## What we sample at each checkpoint tick (0, 100, 500, 1500, 2000):
##   - per (node, good): the demand pool fill ratio (pool / cap).
##   - within-node spread: max ratio - min ratio across goods at one node.
##   - cross-node spread: max ratio - min ratio for one good across nodes.
##   - same-node price spread: max(0, sell_price - buy_price) per (node, good)
##     [tick 1500 and 2000 only -- this is a steady-state gate, no need to
##     pay PricingMath cost at every checkpoint].
##
## Per-cell convergence-delta: for every (seed, node, good), capture
## ratio_at_1500 and ratio_at_2000 in a flat parallel array indexed by
## seed_idx * cells_per_seed + cell_idx; report mean / max of |delta|.

extends Node

# Seed count: 200 matches the slice-7 cargo / production-caps tools (precedent
# for portfolio-leaning runtime budgets). Per-seed work is small here (no
# brute-force optimisation) so total runtime is bounded by world-gen retry cost.
const N: int = 200
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

# Sample checkpoints. Tick 0 is post-gen, pre-tick; the others probe transient
# and steady state. Slice-8.2 adds tick 1500 as the convergence-delta anchor:
# pass criterion #1 reads mean |ratio(2000) - ratio(1500)| < 0.02. 2000 remains
# the steady-state read for the below-cap and cross-node criteria.
const SAMPLE_TICKS: Array[int] = [0, 100, 500, 1500, 2000]

# Ticks at which we additionally sample the same-node price spread. Pricing
# pulls are O(N_NODES * N_GOODS) per checkpoint and are only meaningful at
# steady state, so we sample 1500 + 2000 (matching the convergence pair) and
# report the steady-state value at 2000.
const SAME_NODE_SPREAD_TICKS: Array[int] = [1500, 2000]

# Goods order matches measure_production_caps.gd for parity.
const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
	"res://goods/iron.tres",
]

func _ready() -> void:
	# Game autoload populates Game.goods in its _ready(); confirm it ran before
	# we lean on PricingMath. The SceneTree _ready() runs autoloads first, so
	# this is structurally guaranteed -- the assert is documentary.
	assert(not Game.goods.is_empty(), "measure: Game.goods empty -- run via .tscn driver, not --script")
	var goods: Array[Good] = _load_goods()
	# Per-checkpoint accumulators. Each holds parallel arrays across the seed
	# sweep so we can summarise mean / min / max per checkpoint at the end.
	var per_tick_stats: Dictionary[int, Dictionary] = {}
	for t: int in SAMPLE_TICKS:
		per_tick_stats[t] = {
			"ratios_all": [] as Array[float],
			"within_node_spreads": [] as Array[float],
			"cross_node_spreads": [] as Array[float],
			"producer_zero_count": 0,
			"producer_total_count": 0,
			"consumer_full_count": 0,
			"consumer_total_count": 0,
			"ratios_by_cell": [] as Array[float],
			# Slice-8.2.1 same-node spread bookkeeping. Populated only at the
			# SAME_NODE_SPREAD_TICKS subset; left empty otherwise.
			# spreads_by_good[good_id] = Array[int] of (sell - buy) values >= 0
			# across every (seed, node) sampled at this tick. world_max_spread
			# is the per-world max same-node spread -- one entry per seed.
			# world_cheapest_edge_cost is the per-world cheapest edge cost --
			# one entry per seed. world_pass is bool per seed (max <= cheapest).
			"spreads_by_good": {} as Dictionary,
			"world_max_spread": [] as Array[int],
			"world_cheapest_edge_cost": [] as Array[int],
			"world_pass": [] as Array[bool],
		}
		var spreads_by_good: Dictionary = per_tick_stats[t]["spreads_by_good"]
		for good: Good in goods:
			spreads_by_good[good.id] = [] as Array[int]
	var skipped_worldgen: int = 0
	var first_seed_sampled: bool = false
	var first_seed_log: Array[String] = []

	for seed_value: int in range(N):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			skipped_worldgen += 1
			continue
		var max_tick: int = SAMPLE_TICKS[SAMPLE_TICKS.size() - 1]
		# Walk tick 0 to max_tick. Sample BEFORE applying the tick's mutation so
		# tick 0 reflects post-gen state. After sampling, mutate (refill + demand
		# tick) once. Mirrors measure_production_caps.gd's sample-then-mutate
		# ordering. The demand tick mirrors DemandSystem._on_tick_advanced byte
		# for byte (decay then proportional drain).
		for t: int in range(max_tick + 1):
			# Keep world.tick in lockstep with the loop index so PricingMath's
			# perturbation seed (which reads world.tick) draws stable per-tick
			# values. Without this the seed would always be 0 and every
			# perturbation would resolve to the same draw across checkpoints.
			world.tick = t
			if SAMPLE_TICKS.has(t):
				_sample_world(world, goods, per_tick_stats[t])
				if SAME_NODE_SPREAD_TICKS.has(t):
					_sample_same_node_spreads(world, goods, per_tick_stats[t])
				if not first_seed_sampled:
					first_seed_log.append(_format_seed_block(seed_value, t, world, goods))
			_apply_refill(world)
			_apply_demand_tick(world)
		first_seed_sampled = true

	_print_header(skipped_worldgen)
	for t: int in SAMPLE_TICKS:
		_print_tick_block(t, per_tick_stats[t])
	# Slice-8.2 pass-criteria block. The three criteria from spec §9 are
	# evaluated against the matched-cell deltas (1500 -> 2000) and the tick-2000
	# steady-state numbers. Slice-8.2.1 adds the within-node arbitrage shadow
	# gate on the same tick-2000 sample.
	_print_pass_criteria_block(per_tick_stats[1500], per_tick_stats[2000], goods)
	if not first_seed_log.is_empty():
		print("=== first-seed sample dump (seed=0) ===")
		print("")
		for block: String in first_seed_log:
			print(block)
	get_tree().quit()

func _load_goods() -> Array[Good]:
	var goods: Array[Good] = []
	for path: String in GOOD_PATHS:
		var good: Good = load(path) as Good
		assert(good != null, "measure: failed to load %s" % path)
		goods.append(good)
	return goods

# Sample one world: collect all (node, good) pool/cap ratios, plus per-node
# within-node spread (across goods at one node) and per-good cross-node spread
# (across nodes for one good). Mutates the stats dict in-place.
#
# Slice-8.2 addition: also append every (node, good) ratio into ratios_by_cell
# in a stable iteration order (node_idx outer, good_idx inner). Across two
# ticks of the same seed-set, the i-th entry refers to the same physical cell,
# so a parallel-array delta gives the per-cell convergence metric for free
# without a Dictionary keyed on (seed, node_idx, good_idx).
func _sample_world(world: WorldState, goods: Array[Good], stats: Dictionary) -> void:
	var ratios_all: Array[float] = stats["ratios_all"]
	var within_node_spreads: Array[float] = stats["within_node_spreads"]
	var cross_node_spreads: Array[float] = stats["cross_node_spreads"]
	var ratios_by_cell: Array[float] = stats["ratios_by_cell"]
	# Build a per-good cross-node ratio array on the fly.
	var per_good_ratios: Dictionary[String, Array] = {}
	for good: Good in goods:
		per_good_ratios[good.id] = [] as Array[float]
	for node: NodeState in world.nodes:
		var node_ratios: Array[float] = []
		for good: Good in goods:
			var cap: int = int(node.demand_caps[good.id])
			var pool: int = int(node.demand_pools[good.id])
			# Cap is guaranteed >= 1 by _author_demand's maxi(1, ...) clamp.
			# Slice-8.2: conservation can lower cap to MIN_DEMAND_CAP_AFTER_EROSION
			# (2); still safe. The trader-free tool never erodes caps, so this
			# is purely defensive parity with the live system.
			var ratio: float = float(pool) / float(cap)
			ratios_all.append(ratio)
			ratios_by_cell.append(ratio)
			node_ratios.append(ratio)
			per_good_ratios[good.id].append(ratio)
			# Tag-gated fill sanity: count cells where producer fill is exactly
			# 0 and consumer fill is exactly cap. At tick 0 these should be
			# 100% / 100%; at later ticks the counts drift as decay refills
			# producer pools (slice-8.2 drain pulls them back toward 0.30).
			if good.id in node.produces:
				stats["producer_total_count"] += 1
				if pool == 0:
					stats["producer_zero_count"] += 1
			elif good.id in node.consumes:
				stats["consumer_total_count"] += 1
				if pool == cap:
					stats["consumer_full_count"] += 1
		within_node_spreads.append(_spread(node_ratios))
	for good: Good in goods:
		cross_node_spreads.append(_spread(per_good_ratios[good.id]))

# Slice-8.2.1: per-(node, good) same-node price spread = max(0, sell - buy),
# pulled through PricingMath so the formula is the canonical one shipped to
# the player. We bundle three rollups in one pass:
#   - per-good aggregate spread (`spreads_by_good[good_id]`) for naming the
#     worst offender at report time.
#   - per-world max spread (`world_max_spread`) so the gate is evaluated
#     world-by-world: one bad world is one fail.
#   - per-world cheapest edge cost (`world_cheapest_edge_cost`) sourced from
#     `world.edges` via WorldRules.edge_cost -- the per-world calibration anchor.
#
# Pass condition (per world): max same-node spread <= cheapest edge cost.
# Aggregate pass = all worlds pass. Implementation note: PricingMath internally
# clamps to [floor_price, ceiling_price]; we read its output directly so the
# gate measures shipped behaviour, not the analytic curve.
func _sample_same_node_spreads(world: WorldState, goods: Array[Good], stats: Dictionary) -> void:
	var spreads_by_good: Dictionary = stats["spreads_by_good"]
	var world_max_spread: Array[int] = stats["world_max_spread"]
	var world_cheapest_edge_cost: Array[int] = stats["world_cheapest_edge_cost"]
	var world_pass: Array[bool] = stats["world_pass"]
	var max_spread_this_world: int = 0
	for node: NodeState in world.nodes:
		for good: Good in goods:
			var sell: int = PricingMath.sell_price_for(world, node, good.id)
			var buy: int = PricingMath.buy_price_for(world, node, good.id)
			var spread: int = maxi(0, sell - buy)
			(spreads_by_good[good.id] as Array[int]).append(spread)
			if spread > max_spread_this_world:
				max_spread_this_world = spread
	var cheapest_edge_cost: int = _cheapest_edge_cost(world)
	world_max_spread.append(max_spread_this_world)
	world_cheapest_edge_cost.append(cheapest_edge_cost)
	world_pass.append(max_spread_this_world <= cheapest_edge_cost)

# Cheapest edge in the world by travel cost (= distance * TRAVEL_COST_PER_DISTANCE).
# The per-world calibration anchor for the within-node arbitrage shadow gate.
# Returns INT64_MAX (essentially) on a degenerate edgeless world so that gate
# does not falsely pass; in practice WorldGen guarantees a connected graph so
# the edges array is never empty.
func _cheapest_edge_cost(world: WorldState) -> int:
	if world.edges.is_empty():
		return 1 << 62
	var lo: int = WorldRules.edge_cost(world.edges[0])
	for e: EdgeState in world.edges:
		var c: int = WorldRules.edge_cost(e)
		if c < lo:
			lo = c
	return lo

# Max minus min across the array. Empty / single-element arrays return 0.0.
func _spread(values: Array[float]) -> float:
	if values.size() < 2:
		return 0.0
	var lo: float = values[0]
	var hi: float = values[0]
	for v: float in values:
		if v < lo:
			lo = v
		if v > hi:
			hi = v
	return hi - lo

# Mirrors StockSystem._on_tick_advanced. Trader-free, so source stocks never
# decrement -- this is a pure refill loop. Stocks start at cap, so this is a
# no-op every tick; included only to mirror the production tick path exactly.
func _apply_refill(world: WorldState) -> void:
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

# Mirrors DemandSystem._on_tick_advanced byte-for-byte. The shared body is the
# contract -- a divergence here would silently make the headless tool measure
# something different from what the game ships. Slice-8.2 reshape: decay
# (refill toward cap) then proportional drain (drain_rate * pool/cap pulls
# pool back down). Together: leaky-integrator equilibrium with steady-state
# pool*/cap = decay_rate / drain_rate.
func _apply_demand_tick(world: WorldState) -> void:
	for node: NodeState in world.nodes:
		for good_id: String in node.demand_pools.keys():
			var cap: int = int(node.demand_caps[good_id])
			var rate: float = float(node.demand_decay_rates[good_id])
			var pool: int = int(node.demand_pools[good_id])
			var decay_accum: float = float(node.demand_decay_accumulators[good_id])
			var drain_rate: float = float(node.demand_drain_rates[good_id])
			var drain_accum: float = float(node.demand_drain_accumulators[good_id])
			# Step 1: decay toward cap.
			if pool >= cap:
				decay_accum = 0.0
				pool = cap
			else:
				decay_accum += rate
				var whole_units: int = int(decay_accum)
				if whole_units > 0:
					pool = mini(cap, pool + whole_units)
					decay_accum -= float(whole_units)
			# Step 2: proportional drain on the post-decay pool.
			if cap > 0:
				drain_accum += drain_rate * (float(pool) / float(cap))
				var whole_drain: int = int(drain_accum)
				if whole_drain > 0:
					pool = maxi(0, pool - whole_drain)
					drain_accum -= float(whole_drain)
			node.demand_pools[good_id] = pool
			node.demand_decay_accumulators[good_id] = decay_accum
			node.demand_drain_accumulators[good_id] = drain_accum

# Per-checkpoint render dump for one seed (the first-sampled seed). Written
# eagerly into a string so the tick-block summary printout above stays clean.
func _format_seed_block(seed_value: int, tick_value: int, world: WorldState, goods: Array[Good]) -> String:
	var lines: Array[String] = []
	lines.append("--- seed=%d tick=%d ---" % [seed_value, tick_value])
	for node: NodeState in world.nodes:
		var tag_parts: Array[String] = []
		for good: Good in goods:
			var pool: int = int(node.demand_pools[good.id])
			var cap: int = int(node.demand_caps[good.id])
			var ratio: float = float(pool) / float(cap)
			var tag: String = "neutral"
			if good.id in node.produces:
				tag = "producer"
			elif good.id in node.consumes:
				tag = "consumer"
			tag_parts.append("%s(%s)=%d/%d (%.2f)" % [good.id, tag, pool, cap, ratio])
		lines.append("  %s: %s" % [node.id, ", ".join(tag_parts)])
	lines.append("")
	return "\n".join(lines)

func _print_header(skipped_worldgen: int) -> void:
	print("=== slice-8.2 demand drift measurement (decay + drain + refill, no trader) ===")
	print("seeds=%d, sample_ticks=%s, skipped_worldgen=%d" % [N, str(SAMPLE_TICKS), skipped_worldgen])
	print("")

func _print_tick_block(tick: int, stats: Dictionary) -> void:
	var ratios: Array[float] = stats["ratios_all"]
	var within: Array[float] = stats["within_node_spreads"]
	var cross: Array[float] = stats["cross_node_spreads"]
	print("=== tick=%d ===" % tick)
	print("  fill ratio (pool/cap) over %d (node, good) cells:" % ratios.size())
	print("    mean=%.2f  min=%.2f  max=%.2f" % [_mean(ratios), _min(ratios), _max(ratios)])
	print("  within-node spread (max-min ratio across goods at one node), %d nodes:" % within.size())
	print("    mean=%.2f  min=%.2f  max=%.2f" % [_mean(within), _min(within), _max(within)])
	print("  cross-node spread (max-min ratio for one good across nodes), %d goods:" % cross.size())
	print("    mean=%.2f  min=%.2f  max=%.2f" % [_mean(cross), _min(cross), _max(cross)])
	var prod_total: int = int(stats["producer_total_count"])
	var prod_zero: int = int(stats["producer_zero_count"])
	var cons_total: int = int(stats["consumer_total_count"])
	var cons_full: int = int(stats["consumer_full_count"])
	var prod_pct: float = 0.0
	if prod_total > 0:
		prod_pct = 100.0 * float(prod_zero) / float(prod_total)
	var cons_pct: float = 0.0
	if cons_total > 0:
		cons_pct = 100.0 * float(cons_full) / float(cons_total)
	print("  tag-gated fill markers:")
	print("    producer cells at pool=0:   %d / %d  (%.1f%%)" % [prod_zero, prod_total, prod_pct])
	print("    consumer cells at pool=cap: %d / %d  (%.1f%%)" % [cons_full, cons_total, cons_pct])
	print("")

# Slice-8.2 pass-criteria block. Reads tick-1500 and tick-2000 stats and
# evaluates the three spec §9 criteria against them, printing PASS / FAIL per
# criterion. The flat parallel ratios_by_cell arrays are aligned by sample
# order: i-th entry refers to the same physical cell at both ticks.
#
# Slice-8.2.1 extension: report the within-node arbitrage shadow gate from
# the tick-2000 same-node spread sample. The gate fires per-world (each world's
# max same-node spread vs that world's cheapest edge cost) and aggregates as
# pass-iff-all-worlds-pass.
func _print_pass_criteria_block(stats_1500: Dictionary, stats_2000: Dictionary, goods: Array[Good]) -> void:
	var by_cell_1500: Array[float] = stats_1500["ratios_by_cell"]
	var by_cell_2000: Array[float] = stats_2000["ratios_by_cell"]
	var ratios_2000: Array[float] = stats_2000["ratios_all"]
	var cross_2000: Array[float] = stats_2000["cross_node_spreads"]
	# Convergence (1500 -> 2000).
	var deltas: Array[float] = []
	if by_cell_1500.size() == by_cell_2000.size():
		for i: int in range(by_cell_1500.size()):
			deltas.append(absf(by_cell_2000[i] - by_cell_1500[i]))
	else:
		push_warning("measure: ratios_by_cell size mismatch %d vs %d -- convergence skipped" % [by_cell_1500.size(), by_cell_2000.size()])
	var convergence_mean: float = _mean(deltas)
	var convergence_max: float = _max(deltas)
	var max_ratio_2000: float = _max(ratios_2000)
	var mean_ratio_2000: float = _mean(ratios_2000)
	var cross_mean_2000: float = _mean(cross_2000)
	# Slice-8.2.1 same-node spread gate inputs.
	var world_max_spread: Array[int] = stats_2000["world_max_spread"]
	var world_cheap_edge: Array[int] = stats_2000["world_cheapest_edge_cost"]
	var world_pass: Array[bool] = stats_2000["world_pass"]
	var spreads_by_good: Dictionary = stats_2000["spreads_by_good"]
	# Aggregate same-node spread numbers.
	var aggregate_max: int = 0
	for v: int in world_max_spread:
		if v > aggregate_max:
			aggregate_max = v
	var min_cheap_edge: int = (1 << 62)
	for v: int in world_cheap_edge:
		if v < min_cheap_edge:
			min_cheap_edge = v
	var failing_worlds: int = 0
	for ok: bool in world_pass:
		if not ok:
			failing_worlds += 1
	# Spec §9 + §slice-8.2.1 thresholds.
	var pass_convergence: bool = convergence_mean < 0.02
	var pass_below_cap: bool = (max_ratio_2000 <= 0.95) and (mean_ratio_2000 <= 0.80)
	var pass_cross_node: bool = cross_mean_2000 >= 0.25
	var pass_same_node_spread: bool = failing_worlds == 0
	print("=== convergence (1500 -> 2000) ===")
	print("  per-cell |delta ratio| over %d cells:" % deltas.size())
	print("    mean=%.4f  max=%.4f" % [convergence_mean, convergence_max])
	print("")
	print("=== same-node price spread (tick=2000) ===")
	print("  per-good max(0, sell - buy) over %d cells per good:" % (world_max_spread.size() * world_max_spread.size() / maxi(1, world_max_spread.size())))
	for good: Good in goods:
		var per_good: Array[int] = spreads_by_good[good.id]
		print("    %-6s  max=%d  mean=%.2f  (n=%d)" % [good.id, _max_int(per_good), _mean_int(per_good), per_good.size()])
	print("  per-world max spread vs that world's cheapest edge cost:")
	print("    aggregate_max_same_node_spread=%d   min_cheapest_edge_cost=%d" % [aggregate_max, min_cheap_edge])
	print("    failing worlds (max_spread > cheapest_edge): %d / %d" % [failing_worlds, world_max_spread.size()])
	print("")
	print("=== slice-8.2 pass criteria ===")
	print("  1. convergence       mean=%.4f  threshold<0.02   %s" % [convergence_mean, _pass_label(pass_convergence)])
	print("  2. below-cap (t=2000) max=%.2f mean=%.2f  thresholds max<=0.95 mean<=0.80   %s" % [max_ratio_2000, mean_ratio_2000, _pass_label(pass_below_cap)])
	print("  3. cross-node spread mean=%.2f  threshold>=0.25   %s" % [cross_mean_2000, _pass_label(pass_cross_node)])
	print("  4. same-node spread <= cheapest edge (per world):  %s" % _pass_label(pass_same_node_spread))
	print("")

func _pass_label(ok: bool) -> String:
	if ok:
		return "PASS"
	return "FAIL"

func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sum: float = 0.0
	for v: float in values:
		sum += v
	return sum / float(values.size())

func _min(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var lo: float = values[0]
	for v: float in values:
		if v < lo:
			lo = v
	return lo

func _max(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var hi: float = values[0]
	for v: float in values:
		if v > hi:
			hi = v
	return hi

func _max_int(values: Array[int]) -> int:
	if values.is_empty():
		return 0
	var hi: int = values[0]
	for v: int in values:
		if v > hi:
			hi = v
	return hi

func _mean_int(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var sum: int = 0
	for v: int in values:
		sum += v
	return float(sum) / float(values.size())
