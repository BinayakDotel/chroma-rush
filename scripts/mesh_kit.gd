class_name MeshKit
extends RefCounted
## Builds flat-shaded, vertex-coloured low-poly meshes out of simple shapes.
## Colours can be a Color or a Callable(local_dir: Vector3) -> Color.

static var _ico_cache := {}

var rng := RandomNumberGenerator.new()
var _st := SurfaceTool.new()
var _count := 0


func _init(seed_value := 0) -> void:
	rng.seed = seed_value
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func rand(a: float, b: float) -> float:
	return rng.randf_range(a, b)


## Colour with a little random brightness variation, for a faceted look.
func vary(color: Color, amount := 0.06) -> Color:
	var k := rand(1.0 - amount, 1.0 + amount)
	return Color(color.r * k, color.g * k, color.b * k)


## Adds one triangle, flipped if needed so it faces `outward`.
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward := Vector3.ZERO) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if outward != Vector3.ZERO and n.dot(outward) < 0.0:
		n = -n
		var swap := b
		b = c
		c = swap
	# Godot treats clockwise triangles as front-facing.
	for v in [a, c, b]:
		_st.set_color(color)
		_st.set_normal(n)
		_st.add_vertex(v)
	_count += 1


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward := Vector3.ZERO) -> void:
	tri(a, b, c, color, outward)
	tri(a, c, d, color, outward)


## Finishes the mesh. Pass `into` to append this as another surface of an existing mesh.
func commit(material: Material, into: ArrayMesh = null) -> ArrayMesh:
	if _count == 0:
		return into if into else ArrayMesh.new()
	var mesh := _st.commit(into) if into else _st.commit()
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func sphere(center: Vector3, radius: Vector3, subdiv: int, jitter: float, color, seed_offset := 0.0) -> void:
	for t: Array in _icosphere(subdiv):
		var p: Array[Vector3] = []
		for v: Vector3 in t:
			p.append(center + v * (1.0 + jitter * (_hash(v, seed_offset) - 0.5) * 2.0) * radius)
		var mid: Vector3 = (t[0] + t[1] + t[2]) / 3.0
		tri(p[0], p[1], p[2], _color(color, mid), (p[0] + p[1] + p[2]) / 3.0 - center)


## Frustum from `base` along `axis`; r1 = 0 makes a cone.
func cylinder(base: Vector3, axis: Vector3, r0: float, r1: float, sides: int, color, caps := false, jitter := 0.0, cap_color = null) -> void:
	var up := axis.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := up.cross(side)
	var top := base + axis
	var ring0: Array[Vector3] = []
	var ring1: Array[Vector3] = []
	var phase := rand(0.0, TAU)
	for k in sides:
		var a := phase + TAU * k / sides
		var dir := side * cos(a) + fwd * sin(a)
		ring0.append(base + dir * r0 * (1.0 + rand(-jitter, jitter)))
		ring1.append(top + dir * r1 * (1.0 + rand(-jitter, jitter)))
	for k in sides:
		var n := (k + 1) % sides
		var centroid := (ring0[k] + ring0[n] + ring1[k] + ring1[n]) / 4.0
		var out := centroid - (base + up * (centroid - base).dot(up))
		var col := _color(color, (centroid - base).normalized())
		if r1 > 0.001:
			quad(ring0[k], ring0[n], ring1[n], ring1[k], col, out)
		else:
			tri(ring0[k], ring0[n], top, col, out)
	if caps:
		var cc = cap_color if cap_color != null else color
		for k in sides:
			var n := (k + 1) % sides
			tri(base, ring0[k], ring0[n], _color(cc, -up), -up)
			if r1 > 0.001:
				tri(top, ring1[k], ring1[n], _color(cc, up), up)


## Jagged peak: stacked rings narrowing to an apex. `bands` is [[max_height_fraction, Color], ...].
func mountain(base: Vector3, radius: float, height: float, sides: int, bands: Array) -> void:
	var rings := 5
	var levels: Array = []
	var phase := rand(0.0, TAU)
	for r in rings:
		var t := float(r) / rings
		var ring: Array[Vector3] = []
		var rr := radius * pow(1.0 - t, 0.85)
		for k in sides:
			var a := phase + TAU * (k + rand(-0.25, 0.25)) / sides
			var y := height * t * (1.0 + (rand(-0.06, 0.06) if r > 0 else 0.0))
			ring.append(base + Vector3(cos(a) * rr * rand(0.8, 1.15), y, sin(a) * rr * rand(0.8, 1.15)))
		levels.append(ring)
	var apex := base + Vector3(rand(-0.08, 0.08) * radius, height, rand(-0.08, 0.08) * radius)
	for r in rings:
		var lower: Array[Vector3] = levels[r]
		for k in sides:
			var n := (k + 1) % sides
			if r == rings - 1:
				var c := (lower[k] + lower[n] + apex) / 3.0
				tri(lower[k], lower[n], apex, _band(bands, (c.y - base.y) / height), _out(c, base))
			else:
				var upper: Array[Vector3] = levels[r + 1]
				var c := (lower[k] + lower[n] + upper[k] + upper[n]) / 4.0
				var col := _band(bands, (c.y - base.y) / height)
				tri(lower[k], lower[n], upper[n], col, _out(c, base))
				tri(lower[k], upper[n], upper[k], _band(bands, (c.y - base.y) / height + 0.02), _out(c, base))


## Box with slightly jittered corners.
func box(center: Vector3, size: Vector3, color, jitter := 0.0) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		var s := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		c.append(center + s * h + Vector3(rand(-jitter, jitter), rand(-jitter, jitter), rand(-jitter, jitter)))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		var mid: Vector3 = (c[f[0]] + c[f[1]] + c[f[2]] + c[f[3]]) / 4.0
		quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]], _color(color, (mid - center).normalized()), mid - center)


## Side profile extruded across X: `profile` is a star-shaped outline of (z, y) points, swept
## from x = x0 to x = x1 and capped at both ends. Handy for car bodies, hulls and hats.
func extrude(profile: Array[Vector2], x0: float, x1: float, color) -> void:
	var n := profile.size()
	var centroid := Vector2.ZERO
	for p in profile:
		centroid += p
	centroid /= n
	var mid_x := (x0 + x1) * 0.5
	var center := Vector3(mid_x, centroid.y, centroid.x)
	for i in n:
		var a := profile[i]
		var b := profile[(i + 1) % n]
		var pa0 := Vector3(x0, a.y, a.x)
		var pb0 := Vector3(x0, b.y, b.x)
		var pa1 := Vector3(x1, a.y, a.x)
		var pb1 := Vector3(x1, b.y, b.x)
		var side_mid := (pa0 + pb1) * 0.5
		var out := Vector3(0.0, side_mid.y - center.y, side_mid.z - center.z)
		quad(pa0, pb0, pb1, pa1, _color(color, out.normalized()), out)
		var c0 := Vector3(x0, centroid.y, centroid.x)
		var c1 := Vector3(x1, centroid.y, centroid.x)
		tri(c0, pa0, pb0, _color(color, Vector3.LEFT), Vector3.LEFT)
		tri(c1, pa1, pb1, _color(color, Vector3.RIGHT), Vector3.RIGHT)


## Flat plate: a planar convex polygon given by `points`, thickened by `thickness` along its
## normal. Used for wings, fins and signs.
func slab(points: Array, thickness: float, color) -> void:
	var pts: Array[Vector3] = []
	pts.assign(points)
	var n := pts.size()
	var normal := (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
	var half := normal * thickness * 0.5
	var center := Vector3.ZERO
	for p in pts:
		center += p
	center /= n
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		tri(center + half, a + half, b + half, _color(color, normal), normal)
		tri(center - half, a - half, b - half, _color(color, -normal), -normal)
		var out := (a + b) * 0.5 - center
		quad(a - half, b - half, b + half, a + half, _color(color, out.normalized()), out)


## Straight round bar from `a` to `b`.
func tube(a: Vector3, b: Vector3, radius: float, color, sides := 6) -> void:
	cylinder(a, b - a, radius, radius, sides, color, true)


## Flat double-sided annulus in the plane perpendicular to `normal`.
func ring(center: Vector3, normal: Vector3, r_in: float, r_out: float, segments: int, colors: Array) -> void:
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := up.cross(side)
	var bands := colors.size()
	for b in bands:
		var ra := lerpf(r_in, r_out, float(b) / bands)
		var rb := lerpf(r_in, r_out, float(b + 1) / bands)
		for k in segments:
			var a0 := TAU * k / segments
			var a1 := TAU * (k + 1) / segments
			var d0 := side * cos(a0) + fwd * sin(a0)
			var d1 := side * cos(a1) + fwd * sin(a1)
			var col := vary(colors[b], 0.05)
			quad(center + d0 * ra, center + d1 * ra, center + d1 * rb, center + d0 * rb, col, up)
			quad(center + d0 * ra, center + d1 * ra, center + d1 * rb, center + d0 * rb, col, -up)


func _color(color, dir: Vector3) -> Color:
	if color is Callable:
		return color.call(dir)
	return vary(color)


func _band(bands: Array, t: float) -> Color:
	t += rand(-0.04, 0.04)
	for band: Array in bands:
		if t <= band[0]:
			return vary(band[1], 0.05)
	return vary(bands[-1][1], 0.05)


func _out(point: Vector3, base: Vector3) -> Vector3:
	var d := point - base
	return Vector3(d.x, 0.35 * d.length() * 0.2, d.z)


static func _hash(v: Vector3, seed_offset: float) -> float:
	return fposmod(sin(v.x * 12.9898 + v.y * 78.233 + v.z * 37.719 + seed_offset) * 43758.5453, 1.0)


static func _icosphere(subdiv: int) -> Array:
	if _ico_cache.has(subdiv):
		return _ico_cache[subdiv]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4],
		[11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8],
		[3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var tris: Array = []
	for f: Array in faces:
		tris.append([v[f[0]].normalized(), v[f[1]].normalized(), v[f[2]].normalized()])
	for k in subdiv:
		var next: Array = []
		for tr: Array in tris:
			var a: Vector3 = tr[0]
			var b: Vector3 = tr[1]
			var c: Vector3 = tr[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			next.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
		tris = next
	_ico_cache[subdiv] = tris
	return tris
