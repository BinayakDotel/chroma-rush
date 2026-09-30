class_name Themes
## Visual themes: sky, lighting, path surface, scenery, obstacles and the player vehicle.
##
## Art direction (after the low-poly reference images): each world is built from one colour
## family plus a single accent, with a warm key light and cool, tinted shadows (the ambient
## colour), big calm shapes, and a soft horizon that the fog colour matches exactly. The world
## floats above a faceted sea (water, ice, sand haze or lava) drawn by the sky shader.
##
## Each theme has its own three gate colours, picked for contrast against its sky, ground,
## path, obstacles, fuel and the dark vehicle bodies (checked with CIEDE2000 colour difference).


static func all() -> Array[Dictionary]:
	return [meadow(), glacier(), canyon(), volcano(), space()]


## Green and earth-brown with pale stone; accent: turquoise sea. (Camping-diorama references.)
static func meadow() -> Dictionary:
	var horizon := Color(0.8, 0.9, 0.95)
	return {
		"name": "MEADOW",
		"player": "kart",
		"fuel": "jerrycan",
		"sky": {
			"zenith_color": Color(0.3, 0.6, 0.9), "horizon_color": horizon,
			"ground_color": Color(0.26, 0.68, 0.76), "sea_amount": 1.0, "sea_glint": Color(0.85, 0.97, 1.0),
			"sun_color": Color(1.0, 0.96, 0.84), "sun_size": 0.06, "sun_glow": 0.3,
			"cloud_color": Color(1.0, 1.0, 1.0), "cloud_shade": Color(0.8, 0.84, 0.96), "cloud_amount": 0.3,
		},
		"sun_elevation": 42.0, "sun_azimuth": 35.0,
		"light_color": Color(1.0, 0.93, 0.8), "light_energy": 1.4,
		"ambient_sky": false, "ambient_color": Color(0.7, 0.76, 0.92), "ambient_energy": 0.45,
		"fog_color": horizon, "fog_begin": 160.0, "fog_end": 700.0, "fog_curve": 1.6,
		"gates": [Color(0.9, 0.12, 0.18), Color(0.95, 0.55, 0.05), Color(0.5, 0.18, 0.85)],
		"fuel_color": Color(0.3, 0.9, 0.35),
		"road": {
			"base_color": Color(0.96, 0.9, 0.74), "edge_color": Color(0.6, 0.42, 0.24),
			"lane_glow": 0.0, "roughness_value": 0.9, "metallic_value": 0.0,
		},
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
		"name": "GLACIER",
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
		"light_color": Color(1.0, 0.92, 0.88), "light_energy": 1.3,
		"ambient_sky": true, "ambient_color": Color.WHITE, "ambient_energy": 0.55,
		"fog_color": Color(0.42, 0.52, 0.95), "fog_begin": 140.0, "fog_end": 600.0, "fog_curve": 1.5,
		"gates": [Color(0.9, 0.12, 0.18), Color(1.0, 0.78, 0.05), Color(0.1, 0.65, 0.25)],
		"fuel_color": Color(0.2, 0.9, 1.0),
		"road": {
			"base_color": Color(0.8, 0.92, 1.0), "edge_color": Color(0.35, 0.6, 0.9),
			"lane_glow": 0.0, "roughness_value": 0.9, "metallic_value": 0.0,
		},
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
		"name": "CANYON",
		"player": "buggy",
		"fuel": "jerrycan",
		"sky": {
			"zenith_color": Color(0.6, 0.72, 0.88), "horizon_color": horizon,
			"ground_color": Color(0.98, 0.78, 0.5), "sea_amount": 0.5, "sea_glint": Color(1.0, 0.9, 0.7),
			"sun_color": Color(1.0, 0.98, 0.88), "sun_size": 0.08, "sun_glow": 0.7,
			"cloud_color": Color(1.0, 0.95, 0.86), "cloud_shade": Color(0.98, 0.8, 0.66), "cloud_amount": 0.15,
		},
		"sun_elevation": 30.0, "sun_azimuth": -30.0,
		"light_color": Color(1.0, 0.9, 0.72), "light_energy": 1.35,
		"ambient_sky": false, "ambient_color": Color(0.8, 0.6, 0.5), "ambient_energy": 0.45,
		"fog_color": horizon, "fog_begin": 180.0, "fog_end": 640.0, "fog_curve": 1.5,
		"gates": [Color(0.0, 0.6, 0.6), Color(0.88, 0.12, 0.62), Color(0.2, 0.3, 0.85)],
		"fuel_color": Color(0.3, 0.9, 0.35),
		"road": {
			"base_color": Color(1.0, 0.95, 0.86), "edge_color": Color(0.64, 0.36, 0.22),
			"lane_glow": 0.0, "roughness_value": 0.9, "metallic_value": 0.0,
		},
		"verge": {
			"width": 7.0,
			"top": [Color(0.98, 0.78, 0.46), Color(0.95, 0.73, 0.42), Color(1.0, 0.82, 0.52)],
			"cliff": [Color(0.9, 0.55, 0.3), Color(0.8, 0.45, 0.26), Color(0.96, 0.66, 0.38), Color(0.86, 0.5, 0.28)],
		},
		"block": "saguaro", "hurdle": "ranch_fence",
		"near": [["cactus", 3.0], ["desert_rock", 2.0], ["dry_bush", 2.0]],
		"near_count": 6,
		"far": [["dune", 2.5], ["mesa", 2.0], ["hoodoo", 1.2], ["balloon", 0.6]],
		"far_spacing": 32.0,
	}


## Slate-purple rock under a crimson dusk; accent: orange lava (and a lava sea below).
static func volcano() -> Dictionary:
	var horizon := Color(0.82, 0.3, 0.36)
	return {
		"name": "VOLCANO",
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
		"light_color": Color(1.0, 0.76, 0.6), "light_energy": 1.3,
		"ambient_sky": false, "ambient_color": Color(0.58, 0.44, 0.72), "ambient_energy": 0.45,
		"fog_color": horizon, "fog_begin": 130.0, "fog_end": 600.0, "fog_curve": 1.5,
		"gates": [Color(0.45, 0.85, 0.1), Color(0.0, 0.75, 0.95), Color(1.0, 0.78, 0.05)],
		"fuel_color": Color(0.95, 0.95, 1.0),
		"road": {
			"base_color": Color(0.88, 0.85, 0.88), "edge_color": Color(0.22, 0.18, 0.26),
			"lane_glow": 0.0, "roughness_value": 0.9, "metallic_value": 0.0,
		},
		"verge": {
			"width": 7.0,
			"top": [Color(0.22, 0.19, 0.27), Color(0.26, 0.22, 0.3), Color(0.2, 0.17, 0.25)],
			"cliff": [Color(0.24, 0.2, 0.28), Color(0.3, 0.24, 0.32), Color(0.2, 0.17, 0.24), Color(0.95, 0.4, 0.1)],
		},
		"block": "lava_boulder", "hurdle": "lava_pool",
		"near": [["obsidian", 2.5], ["dead_tree", 2.0], ["lava_rock", 2.5]],
		"near_count": 7,
		"far": [["volcano", 2.0], ["basalt_spire", 1.5], ["magma_rock", 1.2]],
		"far_spacing": 32.0,
	}


## Navy and teal with pastel planets; accent: the silver road. (Monument Valley reference.)
static func space() -> Dictionary:
	return {
		"name": "SOLAR SYSTEM",
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
		"light_color": Color(1.0, 0.95, 0.88), "light_energy": 1.6,
		"ambient_sky": false, "ambient_color": Color(0.42, 0.52, 0.78), "ambient_energy": 0.65,
		"fog_color": Color(0.08, 0.16, 0.26), "fog_begin": 220.0, "fog_end": 950.0, "fog_curve": 1.5,
		"gates": [Color(0.9, 0.12, 0.18), Color(1.0, 0.78, 0.05), Color(0.1, 0.65, 0.25)],
		"fuel_color": Color(0.2, 0.9, 1.0),
		"road": {
			"base_color": Color(0.88, 0.9, 0.95), "edge_color": Color(0.2, 0.4, 0.55),
			"lane_glow": 0.5, "roughness_value": 0.9, "metallic_value": 0.0,
		},
		"verge": null,
		"side_color": Color(0.14, 0.22, 0.34),
		"block": "meteoroid", "hurdle": "laser",
		"near": [],
		"near_count": 0,
		"far": [["asteroid", 6.0], ["planet", 0.35], ["ringed_planet", 0.3]],
		"far_spacing": 11.0,
	}
