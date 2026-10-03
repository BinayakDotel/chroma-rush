extends Node3D
## Chroma Rush: game flow (home, run, pause, results), scoring, collisions, input, and the
## hooks into progression (shards, unlocks), ads (second chance, double shards) and settings.

const START_S := 12.0
const PRISM_SPEED_BOOST := 1.25
const GRACE_DURATION := 1.2
const REVIVE_GRACE := 2.0
const REVIVE_FUEL := 0.6
const RESULTS_DELAY := 0.9
const SWIPE_PX := 50.0
const MILESTONE := 500
const LOW_FUEL := 0.25
## Seconds of rolling to a stop on an empty tank; a pickup in that time still saves the run.
const COAST_TIME := 2.2
const HINT_DISTANCE := 38.0
## Chase-camera framing: metres behind and above the vehicle, where it looks, and its field of
## view at base speed (portrait keeps the horizontal FOV, see _frame_camera). Close and low so
## the vehicle and the next obstacles fill the screen; all three lanes stay in view.
const CAM_PORTRAIT := {"back": 8.0, "up": 4.3, "ahead": 16.0, "look_height": 0.0, "fov": 52.0}
const CAM_LANDSCAPE := {"back": 7.5, "up": 3.6, "ahead": 16.0, "look_height": 0.3, "fov": 52.0}
## Extra degrees of field of view at top speed, for a sense of speed without shrinking the road.
const CAM_FOV_GAIN := 10.0
## How quickly the camera catches up with a lane change (rad/s of the spring).
const CAM_LATERAL_RATE := 11.0

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

var state := State.MENU:
	set(value):
		state = value
		Portal.set_playing(state == State.PLAYING)
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
## Power gem effects (see Powers): a held shield, and seconds of magnet left.
var shield := false
var magnet_left := 0.0
var world_index := 0
## Counters for this run, for tuning and missions.
var run_stats := {}
## Set only by the developer harness: obstacles are smashed instead of ending the run.
var dev_god := false
## Dev harness: don't pause when the window loses focus.
var dev_keep_running := false

var _themes := Themes.all()
var _state_time := 0.0
## Seconds driven this run (pauses excluded).
var _run_time := 0.0
var _next_milestone := MILESTONE
var _menu_angle := 0.0
var _sky_yaw := 0.0
var _touch_start := Vector2.ZERO
var _swiped := false
var _sun_dir := Vector3(0.0, 0.5, -1.0)
var _coast := -1.0  # seconds spent rolling to a stop on an empty tank; -1 while fuelled
var _drop_cooldown := 0.0
## Seconds until the missions are next checked against this run's counters.
var _mission_check := 0.0
var _next_power_s := Powers.FIRST_AT
## Upgrade effects, read at the start of each run (see Economy.UPGRADES).
var _prism_duration := 5.0
var _magnet_duration := Powers.MAGNET_TIME
var _tank_bonus := 1.0
var _gem_luck := 1.0
var _low_fuel_warned := false
var _revive_used := false
var _recorded := true
var _run_shards := 0
var _end_title := ""
var _crash_row := {}
var _hints_shown := {}
var _first_run := false
var _probe: FrameProbe
## Camera's own lateral position, trailing the vehicle's so lane changes glide on screen.
var _cam_lateral := 0.0
var _cam_lateral_velocity := 0.0


func _ready() -> void:
	hud = ui.hud
	# No frame cap: V-Sync paces frames to the display. A cap below the refresh rate (60 FPS on a
	# 120 Hz ProMotion screen) is not aligned to vsync, so frames are held for uneven times and
	# motion judders.
	Engine.max_fps = 0
	if OS.is_debug_build() and OS.has_feature("mobile"):
		_probe = FrameProbe.new()
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
	ui.revive_token_requested.connect(_revive_with_token)
	ui.double_shards_requested.connect(func() -> void: Ads.show_rewarded(Ads.DOUBLE_SHARDS))
	ui.quit_requested.connect(_quit)
	world_index = Themes.index_of(Profile.selected_world)
	_apply_quality()
	_apply_theme()
	_enter_menu()


func _process(delta: float) -> void:
	if _probe:
		_probe.tick(delta)
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
			if state == State.PLAYING and not dev_keep_running:
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
	speed = Pacing.speed_at(distance)
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
	_drop_cooldown = 0.0
	run_stats = {"fuel_taken": 0, "fuel_missed": 0, "drops": 0, "powers": 0, "bonus_shards": 0,
		"hurdles": 0, "smashes": 0, "overdrives": 0}
	shield = false
	magnet_left = 0.0
	_next_power_s = Powers.FIRST_AT
	_run_time = 0.0
	_cam_lateral = 0.0
	_cam_lateral_velocity = 0.0
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
	# New players land straight in a run: the first run's tips teach as they drive, and How to
	# Play stays in Settings.
	_start()


## Starts driving on the freshly reset track (callers reset it first).
func _start() -> void:
	Profile.select_world(_themes[world_index].id)
	# Read upgrades here, not when the home screen resets the track: they may be bought there.
	_prism_duration = Profile.upgrade_value("overdrive")
	_magnet_duration = Profile.upgrade_value("magnet")
	_tank_bonus = Profile.upgrade_value("tank")
	_gem_luck = Profile.upgrade_value("luck")
	_first_run = Profile.lifetime_runs == 0
	Profile.mark_tutorial_done()
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
	player.set_look(theme.look)
	player.set_trail_style(theme.trail)
	player.set_color(player.color_idx)


## Graphics presets. Mobile builds use the Mobile renderer, which ignores SSAO anyway.
## Low has no real shadows (the vehicle and pickups keep their soft patches on the road) and
## no bloom; Medium draws one shadow map over a short range; High draws two over a long one.
func _apply_quality() -> void:
	var q := Settings.quality
	var env := world.environment
	# On the Compatibility renderer (web builds) a sun that casts shadows lights the scene far
	# too brightly and washes the road out to white, so it never casts them there.
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	sun.shadow_enabled = q >= Settings.Quality.MEDIUM and not compatibility
	if q == Settings.Quality.HIGH:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 90.0
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = 48.0
	env.ssao_enabled = q == Settings.Quality.HIGH
	env.glow_enabled = q >= Settings.Quality.MEDIUM
	var viewport := get_viewport()
	viewport.msaa_3d = Viewport.MSAA_DISABLED if q == Settings.Quality.LOW else Viewport.MSAA_2X
	var mobile := Defs.touch_device()
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
	_run_time += delta
	cam.frame_offset = cam.frame_offset.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	speed = Pacing.speed_at(distance) * (PRISM_SPEED_BOOST if prism_left > 0.0 else 1.0)
	if _coast >= 0.0:
		_coast += delta
		speed *= clampf(1.0 - _coast / COAST_TIME, 0.0, 1.0)
	distance += speed * delta
	_burn_fuel(delta)
	track.update(distance)
	player.transform = track.frame_at(distance)
	player.speed = speed
	player.tick(delta)
	_tick_prism(delta)
	magnet_left = maxf(magnet_left - delta, 0.0)
	player.shield = shield
	_check_orbs()
	_check_fuel()
	_check_powers()
	_maybe_drop_fuel(delta)
	_maybe_place_power()
	_check_rows()
	if state != State.PLAYING:
		return
	if _coast >= COAST_TIME:
		_end_run("OUT OF FUEL!", false)
		return
	if _first_run:
		_tutorial_hints()
	_mission_check -= delta
	if _mission_check <= 0.0:
		_mission_check = 0.25
		_check_missions()

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
	hud.set_powers(shield, magnet_left / _magnet_duration)
	hud.set_speed_fx(remap(speed, 26.0, Pacing.MAX_SPEED * PRISM_SPEED_BOOST, 0.0, 1.0))


func _update_camera(delta: float) -> void:
	var view: Dictionary = CAM_PORTRAIT if _is_portrait() else CAM_LANDSCAPE
	# The camera trails the vehicle sideways on a critically damped spring, so a lane change
	# glides across the screen instead of dragging the whole view with it.
	var stiffness := CAM_LATERAL_RATE * CAM_LATERAL_RATE
	_cam_lateral_velocity += ((player.lateral - _cam_lateral) * stiffness - _cam_lateral_velocity * 2.0 * CAM_LATERAL_RATE) * delta
	_cam_lateral += _cam_lateral_velocity * delta
	var behind := track.frame_at(distance - float(view.back))
	var eye: Vector3 = behind.origin + behind.basis.x * (_cam_lateral * 0.65) + behind.basis.y * (view.up + player.height * 0.35)
	var look := track.point(distance + float(view.ahead), _cam_lateral * 0.4, float(view.look_height) + player.height * 0.3)
	var target := Transform3D(Basis.IDENTITY, eye).looking_at(look, track.frame_at(distance).basis.y)
	# Glide from the menu orbit into the chase position, then lock on.
	var blend := clampf(_state_time / 1.2, 0.0, 1.0)
	cam.follow(target, delta, 10.0, 4.0, blend * blend)
	var fov: float = view.fov + remap(speed, Pacing.BASE_SPEED, Pacing.MAX_SPEED, 0.0, CAM_FOV_GAIN)
	if prism_left > 0.0:
		fov += 6.0
	_frame_camera(clampf(fov, 50.0, 95.0), delta)


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


## First run only: one tip the first time each kind of obstacle comes up, and one for the
## first fuel pickup, since an empty tank ends the run.
func _tutorial_hints() -> void:
	if not _hints_shown.has("fuel"):
		for pickup in track.fuels:
			if pickup.done:
				continue
			if pickup.s - distance <= HINT_DISTANCE:
				_hints_shown["fuel"] = true
				hud.hint("GRAB FUEL TO KEEP GOING!", _themes[world_index].fuel_color, 1.6)
				return
			break
	var row := track.next_row(distance)
	if row.is_empty() or row.s - distance > HINT_DISTANCE:
		return
	var touch := Defs.touch_device()
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
		track.retire_row(row)
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
		run_stats.smashes += 1
		score += 50 * _multiplier()
		audio.play("smash", randf_range(0.9, 1.2))
		player.sparkle(Color.WHITE, true)
		cam.shake(0.35)
		return
	if grace_left > 0.0:
		track.smash_cell(row, lane)
		return
	if cell == Defs.LOW:
		if player.height + Racer.HOVER > Track.LOW_SIZE.y:
			combo += 1
			best_combo = maxi(best_combo, combo)
			run_stats.hurdles += 1
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
	player.sparkle(player.display_color)
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
		# Magnet and Overdrive pull orbs in from every lane.
		var pulled := magnet_left > 0.0 or prism_left > 0.0
		if player.current_lane() != orb.lane and not pulled:
			track.drop(orb)
			continue
		track.collect_orb(orb)
		player.sparkle(Defs.COLORS[orb.color])
		if orb.color == player.color_idx or pulled:
			orbs_collected += 1
			if prism_left > 0.0:
				# Overdrive is the best time to collect: every orb is worth double shards.
				run_stats.bonus_shards += Economy.SHARDS_PER_ORB
			score += 20 * _multiplier()
			_add_meter(0.05)
			audio.play("coin", 1.0 + randf() * 0.1, -6.0)
		else:
			score += 5 * _multiplier()
			_add_meter(0.02)
			audio.play("orb", 0.9, -8.0)


## Prism Overdrive runs free; otherwise fuel burns with time (see Pacing.tank_time).
func _burn_fuel(seconds: float) -> void:
	if prism_left > 0.0 or _coast >= 0.0:
		return
	fuel = maxf(fuel - seconds / (Pacing.tank_time(distance) * _tank_bonus), 0.0)
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
			run_stats.fuel_missed += 1
			track.drop(pickup)
			continue
		run_stats.fuel_taken += 1
		track.collect_fuel(pickup)
		player.sparkle(_themes[world_index].fuel_color, true)
		fuel = minf(fuel + float(pickup.amount), 1.0)
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


## Last resort (see Pacing.DROP_*): the tank is nearly empty and no pickup can be reached
## before it runs dry, so a small fuel drop lands a few seconds ahead. It is announced, it is
## rare, it is limited per run, and it is not placed in the player's lane: a rescue to earn,
## not a free refill.
func _maybe_drop_fuel(delta: float) -> void:
	_drop_cooldown = maxf(_drop_cooldown - delta, 0.0)
	if fuel >= Pacing.DROP_BELOW or _drop_cooldown > 0.0 or prism_left > 0.0 or _coast >= COAST_TIME * 0.5:
		return
	if int(run_stats.drops) >= Pacing.DROP_LIMIT:
		return
	# How far the vehicle can still get: the fuel left, then half the coasting time (it slows
	# to a stop while coasting). The drop has to land well inside that.
	var full_speed := Pacing.speed_at(distance)
	var range_left := full_speed * (fuel * Pacing.tank_time(distance) * _tank_bonus + (COAST_TIME - maxf(_coast, 0.0)) * 0.5)
	for pickup in track.fuels:
		if not pickup.done and pickup.s > distance + 1.0 and pickup.s < distance + range_left * 0.9:
			return
	var near := distance + minf(full_speed * Pacing.DROP_AHEAD.x, range_left * 0.55)
	var far := distance + minf(full_speed * Pacing.DROP_AHEAD.y, range_left * 0.85)
	var lane := (player.lane + 1 + randi() % 2) % Defs.LANES
	if track.drop_fuel(near, far, lane, Pacing.DROP_FUEL):
		run_stats.drops += 1
		_drop_cooldown = Pacing.DROP_COOLDOWN
		hud.hint("FUEL DROP!", _themes[world_index].fuel_color, 1.2)
		audio.play("start", 0.8)


func _check_powers() -> void:
	for power in track.powers:
		if power.done:
			continue
		if power.s > distance + 0.5:
			break
		power.done = true
		if player.current_lane() != power.lane:
			track.drop(power)
			continue
		track.collect_power(power)
		_apply_power(power.kind)


func _apply_power(kind: Powers.Kind) -> void:
	var info := Powers.info(kind)
	run_stats.powers += 1
	var text: String = info.name + "!"
	match kind:
		Powers.Kind.SHIELD:
			shield = true
		Powers.Kind.MAGNET:
			magnet_left = _magnet_duration
		Powers.Kind.FULL_TANK:
			fuel = 1.0
			_low_fuel_warned = false
			_coast = -1.0
		Powers.Kind.PRISM:
			if prism_left > 0.0:
				prism_left = _prism_duration
			else:
				_add_meter(1.0)
		Powers.Kind.PHOENIX:
			text = "PHOENIX GEM!  +1 REVIVE" if Profile.add_revive_token() else "PHOENIX GEM!"
	hud.hint(text, info.color, 1.6)
	player.sparkle(info.color, true)
	audio.play("unlock", 1.2)
	cam.shake(0.2)
	Settings.vibrate(0.4)


## Every so often, a power gem a few seconds ahead. Which kind depends on what would help:
## fuel when low, no Prism Charge with the meter nearly full, no second shield.
func _maybe_place_power() -> void:
	if distance + speed * Powers.LEAD_TIME.x < _next_power_s:
		return
	var from := distance + speed * Powers.LEAD_TIME.x
	var to := distance + speed * Powers.LEAD_TIME.y
	if track.place_power(_pick_power(), from, to, player.lane):
		_next_power_s = to + randf_range(Powers.EVERY.x, Powers.EVERY.y) / _gem_luck
	else:
		_next_power_s += 20.0


func _pick_power() -> Powers.Kind:
	var weights := {}
	for kind: Powers.Kind in Powers.INFO:
		weights[kind] = float(Powers.info(kind).weight)
	if shield:
		weights[Powers.Kind.SHIELD] = 0.0
	if fuel < 0.5:
		weights[Powers.Kind.FULL_TANK] *= 1.6
	elif fuel > 0.8:
		weights[Powers.Kind.FULL_TANK] *= 0.3
	if meter > 0.6 or prism_left > 0.0:
		weights[Powers.Kind.PRISM] = 0.0
	weights[Powers.Kind.PHOENIX] *= _gem_luck
	if distance < Powers.PHOENIX_FROM or Profile.revive_tokens >= Profile.MAX_REVIVE_TOKENS:
		weights[Powers.Kind.PHOENIX] = 0.0
	var total := 0.0
	for w: float in weights.values():
		total += w
	var roll := randf() * total
	for kind: Powers.Kind in weights:
		roll -= weights[kind]
		if roll <= 0.0:
			return kind
	return Powers.Kind.MAGNET


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
	prism_left = _prism_duration
	run_stats.overdrives += 1
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
	meter = maxf(prism_left / _prism_duration, 0.0)
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
	if shield:
		# The shield takes the hit: smash through and carry on, with a moment's grace.
		shield = false
		player.shield = false
		track.smash_cell(row, player.current_lane())
		grace_left = GRACE_DURATION
		hud.hint("SHIELD SAVED YOU!", Powers.info(Powers.Kind.SHIELD).color)
		audio.play("smash")
		cam.shake(0.6)
		Settings.vibrate(0.7)
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


## This run's counters in the form Missions expects (see Missions.STATS).
func _mission_run() -> Dictionary:
	return {"gates": gates, "metres": int(distance - START_S), "orbs": orbs_collected, "hurdles": int(run_stats.hurdles),
		"fuel": int(run_stats.fuel_taken), "powers": int(run_stats.powers), "smashes": int(run_stats.smashes),
		"overdrives": int(run_stats.overdrives)}


## Pays and announces any mission this run has just completed.
func _check_missions() -> void:
	for mission in Missions.check(_mission_run()):
		hud.hint("MISSION COMPLETE!  +%d" % Missions.payout(mission), UiKit.GOLD, 1.8)
		audio.play("unlock", 1.1)
		Settings.vibrate(0.5)


func _show_results() -> void:
	var travelled := int(distance - START_S)
	_run_shards = (Economy.run_shards(orbs_collected, travelled) + int(run_stats.bonus_shards)) * Profile.shard_multiplier()
	var world_id: String = _themes[world_index].id
	var final := int(score)
	var can_revive := not _revive_used and Ads.rewarded_ready()
	var can_token := not _revive_used and Profile.revive_tokens > 0
	# Where the missions stand after this run, and what the shards are building towards.
	var run := _mission_run()
	Missions.check(run)
	var missions := Profile.missions.map(func(mission: Dictionary) -> Dictionary:
		return {"mission": mission.duplicate(), "value": Missions.progress(mission, run)})
	var goal := Profile.next_goal()
	if not goal.is_empty():
		goal.have = Profile.shards + _run_shards
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
		"revive_tokens": Profile.revive_tokens if can_token else 0,
		"can_double": _run_shards > 0 and Ads.rewarded_ready(),
		"missions": missions,
		"goal": goal,
	})
	# Without a second chance on offer, the run is over: save it straight away.
	if not can_revive and not can_token:
		_record_run()


## Saves a finished run once: stats, best score and shards.
func _record_run() -> void:
	if _recorded or state != State.DEAD:
		return
	_recorded = true
	var travelled := distance - START_S
	Profile.add_shards(_run_shards)
	Missions.finish_run(_mission_run())
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


## A banked Phoenix gem buys the second chance instead of an ad.
func _revive_with_token() -> void:
	if state == State.DEAD and not _revive_used and Profile.use_revive_token():
		_revive()


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


## Colour taps always count, even during Prism Overdrive (the vehicle stays rainbow until it
## ends): a tap for the next gate in the last moment of Overdrive must not be lost.
func _set_color(index: int) -> void:
	if state != State.PLAYING or index == player.color_idx:
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
