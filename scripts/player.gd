class_name Racer
extends Node3D
## The player's vehicle. The game places this node on the track each frame; the body
## inside it is offset for lane position and jumps. The vehicle's paint shows the
## current gate colour.

signal landed

const SIZE := 0.9
const HOVER := 0.15
const LANE_SPEED := 20.0
const GRAVITY := 34.0
const JUMP_SPEED := 11.0
const SLAM_SPEED := 24.0
const AIR_TIME := 2.0 * JUMP_SPEED / GRAVITY

var lane := 1
var lateral := 0.0
var height := 0.0
var color_idx := 0
## Cycles through hues while Prism Overdrive is active.
var rainbow := false
## Blinks the cube during post-Prism invulnerability.
var ghost := false
var display_color := Color.WHITE
## Forward speed in m/s, used to spin the wheels.
var speed := 0.0

var _vy := 0.0
var _air := 0.0
var _t := 0.0
var _body := Node3D.new()
var _model: Node3D
var _wheels: Array = []
var _flame: Node3D
var _hover := HOVER
var _bob := 0.02
var _paint := StandardMaterial3D.new()
var _detail := StandardMaterial3D.new()
var _flame_material := StandardMaterial3D.new()
var _debris: Array[Dictionary] = []


func _ready() -> void:
	_paint.vertex_color_use_as_albedo = true
	_paint.roughness = 0.45
	_detail.vertex_color_use_as_albedo = true
	_detail.roughness = 0.7
	_flame_material.vertex_color_use_as_albedo = true
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_material.albedo_color = Color(1.8, 1.8, 1.8)
	add_child(_body)
	set_model("kart")
	reset()


## Swaps in the vehicle for a theme ("kart", "buggy", "sled" or "rocket").
func set_model(kind: String) -> void:
	if _model:
		_model.queue_free()
	_model = Props.build_player(kind, _paint, _detail, _flame_material)
	_body.add_child(_model)
	_wheels = _model.get_meta("wheels")
	_flame = _model.get_meta("flame") if _model.has_meta("flame") else null
	var flying := kind == "rocket"
	_hover = HOVER + (0.15 if flying else 0.0)
	_bob = 0.06 if flying else 0.015


func _process(delta: float) -> void:
	_update_debris(delta)


func reset() -> void:
	for piece in _debris:
		piece.node.queue_free()
	_debris.clear()
	lane = 1
	lateral = 0.0
	height = 0.0
	_vy = 0.0
	rainbow = false
	ghost = false
	_body.visible = true
	_body.position = Vector3(0.0, SIZE * 0.5 + _hover, 0.0)
	_body.rotation = Vector3.ZERO
	set_color(0)
	_body.scale = Vector3.ONE


func tick(delta: float) -> void:
	_t += delta
	var target := Defs.lane_x(lane)
	lateral = move_toward(lateral, target, LANE_SPEED * delta)
	if height > 0.0:
		_vy -= GRAVITY * delta
		height += _vy * delta
		_air += delta
		if height <= 0.0:
			height = 0.0
			_vy = 0.0
			_body.scale = Vector3(1.35, 0.6, 1.35)
			landed.emit()

	var lean := (target - lateral) / Defs.LANE_WIDTH
	var flip := -TAU * clampf(_air / AIR_TIME, 0.0, 1.0) if height > 0.0 else 0.0
	var bob_rate := 4.0 if _flame else 30.0
	_body.position = Vector3(lateral, SIZE * 0.5 + _hover + sin(_t * bob_rate) * _bob + height, 0.0)
	_body.rotation = Vector3(flip, 0.0, -lean * 0.6)
	_body.scale = _body.scale.lerp(Vector3.ONE, 1.0 - exp(-10.0 * delta))
	_body.visible = not ghost or fmod(_t * 12.0, 1.0) < 0.6
	for wheel: Node3D in _wheels:
		wheel.rotation.x -= speed * delta / 0.26
	if _flame:
		var power := clampf(speed / 16.0, 0.2, 1.6)
		_flame.scale = Vector3(1.0, 1.0, power * (1.0 + 0.3 * sin(_t * 47.0) + 0.15 * sin(_t * 31.0)))
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
	return true


func slam() -> bool:
	if height <= 0.0:
		return false
	_vy = -SLAM_SPEED
	return true


func set_color(i: int) -> void:
	color_idx = i
	_apply_color(Defs.colors[i])
	_body.scale = Vector3.ONE * 1.2


## Shatters the vehicle into fragments that bounce on the road.
func explode() -> void:
	_body.visible = false
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
