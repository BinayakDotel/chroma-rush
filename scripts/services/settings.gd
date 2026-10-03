extends Node
## Player preferences: audio, feedback, accessibility and graphics. Autoloaded as `Settings`
## and saved to user://settings.cfg. Other systems read the values directly and listen to
## `changed` to react to edits made on the Settings screen.

signal changed(key: StringName)

enum Quality { LOW, MEDIUM, HIGH }

const PATH := "user://settings.cfg"
const SANDBOX_PATH := "user://dev/settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const KEYS: Array[StringName] = [
	&"music_volume", &"sfx_volume", &"muted", &"haptics", &"color_symbols", &"reduce_motion", &"show_fps", &"quality",
]

var music_volume := 0.7
var sfx_volume := 1.0
## Silences music and effects without losing their volumes: the HUD's one-tap mute.
var muted := false
var haptics := true
## Draws a shape on every gate, orb and colour button so colours never rely on hue alone.
var color_symbols := true
## Turns off camera shake and the speed-line overlay.
var reduce_motion := false
var show_fps := false
var quality: int = Quality.MEDIUM if Defs.touch_device() else Quality.HIGH
var _path := PATH


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	if DevMode.active():
		use_sandbox()
	_load()
	_apply_audio()


func set_value(key: StringName, value: Variant) -> void:
	if not key in KEYS or get(key) == value:
		return
	set(key, value)
	_save()
	_apply_audio()
	changed.emit(key)


## Developer harness only: keep test changes out of the real settings file.
func use_sandbox() -> void:
	DirAccess.make_dir_recursive_absolute(SANDBOX_PATH.get_base_dir())
	_path = SANDBOX_PATH
	if FileAccess.file_exists(SANDBOX_PATH):
		DirAccess.remove_absolute(SANDBOX_PATH)


## Short vibration on phones, if enabled. `strength` 0..1 scales the duration.
func vibrate(strength := 0.5) -> void:
	if haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(int(lerpf(12.0, 60.0, clampf(strength, 0.0, 1.0))))


## Only the Music and SFX buses: the portal and ads mute Master on their own.
func _apply_audio() -> void:
	_set_bus_volume(MUSIC_BUS, 0.0 if muted else music_volume)
	_set_bus_volume(SFX_BUS, 0.0 if muted else sfx_volume)


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")


func _load() -> void:
	var cfg := ConfigFile.new()
	if not SaveIO.read(cfg, _path):
		return
	for key in KEYS:
		var fallback: Variant = get(key)
		var value: Variant = cfg.get_value("settings", key, fallback)
		if typeof(value) == typeof(fallback):
			set(key, value)
	music_volume = clampf(music_volume, 0.0, 1.0)
	sfx_volume = clampf(sfx_volume, 0.0, 1.0)
	quality = clampi(quality, Quality.LOW, Quality.HIGH)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value("settings", key, get(key))
	SaveIO.write(cfg, _path)
