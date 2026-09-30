extends RefCounted
## End-to-end check of the game's flows, driven through the same signals the UI uses. Run with
##   godot --headless --path . res://scripts/dev/dev.tscn -- --flow-test
## Prints PASS / FAIL per step and exits with code 1 if anything failed. Uses the sandboxed
## profile, the debug test store and the debug test ads.

var harness: Node
var game: Node
var ui: UiRoot
var failures := 0


func run(host: Node) -> void:
	harness = host
	game = host.game
	ui = game.get("ui")
	await _frames(5)

	_check("starts on the home screen", _state() == "MENU" and ui.home.visible)
	_check("first-time player has not seen the tutorial", not Profile.tutorial_done)

	ui.play_requested.emit()
	await _frames(3)
	_check("PLAY on first launch opens How to Play instead of starting", _state() == "MENU" and ui.has_overlay())
	var howto := ui.top_overlay()
	if howto == null:
		_check("how to play overlay exists", false)
		harness.get_tree().quit(1)
		return
	howto.call("_finish")
	await _frames(3)
	_check("finishing the tutorial starts the run", _state() == "PLAYING")
	_check("tutorial is remembered", Profile.tutorial_done)
	_check("HUD is shown in a run", ui.hud.visible)

	ui.pause_requested.emit()
	await _frames(2)
	_check("pause freezes the tree", _state() == "PAUSED" and harness.get_tree().paused)
	ui.handle_back()
	await _frames(2)
	_check("back button resumes from pause", _state() == "PLAYING" and not harness.get_tree().paused)

	await _seconds(1.0)
	game.call("_end_run", "CRASHED!", true)
	await _seconds(2.5)
	_check("crash shows results", _state() == "DEAD" and ui.results.visible)
	_check("second chance is offered once", bool(ui.results.get("_revive").visible))
	var runs_before := Profile.lifetime_runs
	ui.revive_requested.emit()
	await _seconds(3.5)
	_check("second chance puts the player back in the run", _state() == "PLAYING")
	_check("a revived run is not recorded yet", Profile.lifetime_runs == runs_before)

	game.set("orbs_collected", 40)
	game.call("_end_run", "CRASHED!", true)
	await _seconds(2.5)
	_check("no second chance after using it", not bool(ui.results.get("_revive").visible))
	_check("run is recorded once results show without a revive", Profile.lifetime_runs == runs_before + 1)
	var shards_after_run := Profile.shards
	_check("shards are awarded for orbs and distance", shards_after_run >= 40)
	ui.double_shards_requested.emit()
	await _seconds(3.5)
	_check("double shards adds the run's shards again", Profile.shards == shards_after_run * 2)

	ui.restart_requested.emit()
	await _frames(5)
	_check("retry starts a fresh run", _state() == "PLAYING" and float(game.get("score")) < 50.0)
	_check("retry did not double-record the run", Profile.lifetime_runs == runs_before + 1)

	ui.pause_requested.emit()
	await _frames(2)
	ui.home_requested.emit()
	await _frames(5)
	_check("home from pause returns to the home screen", _state() == "MENU" and ui.home.visible)
	_check("home unpauses the tree", not harness.get_tree().paused)

	ui.world_browsed.emit(1)
	await _frames(3)
	var glacier_locked := not Profile.is_unlocked("glacier")
	_check("second world starts locked", glacier_locked)
	Profile.shards = 0
	ui.unlock_requested.emit()
	await _frames(2)
	_check("cannot unlock without enough shards", not Profile.is_unlocked("glacier"))
	Profile.add_shards(Economy.world_cost("glacier"))
	ui.unlock_requested.emit()
	await _frames(2)
	_check("unlocking spends shards and opens the world", Profile.is_unlocked("glacier") and Profile.shards == 0)
	ui.play_requested.emit()
	await _frames(3)
	_check("an unlocked world can be played", _state() == "PLAYING")
	ui.home_requested.emit()
	await _frames(3)

	_check("store is available in debug builds", Store.is_available())
	Store.purchase("world_pass")
	await _seconds(1.2)
	_check("World Pass unlocks every world", Profile.is_unlocked("space") and Store.is_owned("world_pass"))
	Store.purchase("supporter_pack")
	await _seconds(1.2)
	_check("Supporter Pack grants no ads and double shards", Profile.has_entitlement(Economy.NO_ADS)
		and Profile.shard_multiplier() == 2)

	Settings.set_value(&"quality", Settings.Quality.LOW)
	await _frames(2)
	var sun: DirectionalLight3D = game.get("sun")
	_check("low quality turns off shadows", not sun.shadow_enabled)
	Settings.set_value(&"quality", Settings.Quality.HIGH)
	await _frames(2)
	_check("high quality turns shadows back on", sun.shadow_enabled)

	ui.open_settings()
	await _frames(2)
	ui.handle_back()
	await _frames(12)
	_check("back closes the settings overlay", not ui.has_overlay())

	print("[flow] %s (%d failure%s)" % ["PASSED" if failures == 0 else "FAILED", failures, "" if failures == 1 else "s"])
	harness.get_tree().quit(1 if failures > 0 else 0)


func _state() -> String:
	return ["MENU", "PLAYING", "PAUSED", "DEAD"][int(game.get("state"))]


func _check(name: String, ok: bool) -> void:
	if not ok:
		failures += 1
	print("[flow] %s  %s" % ["PASS" if ok else "FAIL", name])


func _frames(count: int) -> void:
	for i in count:
		await harness.get_tree().process_frame


func _seconds(duration: float) -> void:
	await harness.get_tree().create_timer(duration, true, false, true).timeout
