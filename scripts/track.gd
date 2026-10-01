class_name Track
extends Node3D
## Endless twisting track. Generates path samples ahead of the player, builds the road in
## chunks (dressed by the theme's Scenery), and spawns obstacle rows, orbs and fuel on it.
##
## Memory stays flat on arbitrarily long runs:
## - path samples are kept in a sliding window (`_base` is the global index of sample 0);
## - chunks, rows, orbs, fuel and landmarks behind the player are freed as it passes;
## - a floating origin shifts the whole world back near (0, 0, 0) every REBASE_DISTANCE metres,
##   so 32-bit vertex positions never lose precision far from the start.

signal rebased(offset: Vector3)

const RoadShader = preload("res://shaders/road.gdshader")
const GateShader = preload("res://shaders/gate.gdshader")
const OrbShader = preload("res://shaders/orb.gdshader")

const STEP := 1.0          # metres between path samples
const CHUNK := 40          # samples per road mesh
const AHEAD := 400.0       # build road this far ahead of the player
const LOOKAHEAD := 750.0   # extra path samples beyond that, for placing landmarks
const BEHIND := 30.0       # free anything further behind than this
const KEEP_SAMPLES_BEHIND := 1000
const TRIM_SAMPLES_AT := 1400
const REBASE_DISTANCE := 1500.0
const HALF_WIDTH := 3.9
const SIDE_TOP := 0.0
const SIDE_BOTTOM := -1.2
const MAX_TURN := 0.055    # radians of heading change per metre
const MAX_PITCH := 0.35    # radians
const BANK := 6.0          # roll per unit of turn rate
const FIRST_ROW := 90.0
const FIRST_FUEL := 150.0
## Pickups placed later (rescue fuel, power gems) keep at least this far from any row.
const SLOT_CLEARANCE := 8.0
const GATE_SIZE := Vector2(2.1, 2.7)
const GATE_BOTTOM := 0.05
const GATE_TOP := GATE_BOTTOM + 2.7
const SOLID_SIZE := Vector3(2.1, 2.4, 1.2)
const LOW_SIZE := Vector3(2.2, 0.55, 0.35)

## Obstacle rows, sorted by distance: {s, cells, node, meshes, done}.
var rows: Array[Dictionary] = []
## Orbs, sorted by distance: {s, lane, color, node, done}.
var orbs: Array[Dictionary] = []
## Fuel pickups, sorted by distance: {s, lane, node, done}.
var fuels: Array[Dictionary] = []
## Power gems, sorted by distance: {s, lane, kind, node, done}.
var powers: Array[Dictionary] = []
var road_material := ShaderMaterial.new()
var gate_material := ShaderMaterial.new()
var scenery: Scenery

var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _base := 0
var _yaw := 0.0
var _rng := RandomNumberGenerator.new()
var _turn_noise := FastNoiseLite.new()
var _hill_noise := FastNoiseLite.new()
var _chunks: Array[Dictionary] = []
var _next_chunk := 0
var _last_row_s := -1.0
## Ways through the last row spawned (see Pacing.row_options), to space the next one fairly.
var _last_options: Array[Dictionary] = []
var _next_fuel_s := FIRST_FUEL
var _fuel_wave := 0

var _side_material := StandardMaterial3D.new()
var _orb_material := ShaderMaterial.new()
var _gate_mesh := QuadMesh.new()
var _gem_meshes: Array[ArrayMesh] = []
## Per power kind: {mesh, halo, beam}, built once.
var _power_looks := {}


func _ready() -> void:
	road_material.shader = RoadShader
	road_material.set_shader_parameter("lane_width", Defs.LANE_WIDTH)
	road_material.set_shader_parameter("half_width", HALF_WIDTH)
	_side_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_side_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	gate_material.shader = GateShader
	gate_material.set_shader_parameter("size", GATE_SIZE)
	gate_material.render_priority = 1
	_orb_material.shader = OrbShader
	_orb_material.next_pass = Scenery.outline_material(1.18, true)

	_gate_mesh.size = GATE_SIZE
	_gate_mesh.material = gate_material
	for slot in Defs.COLORS.size():
		_gem_meshes.append(Obstacles.gem(slot, _orb_material))
	_build_power_looks()

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


func set_symbols_visible(show: bool) -> void:
	gate_material.set_shader_parameter("show_symbols", 1.0 if show else 0.0)


## Clears the track and starts a fresh layout from the given seed.
func reset(seed_value: int) -> void:
	for child in get_children():
		child.queue_free()
	rows.clear()
	orbs.clear()
	fuels.clear()
	powers.clear()
	_chunks.clear()
	_pos.clear()
	_rot.clear()
	_base = 0
	_yaw = 0.0
	_next_chunk = 0
	_last_row_s = -1.0
	_last_options.clear()
	_next_fuel_s = FIRST_FUEL
	_fuel_wave = 0
	_rng.seed = seed_value
	_turn_noise.seed = seed_value
	_hill_noise.seed = seed_value + 7
	scenery.reset(seed_value)
	update(0.0)


## Generates track ahead of distance `s`, frees what is behind it and keeps the origin close.
func update(s: float) -> void:
	_ensure_samples(s + AHEAD + LOOKAHEAD)
	while (_next_chunk + 1) * CHUNK * STEP <= s + AHEAD:
		_build_chunk(_next_chunk)
		_next_chunk += 1
	var built_to := _next_chunk * CHUNK * STEP
	while _last_row_s < built_to - Pacing.MAX_GAP:
		_spawn_row()
	scenery.update(s)
	_free_behind(s - BEHIND)
	_trim_samples(s)
	_maybe_rebase(s)


## Track frame at distance `s`: origin on the road centre, basis x = right, y = up, -z = forward.
func frame_at(s: float) -> Transform3D:
	var f := clampf(s / STEP - _base, 0.0, _pos.size() - 1.001)
	var i := int(f)
	var t := f - i
	return Transform3D(Basis(_rot[i].slerp(_rot[i + 1], t)), _pos[i].lerp(_pos[i + 1], t))


## True when no path sample from a while before `around_s` to the end of the generated
## path lies within `radius` of `pos` (measured horizontally unless `in_3d`).
func is_clear(pos: Vector3, radius: float, in_3d: bool, around_s: float) -> bool:
	var centre := int(around_s / STEP) - _base
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


## The first unresolved row at or after distance `s` (empty if none is built yet).
func next_row(s: float) -> Dictionary:
	for row in rows:
		if not row.done and row.s >= s:
			return row
	return {}


## Number of path samples currently held; bounded no matter how far the run goes.
func sample_count() -> int:
	return _pos.size()


## A gate the player matched: flash, ripple outwards and dissolve.
func pass_cell(row: Dictionary, lane: int) -> void:
	var mi: MeshInstance3D = row.meshes[lane]
	if mi == null:
		return
	var tween := mi.create_tween()
	tween.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("burst", v), 0.001, 1.0, 0.45)
	tween.tween_callback(mi.hide)


## The player is past this row: dissolve its arch and any gate panels still standing, so the
## chase camera (several metres behind and above) never flies through them.
func retire_row(row: Dictionary) -> void:
	var arch: MeshInstance3D = row.get("arch")
	if arch:
		var tween := arch.create_tween()
		tween.tween_property(arch, "transparency", 1.0, 0.18)
		tween.tween_callback(arch.hide)
	for lane in Defs.LANES:
		var mi: MeshInstance3D = row.meshes[lane]
		var cell: int = row.cells[lane]
		if mi == null or cell < 0 or cell > 2 or float(mi.get_instance_shader_parameter("burst")) > 0.0:
			continue
		var fade := mi.create_tween()
		fade.tween_method(func(v: float) -> void: mi.set_instance_shader_parameter("fade", v), 1.0, 0.0, 0.18)
		fade.tween_callback(mi.hide)


## Any obstacle destroyed by Prism mode: gates burst, solid things squash flat.
func smash_cell(row: Dictionary, lane: int) -> void:
	var mi: MeshInstance3D = row.meshes[lane]
	if mi == null:
		return
	if row.cells[lane] <= 2:
		pass_cell(row, lane)
		return
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3(1.6, 0.05, 1.6), 0.15)
	tween.tween_callback(mi.hide)


func collect_fuel(fuel: Dictionary) -> void:
	var node: Node3D = fuel.node
	# Animate scale only: position tweens would fight a floating-origin shift.
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(1.8, 0.01, 1.8), 0.15)
	tween.tween_callback(node.queue_free)


func collect_orb(orb: Dictionary) -> void:
	var mi: MeshInstance3D = orb.node
	var tween := mi.create_tween()
	tween.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.12)
	tween.tween_callback(mi.queue_free)


## A pickup (orb, fuel or power gem) the player drove past in another lane: shrink it away so
## it doesn't sweep past the chase camera.
func drop(item: Dictionary) -> void:
	var node: Node3D = item.node
	if not is_instance_valid(node):
		return
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3.ONE * 0.01, 0.2)
	tween.tween_callback(node.hide)


func _ensure_samples(distance: float) -> void:
	var needed := int(distance / STEP) + 2 - _base
	while _pos.size() < needed:
		_add_sample()


func _add_sample() -> void:
	var i := _base + _pos.size()
	var s := i * STEP
	# Start straight and flat, then twist more the further you get.
	var twist := smoothstep(50.0, 250.0, s) * (0.7 + 0.6 * Pacing.difficulty(s))
	var turn := _turn_noise.get_noise_1d(s) * MAX_TURN * twist
	var pitch := _hill_noise.get_noise_1d(s) * MAX_PITCH * twist
	_yaw += turn * STEP
	var fwd := Vector3(-sin(_yaw) * cos(pitch), sin(pitch), -cos(_yaw) * cos(pitch))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var up := right.cross(fwd)
	var basis := Basis(right, up, -fwd).rotated(fwd, -turn * BANK)
	_pos.append(Vector3.ZERO if _pos.is_empty() else _pos[_pos.size() - 1] + fwd * STEP)
	_rot.append(basis.get_rotation_quaternion())


## Drops samples far behind the player so the path buffer never grows.
func _trim_samples(s: float) -> void:
	var behind := int(s / STEP) - _base
	if behind < TRIM_SAMPLES_AT:
		return
	var drop := behind - KEEP_SAMPLES_BEHIND
	_pos = _pos.slice(drop)
	_rot = _rot.slice(drop)
	_base += drop


## Shifts every generated thing (and the path) so the player stays near the world origin.
func _maybe_rebase(s: float) -> void:
	var origin := frame_at(s).origin
	if origin.length() < REBASE_DISTANCE:
		return
	for i in _pos.size():
		_pos[i] -= origin
	for child in get_children():
		if child is Node3D:
			child.position -= origin
	rebased.emit(origin)


func _build_chunk(c: int) -> void:
	var first := c * CHUNK
	var road := SurfaceTool.new()
	var sides := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in CHUNK + 1:
		var i := first + k
		var b := Basis(_rot[i - _base])
		var p := _pos[i - _base]
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


## Adds the next obstacle row. Its pattern is picked first, then it is placed far enough after
## the previous row for every action it needs (see Pacing.row_gap); the stretch in between
## gets orbs and, when due, fuel.
func _spawn_row() -> void:
	var prev_s := _last_row_s
	var cells := _pick_pattern(FIRST_ROW if prev_s < 0.0 else prev_s + Pacing.row_gap(prev_s, 0))
	var options := Pacing.row_options(cells)
	var s := FIRST_ROW
	if prev_s >= 0.0:
		s = prev_s + Pacing.row_gap(prev_s, Pacing.actions_between(_last_options, options))
	_ensure_samples(s + 2.0)

	var node := Node3D.new()
	add_child(node)
	node.transform = frame_at(s)
	var meshes: Array = []
	for lane in Defs.LANES:
		meshes.append(_make_cell(node, cells[lane], Defs.lane_x(lane)))
	var arch: MeshInstance3D = null
	if cells.any(func(cell: int) -> bool: return cell >= 0 and cell <= 2):
		arch = MeshInstance3D.new()
		arch.mesh = scenery.arch_mesh
		node.add_child(arch)
	rows.append({"s": s, "cells": cells, "node": node, "meshes": meshes, "arch": arch, "done": false})
	_last_row_s = s
	_last_options = options
	if prev_s >= 0.0:
		_fill_gap(prev_s, s)


## Orbs and fuel for the stretch between two rows.
func _fill_gap(from: float, to: float) -> void:
	var orb_lane := -1
	# Breathers are generous with orbs: a calm stretch should still feel rewarding.
	if _rng.randf() < (0.9 if Pacing.is_calm(from) else 0.6):
		orb_lane = _spawn_orbs(from + 9.0, to - 9.0)
	var mid := (from + to) * 0.5
	var wave := Pacing.wave_index(mid)
	var breather_fuel := Pacing.is_calm(mid) and mid > Pacing.WARM_UP and wave > _fuel_wave
	if mid >= _next_fuel_s or breather_fuel:
		var lane := _rng.randi_range(0, 2)
		while lane == orb_lane:
			lane = _rng.randi_range(0, 2)
		_spawn_fuel(mid, lane)
		_next_fuel_s = mid + Pacing.fuel_spacing(mid, _rng.randf_range(-1.0, 1.0))
		if breather_fuel:
			_fuel_wave = wave


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
		mi.position = Vector3(x, GATE_BOTTOM + GATE_SIZE.y * 0.5, 0.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_instance_shader_parameter("color", Defs.COLORS[cell])
		mi.set_instance_shader_parameter("symbol", float(Defs.SYMBOLS[cell]))
	return mi


func _pick_pattern(s: float) -> Array:
	var c := _rng.randi_range(0, 2)
	var other := (c + _rng.randi_range(1, 2)) % 3
	var weights := []
	for row in Pacing.ROWS:
		weights.append(Pacing.row_weight(row, s))
	var cells: Array
	match _weighted(weights) as Pacing.Row:
		Pacing.Row.WALL:
			cells = [c, c, c]
		Pacing.Row.BLOCK:
			cells = [Defs.SOLID, Defs.EMPTY, Defs.EMPTY]
		Pacing.Row.HURDLES:
			cells = [Defs.LOW, Defs.LOW, Defs.LOW]
		Pacing.Row.TWO_COLOURS:
			cells = [c, c, other]
		Pacing.Row.TWO_BLOCKS:
			cells = [Defs.SOLID, Defs.SOLID, Defs.EMPTY]
		Pacing.Row.GATES_AND_BLOCK:
			cells = [c, c, Defs.SOLID]
		Pacing.Row.RAINBOW:
			cells = [0, 1, 2]
		Pacing.Row.HURDLES_AND_BLOCK:
			cells = [Defs.LOW, Defs.LOW, Defs.SOLID]
		_:
			cells = [c, Defs.SOLID, Defs.LOW]
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


## A free spot for a pickup between distances `from` and `to`: midway between two rows (at
## least SLOT_CLEARANCE metres from each), in the open lane nearest `near_lane` with no orb or
## other pickup beside it. Returns {s, lane}, or {} if there is no room.
func find_slot(from: float, to: float, near_lane: int) -> Dictionary:
	var lanes := [0, 1, 2]
	lanes.sort_custom(func(a: int, b: int) -> bool: return absi(a - near_lane) < absi(b - near_lane))
	# Each stretch between neighbouring rows, including the open road before the first one.
	for i in rows.size() + 1:
		var before: Dictionary = rows[i - 1] if i > 0 else {}
		var after: Dictionary = rows[i] if i < rows.size() else {}
		var lo := maxf(from, float(before.s) + SLOT_CLEARANCE if before else -INF)
		var hi := minf(to, float(after.s) - SLOT_CLEARANCE if after else INF)
		if lo > hi:
			if after and float(after.s) > to:
				break
			continue
		var s := clampf((float(before.s) + float(after.s)) * 0.5, lo, hi) if before and after else lo
		for lane: int in lanes:
			if before and after and after.cells[lane] == Defs.SOLID and before.cells[lane] == Defs.SOLID:
				continue
			if not _occupied(s, lane):
				return {"s": s, "lane": lane}
	return {}


## Places a fuel pickup in a free spot (see find_slot). Returns false if there was no room.
func place_fuel(from: float, to: float, near_lane: int) -> bool:
	var slot := find_slot(from, to, near_lane)
	if slot.is_empty():
		return false
	_spawn_fuel(slot.s, slot.lane)
	return true


## Places a power gem in a free spot (see find_slot). Returns false if there was no room.
func place_power(kind: Powers.Kind, from: float, to: float, near_lane: int) -> bool:
	var slot := find_slot(from, to, near_lane)
	if slot.is_empty():
		return false
	var look: Dictionary = _power_looks[kind]
	var node := Node3D.new()
	add_child(node)
	var frame := frame_at(slot.s)
	node.transform = Transform3D(frame.basis, frame.origin + frame.basis.x * Defs.lane_x(slot.lane))
	for part: Mesh in [look.halo, look.beam]:
		var mi := MeshInstance3D.new()
		mi.mesh = part
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
		if part == look.beam:
			# Taller and slimmer than a fuel beam: rare things stand out from far away.
			mi.scale = Vector3(0.7, 2.5, 0.7)
	var item := MeshInstance3D.new()
	item.mesh = look.mesh
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.position = Vector3(0.0, 1.25, 0.0)
	item.scale = Vector3.ONE * 1.3
	item.set_instance_shader_parameter("color", Powers.info(kind).color)
	node.add_child(item)
	if kind == Powers.Kind.PRISM:
		# The Prism Charge cycles through the rainbow, like Overdrive.
		var hue := item.create_tween().set_loops()
		hue.tween_method(func(h: float) -> void: item.set_instance_shader_parameter("color", Color.from_hsv(h, 0.55, 1.0)), 0.0, 1.0, 1.6)
	var entry := {"s": slot.s, "lane": slot.lane, "kind": kind, "node": node, "done": false}
	powers.insert(powers.bsearch_custom(entry, func(a: Dictionary, b: Dictionary) -> bool: return a.s < b.s), entry)
	return true


func collect_power(power: Dictionary) -> void:
	var node: Node3D = power.node
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector3(2.2, 0.01, 2.2), 0.2)
	tween.tween_callback(node.queue_free)


func _occupied(s: float, lane: int) -> bool:
	for list: Array[Dictionary] in [orbs, fuels, powers]:
		for item in list:
			if item.lane == lane and absf(item.s - s) < 4.0:
				return true
	return false


## Places a spinning fuel pickup, keeping `fuels` sorted by distance.
func _spawn_fuel(s: float, lane: int) -> void:
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
	var entry := {"s": s, "lane": lane, "node": node, "done": false}
	fuels.insert(fuels.bsearch_custom(entry, func(a: Dictionary, b: Dictionary) -> bool: return a.s < b.s), entry)


## Spawns a line of orbs and returns its lane (or -1 if there was no room).
func _spawn_orbs(from: float, to: float) -> int:
	if to - from < 6.0:
		return -1
	var lane := _rng.randi_range(0, 2)
	var color := _rng.randi_range(0, 2)
	var s := from
	while s <= to:
		var mi := MeshInstance3D.new()
		mi.mesh = _gem_meshes[color]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.position = point(s, Defs.lane_x(lane), 0.8)
		mi.set_instance_shader_parameter("color", Defs.COLORS[color])
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
	while not powers.is_empty() and powers[0].s < limit:
		var power: Dictionary = powers.pop_front()
		if is_instance_valid(power.node):
			power.node.queue_free()
	while not orbs.is_empty() and orbs[0].s < limit:
		var orb: Dictionary = orbs.pop_front()
		if is_instance_valid(orb.node):
			orb.node.queue_free()


## Each power kind's gem (spinning, outlined, tinted per instance), with a halo and a tall
## light beam in its colour so it can be spotted from far away.
func _build_power_looks() -> void:
	for kind: Powers.Kind in Powers.INFO:
		var color: Color = Powers.info(kind).color
		var halo_material := StandardMaterial3D.new()
		halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_material.vertex_color_use_as_albedo = true
		halo_material.albedo_color = color * 1.4
		var beam_material := StandardMaterial3D.new()
		beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		beam_material.vertex_color_use_as_albedo = true
		beam_material.albedo_color = Color(color.r, color.g, color.b, 0.45)
		_power_looks[kind] = {
			"mesh": Powers.mesh(kind, _orb_material),
			"halo": Props.build("fuel_halo", 6, halo_material),
			"beam": Props.build("fuel_beam", 7, beam_material),
		}
