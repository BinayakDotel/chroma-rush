extends Node
## Developer harness: runs the real game scene with an autopilot, for screenshots and long soak
## tests. Never shipped (scripts/dev is excluded from every export preset).
##
## Run:  godot --path . res://scripts/dev/dev.tscn -- [options]
##   --world=<id>          meadow | glacier | canyon | volcano | space
##   --autoplay            start a run immediately and let the autopilot drive
##   --god                 never crash and never run out of fuel (for soak tests)
##   --soak=<metres>       quit after this distance, printing a memory report
##   --quit-at=<s>         quit after this much game time, printing a memory report
##   --report-every=<s>    print a memory line every s seconds of game time (default 30)
##   --shots=<t1,t2,...>   save screenshots at these game times (seconds)
##   --shot-dir=<path>     where screenshots go (default user://shots)
##   --time-scale=<x>      speed the simulation up
##   --tutorial-done       skip the first-run how-to (saves go to user://dev, never the real profile)
##   --hide-ui             hide every screen (clean shots of the 3D scene)
##   --screen-delay=<s>    seconds of play before --screen=pause|results opens (default 2)
##   --flow-test           run the end-to-end flow checks in flow_test.gd and exit
##   --screen=<name>       open a screen for screenshots: settings | shop | howto | pause | results
##   --showcase=<yaw>      close-up camera orbiting the vehicle at this angle (degrees)

var game: Node
var _args := {}
var _elapsed := 0.0
var _next_report := 0.0
var _shots: Array[float] = []
var _shot_dir := "user://shots"
var _baseline := {}
var _runs := 0


func _ready() -> void:
	# Run after the game each frame, so the showcase camera wins.
	process_priority = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	Profile.use_sandbox()
	Settings.use_sandbox()
	if _flag("tutorial-done"):
		# Behave like a returning player: no how-to and no first-run tips.
		Profile.mark_tutorial_done()
		Profile.lifetime_runs = 1
	game = get_node("Game")
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		_args[parts[0]] = parts[1] if parts.size() > 1 else "true"
	Engine.time_scale = float(_args.get("time-scale", "1"))
	_shot_dir = _args.get("shot-dir", _shot_dir)
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	for t in str(_args.get("shots", "")).split(",", false):
		_shots.append(float(t))
	await get_tree().process_frame
	if _args.has("world"):
		game.call("dev_select_world", str(_args.world))
	if _args.has("autoplay"):
		game.call("dev_start_run")
	_baseline = _memory()
	print("[dev] start ", _baseline)
	if _args.has("hide-ui"):
		(game.get("ui") as CanvasLayer).visible = false
	if _args.has("screen"):
		_open_screen(str(_args.screen))
	if _args.has("flow-test"):
		await preload("res://scripts/dev/flow_test.gd").new().run(self)


func _process(delta: float) -> void:
	_elapsed += delta
	if not _shots.is_empty() and _elapsed >= _shots[0]:
		_shots.pop_front()
		var path := "%s/shot_%s_%05.1f.png" % [_shot_dir, _args.get("world", "x"), _elapsed]
		get_viewport().get_texture().get_image().save_png(path)
		print("[dev] shot ", ProjectSettings.globalize_path(path))
		if _shots.is_empty() and not _args.has("soak"):
			get_tree().quit()
	if _args.has("showcase"):
		_showcase(deg_to_rad(float(_args.showcase)))
	if not _args.has("autoplay"):
		return
	if _args.has("god"):
		game.call("dev_keep_alive")
	if not game.call("dev_is_playing"):
		_runs += 1
		game.call("dev_start_run")
		return
	_drive()
	var report_every := float(_args.get("report-every", "30"))
	if _elapsed >= _next_report:
		_next_report = _elapsed + report_every
		print("[dev] t=%6.1fs %s" % [_elapsed, _memory()])
	var done_soak := _args.has("soak") and float(game.get("distance")) >= float(_args.soak)
	var done_time := _args.has("quit-at") and _elapsed >= float(_args["quit-at"])
	if done_soak or done_time:
		var final := _memory()
		print("[dev] done after %d restarts: %s" % [_runs, final])
		print("[dev] delta nodes=%d objects=%d static_mb=%.2f" % [
			final.nodes - _baseline.nodes, final.objects - _baseline.objects, final.static_mb - _baseline.static_mb])
		get_tree().quit()


## Picks the safest lane for the next row, matches gate colours, jumps hurdles, chases fuel.
func _drive() -> void:
	var track: Track = game.get("track")
	var player: Racer = game.get("player")
	var distance: float = game.get("distance")
	var speed: float = maxf(game.get("speed"), 1.0)
	var row := track.next_row(distance - 0.2)
	var want_lane := player.lane
	if not row.is_empty() and row.s - distance < maxf(speed * 1.4, 22.0):
		var best_score := -INF
		for lane in Defs.LANES:
			var cell: int = row.cells[lane]
			var score := -absf(lane - player.lane) * 0.3
			if cell == Defs.SOLID:
				score -= 100.0
			elif cell >= 0 and cell <= 2:
				score += 1.0
			if score > best_score:
				best_score = score
				want_lane = lane
		var cell: int = row.cells[want_lane]
		if cell >= 0 and cell <= 2 and player.color_idx != cell:
			game.call("dev_set_color", cell)
		if cell == Defs.LOW and player.current_lane() == want_lane and (row.s - distance) / speed < 0.28:
			game.call("dev_jump")
	elif float(game.get("fuel")) < 0.6:
		for pickup in track.fuels:
			if not pickup.done and pickup.s > distance and pickup.s - distance < 60.0:
				want_lane = pickup.lane
				break
	if want_lane != player.lane:
		game.call("dev_shift", signi(want_lane - player.lane))
	game.call("dev_prism")


func _flag(name: String) -> bool:
	return ("--" + name) in OS.get_cmdline_user_args()


func _open_screen(screen: String) -> void:
	var ui: UiRoot = game.get("ui")
	match screen:
		"settings":
			ui.open_settings()
		"shop":
			ui.open_shop()
		"howto":
			ui.open_howto(false)
		"pause", "results":
			game.call("dev_start_run")
			await get_tree().create_timer(float(_args.get("screen-delay", "2"))).timeout
			# Stop the autopilot so it does not restart the run behind the screen.
			_args.erase("autoplay")
			if screen == "pause":
				ui.pause_requested.emit()
			else:
				game.call("_end_run", "CRASHED!", true)


func _showcase(yaw: float) -> void:
	var player: Racer = game.get("player")
	var cam: Camera3D = game.get("cam")
	var frame := player.global_transform
	var center := player.body_position() + frame.basis.y * 0.25
	var offset := frame.basis * (Vector3(sin(yaw), 0.45, -cos(yaw)) * 3.2)
	cam.global_transform = Transform3D(Basis.IDENTITY, center + offset).looking_at(center, frame.basis.y)
	cam.fov = 45.0
	(cam as ChaseCamera).frame_offset = Vector2.ZERO


func _memory() -> Dictionary:
	var track: Track = game.get("track")
	return {
		"distance": int(game.get("distance")),
		"fps": Performance.get_monitor(Performance.TIME_FPS),
		"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"samples": track.sample_count() if track.has_method("sample_count") else -1,
		"rows": track.rows.size(),
		"orbs": track.orbs.size(),
		"origin_dist": snappedf(track.frame_at(game.get("distance")).origin.length(), 0.1),
	}
