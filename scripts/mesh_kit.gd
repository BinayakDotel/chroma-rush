class_name MeshKit
extends RefCounted
## Builds vertex-coloured low-poly meshes out of simple shapes.
##
## Two looks share one kit:
## - faceted (the default): every triangle is flat-shaded, with a little random brightness per
##   face. Used for rocks, cliffs, trees and other scenery.
## - smooth (`smooth = true`): rounded shapes get smooth normals and clean colours, and the
##   finished mesh is indexed so shared vertices are stored once. Used for vehicles, drivers,
##   pickups and anything meant to look moulded rather than chiselled.
##
## Colours can be a Color or a Callable. Faceted shapes call it with the face's direction from
## the shape's centre; smooth shapes call it once per vertex, the lofted ones (grid, lathe,
## loft, rounded_box, capsule) with the vertex position instead.

static var _ico_cache := {}

var rng := RandomNumberGenerator.new()
## Smooth normals and per-vertex colours for the shapes added from now on.
var smooth := false
## Random brightness variation applied to plain colours (0 for a clean, even surface).
var variation := 0.06
var _st := SurfaceTool.new()
var _count := 0
var _indexed := false


func _init(seed_value := 0, smooth_shapes := false) -> void:
	rng.seed = seed_value
	smooth = smooth_shapes
	if smooth:
		variation = 0.0
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func rand(a: float, b: float) -> float:
	return rng.randf_range(a, b)


## Colour with a little random brightness variation, for a faceted look.
func vary(color: Color, amount := 0.06) -> Color:
	if amount <= 0.0:
		return color
	var k := rand(1.0 - amount, 1.0 + amount)
	return Color(color.r * k, color.g * k, color.b * k, color.a)


## Number of triangles added so far.
func triangle_count() -> int:
	return _count


## Adds one flat triangle, flipped if needed so it faces `outward`.
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


## Adds one triangle with a normal and a colour per corner. It is wound to face the way its
## normals point.
func tri_smooth(a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3,
		ca: Color, cb: Color, cc: Color) -> void:
	var face := (b - a).cross(c - a)
	if face.length_squared() < 1e-14:
		return
	_indexed = true
	_count += 1
	if face.dot(na + nb + nc) < 0.0:
		_vertex(a, na, ca)
		_vertex(b, nb, cb)
		_vertex(c, nc, cc)
	else:
		_vertex(a, na, ca)
		_vertex(c, nc, cc)
		_vertex(b, nb, cb)


## Finishes the mesh. Pass `into` to append this as another surface of an existing mesh.
func commit(material: Material, into: ArrayMesh = null) -> ArrayMesh:
	if _count == 0:
		return into if into else ArrayMesh.new()
	if _indexed:
		# Smooth shapes share vertices between triangles: store each one once.
		_st.index()
	var mesh := _st.commit(into) if into else _st.commit()
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func sphere(center: Vector3, radius: Vector3, subdiv: int, jitter: float, color, seed_offset := 0.0) -> void:
	for t: Array in _icosphere(subdiv):
		var p: Array[Vector3] = []
		for v: Vector3 in t:
			p.append(center + v * (1.0 + jitter * (_hash(v, seed_offset) - 0.5) * 2.0) * radius)
		if smooth:
			var n: Array[Vector3] = []
			var c: Array[Color] = []
			for v: Vector3 in t:
				# Normal of an ellipsoid: the direction scaled by the inverse radii.
				n.append((v / radius).normalized())
				c.append(color.call(v) if color is Callable else color)
			tri_smooth(p[0], p[1], p[2], n[0], n[1], n[2], c[0], c[1], c[2])
		else:
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
	var normals: Array[Vector3] = []
	var phase := rand(0.0, TAU)
	var slope := (r0 - r1) / maxf(axis.length(), 0.0001)
	for k in sides:
		var a := phase + TAU * k / sides
		var dir := side * cos(a) + fwd * sin(a)
		ring0.append(base + dir * r0 * (1.0 + rand(-jitter, jitter)))
		ring1.append(top + dir * r1 * (1.0 + rand(-jitter, jitter)))
		normals.append((dir + up * slope).normalized())
	for k in sides:
		var n := (k + 1) % sides
		var centroid := (ring0[k] + ring0[n] + ring1[k] + ring1[n]) / 4.0
		var out := centroid - (base + up * (centroid - base).dot(up))
		var col := _color(color, (centroid - base).normalized())
		if smooth:
			tri_smooth(ring0[k], ring0[n], ring1[n], normals[k], normals[n], normals[n], col, col, col)
			if r1 > 0.001:
				tri_smooth(ring0[k], ring1[n], ring1[k], normals[k], normals[n], normals[k], col, col, col)
		elif r1 > 0.001:
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


## Box with slightly jittered corners. `basis` turns it about its centre.
func box(center: Vector3, size: Vector3, color, jitter := 0.0, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var c: Array[Vector3] = []
	for i in 8:
		var s := Vector3(1 if i & 1 else -1, 1 if i & 2 else -1, 1 if i & 4 else -1)
		c.append(center + basis * (s * h) + Vector3(rand(-jitter, jitter), rand(-jitter, jitter), rand(-jitter, jitter)))
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	for f: Array in faces:
		var mid: Vector3 = (c[f[0]] + c[f[1]] + c[f[2]] + c[f[3]]) / 4.0
		quad(c[f[0]], c[f[1]], c[f[2]], c[f[3]], _color(color, (mid - center).normalized()), mid - center)


## Box with rounded edges and corners, smooth-shaded: the building block for anything moulded.
## `radius` is clamped to half the smallest side. `basis` turns the box about its centre.
func rounded_box(center: Vector3, size: Vector3, radius: float, color, basis := Basis.IDENTITY) -> void:
	var h := size * 0.5
	var r := minf(radius, minf(h.x, minf(h.y, h.z)) - 0.0005)
	var inner := h - Vector3.ONE * r
	# Each face is a 3 x 3 grid: a flat middle and a bevel strip along every edge. Vertices on
	# the cube's surface are pushed back onto the rounded shape.
	for axis in 3:
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var us := [-h[u], -inner[u], inner[u], h[u]]
		var vs := [-h[v], -inner[v], inner[v], h[v]]
		for side: float in [-1.0, 1.0]:
			var rows: Array = []
			for a: float in us:
				var row := PackedVector3Array()
				for b: float in vs:
					var p := Vector3.ZERO
					p[axis] = h[axis] * side
					p[u] = a
					p[v] = b
					row.append(p)
				rows.append(row)
			for i in 3:
				for j in 3:
					var corners: Array[Vector3] = [rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]]
					var pos: Array[Vector3] = []
					var nrm: Array[Vector3] = []
					var col: Array[Color] = []
					for p: Vector3 in corners:
						var core := p.clamp(-inner, inner)
						var n := (p - core).normalized()
						var at := center + basis * (core + n * r)
						pos.append(at)
						nrm.append(basis * n)
						col.append(_paint(color, at, basis * n))
					tri_smooth(pos[0], pos[1], pos[2], nrm[0], nrm[1], nrm[2], col[0], col[1], col[2])
					tri_smooth(pos[0], pos[2], pos[3], nrm[0], nrm[2], nrm[3], col[0], col[2], col[3])


## Smooth surface through rows of points (each row the same length). With `wrap`, each row is a
## closed ring. Normals come from the neighbouring points, so shapes built this way shade as one
## continuous surface; repeat a row to get a hard crease there. The surface faces the way
## (next point in the row - previous) x (next row - previous row) points; `flip` turns it over.
func grid(rows: Array, wrap: bool, color, flip := false) -> void:
	var count := rows.size()
	var width: int = rows[0].size()
	var normals: Array = []
	for r in count:
		var row: PackedVector3Array = rows[r]
		var before: PackedVector3Array = rows[maxi(r - 1, 0)]
		var after: PackedVector3Array = rows[mini(r + 1, count - 1)]
		# A repeated row marks a crease: look only to the side that differs.
		if r > 0 and r < count - 1:
			if _same_row(row, after):
				after = row
			elif _same_row(row, before):
				before = row
		var out := PackedVector3Array()
		for c in width:
			var left := row[posmod(c - 1, width)] if wrap else row[maxi(c - 1, 0)]
			var right := row[(c + 1) % width] if wrap else row[mini(c + 1, width - 1)]
			var n := (right - left).cross(after[c] - before[c])
			if n.length_squared() < 1e-12:
				# A pole (the ring has shrunk to a point): face along the shape's axis, away
				# from the neighbouring ring.
				n = _centre(row) - _centre(after if r == 0 else before)
			elif flip:
				n = -n
			out.append(n.normalized())
		normals.append(out)
	var last_col := width if wrap else width - 1
	for r in count - 1:
		var a: PackedVector3Array = rows[r]
		var b: PackedVector3Array = rows[r + 1]
		var na: PackedVector3Array = normals[r]
		var nb: PackedVector3Array = normals[r + 1]
		for c in last_col:
			var d := (c + 1) % width
			var c00 := _paint(color, a[c], na[c])
			var c01 := _paint(color, a[d], na[d])
			var c10 := _paint(color, b[c], nb[c])
			var c11 := _paint(color, b[d], nb[d])
			tri_smooth(a[c], a[d], b[d], na[c], na[d], nb[d], c00, c01, c11)
			tri_smooth(a[c], b[d], b[c], na[c], nb[d], nb[c], c00, c11, c10)


## Surface of revolution around `axis` from `base`: `profile` is a list of (radius, height)
## points from the base end to the far end, traced with the solid on the inside. A radius of 0
## closes an end; repeat a point for a crease.
func lathe(base: Vector3, axis: Vector3, profile: Array, sides: int, color) -> void:
	var up := axis.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := up.cross(side)
	var rows: Array = []
	for point: Vector2 in profile:
		var row := PackedVector3Array()
		for k in sides:
			var a := TAU * k / sides
			row.append(base + up * point.y + (side * cos(a) + fwd * sin(a)) * point.x)
		rows.append(row)
	grid(rows, true, color)


## Rounded bar from `a` to `b` with hemispherical ends.
func capsule(a: Vector3, b: Vector3, radius: float, color, sides := 8) -> void:
	var length := (b - a).length()
	var profile: Array = []
	for j in 4:
		var angle := PI * 0.5 * j / 3.0
		profile.append(Vector2(sin(angle) * radius, -cos(angle) * radius))
	for j in range(3, -1, -1):
		var angle := PI * 0.5 * j / 3.0
		profile.append(Vector2(sin(angle) * radius, length + cos(angle) * radius))
	lathe(a, (b - a) if length > 0.0001 else Vector3.UP, profile, sides, color)


## Ring-shaped tube around `center` in the plane facing `normal`: steering wheels, collars,
## scarves, rims. `squash` flattens the tube along the normal (1 = round).
func torus(center: Vector3, normal: Vector3, radius: float, thickness: float, color, segments := 14, sides := 6, squash := 1.0) -> void:
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var fwd := up.cross(side)
	var rows: Array = []
	for i in segments + 1:
		var a := TAU * i / segments
		var dir := side * cos(a) + fwd * sin(a)
		var row := PackedVector3Array()
		for j in sides:
			var b := TAU * j / sides
			row.append(center + dir * (radius + cos(b) * thickness) + up * sin(b) * thickness * squash)
		rows.append(row)
	grid(rows, true, color, true)


## Round bar following `path` (a list of points), with rounded ends: bent pipes, runners, cages.
func pipe(path: Array, radius: float, color, sides := 6) -> void:
	var rows: Array = []
	var count := path.size()
	var reference := Vector3.UP
	for i in count:
		var here: Vector3 = path[i]
		var along: Vector3 = (path[mini(i + 1, count - 1)] - path[maxi(i - 1, 0)]).normalized()
		if absf(along.dot(reference)) > 0.95:
			reference = Vector3.RIGHT
		var side := along.cross(reference).normalized()
		var up := side.cross(along)
		var row := PackedVector3Array()
		for j in sides:
			var a := TAU * j / sides
			row.append(here + (side * cos(a) + up * sin(a)) * radius)
		rows.append(row)
	# Close each end on a point just past it, which rounds the tip off.
	var first: Vector3 = path[0]
	var last: Vector3 = path[count - 1]
	var tip_in := PackedVector3Array()
	var tip_out := PackedVector3Array()
	tip_in.resize(sides)
	tip_out.resize(sides)
	tip_in.fill(first + (first - path[1]).normalized() * radius * 0.6)
	tip_out.fill(last + (last - path[count - 2]).normalized() * radius * 0.6)
	rows.push_front(tip_in)
	rows.append(tip_out)
	grid(rows, true, color, true)


## Body shell swept along Z through a list of cross-sections, each a rounded rectangle:
##   {z, w, h}  position along the body, half width and half height
##   y, x       centre offset (default 0)
##   p          roundness: 2 is an ellipse, higher is boxier (default 2.6)
##   flat       0..1 squashes the underside flat (default 0)
## The ends are closed with a flat cap unless the first or last section is tiny.
func loft(sections: Array, sides: int, color) -> void:
	var rows: Array = []
	for section: Dictionary in sections:
		var power := 2.0 / float(section.get("p", 2.6))
		var centre := Vector3(float(section.get("x", 0.0)), float(section.get("y", 0.0)), float(section.z))
		var flat := float(section.get("flat", 0.0))
		var row := PackedVector3Array()
		for k in sides:
			# Start at the top and go round, so every section's points line up.
			var a := TAU * (k + 0.5) / sides
			var cx := sin(a)
			var cy := cos(a)
			var y := signf(cy) * pow(absf(cy), power) * float(section.h)
			if y < 0.0:
				y *= 1.0 - flat
			row.append(centre + Vector3(signf(cx) * pow(absf(cx), power) * float(section.w), y, 0.0))
		rows.append(row)
	var towards_back := float(sections[0].z) < float(sections[-1].z)
	grid(rows, true, color, towards_back)
	for end in [0, rows.size() - 1]:
		var row: PackedVector3Array = rows[end]
		var section: Dictionary = sections[end]
		if float(section.w) < 0.02 or float(section.h) < 0.02:
			continue
		var centre := _centre(row)
		var normal := Vector3.FORWARD if towards_back else Vector3.BACK
		if end != 0:
			normal = -normal
		for k in sides:
			var n := (k + 1) % sides
			var c := _paint(color, centre, normal)
			tri_smooth(centre, row[k], row[n], normal, normal, normal, c, c, c)


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
			var col := vary(colors[b], 0.05 if variation > 0.0 else 0.0)
			quad(center + d0 * ra, center + d1 * ra, center + d1 * rb, center + d0 * rb, col, up)
			quad(center + d0 * ra, center + d1 * ra, center + d1 * rb, center + d0 * rb, col, -up)


func _vertex(position: Vector3, normal: Vector3, color: Color) -> void:
	_st.set_color(color)
	_st.set_normal(normal)
	_st.add_vertex(position)


func _color(color, dir: Vector3) -> Color:
	if color is Callable:
		return color.call(dir)
	return vary(color, variation)


## Colour for a vertex of a lofted shape: a plain Color, or a Callable(position, normal).
func _paint(color, position: Vector3, normal: Vector3) -> Color:
	if color is Callable:
		return color.call(position, normal)
	return color


func _centre(points: PackedVector3Array) -> Vector3:
	var sum := Vector3.ZERO
	for p in points:
		sum += p
	return sum / points.size()


func _same_row(a: PackedVector3Array, b: PackedVector3Array) -> bool:
	for i in a.size():
		if not a[i].is_equal_approx(b[i]):
			return false
	return true


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
