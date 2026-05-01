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
	]
	emit_gold_changed = _on_gold_changed
	emit_state_dirty = _on_state_dirty
	# SaveService first: it's the architectural primary and owns the boot path.
	# DeathService second: only listens to gold_changed, no ordering dependency,
	# but the primary-then-subscriber sequence is the convention.
	_save_service = SaveService.new()
	_save_service.name = "SaveService"
	add_child(_save_service)
	_death_service = DeathService.new()
	_death_service.name = "DeathService"
	add_child(_death_service)
	bootstrap()

func bootstrap() -> void:
	# Three-state guard per Tier 7 Debugger: world != null (done) → return;
	# _bootstrapping (in flight) → park on bootstrap_completed; else run body.
	# Survives future awaits inserted before world assignment in load_or_init().
	if world != null:
		return
	if _bootstrapping:
		await bootstrap_completed
		return
	_bootstrapping = true
	await _save_service.load_or_init()
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
			await _save_service.wipe_and_regenerate()
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

func _on_gold_changed(new_gold: int, delta: int) -> void:
	gold_changed.emit(new_gold, delta)

func _on_state_dirty() -> void:
	state_dirty.emit()
