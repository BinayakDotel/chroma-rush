extends Node
## Advertising, autoloaded as `Ads`. Owns the placement rules (what may show, and when) and
## hands the actual showing to a backend:
##   AdMob plugin (godot-sdk-integrations/godot-admob) when it is installed
##   a local test ad in desktop debug builds
## Rewarded ads are always opt-in. Interstitials are rare, capped and removed by No Ads.

signal rewarded_finished(placement: StringName, granted: bool)
## True while a full-screen ad covers the game.
signal showing_changed(showing: bool)

const REVIVE := &"revive"
const DOUBLE_SHARDS := &"double_shards"

const FIRST_RUNS_WITHOUT_ADS := 5
const INTERSTITIAL_EVERY_RUNS := 3
const INTERSTITIAL_MIN_GAP_S := 180.0

var backend: AdsBackend
var _pending_placement := &""
var _rewarded_just_shown := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AdMobAds.is_installed():
		backend = AdMobAds.new()
	elif OS.is_debug_build():
		backend = TestAds.new()
	if backend == null:
		return
	add_child(backend)
	backend.rewarded_done.connect(_on_rewarded_done)
	backend.interstitial_done.connect(_on_interstitial_done)
	backend.start()


func rewarded_ready() -> bool:
	return backend != null and backend.is_rewarded_ready() and _pending_placement.is_empty()


func show_rewarded(placement: StringName) -> void:
	if not rewarded_ready():
		rewarded_finished.emit(placement, false)
		return
	_pending_placement = placement
	_set_showing(true)
	backend.show_rewarded()


## Call once per finished run. Shows an interstitial if the caps allow it; returns true if one
## is showing (the caller waits for `showing_changed(false)`).
func after_run() -> bool:
	var state := Profile.ads_state
	state.runs_since = int(state.runs_since) + 1
	var now := Time.get_unix_time_from_system()
	var allowed := (
		backend != null
		and not Profile.has_entitlement(Economy.NO_ADS)
		and Profile.lifetime_runs > FIRST_RUNS_WITHOUT_ADS
		and int(state.runs_since) >= INTERSTITIAL_EVERY_RUNS
		and now - float(state.last_unix) >= INTERSTITIAL_MIN_GAP_S
		and not _rewarded_just_shown
		and backend.is_interstitial_ready()
	)
	_rewarded_just_shown = false
	if allowed:
		state.runs_since = 0
		state.last_unix = now
		_set_showing(true)
		backend.show_interstitial()
	Profile.save()
	return allowed


func _on_rewarded_done(granted: bool) -> void:
	var placement := _pending_placement
	_pending_placement = &""
	_rewarded_just_shown = true
	_set_showing(false)
	rewarded_finished.emit(placement, granted)


func _on_interstitial_done() -> void:
	_set_showing(false)


func _set_showing(showing: bool) -> void:
	# Silence the game under the ad; the ad plays its own audio.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), showing)
	showing_changed.emit(showing)
