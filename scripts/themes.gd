class_name Themes
## Visual themes: sky, lighting, path surface, scenery, obstacles and the player vehicle.
##
## Art direction (after the low-poly reference images): each world is built from one colour
## family plus a single accent, with a warm key light and cool, tinted shadows (the ambient
## colour), big calm shapes, and a soft horizon that the fog colour matches exactly. The world
## floats above a faceted sea (water, ice, sand haze or lava) drawn by the sky shader.
##
## Gate colours are shared by every world (Defs.COLORS); each world's sky, ground and path were
## tuned so those colours keep a CIEDE2000 difference of 12+ against them.
##
## Surfaces share one soft material (see Look and shaders/soft.gdshader); `look` sets its rim
## light per world, usually the colour of that world's sky glow. The path (`road`) is one calm
## colour with a darker shoulder, light dashes between the lanes (`mark_*`) and a low `kerb`.
##
## Keys used by the game besides the look: `id` (save key and price, see Economy), `character`
## and `tagline` (world picker), `arch` (gate arch style), `trail` (particles behind the vehicle).


static func all() -> Array[Dictionary]:
	return [meadow(), glacier(), canyon(), volcano(), space()]


## Index of the world with this id in all(), or 0 if unknown.
static func index_of(world_id: String) -> int:
	var worlds := all()
	for i in worlds.size():
		if worlds[i].id == world_id:
			return i
	return 0


## Green and earth-brown with pale stone; accent: turquoise sea. (Camping-diorama references.)
static func meadow() -> Dictionary:
	var horizon := Color(0.8, 0.9, 0.95)
	return {
		"id": "meadow",
		"name": "MEADOW",
		"character": "Fox in a go-kart",
		"tagline": "Rolling hills, pine forests and a turquoise sea.",
		"arch": "wood",
		"trail": {"color": Color(0.93, 0.87, 0.74, 0.55), "size": 0.16, "gravity": -4.0, "glow": false},
		"player": "kart",
		"fuel": "jerrycan",
		"sky": {
			"zenith_color": Color(0.3, 0.6, 0.9), "horizon_color": horizon,
			"ground_color": Color(0.26, 0.68, 0.76), "sea_amount": 1.0, "sea_glint": Color(0.85, 0.97, 1.0),
			"sun_color": Color(1.0, 0.96, 0.84), "sun_size": 0.06, "sun_glow": 0.3,
			"cloud_color": Color(1.0, 1.0, 1.0), "cloud_shade": Color(0.8, 0.84, 0.96), "cloud_amount": 0.3,
		},
		"sun_elevation": 42.0, "sun_azimuth": 35.0,
		"light_color": Color(1.0, 0.94, 0.82), "light_energy": 1.2,
		"ambient_sky": false, "ambient_color": Color(0.7, 0.76, 0.92), "ambient_energy": 0.45,
		"fog_color": horizon, "fog_begin": 160.0, "fog_end": 700.0, "fog_curve": 1.6,
		"fuel_color": Color(0.3, 0.9, 0.35),
		"road": {
			"base_color": Color(0.96, 0.9, 0.74), "shoulder_color": Color(0.78, 0.62, 0.42),
			"mark_color": Color(1.0, 1.0, 0.96), "mark_strength": 0.6, "line_strength": 0.4, "lane_glow": 0.0,
		},
		"kerb": Color(0.99, 0.97, 0.9),
		"look": {"rim_color": Color(1.0, 0.96, 0.82), "rim": 0.24},
		"verge": {
			"width": 8.0,
			"top": [Color(0.26, 0.6, 0.26), Color(0.3, 0.65, 0.28), Color(0.23, 0.56, 0.24)],
			"cliff": [Color(0.62, 0.4, 0.22), Color(0.5, 0.32, 0.2), Color(0.7, 0.47, 0.26), Color(0.44, 0.28, 0.18)],
			"fence": Color(0.56, 0.36, 0.2),
		},
		"block": "mossy_boulder", "hurdle": "log",
		"near": [["tiered_pine", 3.0], ["pine", 1.5], ["chunky_tree", 2.5], ["bush", 1.5],
			["pale_rock", 2.0], ["flowers", 1.0], ["mushroom", 0.4]],
		"near_count": 9,
		"far": [["mountain", 1.6], ["floating_island", 1.8], ["cloud", 1.4]],
		"far_spacing": 30.0,
	}


## White and ice blue under an aurora; accent: warm sunlit peaks.
static func glacier() -> Dictionary:
	return {
		"id": "glacier",
		"name": "GLACIER",
		"character": "Penguin on a bobsled",
		"tagline": "Ice spires under a shimmering aurora.",
		"arch": "ice",
		"trail": {"color": Color(0.96, 0.98, 1.0, 0.7), "size": 0.14, "gravity": -3.0, "glow": false},
		"player": "sled",
		"fuel": "fish",
		"sky": {
			"zenith_color": Color(0.12, 0.08, 0.38), "horizon_color": Color(0.42, 0.5, 0.95),
			"ground_color": Color(0.5, 0.75, 1.0), "sea_amount": 0.7, "sea_glint": Color(0.9, 0.97, 1.0),
			"sun_color": Color(0.95, 0.95, 1.0), "sun_size": 0.05, "sun_glow": 0.3,
			"star_amount": 0.8, "star_everywhere": 0.0,
			"nebula_a": Color(0.2, 1.0, 0.75), "nebula_b": Color(0.6, 0.35, 1.0), "nebula_amount": 0.7,
		},
		"sun_elevation": 25.0, "sun_azimuth": 30.0,
		"light_color": Color(1.0, 0.92, 0.88), "light_energy": 1.12,
		"ambient_sky": false, "ambient_color": Color(0.72, 0.8, 1.0), "ambient_energy": 0.6,
		"fog_color": Color(0.42, 0.52, 0.95), "fog_begin": 140.0, "fog_end": 600.0, "fog_curve": 1.5,
		"fuel_color": Color(0.2, 0.9, 1.0),
		"road": {
			"base_color": Color(0.8, 0.92, 1.0), "shoulder_color": Color(0.5, 0.72, 0.98),
			"mark_color": Color(1.0, 1.0, 1.0), "mark_strength": 0.7, "line_strength": 0.4, "lane_glow": 0.0,
		},
		"kerb": Color(0.96, 0.98, 1.0),
		"look": {"rim_color": Color(0.7, 1.0, 0.94), "rim": 0.32},
		"verge": {
			"width": 8.0,
			"top": [Color(0.95, 0.97, 1.0), Color(0.88, 0.93, 1.0), Color(0.92, 0.95, 1.0)],
			"cliff": [Color(0.3, 0.72, 0.95), Color(0.22, 0.58, 0.9), Color(0.45, 0.82, 1.0), Color(0.26, 0.5, 0.85)],
		},
		"block": "ice_cube", "hurdle": "snowy_log",
		"near": [["snowy_pine", 4.0], ["ice_crystal", 2.0], ["snow_rock", 1.5], ["snowman", 0.4]],
		"near_count": 8,
		"far": [["snow_mountain", 2.0], ["ice_spire", 1.8], ["cloud", 0.4]],
		"far_spacing": 30.0,
	}


## All warm sand, cream and orange in a hazy sun; accent: green cactus. (Desert reference.)
static func canyon() -> Dictionary:
	var horizon := Color(1.0, 0.87, 0.64)
	return {
		"id": "canyon",
		"name": "CANYON",
		"character": "Gecko in a dune buggy",
		"tagline": "Sun-baked mesas, cacti and hot-air balloons.",
		"arch": "sandstone",
		"trail": {"color": Color(0.98, 0.86, 0.68, 0.55), "size": 0.2, "gravity": -3.0, "glow": false},
		"player": "buggy",
		"fuel": "jerrycan",
		"sky": {
			"zenith_color": Color(0.6, 0.72, 0.88), "horizon_color": horizon,
			"ground_color": Color(0.98, 0.78, 0.5), "sea_amount": 0.5, "sea_glint": Color(1.0, 0.9, 0.7),
			"sun_color": Color(1.0, 0.98, 0.88), "sun_size": 0.08, "sun_glow": 0.5,
			"cloud_color": Color(1.0, 0.95, 0.86), "cloud_shade": Color(0.98, 0.8, 0.66), "cloud_amount": 0.15,
		},
		"sun_elevation": 30.0, "sun_azimuth": -30.0,
		"light_color": Color(1.0, 0.92, 0.78), "light_energy": 1.05,
		"ambient_sky": false, "ambient_color": Color(0.84, 0.62, 0.52), "ambient_energy": 0.42,
		"fog_color": horizon, "fog_begin": 180.0, "fog_end": 640.0, "fog_curve": 1.5,
		"fuel_color": Color(0.3, 0.9, 0.35),
		"road": {
			"base_color": Color(1.0, 0.96, 0.9), "shoulder_color": Color(0.9, 0.7, 0.5),
			"mark_color": Color(0.9, 0.72, 0.54), "mark_strength": 0.5, "line_strength": 0.4, "lane_glow": 0.0,
		},
		"kerb": Color(0.93, 0.62, 0.42),
		"look": {"rim_color": Color(1.0, 0.9, 0.7), "rim": 0.26},
		"verge": {
			"width": 7.0,
			"top": [Color(0.95, 0.72, 0.42), Color(0.92, 0.68, 0.38), Color(0.97, 0.76, 0.46)],
			"cliff": [Color(0.9, 0.55, 0.3), Color(0.8, 0.45, 0.26), Color(0.96, 0.66, 0.38), Color(0.86, 0.5, 0.28)],
		},
		"block": "saguaro", "hurdle": "ranch_fence",
		"near": [["cactus", 3.0], ["desert_rock", 2.0], ["dry_bush", 2.0]],
		"near_count": 6,
		"far": [["dune", 2.5], ["mesa", 2.0], ["hoodoo", 1.2], ["balloon", 0.6]],
		"far_spacing": 32.0,
	}


## Slate-purple rock under a violet dusk; accent: orange lava (and a lava sea below).
static func volcano() -> Dictionary:
	# A dusky purple horizon (not crimson) keeps the red gates readable against the sky.
	var horizon := Color(0.46, 0.24, 0.46)
	return {
		"id": "volcano",
		"name": "VOLCANO",
		"character": "Rock golem in a monster truck",
		"tagline": "Basalt cliffs above a sea of lava.",
		"arch": "basalt",
		"trail": {"color": Color(1.0, 0.55, 0.15, 1.0), "size": 0.09, "gravity": 3.0, "glow": true},
		"player": "monster",
		"fuel": "jerrycan",
		"sky": {
			"zenith_color": Color(0.16, 0.07, 0.24), "horizon_color": horizon,
			"ground_color": Color(1.0, 0.42, 0.1), "sea_amount": 1.0, "sea_glint": Color(1.0, 0.85, 0.3),
			"sun_color": Color(1.0, 0.66, 0.46), "sun_size": 0.1, "sun_glow": 0.45,
			"cloud_color": Color(0.46, 0.26, 0.4), "cloud_shade": Color(0.2, 0.11, 0.2), "cloud_amount": 0.35,
			"star_amount": 0.3, "star_everywhere": 0.0,
		},
		"sun_elevation": 38.0, "sun_azimuth": 30.0,
		"light_color": Color(1.0, 0.76, 0.6), "light_energy": 1.2,
		"ambient_sky": false, "ambient_color": Color(0.58, 0.44, 0.72), "ambient_energy": 0.45,
		"fog_color": horizon, "fog_begin": 130.0, "fog_end": 600.0, "fog_curve": 1.5,
		"fuel_color": Color(0.95, 0.95, 1.0),
		"road": {
			"base_color": Color(0.88, 0.85, 0.88), "shoulder_color": Color(0.56, 0.48, 0.62),
			"mark_color": Color(1.0, 0.98, 1.0), "mark_strength": 0.6, "line_strength": 0.4, "lane_glow": 0.0,
		},
		"kerb": Color(0.4, 0.34, 0.46),
		"look": {"rim_color": Color(1.0, 0.62, 0.34), "rim": 0.34},
		"verge": {
			"width": 7.0,
			"top": [Color(0.22, 0.19, 0.27), Color(0.26, 0.22, 0.3), Color(0.2, 0.17, 0.25)],
			"cliff": [Color(0.24, 0.2, 0.28), Color(0.3, 0.24, 0.32), Color(0.2, 0.17, 0.24), Color(0.95, 0.4, 0.1)],
		},
		"block": "lava_boulder", "hurdle": "lava_pool",
		"hazard": {"cool": Color(0.85, 0.16, 0.02), "hot": Color(1.0, 0.82, 0.28), "brightness": 1.8,
			"flow_speed": 0.5, "scale": 2.5, "pulse": 0.0},
		"near": [["obsidian", 2.5], ["dead_tree", 2.0], ["lava_rock", 2.5]],
		"near_count": 7,
		"far": [["volcano", 2.0], ["basalt_spire", 1.5], ["magma_rock", 1.2]],
		"far_spacing": 32.0,
	}


## Navy and teal with pastel planets; accent: the silver road. (Monument Valley reference.)
static func space() -> Dictionary:
	return {
		"id": "space",
		"name": "SOLAR SYSTEM",
		"character": "Alien astronaut in a star racer",
		"tagline": "Race between planets and asteroid fields.",
		"arch": "tech",
		"trail": {"color": Color(0.45, 0.85, 1.0, 1.0), "size": 0.08, "gravity": 0.0, "glow": true},
		"player": "rocket",
		"fuel": "energy_cell",
		"sky": {
			"zenith_color": Color(0.03, 0.05, 0.14), "horizon_color": Color(0.1, 0.24, 0.36),
			"ground_color": Color(0.03, 0.06, 0.13),
			"sun_color": Color(1.0, 0.9, 0.72), "sun_size": 0.05, "sun_glow": 0.5,
			"star_amount": 0.9, "star_everywhere": 1.0,
			"nebula_a": Color(0.2, 0.6, 0.66), "nebula_b": Color(0.42, 0.3, 0.78), "nebula_amount": 0.5,
		},
		"sun_elevation": 20.0, "sun_azimuth": 40.0,
		"light_color": Color(1.0, 0.95, 0.88), "light_energy": 1.35,
		"ambient_sky": false, "ambient_color": Color(0.42, 0.52, 0.78), "ambient_energy": 0.65,
		"fog_color": Color(0.08, 0.16, 0.26), "fog_begin": 220.0, "fog_end": 950.0, "fog_curve": 1.5,
		"fuel_color": Color(0.2, 0.9, 1.0),
		"road": {
			"base_color": Color(0.88, 0.9, 0.95), "shoulder_color": Color(0.56, 0.68, 0.86),
			"mark_color": Color(0.55, 0.92, 1.0), "mark_strength": 0.75, "line_strength": 0.5, "lane_glow": 0.6,
		},
		"kerb": Color(0.72, 0.84, 0.98),
		"look": {"rim_color": Color(0.6, 0.9, 1.0), "rim": 0.36},
		"verge": null,
		"side_color": Color(0.14, 0.22, 0.34),
		"block": "meteoroid", "hurdle": "laser",
		"hazard": {"cool": Color(1.0, 0.12, 0.3), "hot": Color(1.0, 0.75, 0.85), "brightness": 2.2,
			"flow_speed": 2.0, "scale": 6.0, "pulse": 1.0},
		"near": [],
		"near_count": 0,
		"far": [["asteroid", 6.0], ["planet", 0.35], ["ringed_planet", 0.3]],
		"far_spacing": 11.0,
	}
