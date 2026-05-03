## Slice-5.x Bug C check: the headless --script entry point must not write a
## stub save. This script is the test itself -- the gate's whole point is the
## scene-tree state, so a static check_* call from inside a populated scene
## could not exercise it. Run with:
##
##   godot --headless --path godot --script res://systems/save/check_headless_bootstrap_gate.gd
##
## Pre-condition: any existing user://save.json is removed up front so the
## post-run absence-assertion is unambiguous. Post-condition: after the
## autoload's deferred _f6_fallback_bootstrap_if_needed has run, no
## user://save.json exists. If it does, the gate failed and the script exits
## with code 1.
##
## Spec §5 / §3.C.
extends SceneTree

const SAVE_PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.json.tmp"

func _initialize() -> void:
	# Pre-clean. remove_absolute no-ops on missing files so the err on a fresh
	# user:// is OK -- only loud-warn if a real disk error surfaces.
	if FileAccess.file_exists(SAVE_PATH):
		var err: int = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if err != OK:
			print("[5.x gate] FAIL setup: could not remove pre-existing save.json (err %d)" % err)
			quit(1)
			return
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_PATH))

	# Autoload Game's _ready ran when SceneTree spun up; its
	# _f6_fallback_bootstrap_if_needed was call_deferred'd. That deferred call
	# fires on the next process frame. We need to spin the loop at least once
	# to give it a chance to (incorrectly) write a save -- if our gate works,
	# it returns early before bootstrap() is called and no save lands on disk.
	#
	# SceneTree.process is the canonical "advance one frame" hook for --script.
	# Two iterations is paranoia: the first runs the deferred dispatch, the
	# second gives any awaits a chance to resolve.
	for _i: int in 2:
		await process_frame

	if FileAccess.file_exists(SAVE_PATH):
		print("[5.x gate] FAIL: user://save.json was written during headless --script run")
		quit(1)
		return
	if FileAccess.file_exists(TMP_PATH):
		print("[5.x gate] FAIL: user://save.json.tmp was left behind during headless --script run")
		quit(1)
		return

	print("[5.x gate] PASS: no save written during headless --script run")
	quit(0)
