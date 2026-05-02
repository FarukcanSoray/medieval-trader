## Headless measurement tool: quantifies WorldGen.generate's bias-predicate abort rate
## across N=1000 seeds (range 0..999) per goods-catalogue size, sweeping the size to
## inform slice-5's day-1 / day-2 gate (spec §6).
##
## Run with:
##   godot --headless --path <godot-root> --script res://tools/measure_bias_aborts.gd
##
## Goods-list policy (slice-5 day-1):
##   The canonical good-list path array is [wool, cloth, salt]. Day-2 appends
##   "res://goods/iron.tres" AND extends N_SWEEP to include 4. Today, iron.tres
##   does not exist on disk; the sweep covers N in {2, 3} only. _load_goods(n)
##   asserts n <= GOOD_PATHS.size() so an out-of-range request fails loudly
##   rather than silently producing a smaller goods array.
##
## Fallback rect choice:
##   Production passes Rect2(Vector2.ZERO, $HUD/MapPanel.size) into WorldGen.generate
##   (see main.gd:34). MapPanel is anchored full-rect with offsets
##   left=436 / top=48 / right=-376 / bottom=-8 (main.tscn:37-44). At the project's
##   default viewport of 1280x720 (project.godot window/size/viewport_*), the runtime
##   panel size resolves to (1280 - 436 - 376, 720 - 48 - 8) = (468, 664). That is
##   the slice-2 default the player actually sees on first launch, so this tool
##   uses Rect2(0, 0, 468, 664). The task brief suggested 528x348; that value is
##   not grounded in current main.tscn / project.godot and would understate the
##   rect by ~5x, which would inflate the abort rate vs. what production sees.
##   If the rect is later changed, update FALLBACK_RECT to match.

extends SceneTree

const N: int = 1000
const FALLBACK_RECT: Rect2 = Rect2(0, 0, 468, 664)
# Slice-5 day-1: sweep N=2 (kernel-trained pair) and N=3 (with salt). Day-2
# appends 4 once iron.tres lands.
const N_SWEEP: Array[int] = [2, 3]
# Day-1 gate good count: slice-5 day-1 verdict is read off this N. Day-2 retunes
# this constant to 4 (the final-ship gate per spec §6).
const GATE_N: int = 3
# Slice-5 §6: if abort_pct(GATE_N) > MAX_ABORT_RATE, the slice stops and a
# slice-5.x carryover logs the failing good's allowed_range distribution.
const MAX_ABORT_RATE: float = 5.0
# Canonical goods path list. First-N semantics is load-bearing -- adding goods
# extends the array, never reorders, so historical N=2 numbers reproduce.
const GOOD_PATHS: Array[String] = [
	"res://goods/wool.tres",
	"res://goods/cloth.tres",
	"res://goods/salt.tres",
]
# Allowed-range histogram buckets. Boundaries inclusive on the low side.
# The [0.0, 0.20) bucket is the predicate-fail zone (below MIN_BIAS_RANGE):
# any good in that bucket on a given seed's topology forces the bias-author
# pipeline to abort that attempt. Aborts populate this bucket; successes
# cannot (a successful seed by construction has every good's allowed_range
# >= MIN_BIAS_RANGE on the winning topology). Finer granularity above 0.20
# surfaces the success-side margin distribution.
const ALLOWED_RANGE_BUCKETS: Array[float] = [0.0, 0.20, 0.30, 0.40, 0.60, 0.80]

func _initialize() -> void:
	var sweep_aborts: Dictionary[int, float] = {}
	for n: int in N_SWEEP:
		var goods: Array[Good] = _load_goods(n)
		var sweep_result: Dictionary = _run_sweep(n, goods)
		_print_sweep_block(n, goods, sweep_result)
		sweep_aborts[n] = float(sweep_result["abort_pct"])
	_print_summary(sweep_aborts)
	quit()

func _load_goods(n: int) -> Array[Good]:
	assert(n >= 1, "measure: _load_goods requires n >= 1")
	assert(n <= GOOD_PATHS.size(),
			"measure: _load_goods(%d) exceeds available paths (%d). Day-2 must extend GOOD_PATHS." %
			[n, GOOD_PATHS.size()])
	var goods: Array[Good] = []
	for i: int in range(n):
		var good: Good = load(GOOD_PATHS[i]) as Good
		assert(good != null, "measure: failed to load %s" % GOOD_PATHS[i])
		goods.append(good)
	return goods

func _run_sweep(n: int, goods: Array[Good]) -> Dictionary:
	var success_no_bump: int = 0
	var success_with_bump: int = 0
	var bump_counts: Dictionary[int, int] = {1: 0, 2: 0, 3: 0, 4: 0}
	var aborts: int = 0
	var edge_dist_counts: Dictionary[int, int] = {2: 0, 3: 0, 4: 0}
	var edge_dist_5plus: int = 0
	# Per-good allowed_range histograms, split by outcome. One sample per
	# *requested* seed (not per bumped attempt), per good:
	#   - On success: sample the topology that finally won (post-bump).
	#   - On abort: sample the topology that exhausted (effective_seed =
	#     requested_seed + MAX_SEED_BUMPS - 1, the last attempt before the
	#     bump loop gave up).
	# allowed_range is computed via the same formula WorldGen._solve_bias_range
	# uses (duplicated below to avoid exposing a private static).
	# Why split: the success histogram answers "for worlds that did succeed,
	# how much margin remained per good?" -- useful tuning context. The abort
	# histogram is the load-bearing slice-5.x diagnostic: it answers "if the
	# slice fails the gate, which good drove the aborts?" The success-only
	# histogram cannot answer that, because every good in a successful seed by
	# construction has allowed_range >= MIN_BIAS_RANGE -- the failing good is
	# exactly the one whose distribution gets clipped out of the success
	# sample.
	var per_good_histogram_success: Dictionary[String, Dictionary] = {}
	var per_good_histogram_abort: Dictionary[String, Dictionary] = {}
	for good: Good in goods:
		var hist_s: Dictionary[int, int] = {}
		var hist_a: Dictionary[int, int] = {}
		for b: int in range(ALLOWED_RANGE_BUCKETS.size()):
			hist_s[b] = 0
			hist_a[b] = 0
		per_good_histogram_success[good.id] = hist_s
		per_good_histogram_abort[good.id] = hist_a

	for seed_value: int in range(N):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			aborts += 1
			# Sample the exhausted topology (the last attempted effective_seed
			# before MAX_SEED_BUMPS gave up). Mirrors the bump arithmetic in
			# WorldGen.generate: attempts run for bump in 0..MAX_SEED_BUMPS-1,
			# so the last attempt is at world_seed + MAX_SEED_BUMPS - 1.
			var last_seed: int = seed_value + WorldGen.MAX_SEED_BUMPS - 1
			var min_dist: int = WorldGen.compute_topology_min_edge_distance(last_seed, FALLBACK_RECT)
			# Placement-starvation on the last attempt: every position attempt
			# hit the retry cap. min_dist == -1 means we have no topology to
			# sample; the abort was placement-driven, not predicate-driven.
			# Skip the histogram in that case (rare under MIN_EDGE_DISTANCE=3).
			if min_dist > 0:
				var max_spread_gold: int = min_dist * WorldRules.TRAVEL_COST_PER_DISTANCE
				for good: Good in goods:
					var allowed_range: float = _solve_bias_range(good, max_spread_gold)
					var hist: Dictionary = per_good_histogram_abort[good.id]
					var bucket: int = _bucket_for(allowed_range)
					hist[bucket] = int(hist[bucket]) + 1
		else:
			var bumps: int = world.world_seed - seed_value
			if bumps == 0:
				success_no_bump += 1
			else:
				success_with_bump += 1
				if bump_counts.has(bumps):
					bump_counts[bumps] += 1
			var min_dist: int = _min_edge_distance(world.edges)
			if min_dist >= 5:
				edge_dist_5plus += 1
			elif edge_dist_counts.has(min_dist):
				edge_dist_counts[min_dist] += 1
			# Histogram on the winning world's shortest edge (post-bump topology).
			var max_spread_gold: int = min_dist * WorldRules.TRAVEL_COST_PER_DISTANCE
			for good: Good in goods:
				var allowed_range: float = _solve_bias_range(good, max_spread_gold)
				var hist: Dictionary = per_good_histogram_success[good.id]
				var bucket: int = _bucket_for(allowed_range)
				hist[bucket] = int(hist[bucket]) + 1

	return {
		"success_no_bump": success_no_bump,
		"success_with_bump": success_with_bump,
		"bump_counts": bump_counts,
		"aborts": aborts,
		"abort_pct": 100.0 * float(aborts) / float(N),
		"edge_dist_counts": edge_dist_counts,
		"edge_dist_5plus": edge_dist_5plus,
		"per_good_histogram_success": per_good_histogram_success,
		"per_good_histogram_abort": per_good_histogram_abort,
	}

func _min_edge_distance(edges: Array[EdgeState]) -> int:
	assert(not edges.is_empty(), "measure: empty edges on a successful world")
	var shortest: int = edges[0].distance
	for e: EdgeState in edges:
		if e.distance < shortest:
			shortest = e.distance
	return shortest

# Mirrors WorldGen._solve_bias_range. Duplicated rather than exposing the
# private static -- keeps the production class's API surface minimal. If the
# production formula changes, update both sites.
func _solve_bias_range(good: Good, max_spread_gold: int) -> float:
	if good.volatility <= 0.0 or good.base_price <= 0:
		return 0.0
	var volatility_term: float = 2.0 * good.volatility * float(good.ceiling_price)
	var headroom: float = float(max_spread_gold) - volatility_term
	if headroom <= 0.0:
		return 0.0
	var raw: float = headroom / float(good.base_price)
	var envelope: float = WorldRules.BIAS_MAX - WorldRules.BIAS_MIN
	return clampf(raw, 0.0, envelope)

# Index of the highest bucket whose lower-bound the value reaches (i.e. the
# bucket the value falls into). Values below ALLOWED_RANGE_BUCKETS[0] would map
# to -1, but the formula clamps to >= 0.0 so that case never fires; assert it.
func _bucket_for(value: float) -> int:
	assert(value >= 0.0, "measure: allowed_range must be non-negative, got %f" % value)
	var idx: int = 0
	for i: int in range(ALLOWED_RANGE_BUCKETS.size()):
		if value >= ALLOWED_RANGE_BUCKETS[i]:
			idx = i
		else:
			break
	return idx

func _print_sweep_block(n: int, goods: Array[Good], result: Dictionary) -> void:
	var no_bump_pct: float = 100.0 * float(result["success_no_bump"]) / float(N)
	var with_bump_pct: float = 100.0 * float(result["success_with_bump"]) / float(N)
	var abort_pct: float = float(result["abort_pct"])
	var bump_counts: Dictionary = result["bump_counts"]
	var edge_dist_counts: Dictionary = result["edge_dist_counts"]
	var per_good_histogram_success: Dictionary = result["per_good_histogram_success"]
	var per_good_histogram_abort: Dictionary = result["per_good_histogram_abort"]

	print("=== slice-5 bias-predicate measurement (N=%d goods, seeds=%d) ===" % [n, N])
	print("fallback_rect: %s" % str(FALLBACK_RECT))
	var goods_summary: Array[String] = []
	for good: Good in goods:
		goods_summary.append("%s (vol=%.2f, base=%d, ceiling=%d)" %
				[good.id, good.volatility, good.base_price, good.ceiling_price])
	print("goods: %s" % ", ".join(goods_summary))
	print("WorldRules.MIN_BIAS_RANGE: %.2f" % WorldRules.MIN_BIAS_RANGE)
	print("WorldGen.MIN_EDGE_DISTANCE: %d" % WorldGen.MIN_EDGE_DISTANCE)
	print("")
	print("success_no_bump:    %d (%.2f%%)" % [int(result["success_no_bump"]), no_bump_pct])
	print("success_with_bump:  %d (%.2f%%)" % [int(result["success_with_bump"]), with_bump_pct])
	print("  bumps=1: %d" % int(bump_counts[1]))
	print("  bumps=2: %d" % int(bump_counts[2]))
	print("  bumps=3: %d" % int(bump_counts[3]))
	print("  bumps=4: %d" % int(bump_counts[4]))
	print("abort_5_bumps:      %d (%.2f%%)" % [int(result["aborts"]), abort_pct])
	print("")
	print("min_edge_distance distribution (successes only):")
	print("  d=2: %d" % int(edge_dist_counts[2]))
	print("  d=3: %d" % int(edge_dist_counts[3]))
	print("  d=4: %d" % int(edge_dist_counts[4]))
	print("  d=5+: %d" % int(result["edge_dist_5plus"]))
	print("")
	print("allowed_range histogram per good (successes) -- post-bump winning topology:")
	_print_histogram_lines(goods, per_good_histogram_success)
	print("allowed_range histogram per good (aborts) -- exhausted topology, slice-5.x diagnostic:")
	_print_histogram_lines(goods, per_good_histogram_abort)
	print("")

func _print_histogram_lines(goods: Array[Good], per_good_histogram: Dictionary) -> void:
	for good: Good in goods:
		var hist: Dictionary = per_good_histogram[good.id]
		var line: String = "  %s:" % good.id
		for i: int in range(ALLOWED_RANGE_BUCKETS.size()):
			var lo: float = ALLOWED_RANGE_BUCKETS[i]
			var hi_label: String
			if i + 1 < ALLOWED_RANGE_BUCKETS.size():
				hi_label = "%.2f" % ALLOWED_RANGE_BUCKETS[i + 1]
			else:
				hi_label = "+inf"
			line += " [%.2f-%s)=%d" % [lo, hi_label, int(hist[i])]
		print(line)

func _print_summary(sweep_aborts: Dictionary[int, float]) -> void:
	print("=== sweep summary ===")
	var parts: Array[String] = []
	for n: int in N_SWEEP:
		parts.append("N=%d: %.1f%%" % [n, sweep_aborts[n]])
	print("abort rates: %s" % ", ".join(parts))
	print("")
	print("=== slice-5 day-1 verdict ===")
	# Day-1 gates on N=GATE_N (3): "expansion is viable at all." The day-2 final
	# gate is on N=4 once iron.tres lands and N_SWEEP / GATE_N are extended.
	# A clear gating-N readout matters: day-1 PASS at N=3 does NOT imply N=4
	# will hold; that's the day-2 measurement's job.
	if not sweep_aborts.has(GATE_N):
		print("verdict: SKIPPED -- N=%d not in sweep" % GATE_N)
		return
	var gate_pct: float = sweep_aborts[GATE_N]
	var verdict: String
	if gate_pct <= MAX_ABORT_RATE:
		verdict = "PASS"
	else:
		verdict = "FAIL"
	print("gating N=%d, threshold MAX_ABORT_RATE=%.1f%%, observed=%.1f%%" %
			[GATE_N, MAX_ABORT_RATE, gate_pct])
	print("slice-5 day-1 verdict: %s" % verdict)
	if verdict == "FAIL":
		print("  -> slice ships at N=%d only; log allowed_range histogram for slice-5.x tuning." % (GATE_N - 1))
	else:
		print("  -> day-2 may proceed: author iron.tres, extend N_SWEEP/GATE_N to 4, re-run.")
