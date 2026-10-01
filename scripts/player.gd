class_name Racer
extends Node3D
## The player's vehicle and driver. The game places this node on the track each frame; the
## body inside it is offset for lane position and jumps. Painted panels show the current gate
## colour.
##
## Everything the vehicle does is driven by springs, so nothing snaps: it glides to a new lane,
## leans into the move and settles; it squashes on landing and pops when the colour changes.
## The wheels stay flat on the road while the body above them leans and bounces (see Vehicles
## for the parts). A soft shadow and a glow in the current colour sit on the road underneath.

signal landed

const SIZE := 0.9
const HOVER := 0.15
## How fast the vehicle moves to a new lane (rad/s of a critically damped spring). It is over
## the lane line in about 0.05 s and settled in under 0.2 s, with no jolt at either end.
const LANE_RATE := 34.0
const GRAVITY := 34.0
const JUMP_SPEED := 11.0
const SLAM_SPEED := 24.0
const AIR_TIME := 2.0 * JUMP_SPEED / GRAVITY
## Lean and steering for sideways speed (radians per m/s), and their limits.
const ROLL_PER_SPEED := 0.03
const MAX_ROLL := 0.3
const YAW_PER_SPEED := 0.014
const WOBBLE_STIFFNESS := 90.0
const WOBBLE_DAMPING := 9.0

var lane := 1
var lateral := 0.0
var height := 0.0
var color_idx := 0
## Cycles through hues while Prism Overdrive is active.
var rainbow := false
## Fades the vehicle in and out during post-Prism or post-revive invulnerability.
var ghost := false
## Shows a bubble around the vehicle while a Shield gem is held.
var shield := false
var display_color := Color.WHITE
## Forward speed in m/s, used for wheels, flames and the trail.
var speed := 0.0

var _vy := 0.0
var _air := 0.0
var _t := 0.0
var _lateral_velocity := 0.0
var _last_lateral_velocity := 0.0
var _roll := Spring.new(3.2, 0.6)
var _heave := Spring.new(3.6, 0.45)
var _pitch := Spring.new(3.0, 0.5)
var _punch := Spring.new(6.0, 0.45)
var _squash := Spring.new(5.0, 0.42)
var _body := Node3D.new()
var _model: Node3D
var _chassis: Node3D
var _meshes: Array = []
var _wheels: Array = []
var _steer: Array = []
var _flames: Array = []
var _head: Node3D
## Per floppy part: {node, rest (Vector3), angle (Vector2), velocity (Vector2)}.
var _wobblers: Array[Dictionary] = []
var _hover := HOVER
var _bob := 0.0
var _trail := GPUParticles3D.new()
var _trail_process := ParticleProcessMaterial.new()
var _trail_material := StandardMaterial3D.new()
var _trail_enabled := true
var _paint := Look.soft({}, {"gloss": 1.0, "rim": 0.45})
var _detail := Look.soft({}, {"rim": 0.3})
var _glow := Look.glowing(1.5)
var _glass := Look.glass()
var _debris: Array[Dictionary] = []
var _debris_mesh: ArrayMesh
var _bubble := MeshInstance3D.new()
var _shadow := MeshInstance3D.new()
var _underglow := MeshInstance3D.new()
var _ghosted := false


func _ready() -> void:
	add_child(_body)
	_setup_ground()
	_setup_bubble()
	_setup_trail()
	set_model("kart")
	reset()


## Swaps in the vehicle for a theme ("kart", "sled", "buggy", "monster" or "rocket").
func set_model(kind: String) -> void:
	if _model:
		_model.queue_free()
	_model = Vehicles.build(kind, {"paint": _paint, "detail": _detail, "glow": _glow, "glass": _glass})
	_body.add_child(_model)
	_chassis = _model.get_meta("chassis")
	_meshes = _model.get_meta("meshes")
	_wheels = _model.get_meta("wheels")
	_steer = _model.get_meta("steer")
	_flames = _model.get_meta("flames")
	_head = _model.get_meta("head")
	_wobblers.clear()
	for node: Node3D in _model.get_meta("wobblers"):
		_wobblers.append({"node": node, "rest": node.rotation, "angle": Vector2.ZERO, "velocity": Vector2.ZERO})
	_hover = HOVER + float(_model.get_meta("hover"))
	_bob = float(_model.get_meta("bob"))
	_trail.position = _model.get_meta("trail")
	_ghosted = false


## The world's rim light on the vehicle (a theme's `look`, see Themes).
func set_look(look: Dictionary) -> void:
	for material: ShaderMaterial in [_paint, _detail]:
		material.set_shader_parameter("rim_color", look.get("rim_color", Color.WHITE))


## Colour, size and drift of the trail particles for a theme (see Themes `trail`).
func set_trail_style(style: Dictionary) -> void:
	var color: Color = style.color
	_trail_process.color = color
	_trail_process.gravity = Vector3(0, style.gravity, 0)
	_trail_process.scale_min = style.size * 2.2
	_trail_process.scale_max = style.size * 4.0
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if style.glow else BaseMaterial3D.BLEND_MODE_MIX
	_trail_material.albedo_color = Color(1.5, 1.5, 1.5) if style.glow else Color.WHITE


func set_trail_enabled(enabled: bool) -> void:
	_trail_enabled = enabled
	_trail.emitting = enabled and speed > 1.0


func _process(delta: float) -> void:
	_update_debris(delta)


func reset() -> void:
	_clear_debris()
	lane = 1
	lateral = 0.0
	_lateral_velocity = 0.0
	_last_lateral_velocity = 0.0
	height = 0.0
	_vy = 0.0
	rainbow = false
	ghost = false
	for spring: Spring in [_roll, _heave, _pitch, _punch, _squash]:
		spring.reset()
	_body.visible = true
	_body.position = Vector3(0.0, SIZE * 0.5 + _hover, 0.0)
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3.ONE
	_shadow.visible = true
	_underglow.visible = true
	set_color(0)
	_punch.reset()
	_trail.restart()


## Brings the vehicle back after a crash (second chance), keeping its lane.
func revive() -> void:
	_clear_debris()
	height = 0.0
	_vy = 0.0
	_body.visible = true
	_shadow.visible = true
	_underglow.visible = true
	_body.rotation = Vector3.ZERO
	# Pop back in: start small and let the spring bring it up to size.
	_punch.value = -0.7
	_punch.velocity = 0.0
	_trail.restart()


func tick(delta: float) -> void:
	_t += delta
	_move_sideways(delta)
	var lateral_accel := (_lateral_velocity - _last_lateral_velocity) / maxf(delta, 0.0001)
	_last_lateral_velocity = _lateral_velocity
	var vertical_accel := 0.0
	if height > 0.0:
		_vy -= GRAVITY * delta
		height += _vy * delta
		_air += delta
		vertical_accel = -GRAVITY
		if height <= 0.0:
			height = 0.0
			_vy = 0.0
			_squash.velocity += 8.0
			_heave.velocity -= 1.4
			_pitch.velocity += 2.0
			vertical_accel = 60.0
			landed.emit()

	# Lean into the lane change and point the nose that way; both ease in and out.
	var roll := _roll.step(clampf(-_lateral_velocity * ROLL_PER_SPEED, -MAX_ROLL, MAX_ROLL), delta)
	var yaw := clampf(-_lateral_velocity * YAW_PER_SPEED, -0.2, 0.2)
	var flip := -TAU * smoothstep(0.0, 1.0, clampf(_air / AIR_TIME, 0.0, 1.0)) if height > 0.0 else 0.0
	var moving := clampf(speed / 20.0, 0.0, 1.0)
	# Hovering vehicles float gently; wheeled ones only breathe a little on their springs.
	var float_y := sin(_t * 2.4) * _bob
	var idle := (sin(_t * 5.0) * 0.004 + sin(_t * 8.1) * 0.0025) * moving
	_body.position = Vector3(lateral, SIZE * 0.5 + _hover + float_y + height, 0.0)
	_body.rotation = Vector3(flip, yaw, 0.0)
	var squash := _squash.step(0.0, delta)
	var punch := 1.0 + _punch.step(0.0, delta)
	_body.scale = Vector3(1.0 + squash * 0.5, maxf(1.0 - squash, 0.3), 1.0 + squash * 0.5) * maxf(punch, 0.05)
	_chassis.position.y = _heave.step(0.0, delta) + idle
	_chassis.rotation = Vector3(_pitch.step(0.0, delta), 0.0, roll)
	_fade_for_ghost()
	_bubble.visible = shield and _body.visible
	if _bubble.visible:
		_bubble.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 6.0))
	_update_ground()

	for wheel: Node3D in _wheels:
		wheel.rotation.x -= speed * delta / float(wheel.get_meta("radius", 0.28))
	var steer := clampf(roll * 1.4, -0.45, 0.45)
	for pivot: Node3D in _steer:
		pivot.rotation.y = steer
	if _head:
		# The driver looks into the move and nods slowly with the road.
		_head.rotation = Vector3(sin(_t * 2.3) * 0.025 * moving, roll * 0.9, -roll * 0.35)
	var power := clampf(speed / 16.0, 0.25, 1.6)
	for flame: Node3D in _flames:
		flame.scale = Vector3(1.0, 1.0, power * (1.0 + 0.14 * sin(_t * 23.0) + 0.08 * sin(_t * 37.0)))
	_update_wobblers(delta, lateral_accel, vertical_accel)
	_trail.emitting = _trail_enabled and speed > 1.0 and height <= 0.05 and _body.visible
	_trail.amount_ratio = clampf(speed / Pacing.MAX_SPEED, 0.2, 1.0)
	if rainbow:
		_apply_color(Color.from_hsv(fmod(_t * 1.2, 1.0), 0.6, 1.0))


func current_lane() -> int:
	return clampi(roundi(lateral / Defs.LANE_WIDTH) + 1, 0, Defs.LANES - 1)


func body_position() -> Vector3:
	return _body.global_position


func shift(direction: int) -> bool:
	var next := clampi(lane + direction, 0, Defs.LANES - 1)
	if next == lane:
		return false
	lane = next
	return true


func jump() -> bool:
	if height > 0.0:
		return false
	_vy = JUMP_SPEED
	_air = 0.0
	height = 0.001
	# Stretch upwards as it leaves the ground.
	_squash.velocity -= 5.0
	return true


func slam() -> bool:
	if height <= 0.0:
		return false
	_vy = -SLAM_SPEED
	return true


func set_color(i: int) -> void:
	color_idx = i
	_apply_color(Defs.COLORS[i])
	_punch.velocity += 5.5


## Keeps world-space effects in place when the track shifts the world origin.
func shift_origin(offset: Vector3) -> void:
	for piece in _debris:
		var node: Node3D = piece.node
		node.global_position -= offset
		var ground: Transform3D = piece.ground
		piece.ground = Transform3D(ground.basis, ground.origin - offset)
	_trail.restart()


## Shatters the vehicle into fragments that bounce on the road.
func explode() -> void:
	_body.visible = false
	_shadow.visible = false
	_underglow.visible = false
	_trail.emitting = false
	var basis := global_transform.basis
	var origin := _body.global_position
	if _debris_mesh == null:
		var kit := MeshKit.new(3, true)
		kit.rounded_box(Vector3.ZERO, Vector3.ONE * 0.26, 0.06, Color.WHITE)
		_debris_mesh = kit.commit(null)
	var paint_piece := Look.soft({}, {"tint": display_color, "gloss": 1.0, "rim": 0.4})
	var dark_piece := Look.soft({}, {"tint": Vehicles.DARK, "rim": 0.3})
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell := Vector3(x, y, z)
				var piece := MeshInstance3D.new()
				piece.mesh = _debris_mesh
				piece.material_override = dark_piece if (x + y + z) % 3 == 0 else paint_piece
				piece.top_level = true
				add_child(piece)
				piece.global_position = origin + basis * (cell * 0.3)
				var local_vel := cell * 5.0 + Vector3(randf_range(-2, 2), randf_range(3, 7), randf_range(-4, 2))
				_debris.append({
					"node": piece,
					"vel": basis * local_vel,
					"spin": Vector3(randf_range(-12, 12), randf_range(-12, 12), randf_range(-12, 12)),
					"ground": global_transform,
					"life": 0.0,
				})


## Glides `lateral` towards the current lane (critically damped, so it never overshoots).
func _move_sideways(delta: float) -> void:
	var target := Defs.lane_x(lane)
	var x := LANE_RATE * delta
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var offset := lateral - target
	var step := (_lateral_velocity + LANE_RATE * offset) * delta
	_lateral_velocity = (_lateral_velocity - LANE_RATE * step) * decay
	lateral = target + (offset + step) * decay


func _apply_color(c: Color) -> void:
	display_color = c
	_paint.set_shader_parameter("tint", c)
	_underglow.set_instance_shader_parameter("shade", Color(c.r, c.g, c.b, 0.34))


## Invulnerable: the whole vehicle pulses between solid and see-through (no hard blinking).
func _fade_for_ghost() -> void:
	if not ghost and not _ghosted:
		return
	_ghosted = ghost
	var see_through := 0.5 + 0.3 * sin(_t * 11.0) if ghost else 0.0
	for mi: MeshInstance3D in _meshes:
		mi.transparency = see_through


## The shadow and the colour glow stay on the road under the vehicle, shrinking as it jumps.
func _update_ground() -> void:
	var lift := 1.0 / (1.0 + height * 0.7)
	_shadow.position = Vector3(lateral, 0.0, 0.1)
	_shadow.scale = Vector3(lift, 1.0, lift * 1.25)
	_underglow.position = Vector3(lateral, 0.0, 0.0)
	_underglow.scale = Vector3(lift, 1.0, lift * 1.2)


## Spring-driven floppy parts: they swing against lane changes, bounce on jumps and landings,
## and sway a little in the wind at speed.
func _update_wobblers(delta: float, lateral_accel: float, vertical_accel: float) -> void:
	var wind := (sin(_t * 5.3) * 0.05 + sin(_t * 3.1) * 0.03) * clampf(speed / Pacing.MAX_SPEED, 0.0, 1.0)
	var drive := Vector2(clampf(vertical_accel * 0.006, -0.5, 0.5) + wind, clampf(lateral_accel * 0.0012, -0.6, 0.6))
	var dt := minf(delta, 0.033)
	for w in _wobblers:
		var angle: Vector2 = w.angle
		var velocity: Vector2 = w.velocity
		var force := (drive - angle) * WOBBLE_STIFFNESS - velocity * WOBBLE_DAMPING
		velocity += force * dt
		angle += velocity * dt
		w.angle = angle
		w.velocity = velocity
		var rest: Vector3 = w.rest
		(w.node as Node3D).rotation = rest + Vector3(angle.x, 0.0, angle.y)


## A soft dark patch and a wider glow in the paint colour, flat on the road under the vehicle.
func _setup_ground() -> void:
	_underglow.mesh = Look.patch(3.0, 0.025, Look.blob())
	_shadow.mesh = Look.patch(2.3, 0.035, Look.blob())
	_shadow.set_instance_shader_parameter("shade", Color(0.05, 0.04, 0.12, 0.42))
	for patch: MeshInstance3D in [_underglow, _shadow]:
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)


## A soft glassy bubble: see-through in the middle, glowing at the rim.
func _setup_bubble() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.25
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bubble.gdshader")
	sphere.material = material
	_bubble.mesh = sphere
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubble.position = Vector3(0.0, 0.35, 0.0)
	_bubble.visible = false
	_body.add_child(_bubble)


## Soft round puffs (dust, snow, sparks) streaming from behind the vehicle.
func _setup_trail() -> void:
	var puff := QuadMesh.new()
	puff.size = Vector2.ONE
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_trail_material.billboard_keep_scale = true
	_trail_material.albedo_texture = Look.soft_dot()
	puff.material = _trail_material
	_trail_process.direction = Vector3(0, 0.5, 1)
	_trail_process.spread = 30.0
	_trail_process.initial_velocity_min = 1.5
	_trail_process.initial_velocity_max = 3.5
	_trail_process.damping_min = 2.0
	_trail_process.damping_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_trail_process.color_ramp = ramp
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.5))
	grow.add_point(Vector2(1, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	_trail_process.scale_curve = grow_tex
	_trail.process_material = _trail_process
	_trail.draw_pass_1 = puff
	_trail.amount = 28
	_trail.lifetime = 0.7
	_trail.local_coords = false
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.visibility_aabb = AABB(Vector3(-4, -2, -2), Vector3(8, 6, 12))
	_body.add_child(_trail)
	set_trail_style({"color": Color(0.8, 0.7, 0.5, 0.8), "size": 0.15, "gravity": -3.0, "glow": false})


func _clear_debris() -> void:
	for piece in _debris:
		(piece.node as Node).queue_free()
	_debris.clear()


func _update_debris(delta: float) -> void:
	for piece in _debris:
		var node: MeshInstance3D = piece.node
		var ground: Transform3D = piece.ground
		var up := ground.basis.y
		piece.life += delta
		piece.vel -= up * 22.0 * delta
		node.global_position += piece.vel * delta
		node.rotation += piece.spin * delta
		# Bounce off the (locally flat) road surface.
		var above: float = (node.global_position - ground.origin).dot(up)
		if above < 0.13:
			node.global_position += up * (0.13 - above)
			var vel: Vector3 = piece.vel
			var into := vel.dot(up)
			if into < 0.0:
				piece.vel = (vel - up * into * 1.45) * 0.8
				piece.spin *= 0.7
		if piece.life > 1.5:
			node.scale = Vector3.ONE * maxf(1.0 - (piece.life - 1.5), 0.01)


## A value on a spring: it chases a target and can be kicked by adding to `velocity`.
class Spring:
	var value := 0.0
	var velocity := 0.0
	var _stiffness: float
	var _damping: float

	## `frequency` in Hz; `damping` 1 settles without overshoot, lower values bounce.
	func _init(frequency: float, damping: float) -> void:
		var omega := TAU * frequency
		_stiffness = omega * omega
		_damping = 2.0 * damping * omega

	func reset() -> void:
		value = 0.0
		velocity = 0.0

	func step(target: float, delta: float) -> float:
		# Small fixed steps keep it stable when a frame runs long.
		var steps := clampi(ceili(delta / 0.008), 1, 8)
		var dt := minf(delta, 0.064) / steps
		for i in steps:
			velocity += ((target - value) * _stiffness - velocity * _damping) * dt
			value += velocity * dt
		return value
