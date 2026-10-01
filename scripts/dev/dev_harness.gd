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
##   --screen=<name>       open a screen for screenshots: settings | shop | upgrades | howto |
##                         pause | results
##   --shards=<n>          start with this many shards
##   --showcase=<yaw>      close-up camera orbiting the vehicle at this angle (degrees)
##   --bot=human           with --autoplay: drive like a person instead of perfectly. It looks
##                         at each row only after passing the previous one, reacts after
##                         --react=<s> (default 0.7, +-25%), needs --action=<s> (default 0.25)
##                         per swipe or tap, and goes for a fuel pickup with probability
##                         --fuel-skill=<p> (default 0.8). Prints every run and a summary.
##   --gems=<k1,k2,...>   place these power gems on the road ahead once the run starts
##                         (shield, magnet, full_tank, prism, phoenix), for screenshots
##   --give=<kind>         apply a power gem's effect at the start (e.g. shield)
##   --tokens=<n>          start with this many banked revives (Phoenix gems)
##   --runs=<n>            with --bot=human: quit after this many runs
##   --max-run=<s>         with --bot=human: end a run that lasts this long (game seconds) and
##                         count it as survived (default 600)

var game: Node
var _args := {}
var _elapsed := 0.0
var _next_report := 0.0
var _shots: Array[float] = []
var _shot_dir := "user://shots"
var _baseline := {}
var _runs := 0
## Human-like bot state: the row being handled, queued actions [{at, kind, arg}], results.
var _bot_row := {}
var _bot_queue: Array[Dictionary] = []
var _bot_fuel_seen := {}
var _bot_results: Array[Dictionary] = []
var _bot_rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Run after the game each frame, so the showcase camera wins.
	process_priority = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Profile and Settings already switched to the user://dev sandbox at startup (DevMode).
	if _flag("tutorial-done"):
		# Behave like a returning player: no how-to and no first-run tips.
		Profile.mark_tutorial_done()
		Profile.lifetime_runs = 1
	game = get_node("Game")
	if "--tokens" in str(OS.get_cmdline_user_args()):
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--tokens="):
				Profile.revive_tokens = int(arg.get_slice("=", 1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shards="):
			Profile.shards = int(arg.get_slice("=", 1))
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
	if _args.has("gems") or _args.has("give"):
		await get_tree().create_timer(1.0).timeout
		_place_gems()
	if _args.has("flow-test"):
		# Watchdog: a failing step must never leave the test hanging.
		get_tree().create_timer(180.0, true, false, true).timeout.connect(func() -> void:
			print("[flow] TIMED OUT")
			get_tree().quit(2))
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
		if _args.get("bot") == "human" and _bot_finish_run():
			return
		_runs += 1
		game.call("dev_start_run")
		return
	if _args.get("bot") == "human":
		if float(game.get("_run_time")) >= float(_args.get("max-run", "600")):
			game.call("_end_run", "SURVIVED", false)
			return
		_drive_like_a_person()
	else:
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


## Drives with a person's limits (see --bot=human): reaction time, time per action, and not
## every fuel pickup.
func _drive_like_a_person() -> void:
	var track: Track = game.get("track")
	var player: Racer = game.get("player")
	var distance: float = game.get("distance")
	var speed: float = maxf(game.get("speed"), 1.0)
	var now := _elapsed
	var row := track.next_row(distance - 0.2)
	if not row.is_empty() and row != _bot_row:
		# Just passed the previous row: look at this one and plan.
		_bot_row = row
		_bot_queue.clear()
		var react := float(_args.get("react", "0.7")) * _bot_rng.randf_range(0.75, 1.25)
		var action := float(_args.get("action", "0.25"))
		# A fuel pickup before this row that the bot decides to go for pulls it to that lane.
		var fuel_lane := -1
		for pickup in track.fuels:
			if pickup.done or pickup.s < distance or pickup.s > row.s:
				continue
			if not _bot_fuel_seen.has(pickup.node):
				_bot_fuel_seen[pickup.node] = _bot_rng.randf() < float(_args.get("fuel-skill", "0.8"))
			if _bot_fuel_seen[pickup.node]:
				fuel_lane = pickup.lane
				break
		var want := _best_lane(row, player.lane, fuel_lane)
		var at := now + react
		var lane := player.lane
		while lane != want:
			lane += signi(want - lane)
			_bot_queue.append({"at": at, "kind": "shift", "arg": signi(want - player.lane)})
			at += action
		var cell: int = row.cells[want]
		if cell >= 0 and cell <= 2 and cell != player.color_idx:
			_bot_queue.append({"at": at, "kind": "color", "arg": cell})
			at += action
		if cell == Defs.LOW:
			_bot_queue.append({"at": at, "kind": "jump", "arg": 0})
	while not _bot_queue.is_empty() and now >= float(_bot_queue[0].at):
		var step: Dictionary = _bot_queue[0]
		if step.kind == "jump":
			# Jumps are timed to the hurdle, not done as soon as possible.
			if row.is_empty() or (row.s - distance) / speed > 0.28:
				break
			game.call("dev_jump")
		elif step.kind == "shift":
			game.call("dev_shift", int(step.arg))
		else:
			game.call("dev_set_color", int(step.arg))
		_bot_queue.pop_front()
	game.call("dev_prism")


func _best_lane(row: Dictionary, from_lane: int, fuel_lane: int) -> int:
	var best := from_lane
	var best_score := -INF
	for lane in Defs.LANES:
		var cell: int = row.cells[lane]
		var score := -absf(lane - from_lane) * 0.3 + (1.0 if lane == fuel_lane else 0.0)
		if cell == Defs.SOLID:
			score -= 100.0
		if score > best_score:
			best_score = score
			best = lane
	return best


## Records a finished human-bot run. Returns true when the requested runs are done (and quits).
func _bot_finish_run() -> bool:
	if float(game.get("distance")) < 20.0:
		return false
	var result := {"metres": int(game.get("distance")), "cause": str(game.get("_end_title")),
		"seconds": snappedf(float(game.get("_run_time")), 0.1)}
	var crash: Dictionary = game.get("_crash_row")
	if not crash.is_empty():
		var player: Racer = game.get("player")
		var track: Track = game.get("track")
		var previous := -1.0
		for r in track.rows:
			if r.s < crash.s:
				previous = r.s
		result.crash = {"cells": crash.cells, "lane": player.current_lane(), "color": player.color_idx,
			"gap_s": snappedf((crash.s - previous) / maxf(Pacing.speed_at(crash.s), 1.0), 0.01),
			"queue": _bot_queue.map(func(q: Dictionary) -> String: return "%s:%s@%.2f" % [q.kind, q.arg, float(q.at) - _elapsed])}
	result.fuel = snappedf(float(game.get("fuel")), 0.01)
	result.merge(game.get("run_stats"))
	_bot_results.append(result)
	print("[bot] run %d: %s" % [_bot_results.size(), result])
	_bot_row = {}
	_bot_queue.clear()
	_bot_fuel_seen.clear()
	if _bot_results.size() < int(_args.get("runs", "20")):
		return false
	var metres: Array = _bot_results.map(func(r: Dictionary) -> int: return r.metres)
	metres.sort()
	var fuel_deaths := _bot_results.filter(func(r: Dictionary) -> bool: return r.cause == "OUT OF FUEL!").size()
	var survived := _bot_results.filter(func(r: Dictionary) -> bool: return r.cause == "SURVIVED").size()
	var minutes: Array = _bot_results.map(func(r: Dictionary) -> float: return r.seconds / 60.0)
	minutes.sort()
	print("[bot] summary: runs=%d median=%d m (%.1f min) p10=%d m p90=%d m out_of_fuel=%d%% survived=%d%%" % [
		metres.size(), metres[metres.size() / 2], minutes[minutes.size() / 2], metres[metres.size() / 10],
		metres[metres.size() * 9 / 10], 100 * fuel_deaths / metres.size(), 100 * survived / metres.size()])
	get_tree().quit()
	return true


func _place_gems() -> void:
	var track: Track = game.get("track")
	var distance: float = game.get("distance")
	var at := distance + 40.0
	for name in str(_args.get("gems", "")).split(",", false):
		var kind: int = Powers.Kind.keys().find(name.to_upper())
		if kind >= 0 and track.place_power(kind, at, at + 60.0, (kind % 3)):
			at += 30.0
	if _args.has("give"):
		game.call("_apply_power", Powers.Kind.keys().find(str(_args.give).to_upper()))


func _flag(name: String) -> bool:
	return ("--" + name) in OS.get_cmdline_user_args()


func _open_screen(screen: String) -> void:
	var ui: UiRoot = game.get("ui")
	match screen:
		"settings":
			ui.open_settings()
		"shop":
			ui.open_shop()
		"upgrades":
			ui.open_upgrades()
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
