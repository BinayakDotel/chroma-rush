class_name Missions
## Three small goals at a time, so every run has something to aim for beyond the score. Each
## pays shards when it is completed (straight away, even mid-run) and is replaced by a new one
## when the run ends. Targets and rewards grow with the number of missions completed.
##
## A mission is a Dictionary saved in the profile: {kind, target, reward, progress, done}.
## "run" missions must be done within one run (progress keeps the best attempt so far);
## "total" missions add up across runs. The game reports a run's counters (see STATS) a few
## times a second through check(), and once more through finish_run() when the run is over.

const SLOTS := 3
## Counters a run reports: gates passed, metres driven, orbs collected, hurdles jumped, fuel
## pickups taken, power gems taken, obstacles smashed in Overdrive, Overdrives started.
const STATS: Array[String] = ["gates", "metres", "orbs", "hurdles", "fuel", "powers", "smashes", "overdrives"]
## Shards per mission, by tier. A tier is reached every MISSIONS_PER_TIER completed missions.
const REWARDS: Array[int] = [60, 100, 150, 200]
const MISSIONS_PER_TIER := 3

## `text` and `brief` (a few words, for badges) take the target; `targets` are per tier.
const KINDS := {
	"gates_run": {"stat": "gates", "scope": "run", "icon": "star", "text": "Pass %s gates in one run", "brief": "%s gates in a run",
		"targets": [15, 30, 50, 80]},
	"metres_run": {"stat": "metres", "scope": "run", "icon": "motion", "text": "Drive %s m in one run", "brief": "%s m in a run",
		"targets": [800, 1500, 3000, 5000]},
	"orbs_run": {"stat": "orbs", "scope": "run", "icon": "circle", "text": "Collect %s orbs in one run", "brief": "%s orbs in a run",
		"targets": [20, 40, 70, 110]},
	"hurdles_run": {"stat": "hurdles", "scope": "run", "icon": "up", "text": "Jump %s hurdles in one run", "brief": "%s hurdles in a run",
		"targets": [3, 6, 10, 16]},
	"orbs_total": {"stat": "orbs", "scope": "total", "icon": "circle", "text": "Collect %s orbs", "brief": "%s orbs",
		"targets": [60, 140, 260, 420]},
	"fuel_total": {"stat": "fuel", "scope": "total", "icon": "fuel", "text": "Pick up fuel %s times", "brief": "%s fuel pickups",
		"targets": [5, 10, 18, 28]},
	"powers_total": {"stat": "powers", "scope": "total", "icon": "gem", "text": "Collect %s power gems", "brief": "%s power gems",
		"targets": [2, 4, 6, 10]},
	"smashes_total": {"stat": "smashes", "scope": "total", "icon": "bolt", "text": "Smash %s obstacles in Overdrive", "brief": "%s smashes",
		"targets": [3, 8, 16, 30]},
	"overdrives_total": {"stat": "overdrives", "scope": "total", "icon": "bolt", "text": "Use Prism Overdrive %s times", "brief": "%s Overdrives",
		"targets": [2, 4, 6, 10]},
	"metres_total": {"stat": "metres", "scope": "total", "icon": "motion", "text": "Drive %s m in total", "brief": "%s m in total",
		"targets": [3000, 6000, 12000, 20000]},
}


## Tops the profile up to SLOTS missions (after loading, a reset, or a finished run).
static func refill() -> void:
	var missions := Profile.missions
	var changed := false
	for i in range(missions.size() - 1, -1, -1):
		if not KINDS.has(missions[i].get("kind", "")):
			missions.remove_at(i)
			changed = true
	while missions.size() < SLOTS:
		missions.append(_new_mission(missions))
		changed = true
	if changed:
		Profile.save()
		Profile.missions_changed.emit()


static func describe(mission: Dictionary) -> String:
	return str(KINDS[mission.kind].text) % UiKit.thousands(int(mission.target))


## The mission in a few words, for places with little room.
static func brief(mission: Dictionary) -> String:
	return str(KINDS[mission.kind].brief) % UiKit.thousands(int(mission.target))


static func icon(mission: Dictionary) -> String:
	return KINDS[mission.kind].icon


## How far along a mission is, counting the run in progress (`run` is {} outside a run).
static func progress(mission: Dictionary, run: Dictionary) -> int:
	var spec: Dictionary = KINDS[mission.kind]
	var now := int(run.get(spec.stat, 0))
	var value := int(mission.progress) + now if spec.scope == "total" else maxi(int(mission.progress), now)
	return mini(value, int(mission.target))


## Completes every mission the run in progress has reached, pays its shards and returns the
## missions just completed (so the game can announce them).
static func check(run: Dictionary) -> Array[Dictionary]:
	var completed: Array[Dictionary] = []
	for mission: Dictionary in Profile.missions:
		if mission.done or progress(mission, run) < int(mission.target):
			continue
		mission.done = true
		Profile.missions_done += 1
		completed.append(mission)
	if not completed.is_empty():
		for mission in completed:
			Profile.add_shards(payout(mission))
		Profile.save()
		Profile.missions_changed.emit()
	return completed


## Shards a mission pays, including the Supporter Pack's double shards.
static func payout(mission: Dictionary) -> int:
	return int(mission.reward) * Profile.shard_multiplier()


## A run is over: keep its progress, and swap completed missions for new ones.
static func finish_run(run: Dictionary) -> void:
	check(run)
	var kept: Array = []
	for mission: Dictionary in Profile.missions:
		if mission.done:
			continue
		mission.progress = progress(mission, run)
		kept.append(mission)
	Profile.missions = kept
	Profile.save()
	refill()
	Profile.missions_changed.emit()


## A new mission of the current tier whose counter no active mission is already using.
static func _new_mission(active: Array) -> Dictionary:
	var used := {}
	for mission: Dictionary in active:
		used[KINDS[mission.kind].stat] = true
	var choices: Array = KINDS.keys().filter(func(kind: String) -> bool: return not used.has(KINDS[kind].stat))
	var kind: String = choices[randi() % choices.size()]
	var tier := mini(Profile.missions_done / MISSIONS_PER_TIER, REWARDS.size() - 1)
	return {"kind": kind, "target": int(KINDS[kind].targets[tier]), "reward": REWARDS[tier], "progress": 0, "done": false}
