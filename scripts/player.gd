class_name Racer
extends Node3D
## The player's vehicle and driver. The game places this node on the track each frame; the
## body inside it is offset for lane position and jumps. Painted panels show the current gate
## colour. Parts listed by Vehicles (wheels, steering, head, floppy bits, flames) are animated
## here, and a themed trail of particles streams from behind.

signal landed

const SIZE := 0.9
const HOVER := 0.15
## Seconds a lane change takes. It eases out: quick off the mark (the vehicle is over the lane
## line in about a fifth of this), then settles gently instead of stopping dead.
const LANE_TIME := 0.18
const GRAVITY := 34.0
const JUMP_SPEED := 11.0
const SLAM_SPEED := 24.0
const AIR_TIME := 2.0 * JUMP_SPEED / GRAVITY
const WOBBLE_STIFFNESS := 90.0
const WOBBLE_DAMPING := 9.0

var lane := 1
var lateral := 0.0
var height := 0.0
var color_idx := 0
## Cycles through hues while Prism Overdrive is active.
var rainbow := false
## Blinks the vehicle during post-Prism or post-revive invulnerability.
var ghost := false
var display_color := Color.WHITE
## Forward speed in m/s, used for wheels, flames and the trail.
var speed := 0.0

var _vy := 0.0
var _air := 0.0
var _t := 0.0
var _last_lateral := 0.0
var _lateral_velocity := 0.0
var _lane_from := 0.0
var _lane_t := 1.0
var _body := Node3D.new()
var _model: Node3D
var _wheels: Array = []
var _steer: Array = []
var _flames: Array = []
var _head: Node3D
## Per floppy part: {node, rest (Vector3), angle (Vector2), velocity (Vector2)}.
var _wobblers: Array[Dictionary] = []
var _hover := HOVER
var _bob := 0.015
var _trail := GPUParticles3D.new()
var _trail_process := ParticleProcessMaterial.new()
var _trail_material := StandardMaterial3D.new()
var _trail_enabled := true
var _paint := StandardMaterial3D.new()
var _detail := StandardMaterial3D.new()
var _glow := StandardMaterial3D.new()
var _glass := StandardMaterial3D.new()
var _debris: Array[Dictionary] = []


func _ready() -> void:
	_paint.vertex_color_use_as_albedo = true
	_paint.roughness = 0.35
	_paint.metallic_specular = 0.6
	_detail.vertex_color_use_as_albedo = true
	_detail.roughness = 0.6
	_glow.vertex_color_use_as_albedo = true
	_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow.albedo_color = Color(1.4, 1.4, 1.4)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = Color(0.8, 0.94, 1.0, 0.22)
	_glass.roughness = 0.05
	_glass.metallic_specular = 1.0
	_glass.rim_enabled = true
	_glass.rim = 0.8
	_glass.rim_tint = 0.3
	add_child(_body)
	_setup_trail()
	set_model("kart")
	reset()


## Swaps in the vehicle for a theme ("kart", "sled", "buggy", "monster" or "rocket").
func set_model(kind: String) -> void:
	if _model:
		_model.queue_free()
	_model = Vehicles.build(kind, {"paint": _paint, "detail": _detail, "glow": _glow, "glass": _glass})
	_body.add_child(_model)
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


## Colour, size and drift of the trail particles for a theme (see Themes `trail`).
func set_trail_style(style: Dictionary) -> void:
	var color: Color = style.color
	_trail_process.color = color
	_trail_process.gravity = Vector3(0, style.gravity, 0)
	_trail_process.scale_min = style.size * 0.7
	_trail_process.scale_max = style.size * 1.3
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if style.glow else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_trail_material.albedo_color = Color(1.6, 1.6, 1.6) if style.glow else Color.WHITE


func set_trail_enabled(enabled: bool) -> void:
	_trail_enabled = enabled
	_trail.emitting = enabled and speed > 1.0


func _process(delta: float) -> void:
	_update_debris(delta)


func reset() -> void:
	_clear_debris()
	lane = 1
	lateral = 0.0
	_last_lateral = 0.0
	_lane_from = 0.0
	_lane_t = 1.0
	height = 0.0
	_vy = 0.0
	rainbow = false
	ghost = false
	_body.visible = true
	_body.position = Vector3(0.0, SIZE * 0.5 + _hover, 0.0)
	_body.rotation = Vector3.ZERO
	set_color(0)
	_body.scale = Vector3.ONE
	_trail.restart()


## Brings the vehicle back after a crash (second chance), keeping its lane.
func revive() -> void:
	_clear_debris()
	height = 0.0
	_vy = 0.0
	_body.visible = true
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3(0.2, 0.2, 0.2)
	_trail.restart()


func tick(delta: float) -> void:
	_t += delta
	var target := Defs.lane_x(lane)
	_lane_t = minf(_lane_t + delta / LANE_TIME, 1.0)
	lateral = lerpf(_lane_from, target, 1.0 - pow(1.0 - _lane_t, 3.0))
	var lateral_velocity := (lateral - _last_lateral) / maxf(delta, 0.0001)
	var lateral_accel := (lateral_velocity - _lateral_velocity) / maxf(delta, 0.0001)
	_lateral_velocity = lateral_velocity
	_last_lateral = lateral
	var vertical_accel := 0.0
	if height > 0.0:
		_vy -= GRAVITY * delta
		height += _vy * delta
		_air += delta
		vertical_accel = -GRAVITY
		if height <= 0.0:
			height = 0.0
			_vy = 0.0
			_body.scale = Vector3(1.3, 0.65, 1.3)
			vertical_accel = 60.0
			landed.emit()

	var lean := (target - lateral) / Defs.LANE_WIDTH
	var flip := -TAU * clampf(_air / AIR_TIME, 0.0, 1.0) if height > 0.0 else 0.0
	var bob_rate := 4.0 if _bob > 0.03 else 30.0 * clampf(speed / 20.0, 0.2, 1.5)
	_body.position = Vector3(lateral, SIZE * 0.5 + _hover + sin(_t * bob_rate) * _bob + height, 0.0)
	_body.rotation = Vector3(flip, lean * -0.25, -lean * 0.5)
	_body.scale = _body.scale.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	_body.visible = not ghost or fmod(_t * 12.0, 1.0) < 0.6

	for wheel: Node3D in _wheels:
		wheel.rotation.x -= speed * delta / 0.28
	for pivot: Node3D in _steer:
		pivot.rotation.y = lerp_angle(pivot.rotation.y, clampf(-lean * 0.9, -0.5, 0.5), 1.0 - exp(-14.0 * delta))
	if _head:
		_head.rotation = Vector3(sin(_t * 9.0) * 0.03 * clampf(speed / 20.0, 0.0, 1.0), -lean * 0.45, lean * 0.2)
	var power := clampf(speed / 16.0, 0.25, 1.6)
	for flame: Node3D in _flames:
		flame.scale = Vector3(1.0, 1.0, power * (1.0 + 0.3 * sin(_t * 47.0) + 0.15 * sin(_t * 31.0)))
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
	# Start from wherever the vehicle is, so a second swipe mid-change carries on smoothly.
	_lane_from = lateral
	_lane_t = 0.0
	return true


func jump() -> bool:
	if height > 0.0:
		return false
	_vy = JUMP_SPEED
	_air = 0.0
	height = 0.001
	return true


func slam() -> bool:
	if height <= 0.0:
		return false
	_vy = -SLAM_SPEED
	return true


func set_color(i: int) -> void:
	color_idx = i
	_apply_color(Defs.COLORS[i])
	_body.scale = Vector3.ONE * 1.18


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
	_trail.emitting = false
	var basis := global_transform.basis
	var origin := _body.global_position
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.26
	var paint_piece := StandardMaterial3D.new()
	paint_piece.albedo_color = display_color
	var dark_piece := StandardMaterial3D.new()
	dark_piece.albedo_color = Color(0.2, 0.2, 0.25)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var cell := Vector3(x, y, z)
				var piece := MeshInstance3D.new()
				piece.mesh = mesh
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


func _apply_color(c: Color) -> void:
	display_color = c
	_paint.albedo_color = c


## Spring-driven floppy parts: they swing against lane changes and bounce on jumps and landings.
func _update_wobblers(delta: float, lateral_accel: float, vertical_accel: float) -> void:
	var flutter := sin(_t * 18.0) * 0.08 * clampf(speed / Pacing.MAX_SPEED, 0.0, 1.0)
	var drive := Vector2(clampf(vertical_accel * 0.006, -0.5, 0.5) + flutter, clampf(lateral_accel * 0.0025, -0.7, 0.7))
	for w in _wobblers:
		var angle: Vector2 = w.angle
		var velocity: Vector2 = w.velocity
		var force := (drive - angle) * WOBBLE_STIFFNESS - velocity * WOBBLE_DAMPING
		velocity += force * delta
		angle += velocity * delta
		w.angle = angle
		w.velocity = velocity
		var rest: Vector3 = w.rest
		(w.node as Node3D).rotation = rest + Vector3(angle.x, 0.0, angle.y)


func _setup_trail() -> void:
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 6
	puff.rings = 3
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material = _trail_material
	_trail_process.direction = Vector3(0, 0.5, 1)
	_trail_process.spread = 30.0
	_trail_process.initial_velocity_min = 1.5
	_trail_process.initial_velocity_max = 3.5
	_trail_process.damping_min = 2.0
	_trail_process.damping_max = 3.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_trail_process.color_ramp = ramp
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0.2))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	_trail_process.scale_curve = shrink_tex
	_trail.process_material = _trail_process
	_trail.draw_pass_1 = puff
	_trail.amount = 36
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
