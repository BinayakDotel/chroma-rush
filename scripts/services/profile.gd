extends Node
## The player's progress: shards, unlocked worlds, best scores, lifetime stats and purchased
## entitlements. Autoloaded as `Profile`; saved to user://profile.cfg after every change.

signal shards_changed(total: int)
signal worlds_changed
signal entitlements_changed
signal revive_tokens_changed(count: int)
signal upgrades_changed
signal missions_changed

const PATH := "user://profile.cfg"
const LEGACY_PATH := "user://chroma_rush.cfg"
const VERSION := 1
const FREE_WORLD := "meadow"
const SANDBOX_PATH := "user://dev/profile.cfg"
## Phoenix gems bank free revives, up to this many.
const MAX_REVIVE_TOKENS := 3

var shards := 0
var selected_world := FREE_WORLD
var tutorial_done := false
## Free revives banked from Phoenix gems (see Powers).
var revive_tokens := 0
var lifetime_runs := 0
## Best score per world id.
var bests := {}
var unlocked: Array[String] = [FREE_WORLD]
## Upgrade id -> level bought (see Economy.UPGRADES).
var upgrades := {}
## The current goals (see Missions) and how many have been completed so far.
var missions: Array = []
var missions_done := 0
## Entitlement name -> true. Purchases are also restorable from the store.
var entitlements := {}
var stats := {"distance": 0.0, "gates": 0, "orbs": 0, "best_combo": 0, "best_distance": 0}
## Bookkeeping for the interstitial frequency cap (see Ads).
var ads_state := {"runs_since": 0, "last_unix": 0.0}
var _path := PATH


func _ready() -> void:
	if DevMode.active():
		use_sandbox()
		return
	_load()
	Missions.refill()


## Developer harness only: a throwaway save so tests never touch real progress. Chosen at
## startup (see DevMode) so nothing reads the real save first.
func use_sandbox() -> void:
	DirAccess.make_dir_recursive_absolute(SANDBOX_PATH.get_base_dir())
	_path = SANDBOX_PATH
	entitlements.clear()
	reset_progress()


func best(world_id: String) -> int:
	return int(bests.get(world_id, 0))


func best_overall() -> int:
	var top := 0
	for value: int in bests.values():
		top = maxi(top, value)
	return top


func is_unlocked(world_id: String) -> bool:
	return has_entitlement(Economy.ALL_WORLDS) or world_id in unlocked or Economy.world_cost(world_id) <= 0


func has_entitlement(name: StringName) -> bool:
	return entitlements.get(String(name), false)


func shard_multiplier() -> int:
	return 2 if has_entitlement(Economy.DOUBLE_SHARDS) else 1


func select_world(world_id: String) -> void:
	if selected_world != world_id and is_unlocked(world_id):
		selected_world = world_id
		save()


## Spends shards on a world. Returns false if it is already owned or unaffordable.
func buy_world(world_id: String) -> bool:
	var cost := Economy.world_cost(world_id)
	if is_unlocked(world_id) or shards < cost:
		return false
	shards -= cost
	unlocked.append(world_id)
	save()
	shards_changed.emit(shards)
	worlds_changed.emit()
	return true


func upgrade_level(id: String) -> int:
	return int(upgrades.get(id, 0))


## The upgrade's current effect (see Economy.UPGRADES).
func upgrade_value(id: String) -> float:
	return Economy.upgrade_value(id, upgrade_level(id))


## Spends shards on the next level of an upgrade. False if maxed out or unaffordable.
func buy_upgrade(id: String) -> bool:
	var cost := Economy.upgrade_cost(id, upgrade_level(id))
	if cost < 0 or shards < cost:
		return false
	shards -= cost
	upgrades[id] = upgrade_level(id) + 1
	save()
	shards_changed.emit(shards)
	upgrades_changed.emit()
	return true


## True when some upgrade's next level is affordable (the home screen shows a badge).
func can_buy_upgrade() -> bool:
	for id: String in Economy.UPGRADES:
		var cost := Economy.upgrade_cost(id, upgrade_level(id))
		if cost >= 0 and shards >= cost:
			return true
	return false


func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	shards += amount
	save()
	shards_changed.emit(shards)


## The next thing worth saving for: the cheapest upgrade level or world not bought yet.
## Returns {name, cost, upgrade (true for an upgrade, false for a world)}, or {} when
## everything is owned.
func next_goal() -> Dictionary:
	var goal := {}
	for id: String in Economy.UPGRADES:
		var cost := Economy.upgrade_cost(id, upgrade_level(id))
		if cost >= 0 and (goal.is_empty() or cost < int(goal.cost)):
			goal = {"name": "%s LEVEL %d" % [Economy.UPGRADES[id].name, upgrade_level(id) + 1], "cost": cost, "upgrade": true}
	for world: Dictionary in Themes.all():
		var cost := Economy.world_cost(world.id)
		if not is_unlocked(world.id) and (goal.is_empty() or cost < int(goal.cost)):
			goal = {"name": str(world.name), "cost": cost, "upgrade": false}
	return goal


## Banks a revive from a Phoenix gem. Returns false when the bank is already full.
func add_revive_token() -> bool:
	if revive_tokens >= MAX_REVIVE_TOKENS:
		return false
	revive_tokens += 1
	save()
	revive_tokens_changed.emit(revive_tokens)
	return true


func use_revive_token() -> bool:
	if revive_tokens <= 0:
		return false
	revive_tokens -= 1
	save()
	revive_tokens_changed.emit(revive_tokens)
	return true


func grant(entitlement: StringName) -> void:
	if has_entitlement(entitlement):
		return
	entitlements[String(entitlement)] = true
	save()
	entitlements_changed.emit()
	if entitlement == Economy.ALL_WORLDS:
		worlds_changed.emit()


## Records a finished run. Returns true when it beats the world's best score.
func record_run(world_id: String, score: int, metres: float, gates: int, orbs: int, best_combo: int) -> bool:
	lifetime_runs += 1
	stats.distance = float(stats.distance) + metres
	stats.gates = int(stats.gates) + gates
	stats.orbs = int(stats.orbs) + orbs
	stats.best_combo = maxi(int(stats.best_combo), best_combo)
	stats.best_distance = maxi(int(stats.best_distance), int(metres))
	var new_best := score > best(world_id)
	if new_best:
		bests[world_id] = score
	save()
	return new_best


func mark_tutorial_done() -> void:
	if not tutorial_done:
		tutorial_done = true
		save()


## Clears progress but keeps purchases, which belong to the player's store account.
func reset_progress() -> void:
	shards = 0
	selected_world = FREE_WORLD
	tutorial_done = false
	revive_tokens = 0
	upgrades.clear()
	lifetime_runs = 0
	missions.clear()
	missions_done = 0
	bests.clear()
	unlocked.assign([FREE_WORLD])
	stats = {"distance": 0.0, "gates": 0, "orbs": 0, "best_combo": 0, "best_distance": 0}
	ads_state = {"runs_since": 0, "last_unix": 0.0}
	save()
	Missions.refill()
	shards_changed.emit(shards)
	worlds_changed.emit()
	revive_tokens_changed.emit(revive_tokens)
	upgrades_changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "shards", shards)
	cfg.set_value("progress", "selected_world", selected_world)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "lifetime_runs", lifetime_runs)
	cfg.set_value("progress", "revive_tokens", revive_tokens)
	cfg.set_value("progress", "upgrades", upgrades)
	cfg.set_value("progress", "bests", bests)
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("progress", "missions", missions)
	cfg.set_value("progress", "missions_done", missions_done)
	cfg.set_value("store", "entitlements", entitlements)
	cfg.set_value("ads", "state", ads_state)
	SaveIO.write(cfg, _path)


func _load() -> void:
	var cfg := ConfigFile.new()
	if not SaveIO.read(cfg, PATH):
		_migrate_legacy()
		return
	shards = maxi(int(cfg.get_value("progress", "shards", 0)), 0)
	selected_world = str(cfg.get_value("progress", "selected_world", FREE_WORLD))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	lifetime_runs = int(cfg.get_value("progress", "lifetime_runs", 0))
	revive_tokens = clampi(int(cfg.get_value("progress", "revive_tokens", 0)), 0, MAX_REVIVE_TOKENS)
	var saved_upgrades := _dict(cfg.get_value("progress", "upgrades", {}))
	for id: String in Economy.UPGRADES:
		if saved_upgrades.has(id):
			upgrades[id] = clampi(int(saved_upgrades[id]), 0, Economy.max_level(id))
	bests = _dict(cfg.get_value("progress", "bests", {}))
	var saved_unlocked: Variant = cfg.get_value("progress", "unlocked", [FREE_WORLD])
	if saved_unlocked is Array:
		for world in saved_unlocked:
			if not str(world) in unlocked:
				unlocked.append(str(world))
	stats.merge(_dict(cfg.get_value("progress", "stats", {})), true)
	missions_done = maxi(int(cfg.get_value("progress", "missions_done", 0)), 0)
	var saved_missions: Variant = cfg.get_value("progress", "missions", [])
	if saved_missions is Array:
		for mission: Variant in saved_missions:
			if mission is Dictionary and mission.has_all(["kind", "target", "reward", "progress", "done"]):
				missions.append(mission)
	entitlements = _dict(cfg.get_value("store", "entitlements", {}))
	ads_state.merge(_dict(cfg.get_value("ads", "state", {})), true)
	if not is_unlocked(selected_world):
		selected_world = FREE_WORLD


## Carries the best score over from the first release's save file.
func _migrate_legacy() -> void:
	var old := ConfigFile.new()
	if old.load(LEGACY_PATH) != OK:
		return
	var legacy_best := int(old.get_value("score", "best", 0))
	if legacy_best > 0:
		bests[FREE_WORLD] = legacy_best
	save()


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
