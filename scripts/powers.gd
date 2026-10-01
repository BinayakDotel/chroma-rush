class_name Powers
## Rare power gems: what each one does, how it looks and how often it turns up. The game
## decides when one appears and applies its effect; the track places and shows it.

enum Kind { SHIELD, MAGNET, FULL_TANK, PRISM, PHOENIX }

## name and blurb are shown when picked up; icon is a UiIcon; color tints the gem and its beam.
## weight is how often it is chosen (adjusted for the player's state in Game).
const INFO := {
	Kind.SHIELD: {"name": "SHIELD", "blurb": "Shrugs off your next crash", "icon": "shield",
		"color": Color(0.3, 0.92, 1.0), "weight": 1.0},
	Kind.MAGNET: {"name": "MAGNET", "blurb": "Pulls in orbs from every lane", "icon": "magnet",
		"color": Color(0.82, 0.38, 1.0), "weight": 1.2},
	Kind.FULL_TANK: {"name": "FULL TANK", "blurb": "Fills your fuel to the top", "icon": "fuel",
		"color": Color(0.4, 1.0, 0.45), "weight": 1.0},
	Kind.PRISM: {"name": "PRISM CHARGE", "blurb": "Fills the Prism meter", "icon": "bolt",
		"color": Color(1.0, 1.0, 1.0), "weight": 0.9},
	Kind.PHOENIX: {"name": "PHOENIX GEM", "blurb": "A free revive, kept for any run", "icon": "gem",
		"color": Color(1.0, 0.5, 0.12), "weight": 0.22},
}

## First gem of a run, then one every EVERY metres (randomised), sooner with Gem Luck.
const FIRST_AT := 650.0
const EVERY := Vector2(700.0, 1050.0)
## Seconds of travel ahead at which a gem is placed: far enough to see it and steer for it.
const LEAD_TIME := Vector2(4.0, 6.0)
## Seconds a magnet lasts before upgrades (see Economy.UPGRADES "magnet").
const MAGNET_TIME := 8.0
## Phoenix gems only turn up once the run is going (metres), and only while the player holds
## fewer than Profile.MAX_REVIVE_TOKENS.
const PHOENIX_FROM := 1500.0


static func info(kind: Kind) -> Dictionary:
	return INFO[kind]


## The gem's shape, centred on the origin and about a metre across. Each kind has its own
## silhouette so it reads without relying on colour.
static func mesh(kind: Kind, material: Material) -> ArrayMesh:
	# Smooth where the thing is moulded (magnet, can), faceted where it is cut (badge, gems).
	var k := MeshKit.new(40 + kind, true)
	var white := Color.WHITE
	match kind:
		Kind.SHIELD:
			# A hexagonal badge facing the player.
			k.smooth = false
			k.cylinder(Vector3(0, 0, -0.1), Vector3(0, 0, 0.2), 0.55, 0.55, 6, white, true)
			k.cylinder(Vector3(0, 0, 0.1), Vector3(0, 0, 0.06), 0.36, 0.3, 6, white, true)
		Kind.MAGNET:
			# A horseshoe magnet, open end down: one bent bar with rounded ends.
			var path: Array = [Vector3(-0.38, -0.36, 0)]
			for i in 11:
				var a := PI - PI * i / 10.0
				path.append(Vector3(cos(a) * 0.38, 0.1 + sin(a) * 0.38, 0))
			path.append(Vector3(0.38, -0.36, 0))
			k.pipe(path, 0.14, white, 8)
		Kind.FULL_TANK:
			# A jerrycan.
			k.rounded_box(Vector3.ZERO, Vector3(0.62, 0.8, 0.32), 0.09, white)
			k.capsule(Vector3(-0.2, 0.5, 0), Vector3(0.1, 0.5, 0), 0.055, white)
			k.capsule(Vector3(0.2, 0.36, 0), Vector3(0.28, 0.58, 0), 0.08, white)
		Kind.PRISM:
			# A triangular prism lying on its side.
			k.smooth = false
			k.cylinder(Vector3(-0.45, 0, 0), Vector3(0.9, 0, 0), 0.42, 0.42, 3, white, true)
		Kind.PHOENIX:
			# A cut gemstone: shallow crown over a deep pavilion.
			k.smooth = false
			k.cylinder(Vector3(0, 0.05, 0), Vector3.UP * 0.32, 0.5, 0.28, 8, white, true)
			k.cylinder(Vector3(0, 0.05, 0), Vector3.DOWN * 0.6, 0.5, 0.0, 8, white)
	return k.commit(material)
