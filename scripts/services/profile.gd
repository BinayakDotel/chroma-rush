extends Node
## The player's progress: shards, unlocked worlds, best scores, lifetime stats and purchased
## entitlements. Autoloaded as `Profile`; saved to user://profile.cfg after every change.

signal shards_changed(total: int)
signal worlds_changed
signal entitlements_changed

const PATH := "user://profile.cfg"
const LEGACY_PATH := "user://chroma_rush.cfg"
const VERSION := 1
const FREE_WORLD := "meadow"

var shards := 0
var selected_world := FREE_WORLD
var tutorial_done := false
var lifetime_runs := 0
## Best score per world id.
var bests := {}
var unlocked: Array[String] = [FREE_WORLD]
## Entitlement name -> true. Purchases are also restorable from the store.
var entitlements := {}
var stats := {"distance": 0.0, "gates": 0, "orbs": 0, "best_combo": 0, "best_distance": 0}
## Bookkeeping for the interstitial frequency cap (see Ads).
var ads_state := {"runs_since": 0, "last_unix": 0.0}


func _ready() -> void:
	_load()


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


func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	shards += amount
	save()
	shards_changed.emit(shards)


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
	lifetime_runs = 0
	bests.clear()
	unlocked.assign([FREE_WORLD])
	stats = {"distance": 0.0, "gates": 0, "orbs": 0, "best_combo": 0, "best_distance": 0}
	ads_state = {"runs_since": 0, "last_unix": 0.0}
	save()
	shards_changed.emit(shards)
	worlds_changed.emit()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", VERSION)
	cfg.set_value("progress", "shards", shards)
	cfg.set_value("progress", "selected_world", selected_world)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "lifetime_runs", lifetime_runs)
	cfg.set_value("progress", "bests", bests)
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "stats", stats)
	cfg.set_value("store", "entitlements", entitlements)
	cfg.set_value("ads", "state", ads_state)
	SaveIO.write(cfg, PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if not SaveIO.read(cfg, PATH):
		_migrate_legacy()
		return
	shards = maxi(int(cfg.get_value("progress", "shards", 0)), 0)
	selected_world = str(cfg.get_value("progress", "selected_world", FREE_WORLD))
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
	lifetime_runs = int(cfg.get_value("progress", "lifetime_runs", 0))
	bests = _dict(cfg.get_value("progress", "bests", {}))
	var saved_unlocked: Variant = cfg.get_value("progress", "unlocked", [FREE_WORLD])
	if saved_unlocked is Array:
		for world in saved_unlocked:
			if not str(world) in unlocked:
				unlocked.append(str(world))
	stats.merge(_dict(cfg.get_value("progress", "stats", {})), true)
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
