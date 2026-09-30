class_name Scenery
extends RefCounted
## Dresses the track for a theme: ground verges beside the path, props on them,
## and big landmarks (mountains, mesas, planets) that fade in from the distance.

const VARIANTS := 3
const VERGE_STEP := 2
const NEAR_FADE := Vector2(390.0, 270.0)  # invisible beyond x metres, solid within y
const FAR_FADE := Vector2(720.0, 480.0)
const FAR_AHEAD := 660.0
const FAR_BEHIND := 160.0

## Placement rules for landmarks: lateral distance, height offset, scale,
## clearance radius (per unit scale), and whether clearance is checked in 3D.
const FAR_SPECS := {
	"mountain": {"lat": [70.0, 230.0], "y": [-70.0, -45.0], "scale": [0.8, 1.4], "clear": 32.0, "floating": false},
	"snow_mountain": {"lat": [70.0, 230.0], "y": [-70.0, -45.0], "scale": [0.8, 1.4], "clear": 32.0, "floating": false},
	"floating_island": {"lat": [20.0, 90.0], "y": [-4.0, 22.0], "scale": [0.8, 1.4], "clear": 8.0, "floating": true},
	"cloud": {"lat": [25.0, 160.0], "y": [12.0, 45.0], "scale": [1.0, 2.2], "clear": 6.0, "floating": true},
	"ice_spire": {"lat": [35.0, 150.0], "y": [-45.0, -25.0], "scale": [0.8, 1.3], "clear": 14.0, "floating": false},
	"mesa": {"lat": [60.0, 220.0], "y": [-65.0, -50.0], "scale": [0.8, 1.4], "clear": 32.0, "floating": false},
	"hoodoo": {"lat": [30.0, 120.0], "y": [-45.0, -30.0], "scale": [0.7, 1.2], "clear": 12.0, "floating": false},
	"balloon": {"lat": [14.0, 80.0], "y": [6.0, 30.0], "scale": [1.0, 1.6], "clear": 4.0, "floating": true},
	"dune": {"lat": [40.0, 200.0], "y": [-12.0, -4.0], "scale": [0.8, 1.6], "clear": 42.0, "floating": false},
	"volcano": {"lat": [80.0, 240.0], "y": [-55.0, -40.0], "scale": [0.8, 1.3], "clear": 42.0, "floating": false},
	"basalt_spire": {"lat": [30.0, 120.0], "y": [-40.0, -25.0], "scale": [0.7, 1.2], "clear": 12.0, "floating": false},
	"magma_rock": {"lat": [18.0, 90.0], "y": [-8.0, 20.0], "scale": [1.5, 4.0], "clear": 2.5, "floating": true},
	"asteroid": {"lat": [7.0, 45.0], "y": [-12.0, 16.0], "scale": [0.6, 3.0], "clear": 2.0, "floating": true},
	"planet": {"lat": [260.0, 460.0], "y": [-60.0, 160.0], "scale": [40.0, 110.0], "clear": 1.3, "floating": true},
	"ringed_planet": {"lat": [260.0, 460.0], "y": [-60.0, 160.0], "scale": [35.0, 80.0], "clear": 2.4, "floating": true},
}

var theme: Dictionary
var material := StandardMaterial3D.new()
var block_meshes: Array[ArrayMesh] = []
var hurdle_mesh: ArrayMesh
var arch_mesh: ArrayMesh
var fuel_mesh: ArrayMesh
var fuel_halo_mesh: ArrayMesh
var fuel_beam_mesh: ArrayMesh

var _track: Track
var _near_material := StandardMaterial3D.new()
var _far_material := StandardMaterial3D.new()
var _planet_material := ShaderMaterial.new()
var _meshes := {}
var _far: Array[Dictionary] = []
var _next_far_s := 0.0
var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _init(track: Track, theme_data: Dictionary) -> void:
	_track = track
	theme = theme_data
	for m: StandardMaterial3D in [material, _near_material, _far_material]:
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.9
	for pair in [[_near_material, NEAR_FADE], [_far_material, FAR_FADE]]:
		var m: StandardMaterial3D = pair[0]
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = pair[1].x
		m.distance_fade_max_distance = pair[1].y
	# Big landmarks fade smoothly (dithering shows on large surfaces).
	_far_material.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	_planet_material.shader = preload("res://shaders/planet.gdshader")
	_noise.frequency = 0.02
	var glow := StandardMaterial3D.new()
	glow.vertex_color_use_as_albedo = true
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(2.2, 2.2, 2.2)
	for i in VARIANTS:
		block_meshes.append(Obstacles.block(theme.block, 30 + i * 17, material, glow))
	var hazard := ShaderMaterial.new()
	hazard.shader = preload("res://shaders/hazard.gdshader")
	for key: String in theme.get("hazard", {}):
		hazard.set_shader_parameter(key, theme.hazard[key])
	hurdle_mesh = Obstacles.hurdle(theme.hurdle, material, glow, hazard)
	arch_mesh = Obstacles.arch(theme.arch, material, glow)
	# Pickups get a dark outline so they read against any background.
	var pickup_material: StandardMaterial3D = material.duplicate()
	pickup_material.next_pass = outline_material(1.12, false)
	var fuel_color: Color = theme.fuel_color
	fuel_mesh = Props.build(theme.fuel, 5, pickup_material, fuel_color)
	var halo_material := StandardMaterial3D.new()
	halo_material.vertex_color_use_as_albedo = true
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.albedo_color = Color(fuel_color.r * 1.5, fuel_color.g * 1.5, fuel_color.b * 1.5)
	fuel_halo_mesh = Props.build("fuel_halo", 6, halo_material)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam_material.vertex_color_use_as_albedo = true
	beam_material.albedo_color = Color(fuel_color.r, fuel_color.g, fuel_color.b, 0.3)
	fuel_beam_mesh = Props.build("fuel_beam", 7, beam_material)
	_prewarm()


## Builds every prop and landmark mesh for the theme up front, so nothing is generated mid-run.
func _prewarm() -> void:
	for entry: Array in theme.near + theme.far:
		_mesh(entry[0])


## Cartoon outline pass: a slightly larger, inside-out copy drawn in a dark colour.
static func outline_material(grow: float, spin: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/outline.gdshader")
	m.set_shader_parameter("grow", grow)
	m.set_shader_parameter("spin", 1.0 if spin else 0.0)
	return m


func reset(seed_value: int) -> void:
	_far.clear()
	_next_far_s = 40.0
	_rng.seed = seed_value
	_noise.seed = seed_value


func has_verge() -> bool:
	return theme.verge != null


## Adds verges and props for one road chunk under `parent`.
func decorate_chunk(parent: Node3D, first: int, count: int) -> void:
	if not has_verge():
		return
	var kit := MeshKit.new(first)
	for side in [-1.0, 1.0]:
		_build_verge(kit, first, count, side)
	var ground := MeshInstance3D.new()
	ground.mesh = kit.commit(material)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ground)
	_place_near(parent, first, count)


## Spawns landmarks ahead of `s` and frees the ones left behind.
func update(s: float) -> void:
	if theme.far.is_empty():
		return
	while _next_far_s < s + FAR_AHEAD:
		_spawn_far(_next_far_s)
		_next_far_s += theme.far_spacing * _rng.randf_range(0.5, 1.5)
	while not _far.is_empty() and _far[0].s < s - FAR_BEHIND:
		var old: Dictionary = _far.pop_front()
		if is_instance_valid(old.node):
			old.node.queue_free()


func _mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		var variants: Array[ArrayMesh] = []
		var mat: Material = _far_material if FAR_SPECS.has(kind) else _near_material
		if kind.ends_with("planet"):
			mat = _planet_material
		for i in VARIANTS:
			variants.append(Props.build(kind, i * 7919 + kind.hash() % 1000, mat))
		_meshes[kind] = variants
	return _meshes[kind][_rng.randi() % VARIANTS]


func _pick(weighted: Array) -> String:
	var total := 0.0
	for entry: Array in weighted:
		total += entry[1]
	var r := _rng.randf() * total
	for entry: Array in weighted:
		r -= entry[1]
		if r <= 0.0:
			return entry[0]
	return weighted[0][0]


func _verge_width(s: float, side: float) -> float:
	return theme.verge.width * (0.75 + 0.5 * (_noise.get_noise_2d(s, side * 500.0) * 0.5 + 0.5))


## Cross-section of one verge at sample i: grass top, then an earthy cliff down to under the road.
func _verge_profile(i: int, side: float) -> Array[Vector3]:
	var s := i * Track.STEP
	var frame := _track.frame_at(s)
	var hw := Track.HALF_WIDTH
	var w := _verge_width(s, side)
	var bump := func(k: float) -> float: return maxf(_noise.get_noise_2d(s * 3.0, side * 97.0 + k * 31.0), 0.0) * 0.6
	var columns := [
		Vector2(hw, -0.02), Vector2(hw + 1.0, 0.04 + bump.call(1.0) * 0.4), Vector2(hw + w * 0.55, bump.call(2.0)),
		Vector2(hw + w, -0.15), Vector2(hw + w + 0.4, -1.4), Vector2(hw + w - 0.3, -3.2),
		Vector2(hw + w - 2.0, -5.5 - bump.call(3.0) * 2.0), Vector2(0.0, -6.5),
	]
	var points: Array[Vector3] = []
	for c: Vector2 in columns:
		points.append(frame.origin + frame.basis.x * (c.x * side) + frame.basis.y * c.y)
	return points


func _build_verge(kit: MeshKit, first: int, count: int, side: float) -> void:
	var top: Array = theme.verge.top
	var cliff: Array = theme.verge.cliff
	var i := first
	var prev := _verge_profile(i, side)
	while i < first + count:
		var j := mini(i + VERGE_STEP, first + count)
		var cur := _verge_profile(j, side)
		var basis := _track.frame_at(i * Track.STEP).basis
		for c in prev.size() - 1:
			var color: Color
			var outward: Vector3
			if c < 3:
				color = kit.vary(top[_rng.randi() % top.size()], 0.04)
				outward = basis.y
			else:
				color = kit.vary(cliff[c % cliff.size()], 0.05)
				outward = -basis.y if c == prev.size() - 2 else basis.x * side
			kit.quad(prev[c], prev[c + 1], cur[c + 1], cur[c], color, outward)
		prev = cur
		i = j
	if theme.verge.has("fence"):
		_build_fence(kit, first, count, side, theme.verge.fence)


## Wooden post-and-rail fence just off the road edge.
func _build_fence(kit: MeshKit, first: int, count: int, side: float, wood: Color) -> void:
	var spacing := 3
	var prev_post := Vector3.ZERO
	var prev_up := Vector3.UP
	var start := first - posmod(first, spacing)
	for i in range(start, first + count + 1, spacing):
		var frame := _track.frame_at(i * Track.STEP)
		var post := frame.origin + frame.basis.x * (Track.HALF_WIDTH + 0.55) * side
		var up := frame.basis.y
		kit.cylinder(post - up * 0.1, up * 1.0, 0.09, 0.08, 4, wood, true)
		if i > start:
			for h in [0.4, 0.75]:
				kit.cylinder(prev_post + prev_up * h, (post + up * h) - (prev_post + prev_up * h), 0.045, 0.045, 4, wood.darkened(0.1))
		prev_post = post
		prev_up = up


func _place_near(parent: Node3D, first: int, count: int) -> void:
	var kinds: Array = theme.near
	if kinds.is_empty():
		return
	for side in [-1.0, 1.0]:
		var n := int(theme.near_count * count / 40.0 * _rng.randf_range(0.7, 1.3))
		for k in n:
			var s := (first + _rng.randf() * count) * Track.STEP
			var w := _verge_width(s, side)
			var lateral := Track.HALF_WIDTH + 1.6 + _rng.randf() * maxf(w - 2.6, 0.5)
			var frame := _track.frame_at(s)
			var mi := MeshInstance3D.new()
			mi.mesh = _mesh(_pick(kinds))
			var basis := frame.basis * Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * _rng.randf_range(0.8, 1.25))
			mi.transform = Transform3D(basis, frame.origin + frame.basis.x * lateral * side - frame.basis.y * 0.05)
			parent.add_child(mi)


func _spawn_far(anchor: float) -> void:
	var kind := _pick(theme.far)
	var spec: Dictionary = FAR_SPECS[kind]
	var frame := _track.frame_at(anchor)
	var right := Vector3(frame.basis.x.x, 0.0, frame.basis.x.z).normalized()
	for attempt in 4:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var scale := _rng.randf_range(spec.scale[0], spec.scale[1])
		var pos := frame.origin + right * _rng.randf_range(spec.lat[0], spec.lat[1]) * side
		pos.y += _rng.randf_range(spec.y[0], spec.y[1])
		var radius: float = spec.clear * scale
		if not _track.is_clear(pos, radius + 6.0, spec.floating, anchor) or _overlaps_landmark(pos, radius):
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh(kind)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var spin := Basis(Vector3.UP, _rng.randf() * TAU)
		if spec.floating and kind != "cloud" and kind != "balloon" and kind != "floating_island":
			spin = Basis(Vector3(_rng.randf_range(-1, 1), 1.0, _rng.randf_range(-1, 1)).normalized(), _rng.randf() * TAU)
		mi.transform = Transform3D(spin.scaled(Vector3.ONE * scale), pos)
		_track.add_child(mi)
		_far.append({"s": anchor, "node": mi, "radius": radius})
		return


func _overlaps_landmark(pos: Vector3, radius: float) -> bool:
	for other in _far:
		var r: float = other.radius + radius
		if is_instance_valid(other.node) and other.node.position.distance_squared_to(pos) < r * r:
			return true
	return false
