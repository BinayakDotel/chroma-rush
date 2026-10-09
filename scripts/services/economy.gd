class_name Economy
## Shard rewards, world prices, upgrades and what each purchase unlocks. Tune numbers here only.

## Entitlements a purchase can grant. Checked through Profile.has_entitlement().
const NO_ADS := &"no_ads"
const ALL_WORLDS := &"all_worlds"
const DOUBLE_SHARDS := &"double_shards"

const SHARDS_PER_ORB := 1
const METRES_PER_SHARD := 50.0

## Shards needed to unlock each world (0 = free).
const WORLD_COST := {
	"meadow": 0,
	"glacier": 250,
	"canyon": 1500,
	"volcano": 3500,
	"space": 6000,
}


## Upgrades bought with shards. `levels` holds the value at level 0 (not bought) to 5: seconds
## for Overdrive and Magnet, a multiplier for Fuel Tank (how long a tank lasts) and Gem Luck
## (how often power gems turn up).
const UPGRADES := {
	"overdrive": {"name": "OVERDRIVE", "icon": "bolt", "blurb": "Prism Overdrive lasts longer",
		"levels": [5.0, 5.5, 6.0, 6.5, 7.0, 8.0], "unit": "s"},
	"magnet": {"name": "MAGNET", "icon": "magnet", "blurb": "Magnet gems pull for longer",
		"levels": [8.0, 9.0, 10.0, 11.0, 12.0, 14.0], "unit": "s"},
	"tank": {"name": "FUEL TANK", "icon": "fuel", "blurb": "A full tank lasts longer",
		"levels": [1.0, 1.05, 1.1, 1.15, 1.2, 1.25], "unit": "%"},
	"luck": {"name": "GEM LUCK", "icon": "gem", "blurb": "Power gems turn up more often",
		"levels": [1.0, 1.1, 1.2, 1.3, 1.4, 1.5], "unit": "%"},
}
## Shards for each level, 1 to 5.
const UPGRADE_COSTS: Array[int] = [150, 400, 800, 1500, 2500]


static func upgrade_value(id: String, level: int) -> float:
	var levels: Array = UPGRADES[id].levels
	return levels[clampi(level, 0, levels.size() - 1)]


static func max_level(id: String) -> int:
	return UPGRADES[id].levels.size() - 1


## Shards for the level after `level`, or -1 when already at the top.
static func upgrade_cost(id: String, level: int) -> int:
	return UPGRADE_COSTS[level] if level < max_level(id) else -1


## A level's effect as shown to the player: "6.5 s" or "+15%".
static func upgrade_label(id: String, level: int) -> String:
	var value := upgrade_value(id, level)
	if UPGRADES[id].unit == "s":
		return ("%.1f s" % value).replace(".0 s", " s")
	return "+%d%%" % roundi((value - 1.0) * 100.0)


static func world_cost(world_id: String) -> int:
	return WORLD_COST.get(world_id, 0)


## Shards earned by a finished run, before the Supporter Pack multiplier.
static func run_shards(orbs: int, metres: float) -> int:
	return orbs * SHARDS_PER_ORB + int(metres / METRES_PER_SHARD)
