class_name Obstacles
## Procedural track furniture: solid blocks (dodge), hurdles (jump), the arch that carries a row
## of colour gates, and the collectible gems. Everything is lane-local: centred on x = 0 with the
## road surface at y = 0 and the player arriving from +Z.
##
## Readability rules: blocks are taller than any jump (2+ m); hurdles are a clearly low band no
## higher than Track.LOW_SIZE.y with a hot or bright element on top; arches stand outside the
## lanes so they never look like something to dodge.

const BARK := Color(0.5, 0.31, 0.17)
const WOOD := Color(0.56, 0.36, 0.2)
const SNOW := Color(0.95, 0.97, 1.0)
const ICE := Color(0.45, 0.85, 1.0)
const BASALT := Color(0.22, 0.19, 0.27)
const LAVA := Color(1.0, 0.45, 0.08)
const METAL := Color(0.28, 0.32, 0.42)
const BONE := Color(0.96, 0.93, 0.85)
const MOSS := Color(0.34, 0.62, 0.22)

## Half the distance between the arch's outer pillars (just outside the road edge).
const ARCH_HALF := 4.1
const ARCH_BEAM_Y := 3.05
const LANE_EDGE := 1.05


## Themed solid obstacle, about 2.1 m wide and 2.2-3 m tall. Glowing parts use `glow`.
static func block(kind: String, seed_value: int, material: Material, glow: Material) -> ArrayMesh:
	var k := MeshKit.new(seed_value)
	var g := MeshKit.new(seed_value + 1)
	match kind:
		"mossy_boulder":
			var stone := Color(0.42, 0.4, 0.4)
			var moss := func(d: Vector3) -> Color: return k.vary(MOSS if d.y > 0.55 else stone, 0.08)
			k.sphere(Vector3(0, 1.0, 0), Vector3(1.1, 1.05, 0.75), 1, 0.2, moss, k.rand(0, 50))
			k.sphere(Vector3(k.rand(-0.3, 0.3), 1.95, 0), Vector3(0.7, 0.6, 0.55), 1, 0.25, moss, k.rand(0, 50))
			for i in 2:
				_mushroom(k, Vector3(k.rand(-0.8, 0.8), 0.0, k.rand(-0.1, 0.5)), 0.7)
		"ice_cube":
			var ice := func(d: Vector3) -> Color: return k.vary(Color(0.6, 0.88, 1.0) if d.y > 0.7 else Color(0.15, 0.42, 0.85), 0.07)
			k.box(Vector3(0, 0.75, 0), Vector3(2.0, 1.5, 1.2), ice, 0.06)
			k.box(Vector3(k.rand(-0.35, 0.35), 1.95, 0), Vector3(1.2, 0.9, 0.95), ice, 0.06)
			k.sphere(Vector3(0, 2.42, 0), Vector3(0.7, 0.12, 0.5), 1, 0.2, SNOW)
		"saguaro":
			var green := Color(0.2, 0.52, 0.26)
			k.cylinder(Vector3.ZERO, Vector3.UP * 2.7, 0.6, 0.52, 8, green)
			k.sphere(Vector3(0, 2.7, 0), Vector3.ONE * 0.52, 1, 0.0, green)
			for side in [-1.0, 1.0]:
				var y := k.rand(0.8, 1.2)
				k.cylinder(Vector3(0, y, 0), Vector3(side * 0.8, 0, 0), 0.36, 0.36, 7, green)
				k.cylinder(Vector3(side * 0.75, y - 0.15, 0), Vector3.UP * k.rand(1.0, 1.4), 0.36, 0.32, 7, green)
				k.sphere(Vector3(side * 0.75, y + 1.1, 0), Vector3.ONE * 0.33, 0, 0.0, green)
			k.sphere(Vector3(0, 3.1, 0), Vector3.ONE * 0.16, 0, 0.0, Color(1.0, 0.5, 0.75))
			for i in 3:
				k.sphere(Vector3(k.rand(-0.9, 0.9), 0.15, k.rand(-0.4, 0.4)), Vector3(0.35, 0.25, 0.3), 1, 0.3, Color(0.78, 0.46, 0.3))
		"lava_boulder":
			var cracked := func(d: Vector3) -> Color: return LAVA if MeshKit._hash(d, 4.0) > 0.78 else k.vary(BASALT, 0.1)
			k.sphere(Vector3(0, 1.15, 0), Vector3(1.1, 1.2, 0.75), 1, 0.22, cracked, k.rand(0, 50))
			g.sphere(Vector3(k.rand(-0.3, 0.3), 1.2, -0.62), Vector3(0.18, 0.28, 0.06), 0, 0.2, LAVA)
		"meteoroid":
			var hot := func(d: Vector3) -> Color:
				return Color(1.0, 0.5, 0.15) if MeshKit._hash(d, 7.0) > 0.85 else k.vary(Color(0.45, 0.42, 0.48), 0.12)
			k.sphere(Vector3(0, 1.2, 0), Vector3(1.1, 1.1, 0.8), 1, 0.3, hot, k.rand(0, 50))
			for i in 3:
				var dir := Vector3(k.rand(-1, 1), k.rand(0.2, 1), k.rand(-0.2, 1)).normalized()
				g.cylinder(Vector3(0, 1.2, 0) + dir * 0.8, dir * 0.4, 0.1, 0.0, 5, Color(0.5, 0.95, 1.0))
	return g.commit(glow, k.commit(material))


## Themed jump obstacle spanning one lane. `hazard` is the animated lava / laser material.
static func hurdle(kind: String, material: Material, glow: Material, hazard: Material) -> ArrayMesh:
	var k := MeshKit.new(90)
	var g := MeshKit.new(91)
	var h := MeshKit.new(92)
	match kind:
		"log":
			for x in [-0.85, 0.85]:
				k.sphere(Vector3(x, 0.1, 0), Vector3(0.24, 0.14, 0.22), 1, 0.25, Color(0.6, 0.6, 0.62))
			k.cylinder(Vector3(-1.05, 0.3, 0), Vector3(2.1, 0, 0), 0.25, 0.24, 9, BARK, true, 0.04, Color(0.92, 0.76, 0.5))
			for x in [-0.55, 0.25]:
				k.sphere(Vector3(x, 0.52, 0.02), Vector3(0.28, 0.06, 0.18), 1, 0.2, MOSS)
			k.tube(Vector3(-0.15, 0.45, 0), Vector3(-0.08, 0.72, -0.06), 0.05, BARK)
			k.sphere(Vector3(-0.08, 0.75, -0.06), Vector3(0.1, 0.05, 0.08), 0, 0.1, MOSS.lightened(0.15))
			_mushroom(k, Vector3(0.62, 0.5, 0.05), 0.35)
			_mushroom(k, Vector3(0.75, 0.5, -0.05), 0.25)
		"snowy_log":
			var drift := func(d: Vector3) -> Color: return k.vary(SNOW if d.y > -0.1 else Color(0.66, 0.8, 0.98), 0.03)
			k.sphere(Vector3(0, 0.04, 0), Vector3(1.12, 0.36, 0.5), 1, 0.08, drift, 5.0)
			for i in 5:
				var x := -0.8 + i * 0.4
				var height := 0.28 + 0.12 * float(i % 2)
				k.cylinder(Vector3(x, 0.22, k.rand(-0.08, 0.08)), Vector3(k.rand(-0.05, 0.05), height, 0), 0.1, 0.0, 5, ICE)
			for x in [-1.1, 1.05]:
				k.sphere(Vector3(x, 0.1, 0.25), Vector3.ONE * 0.12, 1, 0.05, SNOW)
		"ranch_fence":
			for x in [-1.0, 0.0, 1.0]:
				k.cylinder(Vector3(x, 0, 0), Vector3.UP * 0.66, 0.09, 0.08, 6, WOOD.darkened(0.1), true, 0.05)
			for y in [0.22, 0.48]:
				k.box(Vector3(0, y, -0.02), Vector3(2.2, 0.12, 0.07), WOOD.lightened(0.1), 0.015)
			k.sphere(Vector3(0, 0.7, -0.07), Vector3(0.1, 0.08, 0.12), 1, 0.05, BONE)
			k.sphere(Vector3(0, 0.66, -0.17), Vector3(0.06, 0.05, 0.06), 0, 0.05, BONE)
			for side in [-1.0, 1.0]:
				k.tube(Vector3(side * 0.07, 0.74, -0.07), Vector3(side * 0.24, 0.84, -0.04), 0.022, BONE, 4)
				k.sphere(Vector3(side * 0.04, 0.71, -0.17), Vector3.ONE * 0.02, 0, 0.0, Color(0.1, 0.08, 0.1))
			k.sphere(Vector3(0.62, 0.2, 0.3), Vector3.ONE * 0.2, 1, 0.35, Color(0.72, 0.58, 0.36))
		"lava_pool":
			for side in [-1.0, 1.0]:
				for i in 7:
					var x := -1.0 + i / 3.0
					var s := Vector3(k.rand(0.16, 0.22), k.rand(0.25, 0.42), 0.16)
					var cracked := func(d: Vector3) -> Color: return LAVA if d.z * side < -0.5 and d.y < 0.3 else k.vary(BASALT, 0.1)
					k.sphere(Vector3(x, s.y * 0.5, side * 0.4), s, 0, 0.3, cracked, k.rand(0, 50))
			h.box(Vector3(0, 0.06, 0), Vector3(2.1, 0.1, 0.62), Color.WHITE)
			for i in 3:
				h.sphere(Vector3(k.rand(-0.8, 0.8), 0.12, k.rand(-0.15, 0.15)), Vector3(0.12, 0.07, 0.12), 0, 0.0, Color.WHITE)
			for i in 4:
				g.sphere(Vector3(k.rand(-0.9, 0.9), k.rand(0.55, 0.9), k.rand(-0.2, 0.2)), Vector3.ONE * 0.035, 0, 0.0, Color(1.0, 0.7, 0.2))
		"laser":
			for x in [-1.08, 1.08]:
				k.box(Vector3(x, 0.02, 0), Vector3(0.3, 0.04, 0.3), METAL.darkened(0.2))
				k.box(Vector3(x, 0.38, 0), Vector3(0.14, 0.72, 0.14), METAL)
				k.box(Vector3(x, 0.38, -0.075), Vector3(0.04, 0.6, 0.01), Color(0.15, 0.17, 0.22))
				g.box(Vector3(x, 0.77, 0), Vector3(0.18, 0.06, 0.18), Color(1.0, 0.3, 0.35))
			for y in [0.15, 0.3, 0.45]:
				h.cylinder(Vector3(-1.02, y, 0), Vector3(2.04, 0, 0), 0.032, 0.032, 6, Color.WHITE)
			g.box(Vector3(0, 0.012, 0), Vector3(2.0, 0.02, 0.06), Color(1.0, 0.25, 0.3))
	var mesh := k.commit(material)
	mesh = g.commit(glow, mesh)
	return h.commit(hazard, mesh)


## Arch spanning the whole road that carries a row's colour gates. Pillars stand outside the
## outer lanes and the beam is above any jump, so nothing here is an obstacle.
static func arch(style: String, material: Material, glow: Material) -> ArrayMesh:
	var k := MeshKit.new(70)
	var g := MeshKit.new(71)
	var top := ARCH_BEAM_Y
	match style:
		"wood":
			for side in [-1.0, 1.0]:
				k.cylinder(Vector3(side * ARCH_HALF, 0, 0), Vector3.UP * (top + 0.35), 0.22, 0.18, 7, BARK, true, 0.04)
				for i in 3:
					var at := Vector3(side * ARCH_HALF + k.rand(-0.3, 0.3), top + 0.35 + k.rand(0.0, 0.25), k.rand(-0.2, 0.2))
					k.sphere(at, Vector3.ONE * k.rand(0.32, 0.45), 1, 0.2, Obstacles.MOSS.lightened(k.rand(0.0, 0.15)))
				k.sphere(Vector3(side * ARCH_HALF, top + 0.8, -0.2), Vector3.ONE * 0.1, 0, 0.0, Color(1.0, 0.85, 0.3))
			k.cylinder(Vector3(-ARCH_HALF - 0.2, top + 0.18, 0), Vector3((ARCH_HALF + 0.2) * 2.0, 0, 0), 0.18, 0.18, 7, BARK.lightened(0.05), true, 0.03, Color(0.92, 0.76, 0.5))
			_hangers(k, top, Color(0.85, 0.72, 0.48))
		"ice":
			for side in [-1.0, 1.0]:
				k.cylinder(Vector3(side * ARCH_HALF, 0, 0), Vector3.UP * (top + 0.4), 0.3, 0.26, 6, Color(0.35, 0.72, 0.98), true, 0.03, SNOW)
				k.sphere(Vector3(side * ARCH_HALF, top + 0.45, 0), Vector3(0.38, 0.18, 0.34), 1, 0.15, SNOW)
			k.box(Vector3(0, top + 0.18, 0), Vector3((ARCH_HALF + 0.3) * 2.0, 0.3, 0.4), Color(0.55, 0.85, 1.0), 0.02)
			k.box(Vector3(0, top + 0.37, 0), Vector3((ARCH_HALF + 0.2) * 2.0, 0.1, 0.44), SNOW, 0.02)
			for x in [-3.6, -1.2, 1.2, 3.6]:
				k.cylinder(Vector3(x, top + 0.03, 0), Vector3(0, -0.28, 0), 0.07, 0.0, 5, ICE)
			_hangers(k, top, Color(0.8, 0.92, 1.0))
		"sandstone":
			var tones := [Color(0.86, 0.52, 0.32), Color(0.95, 0.66, 0.42), Color(0.78, 0.44, 0.28)]
			for side in [-1.0, 1.0]:
				var y := 0.0
				var i := 0
				while y < top:
					var hgt := minf(0.7, top - y)
					k.box(Vector3(side * ARCH_HALF, y + hgt * 0.5, 0), Vector3(0.6, hgt, 0.6), tones[i % 3], 0.03)
					y += hgt
					i += 1
				k.box(Vector3(side * ARCH_HALF, top + 0.5, 0), Vector3(0.75, 0.16, 0.75), tones[1], 0.02)
			k.box(Vector3(0, top + 0.22, 0), Vector3((ARCH_HALF + 0.3) * 2.0, 0.42, 0.5), tones[1], 0.03)
			for x in range(-3, 4):
				k.box(Vector3(x * 1.1, top + 0.22, -0.26), Vector3(0.5, 0.12, 0.02), tones[2])
			_hangers(k, top, Color(0.45, 0.3, 0.2))
		"basalt":
			for side in [-1.0, 1.0]:
				k.cylinder(Vector3(side * ARCH_HALF, 0, 0), Vector3.UP * (top + 0.5), 0.34, 0.3, 6, BASALT, true, 0.05, BASALT.lightened(0.1))
				g.box(Vector3(side * (ARCH_HALF - 0.25), top * 0.5, -0.16), Vector3(0.04, top * 0.8, 0.02), LAVA)
				g.sphere(Vector3(side * ARCH_HALF, top + 0.62, 0), Vector3(0.16, 0.12, 0.16), 0, 0.2, Color(1.0, 0.6, 0.15))
			k.box(Vector3(0, top + 0.22, 0), Vector3((ARCH_HALF + 0.3) * 2.0, 0.4, 0.5), BASALT.lightened(0.05), 0.04)
			g.box(Vector3(0, top + 0.1, -0.26), Vector3(ARCH_HALF * 2.0 - 0.6, 0.03, 0.02), LAVA)
			_hangers(k, top, Color(0.12, 0.1, 0.14))
		"tech":
			for side in [-1.0, 1.0]:
				k.box(Vector3(side * ARCH_HALF, (top + 0.4) * 0.5, 0), Vector3(0.36, top + 0.4, 0.36), METAL)
				g.box(Vector3(side * (ARCH_HALF - 0.19), (top + 0.4) * 0.5, 0), Vector3(0.02, top + 0.1, 0.1), Color(0.4, 0.9, 1.0))
				g.sphere(Vector3(side * ARCH_HALF, top + 0.5, 0), Vector3.ONE * 0.1, 0, 0.0, Color(1.0, 0.4, 0.5))
			k.box(Vector3(0, top + 0.3, 0), Vector3((ARCH_HALF + 0.2) * 2.0, 0.14, 0.3), METAL)
			k.box(Vector3(0, top + 0.02, 0), Vector3((ARCH_HALF + 0.2) * 2.0, 0.1, 0.3), METAL)
			for i in 12:
				var x := -ARCH_HALF + (i + 0.5) * ARCH_HALF * 2.0 / 12.0
				k.tube(Vector3(x - 0.3, top + 0.06, 0), Vector3(x + 0.3, top + 0.26, 0), 0.025, METAL.lightened(0.2), 4)
			g.box(Vector3(0, top - 0.04, -0.16), Vector3(ARCH_HALF * 2.0, 0.03, 0.02), Color(0.4, 0.9, 1.0))
			_hangers(k, top, METAL.lightened(0.3))
	return g.commit(glow, k.commit(material))


## Collectible gem for a colour slot, shaped like that colour's symbol: round, pyramid, cube.
static func gem(slot: int, material: Material) -> ArrayMesh:
	var k := MeshKit.new(5 + slot)
	match Defs.SYMBOLS[slot]:
		Defs.Symbol.CIRCLE:
			k.sphere(Vector3.ZERO, Vector3.ONE * 0.34, 1, 0.0, Color.WHITE)
		Defs.Symbol.TRIANGLE:
			k.cylinder(Vector3(0, -0.2, 0), Vector3.UP * 0.62, 0.4, 0.0, 3, Color.WHITE)
			k.cylinder(Vector3(0, -0.2, 0), Vector3.DOWN * 0.16, 0.4, 0.0, 3, Color.WHITE)
		_:
			k.box(Vector3.ZERO, Vector3.ONE * 0.46, Color.WHITE)
	return k.commit(material)


## Short hangers from the beam to the top of each lane's gate panel.
static func _hangers(k: MeshKit, top: float, color: Color) -> void:
	for lane in 3:
		for side in [-1.0, 1.0]:
			var x: float = Defs.lane_x(lane) + side * (LANE_EDGE - 0.15)
			k.tube(Vector3(x, top - 0.02, 0), Vector3(x, Track.GATE_TOP - 0.02, 0), 0.025, color, 4)


static func _mushroom(k: MeshKit, at: Vector3, size: float) -> void:
	k.cylinder(at, Vector3.UP * 0.5 * size, 0.1 * size, 0.08 * size, 6, BONE)
	var cap := Color(0.9, 0.45, 0.2)
	var dots := func(d: Vector3) -> Color: return BONE if d.y > 0.2 and MeshKit._hash(d, 3.0) > 0.7 else k.vary(cap, 0.05)
	k.sphere(at + Vector3.UP * 0.5 * size, Vector3(0.3, 0.2, 0.3) * size, 1, 0.05, dots)
