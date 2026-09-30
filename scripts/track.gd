class_name Track
extends Node3D
## Endless twisting track. Generates path samples ahead of the player, builds the road
## in chunks (dressed by the theme's Scenery), and spawns obstacle rows and orbs on it.

const RoadShader = preload("res://shaders/road.gdshader")
const GateShader = preload("res://shaders/gate.gdshader")
const OrbShader = preload("res://shaders/orb.gdshader")

const STEP := 1.0          # metres between path samples
const CHUNK := 40          # samples per road mesh
const AHEAD := 400.0       # build road this far ahead of the player
const LOOKAHEAD := 750.0   # extra path samples beyond that, for placing landmarks
const BEHIND := 30.0       # free anything further behind than this
const HALF_WIDTH := 3.9
const SIDE_TOP := 0.0
const SIDE_BOTTOM := -1.2
const MAX_TURN := 0.055    # radians of heading change per metre
const MAX_PITCH := 0.35    # radians
const BANK := 6.0          # roll per unit of turn rate
const FIRST_ROW := 90.0
const FIRST_FUEL := 150.0
const FUEL_EVERY := Vector2(130.0, 210.0)
const GATE_SIZE := Vector2(2.2, 2.6)
const SOLID_SIZE := Vector3(2.1, 2.4, 1.2)
const LOW_SIZE := Vector3(2.2, 0.55, 0.35)

## Obstacle rows, sorted by distance: {s, cells, node, meshes, done}.
var rows: Array[Dictionary] = []
## Orbs, sorted by distance: {s, lane, color, node, done}.
var orbs: Array[Dictionary] = []
## Fuel pickups, sorted by distance: {s, lane, node, done}.
var fuels: Array[Dictionary] = []
var road_material := ShaderMaterial.new()
var scenery: Scenery

var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _turn_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _chunks: Array[Dictionary] = []
var _next_chunk := 0
var _next_row_s := FIRST_ROW
var _next_fuel_s := FIRST_FUEL

var _side_material := StandardMaterial3D.new()
var _gate_material := ShaderMaterial.new()
var _orb_material := ShaderMaterial.new()
var _gate_mesh := QuadMesh.new()
var _orb_mesh: ArrayMesh


func _ready() -> void:
	road_material.shader = RoadShader
	road_material.set_shader_parameter("lane_width", Defs.LANE_WIDTH)
	road_material.set_shader_parameter("half_width", HALF_WIDTH)
	_side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_gate_material.shader = GateShader
	_gate_material.set_shader_parameter("size", GATE_SIZE)
	_orb_material.shader = OrbShader

	_gate_mesh.size = GATE_SIZE
	_gate_mesh.material = _gate_material
	_orb_material.next_pass = Scenery.outline_material(1.18, true)
	_orb_mesh = Props.build("gem", 1, _orb_material)

	for noise: FastNoiseLite in [_turn_noise, _hill_noise]:
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_turn_noise.frequency = 0.006
	_hill_noise.frequency = 0.009


## Switches the look of the path, obstacles and scenery. Takes effect on the next reset().
func set_theme(theme: Dictionary) -> void:
	scenery = Scenery.new(self, theme)
	for key: String in theme.road:
		road_material.set_shader_parameter(key, theme.road[key])
	_side_material.albedo_color = theme.get("side_color", Color.GRAY)


## Clears the track and starts a fresh layout from the given seed.
func reset(seed_value: int) -> void:
	for child in get_children():
		child.queue_free()
	rows.clear()
	orbs.clear()
	fuels.clear()
	_chunks.clear()
	_pos.clear()
	_rot.clear()
	_yaw = 0.0
	_next_chunk = 0
	_next_row_s = FIRST_ROW
	_next_fuel_s = FIRST_FUEL
	_rng.seed = seed_value
	_turn_noise.seed = seed_value
	_hill_noise.seed = seed_value + 7
	scenery.reset(seed_value)
	update(0.0)


## Generates track ahead of distance `s` and frees what is behind it.
func update(s: float) -> void:
	_ensure_samples(s + AHEAD + LOOKAHEAD)
	while (_next_chunk + 1) * CHUNK * STEP <= s + AHEAD:
		_build_chunk(_next_chunk)
		_next_chunk += 1
	var built_to := _next_chunk * CHUNK * STEP
	while _next_row_s < built_to - 5.0:
		_spawn_row()
	scenery.update(s)
	_free_behind(s - BEHIND)


## Track frame at distance `s`: origin on the road centre, basis x = right, y = up, -z = forward.
func frame_at(s: float) -> Transform3D:
	var f := clampf(s / STEP, 0.0, _pos.size() - 1.001)
	var i := int(f)
	var t := f - i
	return Transform3D(Basis(_rot[i].slerp(_rot[i + 1], t)), _pos[i].lerp(_pos[i + 1], t))


## True when no path sample from a while before `around_s` to the end of the generated
## path lies within `radius` of `pos` (measured horizontally unless `in_3d`).
func is_clear(pos: Vector3, radius: float, in_3d: bool, around_s: float) -> bool:
	var centre := int(around_s / STEP)
	for i in range(maxi(centre - 800, 0), _pos.size(), 3):
		var d := _pos[i] - pos
		if not in_3d:
			d.y = 0.0
		if d.length_squared() < radius * radius:
			return false
	return true


func point(s: float, lateral: float, height: float) -> Vector3:
	var frame := frame_at(s)
	return frame.origin + frame.basis.x * lateral + frame.basis.y * height


## A gate the player matched: burst and fade it out.
func pass_cell(row: Dictionary, lane: int) -> void:
	var mi: MeshInstance3D = row.meshes[lane]
	if mi == null:
		return
	var tween := mi.create_tween().set_parallel()
	tween.tween_property(mi, "scale", Vector3(1.4, 1.3, 1.0), 0.3)
	tween.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("flash", v), 1.0, 0.0, 0.3)
	tween.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.3)


## Any obstacle destroyed by Prism mode: squash it flat.
func smash_cell(row: Dictionary, lane: int) -> void:
	var mi: MeshInstance3D = row.meshes[lane]
	if mi == null:
		return
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(1.6, 0.05, 1.6), 0.15)
	tween.tween_callback(mi.hide)


func collect_fuel(fuel: Dictionary) -> void:
	var node: Node3D = fuel.node
	var tween := node.create_tween().set_parallel()
	tween.tween_property(node, "scale", Vector3(1.8, 0.01, 1.8), 0.15)
	tween.tween_property(node, "position", node.position + node.basis.y * 1.2, 0.15)
	tween.chain().tween_callback(node.queue_free)


func collect_orb(orb: Dictionary) -> void:
	var mi: MeshInstance3D = orb.node
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.12)
	tween.tween_callback(mi.queue_free)


func _ensure_samples(distance: float) -> void:
	var needed := int(distance / STEP) + 2
	while _pos.size() < needed:
		_add_sample()


func _add_sample() -> void:
	var i := _pos.size()
	var s := i * STEP
	# Start straight and flat, then twist more the further you get.
	var twist := smoothstep(50.0, 250.0, s) * (0.7 + 0.6 * Defs.difficulty(s))
	var turn := _turn_noise.get_noise_1d(s) * MAX_TURN * twist
	var pitch := _hill_noise.get_noise_1d(s) * MAX_PITCH * twist
	_yaw += turn * STEP
	var fwd := Vector3(-sin(_yaw) * cos(pitch), sin(pitch), -cos(_yaw) * cos(pitch))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var up := right.cross(fwd)
	var basis := Basis(right, up, -fwd).rotated(fwd, -turn * BANK)
	_pos.append(Vector3.ZERO if i == 0 else _pos[i - 1] + fwd * STEP)
	_rot.append(basis.get_rotation_quaternion())


func _build_chunk(c: int) -> void:
	var first := c * CHUNK
	var road := SurfaceTool.new()
	var sides := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in CHUNK + 1:
		var i := first + k
		var b := Basis(_rot[i])
		var p := _pos[i]
		var v := i * STEP
		road.set_normal(b.y)
		road.set_uv(Vector2(0.0, v))
		road.add_vertex(p - b.x * HALF_WIDTH)
		road.set_normal(b.y)
		road.set_uv(Vector2(1.0, v))
		road.add_vertex(p + b.x * HALF_WIDTH)
		for side in [-1.0, 1.0]:
			var edge: Vector3 = p + b.x * HALF_WIDTH * side
			sides.set_uv(Vector2(v, 0.0))
			sides.add_vertex(edge + b.y * SIDE_BOTTOM)
			sides.set_uv(Vector2(v, 1.0))
			sides.add_vertex(edge + b.y * SIDE_TOP)
	for k in CHUNK:
		var a := k * 2
		_quad(road, a, a + 2, a + 3, a + 1)
		var r := k * 4
		_quad(sides, r, r + 4, r + 5, r + 1)
		_quad(sides, r + 2, r + 6, r + 7, r + 3)
	road.set_material(road_material)
	sides.set_material(_side_material)
	var mesh := road.commit()
	if not scenery.has_verge():
		sides.commit(mesh)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	scenery.decorate_chunk(mi, first, CHUNK)
	_chunks.append({"end": (first + CHUNK) * STEP, "node": mi})


func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	st.add_index(a)
	st.add_index(c)
	st.add_index(d)


func _spawn_row() -> void:
	var s := _next_row_s
	var d := Defs.difficulty(s)
	var gap := maxf(lerpf(40.0, 26.0, d), Defs.speed_at(s) * 1.05)
	_ensure_samples(s + gap + 2.0)

	var cells := _pick_pattern(s, d)
	var node := Node3D.new()
	add_child(node)
	node.transform = frame_at(s)
	var meshes: Array = []
	for lane in Defs.LANES:
		meshes.append(_make_cell(node, cells[lane], Defs.lane_x(lane)))
	rows.append({"s": s, "cells": cells, "node": node, "meshes": meshes, "done": false})

	var orb_lane := -1
	if _rng.randf() < 0.6:
		orb_lane = _spawn_orbs(s + 9.0, s + gap - 9.0)
	if s + gap * 0.5 >= _next_fuel_s:
		_spawn_fuel(s + gap * 0.5, orb_lane)
		_next_fuel_s = s + gap * 0.5 + _rng.randf_range(FUEL_EVERY.x, FUEL_EVERY.y)
	_next_row_s = s + gap


func _make_cell(parent: Node3D, cell: int, x: float) -> MeshInstance3D:
	if cell == Defs.EMPTY:
		return null
	var mi := MeshInstance3D.new()
	parent.add_child(mi)
	if cell == Defs.SOLID:
		mi.mesh = scenery.block_meshes[_rng.randi() % scenery.block_meshes.size()]
		mi.transform = Transform3D(Basis(Vector3.UP, PI if _rng.randf() < 0.5 else 0.0), Vector3(x, 0.0, 0.0))
	elif cell == Defs.LOW:
		mi.mesh = scenery.hurdle_mesh
		mi.position = Vector3(x, 0.0, 0.0)
	else:
		mi.mesh = _gate_mesh
		mi.position = Vector3(x, GATE_SIZE.y * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("color", Defs.colors[cell])
	return mi


func _pick_pattern(s: float, d: float) -> Array:
	var c := _rng.randi_range(0, 2)
	var other := (c + _rng.randi_range(1, 2)) % 3
	var early := 0.0 if s < 300.0 else 1.0
	var weights := [
		3.0,                      # 0: wall of one colour
		2.5,                      # 1: solid blocks to dodge
		(1.0 + 2.0 * d) * early,  # 2: one lane per colour
		(0.5 + 2.0 * d) * early,  # 3: gates with one block
		(1.0 + d) * early,        # 4: hurdles to jump
		3.0 * d * early,          # 5: gate + block + hurdle
		(1.0 + d) * early,        # 6: two colours
	]
	var cells: Array
	match _weighted(weights):
		0:
			cells = [c, c, c]
		1:
			cells = [Defs.EMPTY, Defs.EMPTY, Defs.EMPTY]
			var blocked := _rng.randi_range(0, 2)
			cells[blocked] = Defs.SOLID
			if _rng.randf() < 0.3 + 0.5 * d:
				cells[(blocked + _rng.randi_range(1, 2)) % 3] = Defs.SOLID
		2:
			cells = [0, 1, 2]
		3:
			cells = [c, c, c]
			cells[_rng.randi_range(0, 2)] = Defs.SOLID
		4:
			cells = [Defs.LOW, Defs.LOW, Defs.LOW]
		5:
			cells = [c, Defs.SOLID, Defs.LOW]
		_:
			cells = [c, c, other]
	_shuffle(cells)
	return cells


func _weighted(weights: Array) -> int:
	var total := 0.0
	for w: float in weights:
		total += w
	var r := _rng.randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return 0


func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


## Places a spinning fuel pickup in a lane other than `avoid_lane`.
func _spawn_fuel(s: float, avoid_lane: int) -> void:
	var lane := _rng.randi_range(0, 2)
	while lane == avoid_lane:
		lane = _rng.randi_range(0, 2)
	var node := Node3D.new()
	add_child(node)
	var frame := frame_at(s)
	node.transform = Transform3D(frame.basis, frame.origin + frame.basis.x * Defs.lane_x(lane))
	var halo := MeshInstance3D.new()
	halo.mesh = scenery.fuel_halo_mesh
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(halo)
	var beam := MeshInstance3D.new()
	beam.mesh = scenery.fuel_beam_mesh
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(beam)
	var item := MeshInstance3D.new()
	item.mesh = scenery.fuel_mesh
	item.position = Vector3(0.0, 1.1, 0.0)
	item.scale = Vector3.ONE * 1.6
	node.add_child(item)
	var spin := item.create_tween().set_loops()
	spin.tween_property(item, "rotation:y", TAU, 1.6).as_relative()
	var pulse := halo.create_tween().set_loops()
	pulse.tween_property(halo, "scale", Vector3.ONE * 1.25, 0.5)
	pulse.tween_property(halo, "scale", Vector3.ONE, 0.5)
	fuels.append({"s": s, "lane": lane, "node": node, "done": false})


## Spawns a line of orbs and returns its lane (or -1 if there was no room).
func _spawn_orbs(from: float, to: float) -> int:
	if to - from < 6.0:
		return -1
	var lane := _rng.randi_range(0, 2)
	var color := _rng.randi_range(0, 2)
	var s := from
	while s <= to:
		var mi := MeshInstance3D.new()
		mi.mesh = _orb_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = point(s, Defs.lane_x(lane), 0.75)
		mi.set_instance_shader_parameter("color", Defs.colors[color])
		orbs.append({"s": s, "lane": lane, "color": color, "node": mi, "done": false})
		s += 3.5
	return lane


func _free_behind(limit: float) -> void:
	while not _chunks.is_empty() and _chunks[0].end < limit:
		_chunks.pop_front().node.queue_free()
	while not rows.is_empty() and rows[0].s < limit:
		rows.pop_front().node.queue_free()
	while not fuels.is_empty() and fuels[0].s < limit:
		var fuel: Dictionary = fuels.pop_front()
		if is_instance_valid(fuel.node):
			fuel.node.queue_free()
	while not orbs.is_empty() and orbs[0].s < limit:
		var orb: Dictionary = orbs.pop_front()
		if is_instance_valid(orb.node):
			orb.node.queue_free()
