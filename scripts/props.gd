class_name Props
extends RefCounted
## Procedural low-poly models: scenery props, landmarks and fuel pickups.
## Obstacles live in Obstacles, the player vehicles in Vehicles.

const BARK := Color(0.45, 0.3, 0.2)
const SNOW := Color(0.95, 0.97, 1.0)
const LEAVES := [Color(0.3, 0.64, 0.28), Color(0.44, 0.74, 0.3), Color(0.22, 0.55, 0.26)]
const BLOSSOM := [Color(1.0, 0.62, 0.75), Color(1.0, 0.8, 0.88), Color(0.95, 0.55, 0.85)]
const FLOWERS := [Color(1.0, 0.85, 0.2), Color(1.0, 1.0, 1.0), Color(1.0, 0.7, 0.3)]
const BALLOON := [Color(1.0, 0.35, 0.35), Color(1.0, 0.82, 0.2), Color(0.3, 0.7, 1.0), Color(0.5, 0.85, 0.4), Color(0.9, 0.45, 0.9)]
const PLANETS := [
	[Color(0.98, 0.85, 0.66), Color(0.94, 0.72, 0.52), Color(1.0, 0.92, 0.78)],
	[Color(0.36, 0.72, 0.76), Color(0.5, 0.84, 0.82), Color(0.28, 0.6, 0.68)],
	[Color(0.96, 0.52, 0.46), Color(0.88, 0.4, 0.4), Color(1.0, 0.68, 0.56)],
	[Color(0.62, 0.56, 0.9), Color(0.74, 0.68, 0.96), Color(0.52, 0.46, 0.82)],
]
const GREENS := [Color(0.3, 0.64, 0.28), Color(0.44, 0.74, 0.3), Color(0.22, 0.55, 0.26)]
const AUTUMN := [Color(1.0, 0.62, 0.12), Color(1.0, 0.48, 0.1), Color(0.98, 0.75, 0.2)]
const PINE := Color(0.16, 0.48, 0.24)
const TRUNK := Color(0.36, 0.22, 0.14)
const BASALT := Color(0.22, 0.19, 0.27)
const LAVA := Color(1.0, 0.45, 0.08)
const DARK := Color(0.12, 0.12, 0.16)
const CREAM := Color(0.96, 0.92, 0.82)


## `tint` colours theme-dependent parts (the fuel pickups).
static func build(kind: String, seed_value: int, material: Material, tint := Color.WHITE) -> ArrayMesh:
	# Pickups are smooth and clean; scenery is faceted.
	var k := MeshKit.new(seed_value, kind in ["jerrycan", "fish", "energy_cell"])
	match kind:
		"round_tree":
			_round_tree(k, LEAVES[seed_value % LEAVES.size()], Vector3.ZERO)
		"blossom_tree":
			_round_tree(k, BLOSSOM[seed_value % BLOSSOM.size()], Vector3.ZERO)
		"pine":
			_pine(k, false)
		"snowy_pine":
			_tiered_pine(k, true)
		"tiered_pine":
			_tiered_pine(k, false)
		"chunky_tree":
			_round_tree(k, GREENS[seed_value % GREENS.size()], Vector3.ZERO)
		"autumn_tree":
			_round_tree(k, AUTUMN[seed_value % AUTUMN.size()], Vector3.ZERO)
		"coral_rock":
			_chunk_rock(k, Color(0.93, 0.44, 0.4))
		"pale_rock":
			_rock(k, Color(0.86, 0.85, 0.82), false)
		"dune":
			var sand := func(d: Vector3) -> Color: return k.vary(Color(1.0, 0.82, 0.5) if d.x > 0.0 else Color(0.95, 0.72, 0.42), 0.03)
			k.sphere(Vector3.ZERO, Vector3(40.0, 14.0, 22.0), 2, 0.06, sand, k.rand(0, 50))
		"obsidian":
			_obsidian(k)
		"dead_tree":
			_dead_tree(k)
		"lava_rock":
			_lava_rock(k, 1.0)
		"magma_rock":
			_lava_rock(k, 1.0)
		"volcano":
			k.mountain(Vector3.ZERO, 40.0, 80.0, 9, [
				[0.45, BASALT], [0.75, Color(0.32, 0.22, 0.22)], [0.86, Color(0.55, 0.2, 0.12)], [2.0, LAVA]])
		"basalt_spire":
			k.mountain(Vector3.ZERO, 9.0, 60.0, 6, [
				[0.3, BASALT], [0.55, Color(0.28, 0.22, 0.24)], [0.8, Color(0.18, 0.15, 0.17)], [2.0, Color(0.4, 0.2, 0.16)]])
		"bush":
			_bush(k, LEAVES[seed_value % LEAVES.size()], true)
		"dry_bush":
			_dry_bush(k)
		"flowers":
			_flowers(k)
		"mushroom":
			_mushroom(k)
		"rock":
			_rock(k, Color(0.6, 0.58, 0.62), false)
		"snow_rock":
			_rock(k, Color(0.48, 0.54, 0.68), true)
		"desert_rock":
			_rock(k, Color(0.8, 0.46, 0.3), false)
		"ice_crystal":
			_ice_crystal(k)
		"snowman":
			_snowman(k)
		"cactus":
			_cactus(k)
		"mountain":
			k.mountain(Vector3.ZERO, 30.0, 110.0, 9, [
				[0.35, Color(0.26, 0.58, 0.26)], [0.6, Color(0.72, 0.72, 0.74)],
				[0.82, Color(0.84, 0.84, 0.86)], [2.0, SNOW]])
		"snow_mountain":
			k.mountain(Vector3.ZERO, 30.0, 110.0, 9, [
				[0.45, Color(0.45, 0.5, 0.66)], [0.68, Color(0.68, 0.76, 0.9)], [2.0, SNOW]])
		"hoodoo":
			k.mountain(Vector3.ZERO, 9.0, 60.0, 7, [
				[0.2, Color(0.72, 0.34, 0.24)], [0.4, Color(0.9, 0.58, 0.36)], [0.6, Color(0.78, 0.4, 0.26)],
				[0.8, Color(0.95, 0.7, 0.48)], [2.0, Color(0.85, 0.5, 0.32)]])
		"ice_spire":
			_ice_spire(k)
		"floating_island":
			_floating_island(k)
		"cloud":
			_cloud(k)
		"mesa":
			_mesa(k)
		"balloon":
			_balloon(k)
		"asteroid":
			_asteroid(k)
		"planet":
			_planet(k, false)
		"ringed_planet":
			_planet(k, true)
		"jerrycan":
			_jerrycan(k, tint)
		"fish":
			_fish(k)
		"energy_cell":
			_energy_cell(k, tint)
	return k.commit(material)


# --- scenery ---------------------------------------------------------------

static func _round_tree(k: MeshKit, leaf: Color, at: Vector3) -> void:
	var h := k.rand(1.3, 1.9)
	k.cylinder(at, Vector3.UP * (h + 0.4), 0.22, 0.14, 6, BARK)
	var r := k.rand(1.1, 1.5)
	k.sphere(at + Vector3(0, h + r * 0.7, 0), Vector3(r, r * 0.9, r), 1, 0.18, leaf, k.rand(0, 100))
	if k.rng.randf() < 0.7:
		var off := Vector3(k.rand(-0.7, 0.7), h + r * 0.45, k.rand(-0.7, 0.7))
		k.sphere(at + off, Vector3.ONE * r * 0.65, 1, 0.2, leaf.darkened(0.08), k.rand(0, 100))


static func _pine(k: MeshKit, snowy: bool) -> void:
	k.cylinder(Vector3.ZERO, Vector3.UP * 0.9, 0.18, 0.14, 5, BARK)
	var green := Color(0.16, 0.5, 0.32)
	var y := 0.6
	var r := k.rand(1.2, 1.5)
	for i in k.rng.randi_range(3, 4):
		var h := r * 1.3
		k.cylinder(Vector3(0, y, 0), Vector3.UP * h, r, 0.0, 7, green)
		if snowy:
			k.cylinder(Vector3(0, y + h * 0.45, 0), Vector3.UP * h * 0.58, r * 0.6, 0.0, 7, SNOW)
		y += h * 0.55
		r *= 0.72


static func _bush(k: MeshKit, leaf: Color, flowers: bool) -> void:
	var s := k.rand(0.8, 1.2)
	k.sphere(Vector3(0, 0.3 * s, 0), Vector3(0.8, 0.55, 0.8) * s, 1, 0.2, leaf, k.rand(0, 100))
	if flowers:
		var col: Color = FLOWERS[k.rng.randi() % FLOWERS.size()]
		for i in k.rng.randi_range(3, 6):
			var a := k.rand(0, TAU)
			k.sphere(Vector3(cos(a) * 0.45 * s, 0.7 * s, sin(a) * 0.45 * s), Vector3.ONE * 0.11, 0, 0.0, col)


static func _dry_bush(k: MeshKit) -> void:
	for i in 7:
		var dir := Vector3(k.rand(-0.7, 0.7), 1.0, k.rand(-0.7, 0.7)).normalized()
		k.cylinder(Vector3.ZERO, dir * k.rand(0.6, 1.1), 0.08, 0.0, 4, Color(0.62, 0.55, 0.3))


static func _flowers(k: MeshKit) -> void:
	for i in k.rng.randi_range(5, 9):
		var base := Vector3(k.rand(-0.8, 0.8), 0.0, k.rand(-0.8, 0.8))
		var h := k.rand(0.3, 0.6)
		k.cylinder(base, Vector3.UP * h, 0.03, 0.03, 3, Color(0.3, 0.6, 0.25))
		k.sphere(base + Vector3.UP * h, Vector3.ONE * 0.11, 0, 0.1, FLOWERS[k.rng.randi() % FLOWERS.size()])


static func _mushroom(k: MeshKit) -> void:
	var h := k.rand(0.45, 0.7)
	k.cylinder(Vector3.ZERO, Vector3.UP * h, 0.16, 0.12, 6, CREAM)
	var red := Color(0.9, 0.2, 0.2)
	var dots := func(d: Vector3) -> Color:
		return CREAM if d.y > 0.2 and MeshKit._hash(d, 3.0) > 0.7 else k.vary(red, 0.05)
	k.sphere(Vector3(0, h, 0), Vector3(0.5, 0.32, 0.5), 1, 0.05, dots)


static func _rock(k: MeshKit, base: Color, snow_top: bool) -> void:
	var s := Vector3(k.rand(0.8, 1.3), k.rand(0.5, 0.9), k.rand(0.8, 1.2))
	var color = base
	if snow_top:
		color = func(d: Vector3) -> Color: return k.vary(SNOW if d.y > 0.35 else base, 0.05)
	k.sphere(Vector3(0, s.y * 0.4, 0), s, 1, 0.3, color, k.rand(0, 100))


static func _ice_crystal(k: MeshKit) -> void:
	var ice := Color(0.35, 0.82, 1.0)
	for i in k.rng.randi_range(3, 5):
		var dir := Vector3(k.rand(-0.45, 0.45), 1.0, k.rand(-0.45, 0.45)).normalized()
		var length := k.rand(0.8, 2.2)
		var r := k.rand(0.14, 0.28)
		var base := Vector3(k.rand(-0.3, 0.3), 0.0, k.rand(-0.3, 0.3))
		k.cylinder(base, dir * length, r, r, 6, ice)
		k.cylinder(base + dir * length, dir * r * 1.8, r, 0.0, 6, Color(0.85, 0.97, 1.0))


static func _snowman(k: MeshKit) -> void:
	k.sphere(Vector3(0, 0.6, 0), Vector3.ONE * 0.7, 1, 0.06, SNOW)
	k.sphere(Vector3(0, 1.45, 0), Vector3.ONE * 0.5, 1, 0.06, SNOW)
	k.sphere(Vector3(0, 2.1, 0), Vector3.ONE * 0.36, 1, 0.06, SNOW)
	k.cylinder(Vector3(0, 2.1, -0.32), Vector3(0, -0.03, -0.35), 0.07, 0.0, 5, Color(1.0, 0.5, 0.1))
	for x in [-0.13, 0.13]:
		k.sphere(Vector3(x, 2.22, -0.3), Vector3.ONE * 0.05, 0, 0.0, DARK)
	k.cylinder(Vector3(0, 2.38, 0), Vector3.UP * 0.1, 0.42, 0.42, 8, DARK, true)
	k.cylinder(Vector3(0, 2.45, 0), Vector3.UP * 0.4, 0.26, 0.26, 8, DARK, true)
	k.cylinder(Vector3(0, 1.78, 0), Vector3.UP * 0.12, 0.42, 0.4, 8, Color(0.9, 0.2, 0.25), true)


static func _cactus(k: MeshKit) -> void:
	var green := Color(0.32, 0.62, 0.3)
	var h := k.rand(2.0, 3.0)
	k.cylinder(Vector3.ZERO, Vector3.UP * h, 0.36, 0.3, 7, green)
	k.sphere(Vector3(0, h, 0), Vector3.ONE * 0.3, 0, 0.0, green)
	for i in k.rng.randi_range(1, 2):
		var side := Vector3.RIGHT if i == 0 else Vector3.LEFT
		var y := k.rand(0.9, h * 0.65)
		k.cylinder(Vector3(0, y, 0), side * 0.7, 0.2, 0.2, 6, green)
		var up := k.rand(0.5, 0.9)
		k.cylinder(side * 0.62 + Vector3(0, y - 0.1, 0), Vector3.UP * up, 0.2, 0.18, 6, green)
		k.sphere(side * 0.62 + Vector3(0, y - 0.1 + up, 0), Vector3.ONE * 0.18, 0, 0.0, green)
	if k.rng.randf() < 0.5:
		k.sphere(Vector3(0, h + 0.3, 0), Vector3.ONE * 0.13, 0, 0.0, Color(1.0, 0.45, 0.65))


static func _ice_spire(k: MeshKit) -> void:
	for i in k.rng.randi_range(3, 5):
		var dir := Vector3(k.rand(-0.25, 0.25), 1.0, k.rand(-0.25, 0.25)).normalized()
		var r := k.rand(3.0, 6.0)
		var length := k.rand(30.0, 60.0)
		var base := Vector3(k.rand(-6, 6), 0.0, k.rand(-6, 6))
		var col := Color(0.3, 0.75, 1.0) if i % 2 == 0 else Color(0.55, 0.9, 1.0)
		k.cylinder(base, dir * length, r, r * 0.9, 6, col)
		k.cylinder(base + dir * length, dir * r * 2.0, r * 0.9, 0.0, 6, SNOW)


static func _floating_island(k: MeshKit) -> void:
	var r := k.rand(4.5, 7.0)
	var dirt := [Color(0.62, 0.4, 0.22), Color(0.48, 0.3, 0.19), Color(0.6, 0.46, 0.3)]
	k.cylinder(Vector3(0, -0.3, 0), Vector3.DOWN * r * 0.6, r, r * 0.6, 8, dirt[0], false, 0.12)
	k.cylinder(Vector3(0, -0.3 - r * 0.6, 0), Vector3.DOWN * r * 0.9, r * 0.6, 0.2, 8, dirt[1], false, 0.15)
	k.cylinder(Vector3(0, -0.3, 0), Vector3.UP * 0.35, r * 1.02, r * 0.96, 8, Color(0.26, 0.6, 0.26), true, 0.05)
	for i in k.rng.randi_range(1, 3):
		var a := k.rand(0, TAU)
		var at := Vector3(cos(a), 0, sin(a)) * k.rand(0.0, r * 0.55)
		_round_tree(k, LEAVES[k.rng.randi() % LEAVES.size()], at)


static func _cloud(k: MeshKit) -> void:
	var shade := func(d: Vector3) -> Color:
		return k.vary(Color(1, 1, 1) if d.y > -0.2 else Color(0.8, 0.84, 0.96), 0.03)
	for i in k.rng.randi_range(4, 6):
		var c := Vector3(k.rand(-4.0, 4.0), k.rand(-0.3, 0.8), k.rand(-1.5, 1.5))
		var r := k.rand(1.6, 2.8)
		k.sphere(c, Vector3(r, r * 0.75, r), 1, 0.08, shade, k.rand(0, 100))


static func _mesa(k: MeshKit) -> void:
	var bands := [Color(0.8, 0.42, 0.28), Color(0.92, 0.6, 0.38), Color(0.72, 0.34, 0.24), Color(0.95, 0.72, 0.5)]
	var r := k.rand(20.0, 30.0)
	var height := k.rand(80.0, 100.0)
	var layers := k.rng.randi_range(4, 6)
	var y := 0.0
	for l in layers:
		var h := height / layers
		var r_next := r * k.rand(0.88, 0.97)
		var top_cap: Color = Color(0.92, 0.64, 0.42) if l == layers - 1 else bands[l % bands.size()]
		k.cylinder(Vector3(0, y, 0), Vector3.UP * h, r, r_next, 10, bands[l % bands.size()], true, 0.05, top_cap)
		y += h
		r = r_next


static func _balloon(k: MeshKit) -> void:
	var ia := k.rng.randi() % BALLOON.size()
	var a: Color = BALLOON[ia]
	var b: Color = BALLOON[(ia + k.rng.randi_range(1, BALLOON.size() - 1)) % BALLOON.size()]
	var stripes := func(d: Vector3) -> Color:
		return k.vary(a if int(floor((atan2(d.z, d.x) + PI) / TAU * 10.0)) % 2 == 0 else b, 0.04)
	k.sphere(Vector3(0, 3.2, 0), Vector3(1.6, 1.9, 1.6), 1, 0.0, stripes)
	k.cylinder(Vector3(0, 1.1, 0), Vector3.UP * 0.6, 0.45, 0.9, 8, a)
	k.box(Vector3(0, 0.3, 0), Vector3(0.7, 0.55, 0.7), Color(0.55, 0.38, 0.22))
	for x in [-0.3, 0.3]:
		for z in [-0.3, 0.3]:
			k.cylinder(Vector3(x, 0.55, z), Vector3(x * 0.4, 0.6, z * 0.4), 0.025, 0.025, 3, BARK)


static func _asteroid(k: MeshKit) -> void:
	var tones := [Color(0.42, 0.46, 0.58), Color(0.36, 0.42, 0.54), Color(0.48, 0.5, 0.62)]
	var base: Color = tones[k.rng.randi() % tones.size()]
	k.sphere(Vector3.ZERO, Vector3(1.0, k.rand(0.6, 0.9), k.rand(0.7, 1.0)), 1, 0.4, base, k.rand(0, 100))
	if k.rng.randf() < 0.4:
		for i in 3:
			var dir := Vector3(k.rand(-1, 1), k.rand(0.2, 1), k.rand(-1, 1)).normalized()
			k.cylinder(dir * 0.5, dir * k.rand(0.4, 0.8), 0.12, 0.0, 5, Color(0.6, 0.95, 1.0))


static func _planet(k: MeshKit, ringed: bool) -> void:
	var palette: Array = PLANETS[k.rng.randi() % PLANETS.size()]
	var wobble := k.rand(0, 10)
	var bands := func(d: Vector3) -> Color:
		var lat := d.y + 0.08 * sin(d.x * 9.0 + wobble)
		var idx := int(floor((lat * 0.5 + 0.5) * palette.size() * 2.0))
		return k.vary(palette[posmod(idx, palette.size())], 0.03)
	k.sphere(Vector3.ZERO, Vector3.ONE, 3, 0.015, bands)
	if ringed:
		var ring_colors := [palette[0].lightened(0.2), palette[1], palette[0].darkened(0.1), palette[2].lightened(0.3)]
		k.ring(Vector3.ZERO, Vector3(0.25, 1.0, 0.1), 1.45, 2.3, 48, ring_colors)


## Pine made of stacked, flattened tiers on a dark trunk.
static func _tiered_pine(k: MeshKit, snowy: bool) -> void:
	var tiers := k.rng.randi_range(3, 4)
	var r := k.rand(1.3, 1.7)
	var y := 0.9
	var green := PINE.lightened(k.rand(-0.05, 0.12))
	k.cylinder(Vector3.ZERO, Vector3.UP * (y + tiers * 0.95 + 0.4), 0.2, 0.12, 6, TRUNK)
	for i in tiers:
		var h := 0.85
		var top: Color = Props.SNOW if snowy else green.darkened(0.12)
		k.cylinder(Vector3(0, y, 0), Vector3.UP * h, r, r * 0.4, 8, green, true, 0.06, top)
		y += 0.95
		r *= 0.76
	k.cylinder(Vector3(0, y, 0), Vector3.UP * 0.9, r * 0.9, 0.0, 8, Props.SNOW if snowy else green)


## Chunky blocky rocks.
static func _chunk_rock(k: MeshKit, color: Color) -> void:
	for i in k.rng.randi_range(1, 3):
		var size := Vector3(k.rand(0.5, 1.1), k.rand(0.35, 0.8), k.rand(0.5, 1.0))
		var at := Vector3(k.rand(-0.6, 0.6), size.y * 0.45, k.rand(-0.6, 0.6))
		k.box(at, size, color, 0.12)


static func _obsidian(k: MeshKit) -> void:
	for i in k.rng.randi_range(3, 5):
		var dir := Vector3(k.rand(-0.5, 0.5), 1.0, k.rand(-0.5, 0.5)).normalized()
		var length := k.rand(0.8, 2.0)
		var r := k.rand(0.18, 0.32)
		var base := Vector3(k.rand(-0.4, 0.4), 0.0, k.rand(-0.4, 0.4))
		k.cylinder(base, dir * length, r, r * 0.8, 5, Color(0.12, 0.1, 0.14))
		k.cylinder(base + dir * length, dir * r * 2.2, r * 0.8, 0.0, 5, LAVA)


static func _dead_tree(k: MeshKit) -> void:
	var charred := Color(0.18, 0.14, 0.13)
	var h := k.rand(2.2, 3.2)
	k.cylinder(Vector3.ZERO, Vector3.UP * h, 0.24, 0.1, 5, charred)
	for i in k.rng.randi_range(2, 4):
		var y := k.rand(1.0, h * 0.9)
		var a := k.rand(0, TAU)
		var dir := Vector3(cos(a), k.rand(0.4, 1.0), sin(a)).normalized()
		k.cylinder(Vector3(0, y, 0), dir * k.rand(0.6, 1.2), 0.08, 0.02, 4, charred)


## Dark rock with glowing lava faces.
static func _lava_rock(k: MeshKit, size: float) -> void:
	var cracked := func(d: Vector3) -> Color:
		return LAVA if MeshKit._hash(d, 9.0) > 0.8 else k.vary(BASALT, 0.1)
	var s := Vector3(k.rand(0.8, 1.3), k.rand(0.5, 0.9), k.rand(0.8, 1.2)) * size
	k.sphere(Vector3(0, s.y * 0.4, 0), s, 1, 0.3, cracked, k.rand(0, 100))


# --- fuel pickups (centred on the origin so they can spin) -----------------

static func _jerrycan(k: MeshKit, body: Color) -> void:
	k.rounded_box(Vector3.ZERO, Vector3(0.3, 0.7, 0.56), 0.08, body)
	# A paler pressed panel on each side, the cap, and a handle across the top.
	k.rounded_box(Vector3.ZERO, Vector3(0.34, 0.34, 0.36), 0.05, body.lightened(0.35))
	k.capsule(Vector3(0, 0.3, -0.2), Vector3(0, 0.44, -0.27), 0.06, DARK)
	k.capsule(Vector3(0, 0.34, -0.02), Vector3(0, 0.45, 0.0), 0.03, body.darkened(0.25))
	k.capsule(Vector3(0, 0.45, 0.0), Vector3(0, 0.45, 0.2), 0.03, body.darkened(0.25))
	k.capsule(Vector3(0, 0.45, 0.2), Vector3(0, 0.34, 0.22), 0.03, body.darkened(0.25))


static func _fish(k: MeshKit) -> void:
	var skin := func(d: Vector3) -> Color:
		return Color(0.95, 0.97, 1.0).lerp(Color(0.3, 0.62, 1.0), smoothstep(-0.35, 0.15, d.y))
	k.sphere(Vector3.ZERO, Vector3(0.17, 0.25, 0.48), 2, 0.0, skin)
	var fin := Color(0.25, 0.5, 0.95)
	k.smooth = false
	k.slab([Vector3(0, 0, 0.4), Vector3(0, 0.27, 0.78), Vector3(0, 0, 0.66), Vector3(0, -0.27, 0.78)], 0.03, fin)
	k.slab([Vector3(0, 0.2, -0.1), Vector3(0, 0.38, 0.14), Vector3(0, 0.2, 0.2)], 0.03, fin)
	k.smooth = true
	for x in [-0.13, 0.13]:
		k.sphere(Vector3(x, 0.06, -0.3), Vector3.ONE * 0.05, 1, 0.0, DARK)
		k.sphere(Vector3(x * 1.2, 0.08, -0.32), Vector3.ONE * 0.018, 0, 0.0, Color.WHITE)


static func _energy_cell(k: MeshKit, glow: Color) -> void:
	var metal := Color(0.36, 0.4, 0.5)
	var bright := glow.lightened(0.3)
	var paint := func(p: Vector3, _n: Vector3) -> Color: return bright if absf(p.y) < 0.23 else metal
	# Repeated points make crisp steps between the caps and the glowing core.
	k.lathe(Vector3(0, -0.4, 0), Vector3.UP, [
		Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.25, 0.04), Vector2(0.25, 0.16), Vector2(0.25, 0.16),
		Vector2(0.2, 0.16), Vector2(0.2, 0.64), Vector2(0.2, 0.64), Vector2(0.25, 0.64), Vector2(0.25, 0.76),
		Vector2(0.2, 0.8), Vector2(0.09, 0.8), Vector2(0.09, 0.8), Vector2(0.09, 0.88), Vector2(0.0, 0.9),
	], 12, paint)
