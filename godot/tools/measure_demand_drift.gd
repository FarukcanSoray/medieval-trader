## Headless measurement tool: pure decay+refill drift over N seeds, sampled at
## tick checkpoints. Trader-free -- no buys, no sells. Each tick advances world
## state by applying StockSystem-equivalent refill and DemandSystem-equivalent
## decay-toward-cap once per (node, good).
##
## Run with:
##   godot --headless --path godot/ --script res://tools/measure_demand_drift.gd
##
## Slice-8.1 gate: this tool sanity-checks that the tag-gated initial demand
## fill plus the existing decay rates produce a stable enough state that the
## slice-8.2 perturbation work has a meaningful baseline. The metrics are
## non-gating descriptive statistics; the operator reads them, the Reviewer
## decides if they look healthy enough to proceed.
##
## What we sample at each checkpoint tick (0, 100, 500, 2000):
##   - per (node, good): the demand pool fill ratio (pool / cap).
##   - within-node spread: max ratio - min ratio across goods at one node.
##   - cross-node spread: max ratio - min ratio for one good across nodes.
##
## At tick 0, producer (node, good) cells should read 0.0 and consumer cells
## should read 1.0 -- this is the sanity check on the tag-gated fill change.
## At tick 2000, decay has long since saturated every cell (cap is reached
## within decay_rate * 2000 cycles for any reasonable rate), so within-node and
## cross-node spreads should be ~0.0. Mid-ticks (100, 500) reveal the transient.

extends SceneTree

# Seed count: 200 matches the slice-7 cargo / production-caps tools (precedent
# for portfolio-leaning runtime budgets). Per-seed work is small here (no
# brute-force optimisation) so total runtime is bounded by world-gen retry cost.
const N: int = 200
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)

# Sample checkpoints. Tick 0 is post-gen, pre-decay; the others probe transient
# and steady state. 2000 is a generous upper bound -- with neutral decay rate
# 1.0/tick and producer-side rate 0.2/tick on caps that top out at ~80, the
# slowest cell saturates at tick ~400. 2000 = 5x headroom so a future cap bump
# does not silently outrun the sample.
const SAMPLE_TICKS: Array[int] = [0, 100, 500, 2000]

# Goods order matches measure_production_caps.gd for parity.
const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
	"res://goods/iron.tres",
]

func _initialize() -> void:
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
		}
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
		# tick 0 reflects post-gen state. After sampling, mutate (refill + decay)
		# once. Mirrors measure_production_caps.gd's sample-then-mutate ordering.
		for t: int in range(max_tick + 1):
			if SAMPLE_TICKS.has(t):
				_sample_world(world, goods, per_tick_stats[t])
				if not first_seed_sampled:
					first_seed_log.append(_format_seed_block(seed_value, t, world, goods))
			_apply_refill(world)
			_apply_decay(world)
		first_seed_sampled = true

	_print_header(skipped_worldgen)
	for t: int in SAMPLE_TICKS:
		_print_tick_block(t, per_tick_stats[t])
	if not first_seed_log.is_empty():
		print("=== first-seed sample dump (seed=0) ===")
		print("")
		for block: String in first_seed_log:
			print(block)
	quit()

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
func _sample_world(world: WorldState, goods: Array[Good], stats: Dictionary) -> void:
	var ratios_all: Array[float] = stats["ratios_all"]
	var within_node_spreads: Array[float] = stats["within_node_spreads"]
	var cross_node_spreads: Array[float] = stats["cross_node_spreads"]
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
			var ratio: float = float(pool) / float(cap)
			ratios_all.append(ratio)
			node_ratios.append(ratio)
			per_good_ratios[good.id].append(ratio)
			# Tag-gated fill sanity: count cells where producer fill is exactly
			# 0 and consumer fill is exactly cap. At tick 0 these should be
			# 100% / 100%; at later ticks the counts drift as decay refills
			# producer pools and (no-op for consumer cells already at cap).
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

# Mirrors DemandSystem._on_tick_advanced. Demand pools grow toward cap.
func _apply_decay(world: WorldState) -> void:
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
	print("=== slice-8.1 demand drift measurement (pure decay+refill, no trader) ===")
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
