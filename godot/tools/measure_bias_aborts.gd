## Headless measurement tool: quantifies WorldGen.generate's bias-predicate abort rate
## across N=1000 seeds (range 0..999), to inform whether slice-3 needs a fix here.
##
## Run with:
##   godot --headless --path <godot-root> --script res://tools/measure_bias_aborts.gd
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

func _initialize() -> void:
	var goods: Array[Good] = _load_goods()
	var success_no_bump: int = 0
	var success_with_bump: int = 0
	var bump_counts: Dictionary[int, int] = {1: 0, 2: 0, 3: 0, 4: 0}
	var aborts: int = 0
	var edge_dist_counts: Dictionary[int, int] = {2: 0, 3: 0, 4: 0}
	var edge_dist_5plus: int = 0

	for seed_value: int in range(N):
		var world: WorldState = WorldGen.generate(seed_value, goods, FALLBACK_RECT)
		if world == null:
			aborts += 1
			continue
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

	_print_report(success_no_bump, success_with_bump, bump_counts, aborts, edge_dist_counts, edge_dist_5plus)
	quit()

func _load_goods() -> Array[Good]:
	var goods: Array[Good] = []
	goods.append(load("res://goods/wool.tres") as Good)
	goods.append(load("res://goods/cloth.tres") as Good)
	return goods

func _min_edge_distance(edges: Array[EdgeState]) -> int:
	assert(not edges.is_empty(), "measure: empty edges on a successful world")
	var shortest: int = edges[0].distance
	for e: EdgeState in edges:
		if e.distance < shortest:
			shortest = e.distance
	return shortest

func _print_report(
	success_no_bump: int,
	success_with_bump: int,
	bump_counts: Dictionary[int, int],
	aborts: int,
	edge_dist_counts: Dictionary[int, int],
	edge_dist_5plus: int,
) -> void:
	var total: float = float(N)
	var no_bump_pct: float = 100.0 * float(success_no_bump) / total
	var with_bump_pct: float = 100.0 * float(success_with_bump) / total
	var abort_pct: float = 100.0 * float(aborts) / total

	print("=== slice-3 bias-predicate measurement (N=%d seeds) ===" % N)
	print("fallback_rect: %s" % str(FALLBACK_RECT))
	print("goods: wool (vol=0.10, ceiling=25, base=12), cloth (vol=0.06, ceiling=32, base=18)")
	print("WorldRules.MIN_BIAS_RANGE: %.2f" % WorldRules.MIN_BIAS_RANGE)
	print("WorldGen.MIN_EDGE_DISTANCE: %d" % WorldGen.MIN_EDGE_DISTANCE)
	print("")
	print("success_no_bump:    %d (%.2f%%)" % [success_no_bump, no_bump_pct])
	print("success_with_bump:  %d (%.2f%%)" % [success_with_bump, with_bump_pct])
	print("  bumps=1: %d" % bump_counts[1])
	print("  bumps=2: %d" % bump_counts[2])
	print("  bumps=3: %d" % bump_counts[3])
	print("  bumps=4: %d" % bump_counts[4])
	print("abort_5_bumps:      %d (%.2f%%)" % [aborts, abort_pct])
	print("")
	print("min_edge_distance distribution (successes only):")
	print("  d=2: %d" % edge_dist_counts[2])
	print("  d=3: %d" % edge_dist_counts[3])
	print("  d=4: %d" % edge_dist_counts[4])
	print("  d=5+: %d" % edge_dist_5plus)
	print("")
	print("=== verdict ===")
	var verdict: String
	if abort_pct > 1.0:
		verdict = "ship-blocking"
	elif abort_pct >= 0.1:
		verdict = "tolerable but worth fixing"
	else:
		verdict = "trivial"
	print("abort rate %.2f%% -- %s" % [abort_pct, verdict])
