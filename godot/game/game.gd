## The slice's one autoload: holds trader+world refs, fans out the four cross-system signals, provides the Callable seam for resource mutators.
## No class_name — autoload name "Game" is already globally accessible; declaring class_name Game would collide with the autoload singleton in Godot 4.
extends Node

signal tick_advanced(new_tick: int)
signal gold_changed(new_gold: int, delta: int)
signal state_dirty
signal died(cause: String)
# Implementation detail of bootstrap() idempotency — NOT part of Game's public API.
# Do not subscribe from other systems; use `await Game.bootstrap()` instead.
signal bootstrap_completed

var trader: TraderState
var world: WorldState
var goods: Array[Good]
# Slice-6: O(1) good-by-id lookup for CargoMath.compute_load. Populated in
# _ready alongside `goods` and never mutated thereafter; consumers may read
# directly. Mirrors `goods` semantically -- if `goods` is empty, this is empty too.
var goods_by_id: Dictionary[String, Good] = {}

# signature: func(new_gold: int, delta: int) -> void
var emit_gold_changed: Callable
# signature: func() -> void
var emit_state_dirty: Callable

var _save_service: SaveService
var _death_service: DeathService
var _bootstrapping: bool = false
var _save_corruption_notice_pending: bool = false

func _ready() -> void:
	goods = [
		preload("res://goods/wool.tres") as Good,
		preload("res://goods/cloth.tres") as Good,
		preload("res://goods/salt.tres") as Good,
		preload("res://goods/iron.tres") as Good,
	]
	# Slice-6: parallel id->Good dict for CargoMath.compute_load O(1) lookup.
	# Built once here, before any consumer (Trade / NodePanel) reads it.
	goods_by_id = {}
	for good: Good in goods:
		goods_by_id[good.id] = good
	emit_gold_changed = _on_gold_changed
	emit_state_dirty = _on_state_dirty
	_save_service = SaveService.new()
	_save_service.name = "SaveService"
	add_child(_save_service)
	_death_service = DeathService.new()
	_death_service.name = "DeathService"
	add_child(_death_service)
	# Defer to next idle frame: Main supplies the real MapPanel rect and races
	# us via its own bootstrap() await. F6-isolated scenes have no Main, so the
	# sentinel self-bootstraps with the fallback rect.
	call_deferred("_f6_fallback_bootstrap_if_needed")

func bootstrap(seed_override: int = -1, map_rect: Rect2 = Rect2()) -> void:
	# Three-state guard per Tier 7 Debugger: world != null (done) → return;
	# _bootstrapping (in flight) → park on bootstrap_completed; else run body.
	# Survives future awaits inserted before world assignment in load_or_init().
	if world != null:
		return
	if _bootstrapping:
		await bootstrap_completed
		return
	_bootstrapping = true
	# Empty rect = F6 or other isolated callers that bypassed Main's panel read.
	var effective_rect: Rect2 = map_rect
	if effective_rect.size == Vector2.ZERO:
		push_warning("bootstrap called with empty map_rect; falling back to default")
		effective_rect = SaveService.FALLBACK_MAP_RECT
	await _save_service.load_or_init(seed_override, effective_rect)
	# B1 invariant harness runs here, BEFORE _bootstrapping clears, so a
	# corrupted dead-record can't reach Main._ready's death-screen branch.
	# Per 2026-05-01-save-invariant-checker-harness-no-autoload this site is
	# load-bearing — do not move to Main._ready.
	var report: InvariantReport = SaveInvariantChecker.check(trader, world)
	if not report.ok:
		for v: String in report.violations:
			push_warning("[B1 harness] FAIL " + v)
		if OS.is_debug_build():
			# Debug halts the frame so the violation is impossible to miss.
			# Folding the violation list into the message keeps the diagnosis
			# durable when warnings scroll out of the editor output.
			assert(false, "Save invariant violation: " + ", ".join(report.violations))
		else:
			# Release wipes-and-regenerates; toast announces the wipe to the player.
			# Set the flag BEFORE the await so a re-entrant bootstrap() that
			# returns early via the world != null guard during wipe_and_regenerate
			# still observes the pending toast. Mirrors the defensive style of the
			# three-state guard above ("survives future awaits inserted in load_or_init").
			_save_corruption_notice_pending = true
			# Preserve pre-slice-2-followup semantics: B1 harness wipe ignores
			# --seed=N (the load path that just failed didn't consume it either).
			# Pass effective_rect so the regen still places nodes in the live panel.
			await _save_service.wipe_and_regenerate(-1, effective_rect)
	# Clear flag before emit so awaiters wake to a consistent state, and so a
	# future early-return inserted between here and emit doesn't strand them.
	_bootstrapping = false
	bootstrap_completed.emit()

## One-shot read: returns true at most once per regenerate. The read clears the
## flag so a later UI boot or reconnect can't re-trigger the toast.
func consume_save_corruption_notice() -> bool:
	var pending: bool = _save_corruption_notice_pending
	_save_corruption_notice_pending = false
	return pending

# F6 entry: if main.tscn isn't running, no caller will provide a real MapPanel
# rect. Self-bootstrap with the fallback so isolated scenes have a viable
# Game.world to read. Main-driven boot has already awaited bootstrap() by this
# idle frame; the world != null guard no-ops us.
func _f6_fallback_bootstrap_if_needed() -> void:
	# _bootstrapping guard removes the implicit ordering dependency on Main
	# reaching its bootstrap() call before this idle frame fires. If a future
	# Main inserts an `await get_tree().process_frame` ahead of bootstrap(),
	# the world != null check would still see null and current_scene is Main
	# would still return — but the dependency is implicit. Make it explicit.
	if _bootstrapping:
		return
	if world != null:
		return
	var current: Node = get_tree().current_scene
	# Slice-5.x Bug C: headless --script mode has no scene tree; the F6 fallback
	# is a no-op there. Without this gate, a tooling run would write a stub save
	# over a real one. Spec §3.C.
	if current == null:
		return
	if current is Main:
		return
	bootstrap()

func _on_gold_changed(new_gold: int, delta: int) -> void:
	gold_changed.emit(new_gold, delta)

func _on_state_dirty() -> void:
	state_dirty.emit()
