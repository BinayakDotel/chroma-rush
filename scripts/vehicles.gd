class_name Vehicles
## Player vehicles, one per world, each driven by a chibi character: big head, big glossy eyes,
## blush cheeks. Painted panels take the current gate colour (`paint` material); glowing bits use
## `glow`, helmets and canopies `glass`; everything else keeps its own vertex colours.
## Moving parts are separate nodes listed in metadata so Racer can animate them:
##   "wheels"   spinning wheel nodes (rotate around X)
##   "steer"    front wheel pivots (rotate around Y when changing lanes)
##   "head"     driver head pivot
##   "wobblers" floppy parts (ears, tails, scarves, antennas) driven by a spring
##   "flames"   engine flames, stretched along their local +Z with throttle
##   "trail"    local position where dust / snow / sparks are emitted
##   "hover", "bob"  extra ride height and idle bob amplitude

## Road height in body space: the body origin sits Racer.SIZE * 0.5 + Racer.HOVER above the road.
const ROAD := -0.6

const TIRE := Color(0.13, 0.13, 0.16)
const RIM := Color(0.86, 0.87, 0.92)
const DARK := Color(0.12, 0.12, 0.17)
const METAL := Color(0.42, 0.44, 0.52)
const CHROME := Color(0.82, 0.84, 0.9)
const SEAT := Color(0.24, 0.25, 0.34)
const GLASS := Color(0.45, 0.8, 1.0)
const WHITE := Color(0.97, 0.97, 0.98)
const EYE := Color(0.08, 0.07, 0.12)
const BLUSH := Color(1.0, 0.55, 0.62)
## Accessories avoid the gate hues so they never read as a gate colour.
const TEAL := Color(0.1, 0.68, 0.62)
const MINT := Color(0.55, 0.92, 0.75)
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
	d.box(Vector3(0, -0.44, 0.02), Vector3(0.78, 0.08, 1.5), DARK)
	# Nose cone and front wing.
	p.cylinder(Vector3(0, -0.3, -0.3), Vector3(0, -0.04, -0.58), 0.27, 0.12, 8, WHITE)
	p.sphere(Vector3(0, -0.33, -0.88), Vector3(0.13, 0.1, 0.1), 1, 0.0, WHITE)
	d.box(Vector3(0, -0.45, -0.95), Vector3(0.96, 0.05, 0.16), DARK)
	for x in [-0.46, 0.46]:
		p.box(Vector3(x, -0.4, -0.95), Vector3(0.05, 0.14, 0.22), WHITE)
	# Side pods with a white stripe.
	for x in [-0.37, 0.37]:
		p.box(Vector3(x, -0.3, 0.12), Vector3(0.22, 0.22, 0.66), WHITE, 0.01)
		d.box(Vector3(x * 1.32, -0.24, 0.12), Vector3(0.012, 0.05, 0.62), WHITE)
	# Seat, engine and twin exhausts.
	d.box(Vector3(0, -0.34, 0.2), Vector3(0.44, 0.08, 0.36), SEAT)
	d.box(Vector3(0, -0.14, 0.38), Vector3(0.44, 0.34, 0.08), SEAT)
	d.box(Vector3(0, -0.26, 0.6), Vector3(0.46, 0.22, 0.24), METAL)
	for x in [-0.12, 0.12]:
		d.cylinder(Vector3(x, -0.22, 0.7), Vector3(0, 0.14, 0.24), 0.045, 0.05, 6, CHROME, true, 0.0, DARK)
	# Rear wing.
	for x in [-0.28, 0.28]:
		d.tube(Vector3(x, -0.16, 0.7), Vector3(x, 0.2, 0.78), 0.025, DARK)
	p.box(Vector3(0, 0.23, 0.8), Vector3(1.02, 0.05, 0.28), WHITE)
	for x in [-0.52, 0.52]:
		p.box(Vector3(x, 0.17, 0.8), Vector3(0.04, 0.2, 0.32), WHITE)
	# Steering wheel.
	d.tube(Vector3(0, -0.3, -0.3), Vector3(0, -0.1, -0.12), 0.022, DARK)
	d.ring(Vector3(0, -0.08, -0.1), Vector3(0, 0.55, -0.83), 0.08, 0.12, 10, [DARK])
	r.glow.sphere(Vector3(0, -0.3, -0.96), Vector3(0.05, 0.035, 0.02), 0, 0.0, HEADLIGHT)

	r.wheel(Vector3(-0.52, ROAD + 0.2, -0.52), 0.2, 0.18, true, false)
	r.wheel(Vector3(0.52, ROAD + 0.2, -0.52), 0.2, 0.18, true, false)
	r.wheel(Vector3(-0.55, ROAD + 0.25, 0.52), 0.25, 0.26, false, false)
	r.wheel(Vector3(0.55, ROAD + 0.25, 0.52), 0.25, 0.26, false, false)

	# Fox: orange coat, cream muzzle and chest, teal scarf.
	var fur := Color(0.98, 0.52, 0.16)
	var cream := Color(1.0, 0.93, 0.82)
	var coat := func(dir: Vector3) -> Color: return cream if dir.z < -0.45 and dir.y < 0.4 else fur
	d.sphere(Vector3(0, -0.08, 0.2), Vector3(0.2, 0.2, 0.17), 1, 0.0, coat)
	for x in [-1.0, 1.0]:
		d.tube(Vector3(x * 0.16, 0.0, 0.14), Vector3(x * 0.1, -0.08, -0.08), 0.05, fur)
		d.sphere(Vector3(x * 0.1, -0.08, -0.1), Vector3.ONE * 0.055, 0, 0.0, cream)
	d.cylinder(Vector3(0, 0.08, 0.2), Vector3.UP * 0.06, 0.15, 0.14, 8, TEAL, true)
	var scarf := r.part(Vector3(0.06, 0.1, 0.33), true)
	scarf.detail.box(Vector3(0, -0.02, 0.14), Vector3(0.09, 0.025, 0.28), TEAL)
	scarf.node.rotation.x = 0.35
	var tail := r.part(Vector3(0, -0.2, 0.44), true)
	var tail_col := func(dir: Vector3) -> Color: return cream if dir.z > 0.55 else fur
	tail.detail.sphere(Vector3(0, 0.02, 0.24), Vector3(0.12, 0.12, 0.28), 1, 0.05, tail_col)
	tail.node.rotation.x = 0.6

	var head := r.head_part(Vector3(0, 0.24, 0.18))
	var h := head.detail
	var face := func(dir: Vector3) -> Color: return cream if dir.z < -0.55 and dir.y < 0.1 else fur
	h.sphere(Vector3(0, 0.08, 0), Vector3(0.25, 0.22, 0.23), 2, 0.0, face)
	h.cylinder(Vector3(0, 0.02, -0.16), Vector3(0, -0.02, -0.14), 0.09, 0.035, 8, cream)
	h.sphere(Vector3(0, 0.0, -0.31), Vector3.ONE * 0.035, 0, 0.0, EYE)
	_eyes(h, Vector3(0, 0.11, -0.19), 0.09, 0.045)
	_cheeks(h, Vector3(0, 0.03, -0.17), 0.15)
	# Goggles pushed up on the forehead.
	h.cylinder(Vector3(0, 0.2, 0), Vector3.UP * 0.04, 0.235, 0.225, 12, SEAT)
	for x in [-0.08, 0.08]:
		h.cylinder(Vector3(x, 0.24, -0.2), Vector3(0, 0, -0.05), 0.055, 0.055, 8, GLASS, true, 0.0, CHROME)
	for x in [-1.0, 1.0]:
		var ear := r.part(Vector3(x * 0.13, 0.26, 0.02), true, head.node)
		var ear_col := func(dir: Vector3) -> Color: return EYE if dir.y > 0.75 else fur
		ear.detail.cylinder(Vector3.ZERO, Vector3(x * 0.04, 0.2, 0.02), 0.08, 0.0, 5, ear_col)
		ear.detail.cylinder(Vector3(0, 0.02, -0.03), Vector3(x * 0.03, 0.13, 0.0), 0.045, 0.0, 4, cream)
	r.trail = Vector3(0, ROAD + 0.05, 0.75)


# --- bobsled + penguin (glacier) -------------------------------------------

static func _bobsled(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	var hull: Array[Vector2] = [
		Vector2(-0.95, -0.34), Vector2(-0.82, -0.14), Vector2(-0.5, -0.02), Vector2(0.55, -0.02),
		Vector2(0.72, -0.14), Vector2(0.72, -0.42), Vector2(-0.7, -0.46),
	]
	var shade := func(dir: Vector3) -> Color: return Color(0.78, 0.78, 0.8) if dir.y < -0.5 else WHITE
	p.extrude(hull, -0.38, 0.38, shade)
	for x in [-0.39, 0.39]:
		p.cylinder(Vector3(x, -0.24, -0.6), Vector3(0, 0.0, 1.25), 0.09, 0.09, 6, WHITE, true)
		d.box(Vector3(x * 1.06, -0.16, 0.05), Vector3(0.012, 0.05, 1.1), WHITE)
	d.box(Vector3(0, -0.01, -0.4), Vector3(0.6, 0.02, 0.2), DARK)
	# Runners with curled tips, struts and push bars.
	for x in [-0.3, 0.3]:
		d.box(Vector3(x, ROAD + 0.04, 0.0), Vector3(0.05, 0.04, 1.5), CHROME)
		d.tube(Vector3(x, ROAD + 0.04, -0.75), Vector3(x, ROAD + 0.2, -0.88), 0.025, CHROME)
		for z in [-0.45, 0.45]:
			d.box(Vector3(x, ROAD + 0.1, z), Vector3(0.05, 0.12, 0.06), DARK)
		d.tube(Vector3(x, -0.1, 0.66), Vector3(x, 0.02, 0.86), 0.025, DARK)
	d.tube(Vector3(-0.3, 0.02, 0.86), Vector3(0.3, 0.02, 0.86), 0.025, DARK)
	r.glow.sphere(Vector3(0, -0.2, -0.93), Vector3(0.06, 0.04, 0.02), 0, 0.0, HEADLIGHT)

	# Penguin: round body, white tummy, orange feet peeking out.
	var black := Color(0.14, 0.15, 0.22)
	var belly := func(dir: Vector3) -> Color: return WHITE if dir.z < -0.3 and dir.y < 0.6 else black
	d.sphere(Vector3(0, 0.16, 0.12), Vector3(0.27, 0.3, 0.25), 2, 0.0, belly)
	for x in [-1.0, 1.0]:
		var flipper := r.part(Vector3(x * 0.25, 0.26, 0.1), true)
		flipper.detail.sphere(Vector3(x * 0.04, -0.12, 0), Vector3(0.05, 0.16, 0.1), 1, 0.0, black)
		flipper.node.rotation.z = x * 0.35
	d.cylinder(Vector3(0, 0.36, 0.1), Vector3.UP * 0.07, 0.19, 0.18, 10, TEAL, true)
	var scarf := r.part(Vector3(0.1, 0.4, 0.26), true)
	scarf.detail.box(Vector3(0, -0.02, 0.16), Vector3(0.1, 0.025, 0.32), TEAL)
	scarf.detail.box(Vector3(0, -0.02, 0.3), Vector3(0.1, 0.026, 0.03), WHITE)
	scarf.node.rotation.x = 0.3

	var head := r.head_part(Vector3(0, 0.56, 0.1))
	var h := head.detail
	var mask := func(dir: Vector3) -> Color: return WHITE if dir.z < -0.4 and dir.y < 0.45 and absf(dir.x) < 0.7 else black
	h.sphere(Vector3(0, 0.06, 0), Vector3(0.24, 0.22, 0.22), 2, 0.0, mask)
	h.cylinder(Vector3(0, 0.02, -0.2), Vector3(0, -0.02, -0.12), 0.06, 0.0, 6, Color(1.0, 0.62, 0.15))
	_eyes(h, Vector3(0, 0.08, -0.19), 0.085, 0.045)
	_cheeks(h, Vector3(0, 0.0, -0.16), 0.14)
	# Beanie in the paint colour, so the driver shows the current colour too.
	head.paint.cylinder(Vector3(0, 0.14, 0), Vector3.UP * 0.1, 0.235, 0.2, 12, WHITE, false)
	head.paint.sphere(Vector3(0, 0.24, 0), Vector3(0.2, 0.12, 0.2), 1, 0.0, WHITE)
	h.cylinder(Vector3(0, 0.12, 0), Vector3.UP * 0.05, 0.245, 0.24, 12, WHITE)
	var pompom := r.part(Vector3(0, 0.35, 0.02), true, head.node)
	pompom.detail.sphere(Vector3(0, 0.03, 0), Vector3.ONE * 0.07, 1, 0.1, WHITE)
	r.trail = Vector3(0, ROAD + 0.05, 0.7)


# --- dune buggy + gecko (canyon) -------------------------------------------

static func _buggy(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	d.box(Vector3(0, -0.3, 0), Vector3(0.8, 0.12, 1.3), DARK)
	var hood: Array[Vector2] = [
		Vector2(-0.82, -0.3), Vector2(-0.82, -0.16), Vector2(-0.4, -0.04), Vector2(-0.22, -0.04), Vector2(-0.22, -0.3),
	]
	p.extrude(hood, -0.37, 0.37, WHITE)
	var engine_cover: Array[Vector2] = [
		Vector2(0.34, -0.28), Vector2(0.34, -0.02), Vector2(0.6, -0.06), Vector2(0.74, -0.28),
	]
	p.extrude(engine_cover, -0.35, 0.35, WHITE)
	for x in [-0.4, 0.4]:
		p.box(Vector3(x, -0.2, 0.06), Vector3(0.06, 0.18, 0.62), WHITE)
	d.box(Vector3(0, -0.36, -0.9), Vector3(0.7, 0.1, 0.08), DARK)
	# Roll cage.
	var cage := [
		[Vector3(-0.34, -0.2, -0.3), Vector3(-0.3, 0.42, -0.14)], [Vector3(0.34, -0.2, -0.3), Vector3(0.3, 0.42, -0.14)],
		[Vector3(-0.3, 0.42, -0.14), Vector3(-0.3, 0.45, 0.34)], [Vector3(0.3, 0.42, -0.14), Vector3(0.3, 0.45, 0.34)],
		[Vector3(-0.34, -0.2, 0.42), Vector3(-0.3, 0.45, 0.34)], [Vector3(0.34, -0.2, 0.42), Vector3(0.3, 0.45, 0.34)],
		[Vector3(-0.3, 0.45, 0.34), Vector3(0.3, 0.45, 0.34)], [Vector3(-0.3, 0.42, -0.14), Vector3(0.3, 0.42, -0.14)],
	]
	for bar: Array in cage:
		d.tube(bar[0], bar[1], 0.03, DARK)
	d.box(Vector3(0, 0.47, -0.14), Vector3(0.5, 0.06, 0.06), DARK)
	for x in [-0.18, -0.06, 0.06, 0.18]:
		r.glow.box(Vector3(x, 0.47, -0.175), Vector3(0.08, 0.04, 0.01), HEADLIGHT)
	for x in [-0.22, 0.22]:
		r.glow.sphere(Vector3(x, -0.17, -0.83), Vector3(0.06, 0.05, 0.02), 0, 0.0, HEADLIGHT)
	# Spare tyre on the back.
	d.cylinder(Vector3(0, 0.02, 0.72), Vector3(0, 0, 0.12), 0.2, 0.2, 10, TIRE, true, 0.0, RIM)
	var antenna := r.part(Vector3(0.3, 0.45, 0.36), true)
	antenna.detail.tube(Vector3.ZERO, Vector3(0, 0.6, 0.05), 0.012, DARK, 4)
	antenna.detail.slab([Vector3(0, 0.6, 0.05), Vector3(0, 0.48, 0.05), Vector3(0, 0.54, 0.25)], 0.01, Color(1.0, 0.55, 0.1))

	for x in [-0.57, 0.57]:
		r.wheel(Vector3(x, ROAD + 0.3, -0.5), 0.3, 0.26, true, true)
		r.wheel(Vector3(x, ROAD + 0.3, 0.5), 0.3, 0.26, false, true)

	# Gecko cowboy: green skin, huge eyes, hat and bandana.
	var skin := Color(0.42, 0.78, 0.3)
	var tummy := Color(0.86, 0.95, 0.62)
	var body := func(dir: Vector3) -> Color: return tummy if dir.z < -0.5 else skin
	d.sphere(Vector3(0, -0.02, 0.12), Vector3(0.19, 0.2, 0.17), 1, 0.0, body)
	for x in [-1.0, 1.0]:
		d.tube(Vector3(x * 0.15, 0.06, 0.08), Vector3(x * 0.1, -0.02, -0.14), 0.05, skin)
		d.sphere(Vector3(x * 0.1, -0.02, -0.16), Vector3.ONE * 0.05, 0, 0.0, skin)
	d.tube(Vector3(0, -0.2, -0.3), Vector3(0, -0.02, -0.16), 0.02, DARK)
	d.ring(Vector3(0, -0.01, -0.15), Vector3(0, 0.55, -0.83), 0.07, 0.11, 10, [DARK])
	d.cylinder(Vector3(0, 0.15, 0.12), Vector3.UP * 0.05, 0.14, 0.13, 8, TEAL, true)

	var head := r.head_part(Vector3(0, 0.3, 0.1))
	var h := head.detail
	h.sphere(Vector3(0, 0.03, -0.03), Vector3(0.23, 0.18, 0.24), 2, 0.0, skin)
	for x in [-1.0, 1.0]:
		h.sphere(Vector3(x * 0.15, 0.1, -0.1), Vector3.ONE * 0.085, 1, 0.0, WHITE)
		h.sphere(Vector3(x * 0.17, 0.11, -0.16), Vector3.ONE * 0.048, 1, 0.0, EYE)
		h.sphere(Vector3(x * 0.155, 0.135, -0.195), Vector3.ONE * 0.016, 0, 0.0, WHITE)
	h.box(Vector3(0, -0.04, -0.26), Vector3(0.14, 0.014, 0.01), EYE)
	_cheeks(h, Vector3(0, -0.01, -0.2), 0.16)
	var hat := Color(0.62, 0.38, 0.2)
	h.cylinder(Vector3(0, 0.17, -0.02), Vector3.UP * 0.025, 0.3, 0.3, 14, hat, true)
	h.cylinder(Vector3(0, 0.19, -0.02), Vector3.UP * 0.13, 0.15, 0.12, 10, hat, true, 0.0, hat.darkened(0.1))
	h.cylinder(Vector3(0, 0.19, -0.02), Vector3.UP * 0.035, 0.155, 0.152, 10, DARK)
	r.trail = Vector3(0, ROAD + 0.05, 0.75)


# --- monster truck + rock golem (volcano) ----------------------------------

static func _monster(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	for z in [-0.55, 0.55]:
		d.tube(Vector3(-0.6, ROAD + 0.43, z), Vector3(0.6, ROAD + 0.43, z), 0.05, DARK)
		for x in [-0.3, 0.3]:
			d.tube(Vector3(x, ROAD + 0.43, z), Vector3(x * 1.1, 0.02, z * 0.8), 0.035, CHROME)
	d.box(Vector3(0, 0.0, 0), Vector3(0.6, 0.1, 1.3), DARK)
	# Body: long lower tub, sloped hood, open cab with doors, pickup bed.
	var lower := func(dir: Vector3) -> Color: return Color(0.8, 0.8, 0.82) if dir.y < -0.5 else WHITE
	p.box(Vector3(0, 0.16, 0), Vector3(0.96, 0.22, 1.48), lower, 0.01)
	var hood: Array[Vector2] = [Vector2(-0.74, 0.27), Vector2(-0.74, 0.36), Vector2(-0.26, 0.42), Vector2(-0.26, 0.27)]
	p.extrude(hood, -0.46, 0.46, WHITE)
	p.box(Vector3(0, 0.38, 0.05), Vector3(0.9, 0.2, 0.5), WHITE)
	d.box(Vector3(0, 0.28, 0.52), Vector3(0.86, 0.04, 0.44), DARK)
	for x in [-0.45, 0.45]:
		p.box(Vector3(x, 0.36, 0.52), Vector3(0.04, 0.16, 0.44), WHITE)
	# Windscreen frame and roll bar.
	d.tube(Vector3(-0.42, 0.48, -0.2), Vector3(-0.4, 0.78, -0.12), 0.03, DARK)
	d.tube(Vector3(0.42, 0.48, -0.2), Vector3(0.4, 0.78, -0.12), 0.03, DARK)
	d.tube(Vector3(-0.4, 0.78, -0.12), Vector3(0.4, 0.78, -0.12), 0.03, DARK)
	d.quad(Vector3(-0.38, 0.5, -0.22), Vector3(0.38, 0.5, -0.22), Vector3(0.36, 0.74, -0.14), Vector3(-0.36, 0.74, -0.14),
		Color(0.55, 0.78, 0.95), Vector3(0, 0.3, -1))
	for x in [-0.4, 0.4]:
		d.tube(Vector3(x, 0.48, 0.28), Vector3(x, 0.86, 0.26), 0.035, DARK)
	d.tube(Vector3(-0.4, 0.86, 0.26), Vector3(0.4, 0.86, 0.26), 0.035, DARK)
	# Bull bar, headlights and stacks with flames.
	d.tube(Vector3(-0.42, 0.1, -0.82), Vector3(0.42, 0.1, -0.82), 0.04, CHROME)
	d.tube(Vector3(-0.42, 0.28, -0.8), Vector3(0.42, 0.28, -0.8), 0.04, CHROME)
	for x in [-0.3, 0.3]:
		d.tube(Vector3(x, 0.05, -0.74), Vector3(x, 0.3, -0.8), 0.035, CHROME)
		r.glow.sphere(Vector3(x, 0.2, -0.75), Vector3(0.07, 0.06, 0.02), 0, 0.0, HEADLIGHT)
	for x in [-0.34, 0.34]:
		d.cylinder(Vector3(x, 0.3, 0.3), Vector3.UP * 0.62, 0.05, 0.055, 7, CHROME, true, 0.0, DARK)
		r.flame(Vector3(x, 0.93, 0.3), Vector3(-PI * 0.5, 0, 0), 0.07, 0.3)

	for x in [-0.64, 0.64]:
		r.wheel(Vector3(x, ROAD + 0.43, -0.55), 0.43, 0.36, true, true)
		r.wheel(Vector3(x, ROAD + 0.43, 0.55), 0.43, 0.36, false, true)

	# Rock golem: chunky stone with glowing lava seams and eyes.
	var stone := Color(0.66, 0.58, 0.5)
	var mossy := func(dir: Vector3) -> Color: return Color(0.38, 0.62, 0.3) if dir.y > 0.8 else r.detail.vary(stone, 0.08)
	d.sphere(Vector3(0, 0.56, 0.08), Vector3(0.24, 0.2, 0.2), 1, 0.2, stone)
	for x in [-1.0, 1.0]:
		d.sphere(Vector3(x * 0.26, 0.58, 0.02), Vector3(0.11, 0.1, 0.1), 0, 0.2, stone)
		d.tube(Vector3(x * 0.26, 0.54, -0.02), Vector3(x * 0.2, 0.52, -0.2), 0.06, stone.darkened(0.08))
	r.glow.box(Vector3(0.06, 0.58, -0.13), Vector3(0.03, 0.12, 0.01), Color(1.0, 0.5, 0.1))
	var head := r.head_part(Vector3(0, 0.78, 0.04))
	var h := head.detail
	h.sphere(Vector3(0, 0.1, 0), Vector3(0.26, 0.22, 0.23), 1, 0.18, mossy, 3.0)
	for x in [-1.0, 1.0]:
		head.glow.box(Vector3(x * 0.09, 0.12, -0.21), Vector3(0.08, 0.05, 0.02), Color(1.0, 0.7, 0.2))
	head.glow.box(Vector3(-0.12, 0.24, -0.15), Vector3(0.02, 0.1, 0.02), Color(1.0, 0.45, 0.1))
	_cheeks(h, Vector3(0, 0.03, -0.19), 0.17)
	h.box(Vector3(0, 0.0, -0.22), Vector3(0.1, 0.02, 0.02), EYE)
	r.trail = Vector3(0, ROAD + 0.1, 0.8)


# --- star racer + astronaut (space) ----------------------------------------

static func _star_racer(r: Rig) -> void:
	var p := r.paint
	var d := r.detail
	var under := func(dir: Vector3) -> Color: return Color(0.72, 0.72, 0.76) if dir.y < -0.45 else WHITE
	p.sphere(Vector3(0, 0, 0.05), Vector3(0.32, 0.24, 0.9), 1, 0.0, under)
	d.cylinder(Vector3(0, 0, -0.82), Vector3(0, 0, -0.16), 0.1, 0.0, 8, CHROME)
	# Swept wings, tail fin and nose stripe.
	for x in [-1.0, 1.0]:
		p.slab([Vector3(x * 0.26, -0.06, -0.1), Vector3(x * 0.9, -0.1, 0.36), Vector3(x * 0.94, -0.1, 0.58),
			Vector3(x * 0.26, -0.06, 0.58)], 0.06, WHITE)
		d.slab([Vector3(x * 0.88, -0.1, 0.36), Vector3(x * 0.96, 0.06, 0.46), Vector3(x * 0.98, 0.06, 0.6),
			Vector3(x * 0.94, -0.1, 0.58)], 0.03, DARK)
		# Engine pods and their flames.
		d.cylinder(Vector3(x * 0.44, -0.08, 0.14), Vector3(0, 0, 0.64), 0.11, 0.12, 8, METAL, true, 0.0, DARK)
		d.cylinder(Vector3(x * 0.44, -0.08, 0.78), Vector3(0, 0, 0.06), 0.1, 0.13, 8, DARK, true)
		r.flame(Vector3(x * 0.44, -0.08, 0.84), Vector3.ZERO, 0.1, 0.55)
	p.slab([Vector3(0, 0.16, 0.4), Vector3(0, 0.52, 0.78), Vector3(0, 0.52, 0.95), Vector3(0, 0.16, 0.9)], 0.05, WHITE)
	d.box(Vector3(0, 0.2, -0.46), Vector3(0.04, 0.012, 0.36), WHITE)
	for z in [-0.35, 0.1, 0.5]:
		r.glow.sphere(Vector3(0, -0.24, z), Vector3(0.07, 0.02, 0.07), 0, 0.0, Color(0.35, 0.8, 1.0))
	d.ring(Vector3(0, 0.2, 0.0), Vector3.UP, 0.16, 0.2, 12, [DARK])

	# Alien astronaut: white suit, mint-green face with big glossy eyes, springy antennae, all
	# inside a clear bubble helmet so the face reads from behind and the side.
	var skin := Color(0.66, 0.96, 0.42)
	d.sphere(Vector3(0, 0.12, 0.06), Vector3(0.18, 0.16, 0.15), 1, 0.0, WHITE)
	d.box(Vector3(0, 0.14, -0.08), Vector3(0.1, 0.07, 0.02), Color(1.0, 0.6, 0.2))
	for x in [-1.0, 1.0]:
		d.tube(Vector3(x * 0.15, 0.16, 0.02), Vector3(x * 0.12, 0.08, -0.16), 0.05, WHITE)
		d.sphere(Vector3(x * 0.12, 0.08, -0.18), Vector3.ONE * 0.05, 0, 0.0, Color(1.0, 0.6, 0.2))
	var head := r.head_part(Vector3(0, 0.34, 0.02))
	var h := head.detail
	h.cylinder(Vector3(0, -0.14, 0), Vector3.UP * 0.05, 0.23, 0.22, 14, WHITE, true)
	h.sphere(Vector3(0, 0.04, 0), Vector3(0.2, 0.18, 0.18), 2, 0.0, skin)
	for x in [-1.0, 1.0]:
		var eye := Vector3(x * 0.078, 0.07, -0.14)
		h.sphere(eye, Vector3(0.062, 0.078, 0.04), 1, 0.0, EYE)
		h.sphere(eye + Vector3(-0.018, 0.03, -0.03), Vector3.ONE * 0.022, 0, 0.0, WHITE)
		h.sphere(eye + Vector3(0.02, -0.025, -0.03), Vector3.ONE * 0.01, 0, 0.0, WHITE)
	_cheeks(h, Vector3(0, -0.01, -0.155), 0.125)
	h.box(Vector3(0, -0.055, -0.172), Vector3(0.05, 0.012, 0.01), EYE)
	for x in [-1.0, 1.0]:
		var antenna := r.part(Vector3(x * 0.07, 0.18, 0.0), true, head.node)
		antenna.detail.tube(Vector3.ZERO, Vector3(x * 0.05, 0.13, 0.0), 0.014, skin, 4)
		antenna.glow.sphere(Vector3(x * 0.05, 0.14, 0.0), Vector3.ONE * 0.03, 0, 0.0, Color(1.0, 0.45, 0.7))
		antenna.node.rotation.z = -x * 0.15
	head.glass.sphere(Vector3(0, 0.07, 0), Vector3.ONE * 0.31, 2, 0.0, Color.WHITE)
	r.hover = 0.18
	r.bob = 0.06
	r.trail = Vector3(0, -0.08, 0.95)


# --- shared face parts -----------------------------------------------------

## Two glossy eyes around `center` (face-local), `spread` apart from the middle.
static func _eyes(k: MeshKit, center: Vector3, spread: float, size: float) -> void:
	for x in [-1.0, 1.0]:
		var at := center + Vector3(x * spread, 0, 0)
		k.sphere(at, Vector3(size, size * 1.2, size * 0.6), 1, 0.0, EYE)
		k.sphere(at + Vector3(-size * 0.3, size * 0.4, -size * 0.45), Vector3.ONE * size * 0.32, 0, 0.0, WHITE)


static func _cheeks(k: MeshKit, center: Vector3, spread: float) -> void:
	for x in [-1.0, 1.0]:
		k.sphere(center + Vector3(x * spread, 0, 0), Vector3(0.04, 0.025, 0.012), 0, 0.0, BLUSH)


## Collects a vehicle's meshes and animated parts while it is being built.
class Rig:
	var mats: Dictionary
	var root := Node3D.new()
	var paint := MeshKit.new(11)
	var detail := MeshKit.new(12)
	var glow := MeshKit.new(13)
	var glass := MeshKit.new(14)
	var wheels: Array[Node3D] = []
	var steer: Array[Node3D] = []
	var wobblers: Array[Node3D] = []
	var flames: Array[Node3D] = []
	var head: Node3D
	var trail := Vector3(0, -0.55, 0.7)
	var hover := 0.0
	var bob := 0.015
	var _parts: Array[Part] = []

	func _init(materials: Dictionary) -> void:
		mats = materials

	## A separately moving piece at `at` (in `parent` space, default the vehicle root).
	func part(at: Vector3, wobbles := false, parent: Node3D = null) -> Part:
		var piece := Part.new()
		piece.node.position = at
		(parent if parent else root).add_child(piece.node)
		_parts.append(piece)
		if wobbles:
			wobblers.append(piece.node)
		return piece

	func head_part(at: Vector3) -> Part:
		var piece := part(at)
		head = piece.node
		return piece

	func wheel(at: Vector3, radius: float, width: float, steers: bool, knobby: bool) -> void:
		var holder := Node3D.new()
		holder.position = at
		root.add_child(holder)
		if steers:
			steer.append(holder)
		var k := MeshKit.new(21)
		var side := signf(at.x) if at.x != 0.0 else 1.0
		k.cylinder(Vector3(-width * 0.5, 0, 0), Vector3(width, 0, 0), radius, radius, 12, TIRE, true)
		k.cylinder(Vector3(side * width * 0.5, 0, 0), Vector3(side * 0.02, 0, 0), radius * 0.55, radius * 0.5, 8, RIM, true)
		k.cylinder(Vector3(side * (width * 0.5 + 0.02), 0, 0), Vector3(side * 0.02, 0, 0), radius * 0.16, radius * 0.12, 6, DARK, true)
		if knobby:
			for i in 10:
				var a := TAU * i / 10.0
				k.box(Vector3(0, cos(a), sin(a)) * radius * 0.97, Vector3(width * 0.8, 0.05, 0.05), TIRE.lightened(0.05))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(mats.detail)
		holder.add_child(mi)
		wheels.append(mi)

	## Engine flame at `at`, pointing along the pivot's +Z after `euler` rotation.
	func flame(at: Vector3, euler: Vector3, radius: float, length: float) -> void:
		var pivot := Node3D.new()
		pivot.position = at
		pivot.rotation = euler
		root.add_child(pivot)
		var k := MeshKit.new(31)
		k.cylinder(Vector3.ZERO, Vector3(0, 0, length), radius, 0.0, 7, Color(1.0, 0.55, 0.15))
		k.cylinder(Vector3.ZERO, Vector3(0, 0, length * 0.55), radius * 0.6, 0.0, 7, Color(1.0, 0.95, 0.55))
		var mi := MeshInstance3D.new()
		mi.mesh = k.commit(mats.glow)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		flames.append(pivot)

	func finish() -> Node3D:
		var body := MeshInstance3D.new()
		body.mesh = _commit(paint, detail, glow, glass)
		root.add_child(body)
		for piece in _parts:
			var mi := MeshInstance3D.new()
			mi.mesh = _commit(piece.paint, piece.detail, piece.glow, piece.glass)
			piece.node.add_child(mi)
		root.set_meta("wheels", wheels)
		root.set_meta("steer", steer)
		root.set_meta("wobblers", wobblers)
		root.set_meta("flames", flames)
		root.set_meta("head", head)
		root.set_meta("trail", trail)
		root.set_meta("hover", hover)
		root.set_meta("bob", bob)
		return root

	func _commit(p: MeshKit, d: MeshKit, g: MeshKit, clear: MeshKit) -> ArrayMesh:
		var mesh := p.commit(mats.paint)
		mesh = d.commit(mats.detail, mesh)
		mesh = g.commit(mats.glow, mesh)
		return clear.commit(mats.glass, mesh)


class Part:
	var node := Node3D.new()
	var paint := MeshKit.new(41)
	var detail := MeshKit.new(42)
	var glow := MeshKit.new(43)
	var glass := MeshKit.new(44)
