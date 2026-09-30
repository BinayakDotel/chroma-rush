extends Node3D
## Chroma Rush: run loop, scoring, collisions, input and game states.

const SAVE_PATH := "user://chroma_rush.cfg"
const START_S := 12.0
const PRISM_DURATION := 5.0
const PRISM_SPEED_BOOST := 1.35
const GRACE_DURATION := 1.2
const RESTART_DELAY := 0.8
const SWIPE_PX := 60.0
const MILESTONE := 500
const FUEL_PER_METRE := 1.0 / 420.0
const FUEL_PICKUP := 0.4
const LOW_FUEL := 0.25
const COAST_TIME := 1.6

enum State { MENU, PLAYING, DEAD }

@onready var track: Track = $Track
@onready var player: Racer = $Player
@onready var cam: ChaseCamera = $Camera
@onready var hud: Hud = $HUD
@onready var audio: Sfx = $Audio
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $Sun

var state := State.MENU
var distance := START_S
var speed := 0.0
var score := 0.0
var combo := 0
var meter := 0.0
var prism_left := 0.0
var grace_left := 0.0
var fuel := 1.0
var best := 0
var theme_index := 0

var _state_time := 0.0
var _next_milestone := MILESTONE
var _menu_angle := 0.0
var _sky_yaw := 0.0
var _touch_start := Vector2.ZERO
var _swiped := false
var _themes := Themes.all()
var _sun_dir := Vector3(0.0, 0.5, -1.0)
var _coast := -1.0  # seconds spent rolling to a stop on an empty tank; -1 while fuelled
var _low_fuel_warned := false
## Set only by the developer harness: obstacles are smashed instead of ending the run.
var dev_god := false


func _ready() -> void:
	_load_save()
	hud.prism_pressed.connect(_activate_prism)
	hud.theme_step.connect(_change_theme)
	player.landed.connect(_on_landed)
	track.rebased.connect(_on_track_rebased)
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
		return
	if state != State.PLAYING:
		if event.is_action_pressed("start") and _can_start():
			_start()
		elif event.is_action_pressed("theme_next") and _can_start():
			_change_theme(1)
		return
	if event.is_action_pressed("move_left"):
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


func _new_run() -> void:
	track.reset(randi())
	distance = START_S
	speed = Defs.speed_at(distance)
	score = 0.0
	combo = 0
	meter = 0.0
	prism_left = 0.0
	grace_left = 0.0
	fuel = 1.0
	_coast = -1.0
	_low_fuel_warned = false
	_next_milestone = MILESTONE
	player.reset()
	player.transform = track.frame_at(distance)
	hud.set_color(0)
	hud.set_score(0.0, 1)
	hud.set_distance(0, speed)
	hud.set_meter(0.0, false, false)
	hud.set_fuel(fuel)


func _enter_menu() -> void:
	_new_run()
	state = State.MENU
	_state_time = 0.0
	hud.show_menu(best)
	var frame := track.frame_at(distance)
	cam.global_transform = Transform3D(Basis.IDENTITY, frame * Vector3(0.0, 2.2, 6.0)).looking_at(frame.origin, frame.basis.y)
	_menu_angle = 0.0


## Themes are chosen from the title and game-over screens, never mid-run.
func _change_theme(step: int) -> void:
	if state == State.PLAYING:
		return
	theme_index = posmod(theme_index + step, _themes.size())
	_save()
	_apply_theme()
	_enter_menu()


func _apply_theme() -> void:
	var theme: Dictionary = _themes[theme_index]
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
	hud.set_palette(Defs.COLORS)
	track.set_theme(theme)
	track.set_symbols_visible(Settings.color_symbols)
	player.set_model(theme.player)
	player.set_trail_style(theme.trail)
	player.set_color(player.color_idx)
	hud.set_theme_name(theme.name)


func _start() -> void:
	if state == State.DEAD:
		_new_run()
	state = State.PLAYING
	_state_time = 0.0
	hud.show_playing()
	hud.popup("GO!")
	audio.play("start")


func _can_start() -> bool:
	return state == State.MENU or (state == State.DEAD and _state_time > RESTART_DELAY)


func _menu_tick(delta: float) -> void:
	_menu_angle += delta * 0.35
	var frame := track.frame_at(distance)
	player.transform = frame
	player.speed = 0.0
	player.tick(delta)
	var center := player.body_position()
	var offset := frame.basis * Vector3(sin(_menu_angle) * 6.0, 2.0 + sin(_menu_angle * 0.7) * 0.8, cos(_menu_angle) * 6.0)
	cam.follow(Transform3D(Basis.IDENTITY, center + offset).looking_at(center, frame.basis.y), delta, 5.0, 5.0)


func _play_tick(delta: float) -> void:
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
		_end_run("OUT OF FUEL", false)
		return

	score += speed * delta * 0.5 * _multiplier()
	var travelled := int(distance - START_S)
	if travelled >= _next_milestone:
		hud.popup("%d m" % _next_milestone)
		audio.play("start", 1.3)
		_next_milestone += MILESTONE
	_update_camera(delta)
	hud.set_score(score, _multiplier())
	hud.set_distance(travelled, speed)
	hud.set_meter(meter, meter >= 1.0, prism_left > 0.0)
	hud.set_fuel(fuel)


func _update_camera(delta: float) -> void:
	var behind := track.frame_at(distance - 6.5)
	var eye := behind.origin + behind.basis.x * (player.lateral * 0.6) + behind.basis.y * (3.0 + player.height * 0.35)
	var look := track.point(distance + 9.0, player.lateral * 0.35, 0.8 + player.height * 0.3)
	var target := Transform3D(Basis.IDENTITY, eye).looking_at(look, track.frame_at(distance).basis.y)
	# Glide from the menu orbit into the chase position, then lock on.
	var blend := clampf(_state_time / 1.2, 0.0, 1.0)
	cam.follow(target, delta, 10.0, 4.0, blend * blend)
	var fov := remap(speed, Defs.BASE_SPEED, Defs.MAX_SPEED, 70.0, 88.0)
	if prism_left > 0.0:
		fov += 8.0
	cam.ease_fov(clampf(fov, 60.0, 100.0), delta)


func _update_sky(delta: float) -> void:
	# Keep the synthwave sun roughly ahead, drifting sideways through turns.
	var fwd := -cam.global_transform.basis.z
	var yaw := atan2(-fwd.x, -fwd.z)
	_sky_yaw = lerp_angle(_sky_yaw, yaw, 1.0 - exp(-1.5 * delta))
	world.environment.sky_rotation = Vector3(0.0, _sky_yaw, 0.0)
	# The sunlight follows the sun drawn in the rotated sky.
	var sun_world := Basis(Vector3.UP, _sky_yaw) * _sun_dir
	sun.global_transform.basis = Basis.looking_at(-sun_world)


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
	score += 25 * _multiplier()
	track.pass_cell(row, lane)
	audio.play("gate", 1.0 + minf(combo, 24) * 0.025)
	_add_meter(0.12)
	if combo % 8 == 0:
		hud.popup("COMBO x%d" % _multiplier(), player.display_color)


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
			score += 20 * _multiplier()
			_add_meter(0.05)
			audio.play("orb", 1.2, -4.0)
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
		hud.popup("LOW FUEL!", Color(1.0, 0.45, 0.35))
		audio.play("warn")
	if fuel <= 0.0:
		_coast = 0.0
		hud.popup("OUT OF FUEL!", Color(1.0, 0.45, 0.35))
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
			hud.popup("SAVED!", Color(0.5, 1.0, 0.6))
		else:
			hud.popup("+FUEL", Color(0.5, 1.0, 0.6))
		score += 15 * _multiplier()
		audio.play("fuel")


func _add_meter(amount: float) -> void:
	if prism_left > 0.0:
		return
	var was := meter
	meter = minf(meter + amount, 1.0)
	if was < 1.0 and meter >= 1.0:
		hud.popup("PRISM READY!")
		audio.play("start", 1.6)


func _activate_prism() -> void:
	if state != State.PLAYING or prism_left > 0.0 or meter < 1.0:
		return
	prism_left = PRISM_DURATION
	player.rainbow = true
	audio.play("prism")
	hud.popup("PRISM OVERDRIVE!")
	cam.shake(0.4)


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


func _crash(row: Dictionary) -> void:
	if dev_god:
		track.smash_cell(row, player.current_lane())
		return
	distance = minf(distance, row.s - 0.9)
	player.transform = track.frame_at(distance)
	player.ghost = false
	player.tick(0.0)
	_end_run("CRASHED", true)


func _end_run(title: String, explode: bool) -> void:
	state = State.DEAD
	_state_time = 0.0
	player.speed = 0.0
	var final := int(score)
	var new_best := final > best
	if new_best:
		best = final
		_save()
	if explode:
		player.explode()
		audio.play("crash")
		cam.shake(1.0)
		Engine.time_scale = 0.3
		await get_tree().create_timer(0.5, true, false, true).timeout
		Engine.time_scale = 1.0
	else:
		audio.play("sputter", 0.7)
		await get_tree().create_timer(0.4).timeout
	hud.show_game_over(final, best, new_best, title)


func _multiplier() -> int:
	return 1 + mini(floori(combo / 8.0), 9)


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
	if index == player.color_idx or prism_left > 0.0:
		return
	player.set_color(index)
	hud.set_color(index)
	audio.play("switch", [1.0, 1.25, 1.5][index])


## The track moved the world back towards the origin; move what lives outside it too.
func _on_track_rebased(offset: Vector3) -> void:
	cam.global_position -= offset
	player.shift_origin(offset)


func _on_landed() -> void:
	if state == State.PLAYING:
		audio.play("land", 1.0, -6.0)


func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
			_swiped = false
		elif not _swiped and not hud.is_over_button(event.position):
			if state != State.PLAYING:
				if _can_start():
					_start()
			else:
				_set_color((player.color_idx + 1) % 3)
	elif event is InputEventScreenDrag and not _swiped and state == State.PLAYING:
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


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	best = int(cfg.get_value("score", "best", 0))
	theme_index = clampi(int(cfg.get_value("settings", "theme", 0)), 0, _themes.size() - 1)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("score", "best", best)
	cfg.set_value("settings", "theme", theme_index)
	cfg.save(SAVE_PATH)


# --- developer hooks (used by scripts/dev/dev_harness.gd only) -------------

func dev_select_world(world_id: String) -> void:
	theme_index = Themes.index_of(world_id)
	_apply_theme()
	_enter_menu()


func dev_start_run() -> void:
	if state == State.DEAD:
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
