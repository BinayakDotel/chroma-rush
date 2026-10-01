class_name Vehicles
## Player vehicles, one per world, each driven by a chibi character: big head, big glossy eyes,
## blush cheeks. Bodies are moulded shapes (lofted shells, rounded boxes, bent pipes), smooth
## shaded, not stacks of boxes. Painted panels take the current gate colour (`paint` material);
## glowing bits use `glow`, visors and canopies `glass`; the rest keeps its own vertex colours.
##
## The vehicle is two layers: wheels sit directly on the root and stay on the road; everything
## else hangs from the "chassis" node, which Racer leans and bounces like a body on springs.
## Moving parts are listed in metadata so Racer can animate them:
##   "chassis"  the sprung body (driver, panels, everything but the wheels)
##   "wheels"   spinning wheel nodes (rotate around X; each has a "radius" meta)
##   "steer"    front wheel pivots (rotate around Y when changing lanes)
##   "head"     driver head pivot
##   "wobblers" floppy parts (ears, tails, scarves, antennas) driven by a spring
##   "flames"   engine flames, stretched along their local +Z with throttle
##   "trail"    local position where dust / snow / sparks are emitted
##   "hover", "bob"  extra ride height and float amplitude (hovering vehicles only)

## Road height in body space: the body origin sits Racer.SIZE * 0.5 + Racer.HOVER above the road.
const ROAD := -0.6

const TIRE := Color(0.15, 0.15, 0.19)
const RIM := Color(0.9, 0.91, 0.95)
const DARK := Color(0.16, 0.16, 0.22)
const METAL := Color(0.46, 0.48, 0.56)
const CHROME := Color(0.86, 0.88, 0.94)
const SEAT := Color(0.27, 0.28, 0.38)
const LENS := Color(0.4, 0.78, 1.0)
const WHITE := Color(0.98, 0.98, 0.99)
## Painted panels are white (the material tints them); this is the tone of their undersides.
const UNDER := Color(0.78, 0.78, 0.82)
const EYE := Color(0.09, 0.08, 0.14)
const BLUSH := Color(1.0, 0.58, 0.66)
## Accessories avoid the gate hues so they never read as a gate colour.
const TEAL := Color(0.1, 0.7, 0.64)
const HEADLIGHT := Color(1.0, 0.95, 0.7)


static func build(kind: String, mats: Dictionary) -> Node3D:
	var rig := Rig.new(mats)
	match kind:
		"kart":
			_kart(rig)
		"sled":
			_bobsled(rig)
		"buggy":
			_buggy(rig)
		"monster":
			_monster(rig)
		"rocket":
			_star_racer(rig)
		_:
			_kart(rig)
	return rig.finish()


# --- go-kart + fox (meadow) ------------------------------------------------

static func _kart(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	d.rounded_box(Vector3(0, -0.45, 0.02), Vector3(0.72, 0.07, 1.46), 0.03, DARK)
	# One shell from the nose, widening past the seat, to the tail.
	p.loft([
		{"z": -1.0, "w": 0.01, "h": 0.01, "y": -0.36},
		{"z": -0.96, "w": 0.1, "h": 0.06, "y": -0.36},
		{"z": -0.75, "w": 0.17, "h": 0.1, "y": -0.34, "p": 3.0},
		{"z": -0.35, "w": 0.27, "h": 0.14, "y": -0.31, "p": 3.0},
		{"z": 0.05, "w": 0.4, "h": 0.17, "y": -0.29, "p": 3.4},
		{"z": 0.45, "w": 0.4, "h": 0.18, "y": -0.28, "p": 3.4},
		{"z": 0.7, "w": 0.3, "h": 0.15, "y": -0.27, "p": 3.0},
		{"z": 0.78, "w": 0.01, "h": 0.01, "y": -0.27},
	], 14, _two_tone())
	# Front wing with end plates.
	p.rounded_box(Vector3(0, -0.44, -0.9), Vector3(1.0, 0.05, 0.2), 0.022, WHITE)
	for x in [-0.5, 0.5]:
		p.rounded_box(Vector3(x, -0.4, -0.9), Vector3(0.05, 0.15, 0.25), 0.022, WHITE)
	# Rear wing on two struts.
	for x in [-0.22, 0.22]:
		d.capsule(Vector3(x, -0.14, 0.66), Vector3(x, 0.24, 0.8), 0.026, DARK)
	p.rounded_box(Vector3(0, 0.27, 0.82), Vector3(1.04, 0.06, 0.3), 0.028, WHITE)
	for x in [-0.52, 0.52]:
		p.rounded_box(Vector3(x, 0.22, 0.82), Vector3(0.05, 0.2, 0.34), 0.024, WHITE)
	# Cockpit rim, headrest, engine and exhausts.
	d.torus(Vector3(0, -0.12, 0.2), Vector3.UP, 0.23, 0.045, SEAT, 14, 6)
	d.rounded_box(Vector3(0, 0.0, 0.44), Vector3(0.34, 0.3, 0.1), 0.05, SEAT)
	d.rounded_box(Vector3(0, -0.14, 0.6), Vector3(0.36, 0.14, 0.22), 0.05, METAL)
	for x in [-0.2, 0.2]:
		d.pipe([Vector3(x, -0.2, 0.58), Vector3(x, -0.19, 0.72), Vector3(x * 1.05, -0.15, 0.84)], 0.038, METAL.lightened(0.25))
	# Steering wheel, number roundel and nose light.
	d.capsule(Vector3(0, -0.2, -0.3), Vector3(0, -0.07, -0.11), 0.02, DARK)
	d.torus(Vector3(0, -0.05, -0.09), Vector3(0, 0.55, -0.83), 0.1, 0.022, DARK, 12, 5)
	d.sphere(Vector3(0, -0.185, -0.52), Vector3(0.085, 0.012, 0.085), 1, 0.0, WHITE)
	r.glow.sphere(Vector3(0, -0.35, -0.985), Vector3(0.05, 0.035, 0.025), 1, 0.0, HEADLIGHT)

	for x in [-0.5, 0.5]:
		r.wheel(Vector3(x, ROAD + 0.2, -0.55), 0.2, 0.2, true, false)
		r.wheel(Vector3(x * 1.06, ROAD + 0.26, 0.5), 0.26, 0.28, false, false)

	# Fox: orange coat, cream chest and muzzle, teal scarf, a bushy tail out the back.
	var fur := Color(0.98, 0.55, 0.17)
	var cream := Color(1.0, 0.94, 0.84)
	var chest := func(dir: Vector3) -> Color:
		return fur.lerp(cream, smoothstep(0.2, 0.6, -dir.z) * smoothstep(0.6, 0.0, dir.y))
	d.sphere(Vector3(0, -0.02, 0.2), Vector3(0.19, 0.22, 0.17), 2, 0.0, chest)
	for x in [-1.0, 1.0]:
		d.capsule(Vector3(x * 0.16, 0.03, 0.14), Vector3(x * 0.1, -0.05, -0.07), 0.05, fur)
		d.sphere(Vector3(x * 0.1, -0.05, -0.09), Vector3.ONE * 0.058, 1, 0.0, cream)
	d.torus(Vector3(0, 0.12, 0.2), Vector3.UP, 0.13, 0.05, TEAL, 12, 6, 0.8)
	var scarf := r.part(Vector3(0.07, 0.12, 0.33), true)
	scarf.detail.rounded_box(Vector3(0, -0.01, 0.13), Vector3(0.1, 0.035, 0.26), 0.016, TEAL)
	scarf.node.rotation.x = 0.35
	var tail := r.part(Vector3(0, -0.04, 0.5), true)
	var tail_col := func(dir: Vector3) -> Color: return fur.lerp(cream, smoothstep(0.35, 0.7, dir.z))
	tail.detail.sphere(Vector3(0, 0.0, 0.24), Vector3(0.11, 0.11, 0.27), 2, 0.0, tail_col)
	tail.node.rotation.x = 0.25

	var head := r.head_part(Vector3(0, 0.27, 0.18))
	var h := head.detail
	h.sphere(Vector3(0, 0.08, 0), Vector3(0.26, 0.23, 0.24), 3, 0.0, fur)
	h.sphere(Vector3(0, 0.01, -0.15), Vector3(0.16, 0.11, 0.13), 1, 0.0, cream)
	h.sphere(Vector3(0, 0.035, -0.275), Vector3(0.036, 0.028, 0.026), 1, 0.0, EYE)
	_eyes(h, Vector3(0, 0.12, -0.205), 0.105, 0.05)
	_cheeks(h, Vector3(0, 0.04, -0.2), 0.17)
	# Goggles pushed up on the forehead.
	h.torus(Vector3(0, 0.21, 0.0), Vector3(0, 1, 0.12), 0.215, 0.02, SEAT, 16, 5, 1.6)
	for x in [-0.085, 0.085]:
		_goggle(h, Vector3(x, 0.235, -0.185), Vector3(x * 1.2, 0.45, -1.0))
	for x in [-1.0, 1.0]:
		var ear := r.part(Vector3(x * 0.15, 0.25, 0.02), true, head.node)
		var tip := func(at: Vector3, _n: Vector3) -> Color: return fur.lerp(EYE, smoothstep(0.12, 0.17, at.y))
		ear.detail.lathe(Vector3.ZERO, Vector3(x * 0.25, 1.0, 0.0), [
			Vector2(0.09, 0.0), Vector2(0.075, 0.09), Vector2(0.035, 0.19), Vector2(0.0, 0.235)], 8, tip)
		ear.detail.sphere(Vector3(x * 0.02, 0.09, -0.045), Vector3(0.04, 0.075, 0.02), 1, 0.0, cream)
	r.trail = Vector3(0, ROAD + 0.05, 0.75)


# --- bobsled + penguin (glacier) -------------------------------------------

static func _bobsled(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	p.loft([
		{"z": -1.02, "w": 0.01, "h": 0.01, "y": -0.3},
		{"z": -0.97, "w": 0.14, "h": 0.09, "y": -0.3},
		{"z": -0.75, "w": 0.3, "h": 0.17, "y": -0.28, "p": 2.8, "flat": 0.25},
		{"z": -0.3, "w": 0.4, "h": 0.22, "y": -0.26, "p": 3.2, "flat": 0.3},
		{"z": 0.3, "w": 0.42, "h": 0.22, "y": -0.26, "p": 3.2, "flat": 0.3},
		{"z": 0.7, "w": 0.38, "h": 0.19, "y": -0.24, "p": 3.0, "flat": 0.25},
		{"z": 0.86, "w": 0.26, "h": 0.12, "y": -0.22, "p": 2.6},
		{"z": 0.9, "w": 0.01, "h": 0.01, "y": -0.22},
	], 14, _two_tone())
	d.torus(Vector3(0, -0.045, 0.12), Vector3.UP, 0.28, 0.045, DARK, 16, 6)
	# Runners with curled tips, on struts, and a push bar at the back.
	for x in [-0.3, 0.3]:
		d.pipe([Vector3(x, ROAD + 0.04, 0.82), Vector3(x, ROAD + 0.035, -0.62), Vector3(x, ROAD + 0.09, -0.84),
			Vector3(x, ROAD + 0.22, -0.95)], 0.032, CHROME)
		for z in [-0.42, 0.46]:
			d.capsule(Vector3(x, ROAD + 0.05, z), Vector3(x * 0.92, -0.36, z), 0.028, DARK)
	d.pipe([Vector3(-0.3, -0.14, 0.76), Vector3(-0.3, 0.06, 0.94), Vector3(0.3, 0.06, 0.94), Vector3(0.3, -0.14, 0.76)], 0.03, DARK)
	r.glow.sphere(Vector3(0, -0.29, -1.0), Vector3(0.06, 0.04, 0.03), 1, 0.0, HEADLIGHT)

	# Penguin: round body, white tummy, flippers out for balance.
	var black := Color(0.17, 0.19, 0.3)
	d.sphere(Vector3(0, 0.14, 0.12), Vector3(0.27, 0.3, 0.25), 2, 0.0, black)
	d.sphere(Vector3(0, 0.11, 0.03), Vector3(0.21, 0.25, 0.2), 2, 0.0, WHITE)
	for x in [-1.0, 1.0]:
		var flipper := r.part(Vector3(x * 0.25, 0.27, 0.1), true)
		flipper.detail.sphere(Vector3(x * 0.04, -0.12, 0), Vector3(0.05, 0.16, 0.1), 1, 0.0, black)
		flipper.node.rotation.z = x * 0.4
	d.torus(Vector3(0, 0.38, 0.11), Vector3.UP, 0.18, 0.055, TEAL, 14, 6, 0.8)
	var scarf := r.part(Vector3(0.1, 0.39, 0.27), true)
	scarf.detail.rounded_box(Vector3(0, -0.01, 0.15), Vector3(0.11, 0.035, 0.3), 0.016, TEAL)
	scarf.detail.rounded_box(Vector3(0, -0.01, 0.27), Vector3(0.115, 0.04, 0.04), 0.016, WHITE)
	scarf.node.rotation.x = 0.3

	var head := r.head_part(Vector3(0, 0.56, 0.1))
	var h := head.detail
	h.sphere(Vector3(0, 0.06, 0), Vector3(0.24, 0.22, 0.22), 3, 0.0, black)
	h.sphere(Vector3(0, 0.03, -0.075), Vector3(0.19, 0.16, 0.165), 2, 0.0, WHITE)
	h.lathe(Vector3(0, 0.02, -0.215), Vector3(0, -0.2, -1.0), [Vector2(0.06, 0.0), Vector2(0.045, 0.05), Vector2(0.0, 0.11)],
		8, Color(1.0, 0.64, 0.16))
	_eyes(h, Vector3(0, 0.075, -0.212), 0.092, 0.052)
	_cheeks(h, Vector3(0, 0.0, -0.225), 0.14)
	# Beanie in the paint colour, so the driver shows the current colour too.
	head.paint.lathe(Vector3(0, 0.17, 0), Vector3.UP, [
		Vector2(0.225, 0.0), Vector2(0.22, 0.07), Vector2(0.175, 0.15), Vector2(0.09, 0.2), Vector2(0.0, 0.215)], 14, WHITE)
	h.torus(Vector3(0, 0.185, 0), Vector3.UP, 0.212, 0.042, WHITE, 16, 6)
	var pompom := r.part(Vector3(0, 0.385, 0.02), true, head.node)
	pompom.detail.sphere(Vector3(0, 0.04, 0), Vector3.ONE * 0.078, 1, 0.0, WHITE)
	r.trail = Vector3(0, ROAD + 0.05, 0.7)


# --- dune buggy + gecko (canyon) -------------------------------------------

static func _buggy(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	d.rounded_box(Vector3(0, -0.35, 0), Vector3(0.76, 0.1, 1.4), 0.04, DARK)
	# Body: raised hood, low cockpit, engine cover.
	p.loft([
		{"z": -0.93, "w": 0.3, "h": 0.1, "y": -0.25, "p": 4.0},
		{"z": -0.84, "w": 0.37, "h": 0.14, "y": -0.23, "p": 4.0},
		{"z": -0.42, "w": 0.4, "h": 0.18, "y": -0.19, "p": 4.0},
		{"z": -0.22, "w": 0.42, "h": 0.13, "y": -0.24, "p": 4.0},
		{"z": 0.3, "w": 0.42, "h": 0.13, "y": -0.24, "p": 4.0},
		{"z": 0.46, "w": 0.4, "h": 0.2, "y": -0.17, "p": 4.0},
		{"z": 0.8, "w": 0.37, "h": 0.17, "y": -0.19, "p": 4.0},
		{"z": 0.89, "w": 0.28, "h": 0.1, "y": -0.21, "p": 4.0},
	], 16, _two_tone())
	d.capsule(Vector3(-0.38, -0.32, -0.97), Vector3(0.38, -0.32, -0.97), 0.045, DARK)
	# Roll cage: a hoop each side joined across the top, with a light bar.
	for x in [-1.0, 1.0]:
		d.pipe([Vector3(x * 0.37, -0.14, -0.3), Vector3(x * 0.32, 0.62, -0.16), Vector3(x * 0.32, 0.66, 0.34),
			Vector3(x * 0.37, -0.12, 0.47)], 0.03, DARK)
		r.glow.sphere(Vector3(x * 0.24, -0.2, -0.925), Vector3(0.06, 0.05, 0.03), 1, 0.0, HEADLIGHT)
	d.capsule(Vector3(-0.32, 0.66, 0.34), Vector3(0.32, 0.66, 0.34), 0.03, DARK)
	d.capsule(Vector3(-0.32, 0.62, -0.16), Vector3(0.32, 0.62, -0.16), 0.03, DARK)
	d.rounded_box(Vector3(0, 0.7, -0.16), Vector3(0.5, 0.075, 0.075), 0.03, DARK)
	for x in [-0.18, -0.06, 0.06, 0.18]:
		r.glow.sphere(Vector3(x, 0.7, -0.2), Vector3(0.042, 0.028, 0.012), 1, 0.0, HEADLIGHT)
	# Spare tyre on the back.
	d.lathe(Vector3(0, 0.0, 0.86), Vector3.BACK, [Vector2(0.08, 0.0), Vector2(0.18, 0.0), Vector2(0.21, 0.03),
		Vector2(0.21, 0.1), Vector2(0.18, 0.13), Vector2(0.08, 0.13)], 12, TIRE)
	d.sphere(Vector3(0, 0.0, 0.97), Vector3(0.09, 0.09, 0.025), 1, 0.0, RIM)
	var antenna := r.part(Vector3(0.32, 0.66, 0.36), true)
	antenna.detail.capsule(Vector3.ZERO, Vector3(0, 0.6, 0.05), 0.012, DARK, 5)
	antenna.detail.slab([Vector3(0, 0.6, 0.05), Vector3(0, 0.48, 0.05), Vector3(0, 0.54, 0.25)], 0.012, Color(1.0, 0.58, 0.12))

	for x in [-0.58, 0.58]:
		r.wheel(Vector3(x, ROAD + 0.3, -0.52), 0.3, 0.28, true, true)
		r.wheel(Vector3(x, ROAD + 0.3, 0.52), 0.3, 0.28, false, true)

	# Gecko cowboy: green skin, huge eyes, hat and bandana.
	var skin := Color(0.45, 0.8, 0.32)
	var tummy := Color(0.88, 0.96, 0.66)
	var front := func(dir: Vector3) -> Color: return skin.lerp(tummy, smoothstep(0.25, 0.65, -dir.z))
	d.sphere(Vector3(0, -0.01, 0.12), Vector3(0.19, 0.21, 0.17), 2, 0.0, front)
	for x in [-1.0, 1.0]:
		d.capsule(Vector3(x * 0.15, 0.06, 0.08), Vector3(x * 0.1, -0.02, -0.13), 0.048, skin)
		d.sphere(Vector3(x * 0.1, -0.02, -0.15), Vector3.ONE * 0.055, 1, 0.0, skin)
	d.capsule(Vector3(0, -0.2, -0.3), Vector3(0, -0.03, -0.17), 0.02, DARK)
	d.torus(Vector3(0, -0.01, -0.15), Vector3(0, 0.55, -0.83), 0.1, 0.022, DARK, 12, 5)
	d.torus(Vector3(0, 0.15, 0.12), Vector3.UP, 0.12, 0.05, TEAL, 12, 6, 0.8)
	var knot := r.part(Vector3(0, 0.14, 0.25), true)
	knot.detail.slab([Vector3(-0.09, 0.0, 0.0), Vector3(0.09, 0.0, 0.0), Vector3(0.0, -0.13, 0.05)], 0.03, TEAL)

	var head := r.head_part(Vector3(0, 0.3, 0.1))
	var h := head.detail
	h.sphere(Vector3(0, 0.03, -0.02), Vector3(0.25, 0.18, 0.24), 3, 0.0, skin)
	for x in [-1.0, 1.0]:
		h.sphere(Vector3(x * 0.15, 0.12, -0.08), Vector3.ONE * 0.095, 1, 0.0, skin)
		h.sphere(Vector3(x * 0.155, 0.13, -0.115), Vector3.ONE * 0.078, 1, 0.0, WHITE)
		h.sphere(Vector3(x * 0.165, 0.135, -0.172), Vector3(0.042, 0.052, 0.026), 1, 0.0, EYE)
		h.sphere(Vector3(x * 0.15, 0.158, -0.195), Vector3.ONE * 0.015, 1, 0.0, WHITE)
	h.pipe([Vector3(-0.1, -0.035, -0.235), Vector3(0, -0.055, -0.262), Vector3(0.1, -0.035, -0.235)], 0.008, EYE, 4)
	_cheeks(h, Vector3(0, -0.005, -0.215), 0.17)
	# Hat: a wide brim, a creased crown and a dark band.
	var felt := Color(0.66, 0.42, 0.23)
	h.lathe(Vector3(0, 0.2, 0.03), Vector3(0, 1.0, 0.12), [
		Vector2(0.14, 0.0), Vector2(0.27, 0.012), Vector2(0.285, 0.03), Vector2(0.27, 0.045), Vector2(0.165, 0.04),
		Vector2(0.165, 0.04), Vector2(0.145, 0.15), Vector2(0.1, 0.185), Vector2(0.0, 0.17)], 16, felt)
	h.torus(Vector3(0, 0.258, 0.037), Vector3(0, 1.0, 0.12), 0.163, 0.016, DARK, 16, 5, 1.8)
	r.trail = Vector3(0, ROAD + 0.05, 0.75)


# --- monster truck + rock golem (volcano) ----------------------------------

static func _monster(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	# Frame, axles and shocks.
	d.rounded_box(Vector3(0, -0.02, 0), Vector3(0.56, 0.1, 1.3), 0.04, DARK)
	for z in [-0.56, 0.56]:
		d.capsule(Vector3(-0.6, ROAD + 0.43, z), Vector3(0.6, ROAD + 0.43, z), 0.05, DARK)
		for x in [-0.3, 0.3]:
			d.capsule(Vector3(x, ROAD + 0.43, z), Vector3(x * 1.1, 0.02, z * 0.8), 0.04, CHROME)
	# Body: a long tub, a raised hood, an open cab and a pickup bed.
	p.rounded_box(Vector3(0, 0.17, 0), Vector3(0.98, 0.24, 1.5), 0.07, _two_tone(0.09))
	p.rounded_box(Vector3(0, 0.33, -0.47), Vector3(0.9, 0.14, 0.52), 0.06, WHITE)
	for x in [-0.44, 0.44]:
		p.rounded_box(Vector3(x, 0.4, 0.05), Vector3(0.09, 0.22, 0.5), 0.04, WHITE)
		p.rounded_box(Vector3(x, 0.36, 0.5), Vector3(0.08, 0.15, 0.48), 0.035, WHITE)
	p.rounded_box(Vector3(0, 0.36, 0.73), Vector3(0.96, 0.15, 0.08), 0.035, WHITE)
	d.rounded_box(Vector3(0, 0.39, -0.2), Vector3(0.8, 0.16, 0.08), 0.03, DARK)
	d.rounded_box(Vector3(0, 0.29, 0.5), Vector3(0.8, 0.04, 0.44), 0.015, DARK)
	# Windscreen in a frame, and a roll bar behind the cab.
	d.pipe([Vector3(-0.41, 0.47, -0.21), Vector3(-0.39, 0.78, -0.12), Vector3(0.39, 0.78, -0.12), Vector3(0.41, 0.47, -0.21)], 0.03, DARK)
	r.glass.rounded_box(Vector3(0, 0.625, -0.165), Vector3(0.74, 0.3, 0.02), 0.009, WHITE, Basis(Vector3.RIGHT, 0.29))
	d.pipe([Vector3(-0.4, 0.46, 0.27), Vector3(-0.4, 0.86, 0.26), Vector3(0.4, 0.86, 0.26), Vector3(0.4, 0.46, 0.27)], 0.036, DARK)
	# Bull bar, headlights and stacks with flames.
	d.pipe([Vector3(-0.3, 0.04, -0.74), Vector3(-0.32, 0.1, -0.83), Vector3(-0.32, 0.29, -0.82), Vector3(0.32, 0.29, -0.82),
		Vector3(0.32, 0.1, -0.83), Vector3(0.3, 0.04, -0.74)], 0.04, CHROME)
	d.capsule(Vector3(-0.32, 0.12, -0.83), Vector3(0.32, 0.12, -0.83), 0.035, CHROME)
	for x in [-0.3, 0.3]:
		r.glow.sphere(Vector3(x, 0.2, -0.765), Vector3(0.075, 0.06, 0.03), 1, 0.0, HEADLIGHT)
	for x in [-0.36, 0.36]:
		d.lathe(Vector3(x, 0.3, 0.3), Vector3.UP, [Vector2(0.05, 0.0), Vector2(0.05, 0.56), Vector2(0.065, 0.6),
			Vector2(0.065, 0.63), Vector2(0.04, 0.63)], 8, CHROME)
		r.flame(Vector3(x, 0.92, 0.3), Vector3(-PI * 0.5, 0, 0), 0.06, 0.3)

	for x in [-0.66, 0.66]:
		r.wheel(Vector3(x, ROAD + 0.43, -0.56), 0.43, 0.38, true, true)
		r.wheel(Vector3(x, ROAD + 0.43, 0.56), 0.43, 0.38, false, true)

	# Rock golem: rough-cut stone (faceted on purpose, against the smooth truck), mossy on top,
	# with glowing lava seams and eyes.
	var stone := Color(0.68, 0.6, 0.53)
	d.smooth = false
	d.variation = 0.07
	var mossy := func(dir: Vector3) -> Color: return Color(0.4, 0.66, 0.32) if dir.y > 0.8 else d.vary(stone, 0.07)
	d.sphere(Vector3(0, 0.56, 0.08), Vector3(0.24, 0.2, 0.2), 1, 0.2, stone)
	for x in [-1.0, 1.0]:
		d.sphere(Vector3(x * 0.26, 0.58, 0.02), Vector3(0.11, 0.1, 0.1), 0, 0.2, stone)
		d.cylinder(Vector3(x * 0.26, 0.54, -0.02), Vector3(x * -0.06, -0.02, -0.18), 0.06, 0.055, 6, stone.darkened(0.08), true)
	r.glow.box(Vector3(0.06, 0.58, -0.13), Vector3(0.03, 0.12, 0.01), Color(1.0, 0.5, 0.1))
	var head := r.head_part(Vector3(0, 0.78, 0.04))
	var h := head.detail
	h.smooth = false
	h.variation = 0.07
	h.sphere(Vector3(0, 0.1, 0), Vector3(0.26, 0.22, 0.23), 1, 0.18, mossy, 3.0)
	h.smooth = true
	h.variation = 0.0
	for x in [-1.0, 1.0]:
		head.glow.rounded_box(Vector3(x * 0.09, 0.12, -0.2), Vector3(0.085, 0.06, 0.04), 0.018, Color(1.0, 0.72, 0.22))
	head.glow.box(Vector3(-0.12, 0.24, -0.15), Vector3(0.02, 0.1, 0.02), Color(1.0, 0.45, 0.1))
	_cheeks(h, Vector3(0, 0.03, -0.2), 0.17)
	h.pipe([Vector3(-0.05, 0.005, -0.215), Vector3(0, -0.005, -0.225), Vector3(0.05, 0.005, -0.215)], 0.01, EYE, 4)
	d.smooth = true
	d.variation = 0.0
	r.trail = Vector3(0, ROAD + 0.1, 0.8)


# --- star racer + astronaut (space) ----------------------------------------

static func _star_racer(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	p.loft([
		{"z": -1.0, "w": 0.01, "h": 0.01, "y": -0.02},
		{"z": -0.94, "w": 0.07, "h": 0.06, "y": -0.02},
		{"z": -0.6, "w": 0.18, "h": 0.13, "y": 0.0, "p": 2.4},
		{"z": -0.15, "w": 0.3, "h": 0.2, "y": 0.0, "p": 2.6},
		{"z": 0.35, "w": 0.33, "h": 0.22, "y": 0.0, "p": 2.8},
		{"z": 0.75, "w": 0.27, "h": 0.18, "y": 0.02, "p": 2.8},
		{"z": 0.93, "w": 0.16, "h": 0.11, "y": 0.03},
		{"z": 0.96, "w": 0.01, "h": 0.01, "y": 0.03},
	], 14, _two_tone())
	d.lathe(Vector3(0, -0.02, -0.97), Vector3.FORWARD, [Vector2(0.06, 0.0), Vector2(0.03, 0.09), Vector2(0.0, 0.16)], 8, CHROME)
	# Swept wings with dark tips, a tail fin, and an engine pod under each wing.
	for x in [-1.0, 1.0]:
		p.slab([Vector3(x * 0.24, -0.06, -0.12), Vector3(x * 0.9, -0.1, 0.36), Vector3(x * 0.94, -0.1, 0.6),
			Vector3(x * 0.24, -0.06, 0.6)], 0.06, WHITE)
		d.slab([Vector3(x * 0.88, -0.1, 0.36), Vector3(x * 0.96, 0.08, 0.46), Vector3(x * 0.98, 0.08, 0.62),
			Vector3(x * 0.94, -0.1, 0.6)], 0.035, DARK)
		d.lathe(Vector3(x * 0.46, -0.1, 0.1), Vector3.BACK, [Vector2(0.0, -0.06), Vector2(0.08, 0.0), Vector2(0.12, 0.12),
			Vector2(0.125, 0.6), Vector2(0.125, 0.6), Vector2(0.14, 0.62), Vector2(0.14, 0.72), Vector2(0.1, 0.72)], 10, METAL)
		r.glow.sphere(Vector3(x * 0.46, -0.1, 0.8), Vector3(0.09, 0.09, 0.03), 1, 0.0, Color(0.5, 0.9, 1.0))
		r.flame(Vector3(x * 0.46, -0.1, 0.82), Vector3.ZERO, 0.09, 0.55)
	p.slab([Vector3(0, 0.16, 0.42), Vector3(0, 0.54, 0.8), Vector3(0, 0.54, 0.96), Vector3(0, 0.16, 0.9)], 0.05, WHITE)
	for z in [-0.4, 0.05, 0.5]:
		r.glow.sphere(Vector3(0, -0.21, z), Vector3(0.07, 0.025, 0.07), 1, 0.0, Color(0.4, 0.85, 1.0))
	d.torus(Vector3(0, 0.185, 0.0), Vector3.UP, 0.2, 0.03, DARK, 16, 6)

	# Alien astronaut: white suit, green face with big glossy eyes, springy antennae, all inside
	# a clear bubble helmet so the face reads from behind and the side.
	var skin := Color(0.68, 0.96, 0.45)
	var orange := Color(1.0, 0.62, 0.22)
	d.sphere(Vector3(0, 0.14, 0.06), Vector3(0.17, 0.15, 0.15), 2, 0.0, WHITE)
	d.rounded_box(Vector3(0, 0.16, -0.085), Vector3(0.1, 0.07, 0.03), 0.012, orange)
	for x in [-1.0, 1.0]:
		d.capsule(Vector3(x * 0.15, 0.17, 0.02), Vector3(x * 0.13, 0.12, -0.14), 0.046, WHITE)
		d.sphere(Vector3(x * 0.13, 0.12, -0.16), Vector3.ONE * 0.052, 1, 0.0, orange)
	var head := r.head_part(Vector3(0, 0.36, 0.02))
	var h := head.detail
	h.torus(Vector3(0, -0.115, 0), Vector3.UP, 0.2, 0.035, WHITE, 16, 6)
	h.sphere(Vector3(0, 0.04, 0), Vector3(0.2, 0.18, 0.18), 3, 0.0, skin)
	for x in [-1.0, 1.0]:
		var eye := Vector3(x * 0.08, 0.07, -0.14)
		h.sphere(eye, Vector3(0.062, 0.078, 0.04), 1, 0.0, EYE)
		h.sphere(eye + Vector3(-0.018, 0.03, -0.03), Vector3.ONE * 0.022, 1, 0.0, WHITE)
		h.sphere(eye + Vector3(0.02, -0.025, -0.03), Vector3.ONE * 0.01, 0, 0.0, WHITE)
	_cheeks(h, Vector3(0, -0.01, -0.158), 0.125)
	h.pipe([Vector3(-0.025, -0.05, -0.172), Vector3(0, -0.058, -0.176), Vector3(0.025, -0.05, -0.172)], 0.007, EYE, 4)
	for x in [-1.0, 1.0]:
		var antenna := r.part(Vector3(x * 0.07, 0.18, 0.0), true, head.node)
		antenna.detail.capsule(Vector3.ZERO, Vector3(x * 0.05, 0.12, 0.0), 0.014, skin, 5)
		antenna.glow.sphere(Vector3(x * 0.05, 0.14, 0.0), Vector3.ONE * 0.032, 1, 0.0, Color(1.0, 0.5, 0.75))
		antenna.node.rotation.z = -x * 0.15
	head.glass.sphere(Vector3(0, 0.07, 0), Vector3.ONE * 0.31, 2, 0.0, Color.WHITE)
	r.hover = 0.18
	r.bob = 0.06
	r.trail = Vector3(0, -0.08, 0.95)


# --- shared parts ------------------------------------------------------------

## Paint for a body shell: white on top, shaded on faces that point down, so the tinted panels
## keep some form. `soft` is how gradually the two blend.
static func _two_tone(soft := 0.5) -> Callable:
	return func(_at: Vector3, normal: Vector3) -> Color:
		return UNDER.lerp(WHITE, smoothstep(-soft, 0.1, normal.y))


## Two glossy eyes around `center` (face-local), `spread` apart from the middle.
static func _eyes(k: MeshKit, center: Vector3, spread: float, size: float) -> void:
	for x in [-1.0, 1.0]:
		var at := center + Vector3(x * spread, 0, 0)
		k.sphere(at, Vector3(size, size * 1.22, size * 0.6), 1, 0.0, EYE)
		k.sphere(at + Vector3(-size * 0.3, size * 0.42, -size * 0.5), Vector3.ONE * size * 0.32, 0, 0.0, WHITE)
		k.sphere(at + Vector3(size * 0.3, -size * 0.4, -size * 0.52), Vector3.ONE * size * 0.14, 0, 0.0, WHITE)


static func _cheeks(k: MeshKit, center: Vector3, spread: float) -> void:
	for x in [-1.0, 1.0]:
		k.sphere(center + Vector3(x * spread, 0, 0), Vector3(0.042, 0.026, 0.014), 1, 0.0, BLUSH)


## One goggle lens: a chrome rim around a tinted lens with a glint, facing `facing`.
static func _goggle(k: MeshKit, at: Vector3, facing: Vector3) -> void:
	var out := facing.normalized()
	k.torus(at, out, 0.055, 0.016, CHROME, 12, 5)
	k.sphere(at + out * 0.004, Vector3(0.05, 0.05, 0.022), 1, 0.0, LENS)
	k.sphere(at + out * 0.022 + Vector3(-0.018, 0.018, 0.0), Vector3.ONE * 0.012, 0, 0.0, WHITE)


## Collects a vehicle's meshes and animated parts while it is being built.
class Rig:
	var mats: Dictionary
	var root := Node3D.new()
	var chassis := Node3D.new()
	var paint := MeshKit.new(11, true)
	var detail := MeshKit.new(12, true)
	var glow := MeshKit.new(13, true)
	var glass := MeshKit.new(14, true)
	var wheels: Array[Node3D] = []
	var steer: Array[Node3D] = []
	var wobblers: Array[Node3D] = []
	var flames: Array[Node3D] = []
	var meshes: Array[MeshInstance3D] = []
	var head: Node3D
	var trail := Vector3(0, -0.55, 0.7)
	var hover := 0.0
	var bob := 0.0
	var _parts: Array[Part] = []

	func _init(materials: Dictionary) -> void:
		mats = materials
		root.add_child(chassis)

	## A separately moving piece at `at` (in `parent` space, default the sprung body).
	func part(at: Vector3, wobbles := false, parent: Node3D = null) -> Part:
		var piece := Part.new()
		piece.node.position = at
		(parent if parent else chassis).add_child(piece.node)
		_parts.append(piece)
		if wobbles:
			wobblers.append(piece.node)
		return piece

	func head_part(at: Vector3) -> Part:
		var piece := part(at)
		head = piece.node
		return piece

	## A wheel at `at`: a tyre with rounded shoulders around a dished rim, lugs if `knobby`.
	func wheel(at: Vector3, radius: float, width: float, steers: bool, knobby: bool) -> void:
		var holder := Node3D.new()
		holder.position = at
		root.add_child(holder)
		if steers:
			steer.append(holder)
		var k := MeshKit.new(21, true)
		var out := signf(at.x) if at.x != 0.0 else 1.0
		var axis := Vector3(out, 0, 0)
		var inner := Vector3(-out * width * 0.5, 0, 0)
		k.lathe(inner, axis, [Vector2(radius * 0.5, 0.0), Vector2(radius * 0.9, 0.0), Vector2(radius, width * 0.14),
			Vector2(radius, width * 0.86), Vector2(radius * 0.9, width), Vector2(radius * 0.56, width)], 14, TIRE)
		k.lathe(inner, axis, [Vector2(radius * 0.58, width * 0.8), Vector2(radius * 0.52, width * 0.9),
			Vector2(radius * 0.22, width * 0.9), Vector2(radius * 0.18, width), Vector2(0.0, width * 1.03)], 14, RIM)
		if knobby:
			k.smooth = false
			var lugs := 12
			for i in lugs:
				var a := TAU * i / lugs
				k.box(Vector3(0, cos(a), sin(a)) * radius, Vector3(width * 0.84, 0.07, radius * 0.24), TIRE.lightened(0.07),
					0.0, Basis(Vector3.RIGHT, a))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(mats.detail)
		mi.set_meta("radius", radius)
		holder.add_child(mi)
		wheels.append(mi)
		meshes.append(mi)

	## Engine flame at `at`, pointing along the pivot's +Z after `euler` rotation.
	func flame(at: Vector3, euler: Vector3, radius: float, length: float) -> void:
		var pivot := Node3D.new()
		pivot.position = at
		pivot.rotation = euler
		chassis.add_child(pivot)
		var k := MeshKit.new(31, true)
		k.lathe(Vector3.ZERO, Vector3.BACK, [Vector2(radius * 0.7, 0.0), Vector2(radius, length * 0.2), Vector2(0.0, length)],
			8, Color(1.0, 0.55, 0.15))
		k.lathe(Vector3.ZERO, Vector3.BACK, [Vector2(radius * 0.4, 0.0), Vector2(radius * 0.55, length * 0.15),
			Vector2(0.0, length * 0.55)], 8, Color(1.0, 0.95, 0.6))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(mats.glow)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		flames.append(pivot)

	func finish() -> Node3D:
		_add_mesh(chassis, paint, detail, glow, glass)
		for piece in _parts:
			_add_mesh(piece.node, piece.paint, piece.detail, piece.glow, piece.glass)
		root.set_meta("chassis", chassis)
		root.set_meta("wheels", wheels)
		root.set_meta("steer", steer)
		root.set_meta("wobblers", wobblers)
		root.set_meta("flames", flames)
		root.set_meta("meshes", meshes)
		root.set_meta("head", head)
		root.set_meta("trail", trail)
		root.set_meta("hover", hover)
		root.set_meta("bob", bob)
		return root

	func _add_mesh(parent: Node3D, p: MeshKit, d: MeshKit, g: MeshKit, clear: MeshKit) -> void:
		var mesh := p.commit(mats.paint)
		mesh = d.commit(mats.detail, mesh)
		mesh = g.commit(mats.glow, mesh)
		mesh = clear.commit(mats.glass, mesh)
		if mesh.get_surface_count() == 0:
			return
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		parent.add_child(mi)
		meshes.append(mi)


class Part:
	var node := Node3D.new()
	var paint := MeshKit.new(41, true)
	var detail := MeshKit.new(42, true)
	var glow := MeshKit.new(43, true)
	var glass := MeshKit.new(44, true)
