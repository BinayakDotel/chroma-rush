extends Node3D
## Chroma Rush: game flow (home, run, pause, results), scoring, collisions, input, and the
## hooks into progression (shards, unlocks), ads (second chance, double shards) and settings.

const START_S := 12.0
const PRISM_DURATION := 5.0
const PRISM_SPEED_BOOST := 1.35
const GRACE_DURATION := 1.2
const REVIVE_GRACE := 2.0
const REVIVE_FUEL := 0.6
const RESULTS_DELAY := 0.9
const SWIPE_PX := 50.0
const MILESTONE := 500
const FUEL_PER_METRE := 1.0 / 420.0
const FUEL_PICKUP := 0.4
const LOW_FUEL := 0.25
const COAST_TIME := 1.6
const HINT_DISTANCE := 38.0

enum State { MENU, PLAYING, PAUSED, DEAD }

@onready var track: Track = $Track
@onready var player: Racer = $Player
@onready var cam: ChaseCamera = $Camera
@onready var ui: UiRoot = $UI
@onready var audio: Sfx = $Audio
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun
## The in-run HUD screen (see scripts/ui/screens/hud_screen.gd).
var hud

var state := State.MENU
var distance := START_S
var speed := 0.0
var score := 0.0
var combo := 0
var best_combo := 0
var gates := 0
var orbs_collected := 0
var meter := 0.0
var prism_left := 0.0
var grace_left := 0.0
var fuel := 1.0
var world_index := 0
## Set only by the developer harness: obstacles are smashed instead of ending the run.
var dev_god := false

var _themes := Themes.all()
var _state_time := 0.0
var _next_milestone := MILESTONE
var _menu_angle := 0.0
var _sky_yaw := 0.0
var _touch_start := Vector2.ZERO
var _swiped := false
var _sun_dir := Vector3(0.0, 0.5, -1.0)
var _coast := -1.0  # seconds spent rolling to a stop on an empty tank; -1 while fuelled
var _low_fuel_warned := false
var _revive_used := false
var _recorded := true
var _run_shards := 0
var _end_title := ""
var _crash_row := {}
var _hints_shown := {}
var _first_run := false


func _ready() -> void:
	hud = ui.hud
	if OS.has_feature("mobile"):
		Engine.max_fps = 60
	player.landed.connect(_on_landed)
	track.rebased.connect(_on_track_rebased)
	Settings.changed.connect(_on_setting_changed)
	Ads.rewarded_finished.connect(_on_rewarded_finished)
	ui.play_requested.connect(_on_play_requested)
	ui.world_browsed.connect(_browse)
	ui.unlock_requested.connect(_unlock_world)
	ui.pause_requested.connect(_pause)
	ui.resume_requested.connect(_resume)
	ui.restart_requested.connect(_restart)
	ui.home_requested.connect(_go_home)
	ui.color_pressed.connect(_set_color)
	ui.prism_pressed.connect(_activate_prism)
	ui.revive_requested.connect(func() -> void: Ads.show_rewarded(Ads.REVIVE))
	ui.double_shards_requested.connect(func() -> void: Ads.show_rewarded(Ads.DOUBLE_SHARDS))
	ui.quit_requested.connect(_quit)
	world_index = Themes.index_of(Profile.selected_world)
	_apply_quality()
	_apply_theme()
	_enter_menu()


func _process(delta: float) -> void:
	_state_time += delta
	match state:
		State.MENU:
			_menu_tick(delta)
		State.PLAYING:
			_play_tick(delta)
	track.road_material.set_shader_parameter("line_color", player.display_color)
	_update_sky(delta)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			# Phones: pause on a call, notification shade or app switch; save a finished run.
			if state == State.PLAYING:
				_pause()
			_record_run()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_record_run()


func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		if event.is_action_pressed("theme_next") and state == State.MENU:
			_browse(1)
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		_pause()
	elif event.is_action_pressed("move_left"):
		_shift(-1)
	elif event.is_action_pressed("move_right"):
		_shift(1)
	elif event.is_action_pressed("jump"):
		_jump()
	elif event.is_action_pressed("slam"):
		_slam()
	elif event.is_action_pressed("color_next"):
		_set_color((player.color_idx + 1) % 3)
	elif event.is_action_pressed("color_1"):
		_set_color(0)
	elif event.is_action_pressed("color_2"):
		_set_color(1)
	elif event.is_action_pressed("color_3"):
		_set_color(2)
	elif event.is_action_pressed("prism"):
		_activate_prism()


# --- flow ------------------------------------------------------------------

func _new_run() -> void:
	track.reset(randi())
	distance = START_S
	speed = Defs.speed_at(distance)
	score = 0.0
	combo = 0
	best_combo = 0
	gates = 0
	orbs_collected = 0
	meter = 0.0
	prism_left = 0.0
	grace_left = 0.0
	fuel = 1.0
	_coast = -1.0
	_low_fuel_warned = false
	_revive_used = false
	_crash_row = {}
	_hints_shown.clear()
	_next_milestone = MILESTONE
	Engine.time_scale = 1.0
	player.reset()
	player.transform = track.frame_at(distance)
	hud.reset()


func _enter_menu() -> void:
	_new_run()
	state = State.MENU
	_state_time = 0.0
	get_tree().paused = false
	audio.duck(false)
	ui.show_home(_themes[world_index], world_index, _themes.size())
	var frame := track.frame_at(distance)
	cam.global_transform = Transform3D(Basis.IDENTITY, frame * Vector3(0.0, 2.2, 6.0)).looking_at(frame.origin, frame.basis.y)
	_menu_angle = 0.0


func _on_play_requested() -> void:
	if state != State.MENU or not Profile.is_unlocked(_themes[world_index].id):
		return
	if not Profile.tutorial_done:
		ui.open_howto(true)
		return
	_start()


## Starts driving on the freshly reset track (callers reset it first).
func _start() -> void:
	Profile.select_world(_themes[world_index].id)
	_first_run = Profile.lifetime_runs == 0
	state = State.PLAYING
	_state_time = 0.0
	_recorded = false
	get_tree().paused = false
	ui.show_hud()
	hud.hint("GO!")
	audio.play("start")


func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	audio.duck(true)
	ui.show_pause()


func _resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	audio.duck(false)


func _restart() -> void:
	_leave_results(func() -> void:
		_new_run()
		_start())


func _go_home() -> void:
	_leave_results(_enter_menu)


## Records the run, lets the ad policy show an interstitial if one is due, then continues.
func _leave_results(next: Callable) -> void:
	var was_run := state == State.DEAD
	_record_run()
	get_tree().paused = false
	if was_run and Ads.after_run():
		await Ads.showing_changed
	next.call()


func _quit() -> void:
	_record_run()
	get_tree().quit()


## Worlds are chosen on the home screen only; browsing rebuilds the preview track.
func _browse(step: int) -> void:
	if state != State.MENU:
		return
	world_index = posmod(world_index + step, _themes.size())
	Profile.select_world(_themes[world_index].id)
	_apply_theme()
	_enter_menu()


func _unlock_world() -> void:
	var id: String = _themes[world_index].id
	if Profile.buy_world(id):
		Profile.select_world(id)
		audio.play("unlock")
		Settings.vibrate(0.6)
		ui.toast("%s UNLOCKED!" % _themes[world_index].name, UiKit.GOLD)
		ui.refresh_home(_themes[world_index], world_index, _themes.size())


func _apply_theme() -> void:
	var theme: Dictionary = _themes[world_index]
	var env := world.environment
	var sky_material: ShaderMaterial = env.sky.sky_material
	var sky_values := {"cloud_amount": 0.0, "star_amount": 0.0, "star_everywhere": 0.0, "nebula_amount": 0.0,
		"sea_amount": 0.0, "sea_glint": Color.WHITE}
	sky_values.merge(theme.sky, true)
	for key: String in sky_values:
		sky_material.set_shader_parameter(key, sky_values[key])
	var elevation := deg_to_rad(theme.sun_elevation)
	var azimuth := deg_to_rad(theme.sun_azimuth)
	_sun_dir = Vector3(sin(azimuth) * cos(elevation), sin(elevation), -cos(azimuth) * cos(elevation))
	sky_material.set_shader_parameter("sun_direction", _sun_dir)
	# Depth fog keeps everything near the player crisp and only softens the far distance.
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_light_color = theme.fog_color
	env.fog_depth_begin = theme.fog_begin
	env.fog_depth_end = theme.fog_end
	env.fog_depth_curve = theme.fog_curve
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY if theme.ambient_sky else Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme.ambient_color
	env.ambient_light_energy = theme.ambient_energy
	sun.light_color = theme.light_color
	sun.light_energy = theme.light_energy
	track.set_theme(theme)
	track.set_symbols_visible(Settings.color_symbols)
	player.set_model(theme.player)
	player.set_trail_style(theme.trail)
	player.set_color(player.color_idx)


## Graphics presets. Mobile builds use the Mobile renderer, which ignores SSAO anyway.
func _apply_quality() -> void:
	var q := Settings.quality
	var env := world.environment
	sun.shadow_enabled = q >= Settings.Quality.MEDIUM
	sun.directional_shadow_max_distance = 90.0 if q == Settings.Quality.HIGH else 60.0
	env.ssao_enabled = q == Settings.Quality.HIGH
	env.glow_enabled = q >= Settings.Quality.MEDIUM
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_DISABLED if q == Settings.Quality.LOW else Viewport.MSAA_2X
	var mobile := OS.has_feature("mobile")
	viewport.scaling_3d_scale = [0.7, 0.85 if mobile else 1.0, 1.0][q]
	player.set_trail_enabled(q >= Settings.Quality.MEDIUM)


func _on_setting_changed(key: StringName) -> void:
	match key:
		&"quality":
			_apply_quality()
		&"color_symbols":
			track.set_symbols_visible(Settings.color_symbols)


# --- per frame ---------------------------------------------------------------

func _menu_tick(delta: float) -> void:
	_menu_angle += delta * 0.35
	var frame := track.frame_at(distance)
	player.transform = frame
	player.speed = 0.0
	player.tick(delta)
	var center := player.body_position() + frame.basis.y * 0.3
	var radius := 5.2 if _is_portrait() else 6.0
	var offset := frame.basis * Vector3(sin(_menu_angle) * radius, 1.8 + sin(_menu_angle * 0.7) * 0.6, cos(_menu_angle) * radius)
	_frame_camera(58.0)
	# Landscape home screen: the menu sits on the left, so frame the vehicle on the right.
	cam.frame_offset = cam.frame_offset.lerp(Vector2.ZERO if _is_portrait() else Vector2(-1.5, 0.3), 1.0 - exp(-4.0 * delta))
	cam.follow(Transform3D(Basis.IDENTITY, center + offset).looking_at(center, frame.basis.y), delta, 5.0, 5.0)


func _play_tick(delta: float) -> void:
	cam.frame_offset = cam.frame_offset.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	speed = Defs.speed_at(distance) * (PRISM_SPEED_BOOST if prism_left > 0.0 else 1.0)
	if _coast >= 0.0:
		_coast += delta
		speed *= clampf(1.0 - _coast / COAST_TIME, 0.0, 1.0)
	distance += speed * delta
	_burn_fuel(speed * delta)
	track.update(distance)
	player.transform = track.frame_at(distance)
	player.speed = speed
	player.tick(delta)
	_tick_prism(delta)
	_check_orbs()
	_check_fuel()
	_check_rows()
	if state != State.PLAYING:
		return
	if _coast >= COAST_TIME:
		_end_run("OUT OF FUEL!", false)
		return
	if _first_run:
		_tutorial_hints()

	score += speed * delta * 0.5 * _multiplier()
	var travelled := int(distance - START_S)
	if travelled >= _next_milestone:
		hud.hint("%s m!" % UiKit.thousands(_next_milestone), UiKit.GOLD)
		audio.play("start", 1.3)
		_next_milestone += MILESTONE
	_update_camera(delta)
	hud.set_score(score, _multiplier())
	hud.set_distance(travelled, speed)
	hud.set_meter(meter, meter >= 1.0, prism_left > 0.0)
	hud.set_fuel(fuel)
	hud.set_speed_fx(remap(speed, 30.0, Defs.MAX_SPEED * PRISM_SPEED_BOOST, 0.0, 1.0))


func _update_camera(delta: float) -> void:
	var portrait := _is_portrait()
	# Portrait screens are narrow: sit higher and further back so all three lanes stay in view.
	var back := 8.5 if portrait else 6.5
	var up := 4.8 if portrait else 3.0
	var behind := track.frame_at(distance - back)
	var eye := behind.origin + behind.basis.x * (player.lateral * 0.6) + behind.basis.y * (up + player.height * 0.35)
	var look := track.point(distance + (8.0 if portrait else 9.0), player.lateral * 0.35, 0.8 + player.height * 0.3)
	var target := Transform3D(Basis.IDENTITY, eye).looking_at(look, track.frame_at(distance).basis.y)
	# Glide from the menu orbit into the chase position, then lock on.
	var blend := clampf(_state_time / 1.2, 0.0, 1.0)
	cam.follow(target, delta, 10.0, 4.0, blend * blend)
	var fov := remap(speed, Defs.BASE_SPEED, Defs.MAX_SPEED, 70.0, 88.0)
	if prism_left > 0.0:
		fov += 8.0
	_frame_camera(clampf(fov, 60.0, 100.0), delta)


## Landscape keeps the vertical field of view; portrait keeps the horizontal one instead, so
## the road is never cropped on a tall phone screen.
func _frame_camera(landscape_fov: float, delta := -1.0) -> void:
	var portrait := _is_portrait()
	cam.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
	var target := landscape_fov * 1.08 if portrait else landscape_fov
	if delta < 0.0:
		cam.fov = target
	else:
		cam.ease_fov(target, delta)


func _is_portrait() -> bool:
	var s := get_viewport().get_visible_rect().size
	return s.x < s.y


func _update_sky(delta: float) -> void:
	# Keep the sun roughly ahead, drifting sideways through turns.
	var fwd := -cam.global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	_sky_yaw = lerp_angle(_sky_yaw, yaw, 1.0 - exp(-1.5 * delta))
	world.environment.sky_rotation = Vector3(0.0, _sky_yaw, 0.0)
	# The sunlight follows the sun drawn in the rotated sky.
	var sun_world := Basis(Vector3.UP, _sky_yaw) * _sun_dir
	sun.global_transform.basis = Basis.looking_at(-sun_world)


## First run only: one tip the first time each kind of obstacle comes up.
func _tutorial_hints() -> void:
	var row := track.next_row(distance)
	if row.is_empty() or row.s - distance > HINT_DISTANCE:
		return
	var touch := OS.has_feature("mobile")
	var kind := ""
	var text := ""
	if row.cells.any(func(c: int) -> bool: return c >= 0 and c <= 2):
		kind = "gate"
		text = "TAP THE MATCHING COLOUR!" if touch else "MATCH THE COLOUR!  J K L"
	elif Defs.LOW in row.cells:
		kind = "low"
		text = "SWIPE UP TO JUMP!" if touch else "PRESS W TO JUMP!"
	elif Defs.SOLID in row.cells:
		kind = "solid"
		text = "SWIPE TO DODGE!" if touch else "A / D TO DODGE!"
	if not kind.is_empty() and not _hints_shown.has(kind):
		_hints_shown[kind] = true
		hud.hint(text, Color.WHITE, 1.6)


# --- collisions and pickups ------------------------------------------------

func _check_rows() -> void:
	for row in track.rows:
		if row.done:
			continue
		if row.s > distance + 0.5:
			break
		row.done = true
		_resolve_row(row)
		if state != State.PLAYING:
			return


func _resolve_row(row: Dictionary) -> void:
	var lane := player.current_lane()
	var cell: int = row.cells[lane]
	if cell == Defs.EMPTY:
		if Defs.SOLID in row.cells:
			score += 10 * _multiplier()
		return
	if prism_left > 0.0:
		track.smash_cell(row, lane)
		score += 50 * _multiplier()
		audio.play("smash", randf_range(0.9, 1.2))
		cam.shake(0.35)
		return
	if grace_left > 0.0:
		track.smash_cell(row, lane)
		return
	if cell == Defs.LOW:
		if player.height + Racer.HOVER > Track.LOW_SIZE.y:
			combo += 1
			best_combo = maxi(best_combo, combo)
			score += 20 * _multiplier()
			_add_meter(0.06)
			audio.play("gate", 0.8)
		else:
			_crash(row)
		return
	if cell == player.color_idx:
		_pass_gate(row, lane)
	else:
		_crash(row)


func _pass_gate(row: Dictionary, lane: int) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	gates += 1
	score += 25 * _multiplier()
	track.pass_cell(row, lane)
	audio.play("gate", 1.0 + minf(combo, 24) * 0.025)
	_add_meter(0.12)
	if combo % 8 == 0:
		hud.hint("COMBO x%d" % _multiplier(), player.display_color)


func _check_orbs() -> void:
	for orb in track.orbs:
		if orb.done:
			continue
		if orb.s > distance + 0.5:
			break
		orb.done = true
		if player.current_lane() != orb.lane:
			continue
		track.collect_orb(orb)
		if orb.color == player.color_idx or prism_left > 0.0:
			orbs_collected += 1
			score += 20 * _multiplier()
			_add_meter(0.05)
			audio.play("coin", 1.0 + randf() * 0.1, -6.0)
		else:
			score += 5 * _multiplier()
			_add_meter(0.02)
			audio.play("orb", 0.9, -8.0)


## Prism Overdrive runs free; otherwise fuel burns with distance.
func _burn_fuel(metres: float) -> void:
	if prism_left > 0.0 or _coast >= 0.0:
		return
	fuel = maxf(fuel - metres * FUEL_PER_METRE, 0.0)
	if fuel < LOW_FUEL and not _low_fuel_warned:
		_low_fuel_warned = true
		hud.hint("LOW FUEL!", Color(1.0, 0.55, 0.45))
		audio.play("warn")
		Settings.vibrate(0.3)
	if fuel <= 0.0:
		_coast = 0.0
		hud.hint("OUT OF FUEL!", Color(1.0, 0.55, 0.45))
		audio.play("sputter")


func _check_fuel() -> void:
	for pickup in track.fuels:
		if pickup.done:
			continue
		if pickup.s > distance + 0.5:
			break
		pickup.done = true
		if player.current_lane() != pickup.lane:
			continue
		track.collect_fuel(pickup)
		fuel = minf(fuel + FUEL_PICKUP, 1.0)
		if fuel > LOW_FUEL:
			_low_fuel_warned = false
		if _coast >= 0.0:
			_coast = -1.0
			hud.hint("SAVED!", Color(0.55, 1.0, 0.6))
		else:
			hud.hint("+FUEL", Color(0.55, 1.0, 0.6), 0.6)
		score += 15 * _multiplier()
		audio.play("fuel")
		Settings.vibrate(0.2)


func _add_meter(amount: float) -> void:
	if prism_left > 0.0:
		return
	var was := meter
	meter = minf(meter + amount, 1.0)
	if was < 1.0 and meter >= 1.0:
		hud.hint("PRISM READY!", UiKit.GOLD)
		audio.play("start", 1.6)


func _activate_prism() -> void:
	if state != State.PLAYING or prism_left > 0.0 or meter < 1.0:
		return
	prism_left = PRISM_DURATION
	player.rainbow = true
	audio.play("prism")
	hud.hint("PRISM OVERDRIVE!", UiKit.GOLD)
	cam.shake(0.4)
	Settings.vibrate(0.5)


func _tick_prism(delta: float) -> void:
	grace_left = maxf(grace_left - delta, 0.0)
	player.ghost = grace_left > 0.0
	if prism_left <= 0.0:
		return
	prism_left -= delta
	meter = maxf(prism_left / PRISM_DURATION, 0.0)
	if prism_left <= 0.0:
		prism_left = 0.0
		meter = 0.0
		player.rainbow = false
		player.set_color(player.color_idx)
		grace_left = GRACE_DURATION


# --- end of run, second chance, rewards --------------------------------------

func _crash(row: Dictionary) -> void:
	if dev_god:
		track.smash_cell(row, player.current_lane())
		return
	_crash_row = row
	distance = minf(distance, row.s - 0.9)
	player.transform = track.frame_at(distance)
	player.ghost = false
	player.tick(0.0)
	_end_run("CRASHED!", true)


func _end_run(title: String, explode: bool) -> void:
	state = State.DEAD
	_state_time = 0.0
	player.speed = 0.0
	_end_title = title
	hud.set_speed_fx(0.0)
	if explode:
		player.explode()
		audio.play("crash")
		cam.shake(1.0)
		Settings.vibrate(1.0)
		Engine.time_scale = 0.3
		await get_tree().create_timer(0.5, true, false, true).timeout
		Engine.time_scale = 1.0
	else:
		audio.play("sputter", 0.7)
		await get_tree().create_timer(0.4).timeout
	await get_tree().create_timer(RESULTS_DELAY * 0.5).timeout
	if state == State.DEAD:
		_show_results()


func _show_results() -> void:
	var travelled := int(distance - START_S)
	_run_shards = Economy.run_shards(orbs_collected, travelled) * Profile.shard_multiplier()
	var world_id: String = _themes[world_index].id
	var final := int(score)
	var can_revive := not _revive_used and Ads.rewarded_ready()
	ui.show_results({
		"title": _end_title,
		"score": final,
		"best": maxi(Profile.best(world_id), final),
		"new_best": final > Profile.best(world_id),
		"metres": travelled,
		"gates": gates,
		"combo": best_combo,
		"shards": _run_shards,
		"can_revive": can_revive,
		"can_double": _run_shards > 0 and Ads.rewarded_ready(),
	})
	# Without a second chance on offer, the run is over: save it straight away.
	if not can_revive:
		_record_run()


## Saves a finished run once: stats, best score and shards.
func _record_run() -> void:
	if _recorded or state != State.DEAD:
		return
	_recorded = true
	var travelled := distance - START_S
	Profile.add_shards(_run_shards)
	Profile.record_run(_themes[world_index].id, int(score), travelled, gates, orbs_collected, best_combo)


func _on_rewarded_finished(placement: StringName, granted: bool) -> void:
	if state != State.DEAD:
		return
	if not granted:
		ui.toast("No reward this time. Try again later.")
		return
	match placement:
		Ads.REVIVE:
			_revive()
		Ads.DOUBLE_SHARDS:
			var bonus := _run_shards
			_run_shards *= 2
			if _recorded:
				Profile.add_shards(bonus)
			ui.results.call("show_doubled", _run_shards)
			audio.play("unlock")


## Second chance: back on the road with a short shield and some fuel.
func _revive() -> void:
	_revive_used = true
	if not _crash_row.is_empty():
		track.smash_cell(_crash_row, player.current_lane())
	_crash_row = {}
	player.revive()
	fuel = maxf(fuel, REVIVE_FUEL)
	_coast = -1.0
	_low_fuel_warned = false
	grace_left = REVIVE_GRACE
	state = State.PLAYING
	_state_time = 1.2
	ui.show_hud()
	hud.hint("SECOND CHANCE!", Color(0.55, 1.0, 0.6))
	audio.play("revive")
	Settings.vibrate(0.5)


func _multiplier() -> int:
	return 1 + mini(floori(combo / 8.0), 9)


# --- controls ----------------------------------------------------------------

func _shift(direction: int) -> void:
	if player.shift(direction):
		audio.play("lane", 1.0, -4.0)


func _jump() -> void:
	if player.jump():
		audio.play("jump")


func _slam() -> void:
	if player.slam():
		audio.play("lane", 0.6)


func _set_color(index: int) -> void:
	if state != State.PLAYING or index == player.color_idx or prism_left > 0.0:
		return
	player.set_color(index)
	hud.set_color(index)
	audio.play("switch", [1.0, 1.25, 1.5][index])


func _on_landed() -> void:
	if state == State.PLAYING:
		audio.play("land", 1.0, -6.0)


## The track moved the world back towards the origin; move what lives outside it too.
func _on_track_rebased(offset: Vector3) -> void:
	cam.global_position -= offset
	player.shift_origin(offset)


## Swipes steer, jump and slam; a tap anywhere that isn't a button cycles the colour.
func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_swiped = ui.is_over_button(event.position)
		elif not _swiped and not ui.is_over_button(event.position):
			_set_color((player.color_idx + 1) % 3)
	elif event is InputEventScreenDrag and not _swiped:
		var d: Vector2 = event.position - _touch_start
		if d.length() < SWIPE_PX:
			return
		_swiped = true
		if absf(d.x) > absf(d.y):
			_shift(1 if d.x > 0.0 else -1)
		elif d.y < 0.0:
			_jump()
		else:
			_slam()


# --- developer hooks (used by scripts/dev/dev_harness.gd only) -------------

func dev_select_world(world_id: String) -> void:
	world_index = Themes.index_of(world_id)
	_apply_theme()
	_enter_menu()


func dev_start_run() -> void:
	if state == State.DEAD:
		_record_run()
		_new_run()
	if state != State.PLAYING:
		_start()


func dev_is_playing() -> bool:
	return state == State.PLAYING


## Soak-test god mode: a full tank and no crashes, so the run never ends.
func dev_keep_alive() -> void:
	fuel = 1.0
	dev_god = true


func dev_set_color(index: int) -> void:
	_set_color(index)


func dev_jump() -> void:
	_jump()


func dev_shift(direction: int) -> void:
	_shift(direction)


func dev_prism() -> void:
	_activate_prism()
