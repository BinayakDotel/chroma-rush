class_name Economy
## Shard rewards, world prices and what each purchase unlocks. Tune numbers here only.

## Entitlements a purchase can grant. Checked through Profile.has_entitlement().
const NO_ADS := &"no_ads"
const ALL_WORLDS := &"all_worlds"
const DOUBLE_SHARDS := &"double_shards"

const SHARDS_PER_ORB := 1
const METRES_PER_SHARD := 50.0

## Shards needed to unlock each world (0 = free).
const WORLD_COST := {
	"meadow": 0,
	"glacier": 500,
	"canyon": 1500,
	"volcano": 3500,
	"space": 6000,
}


static func world_cost(world_id: String) -> int:
	return WORLD_COST.get(world_id, 0)


## Shards earned by a finished run, before the Supporter Pack multiplier.
static func run_shards(orbs: int, metres: float) -> int:
	return orbs * SHARDS_PER_ORB + int(metres / METRES_PER_SHARD)
