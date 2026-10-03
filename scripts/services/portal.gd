extends Node
## The game portal a web build runs on, autoloaded as `Portal`. It tells the portal when the
## game has finished loading and when the player is actually playing, and mutes the game when
## the portal asks.
##
## Only the CrazyGames build has a portal: its export preset adds their SDK and a small bridge
## object (`window.chromaPortal`, see `html/head_include` in export_presets.cfg) to the page.
## Everywhere else the bridge is missing and this does nothing.

const BRIDGE := "chromaPortal"

var _bridge: JavaScriptObject
## Kept in a member: the browser can only call a callback that is still referenced here.
var _mute_callback: JavaScriptObject
var _playing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	_bridge = JavaScriptBridge.get_interface(BRIDGE)
	if _bridge == null:
		return
	_mute_callback = JavaScriptBridge.create_callback(_on_mute_changed)
	_bridge.onMute = _mute_callback
	_set_muted(bool(_bridge.muted))
	# Loading started in the page, before the engine was downloaded. It ends when the home
	# screen is on screen: every model, sound and the music are built before the first frame.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_bridge.send("loadingStop")


func is_active() -> bool:
	return _bridge != null


## Call whenever the player starts or stops driving (a run starts, pauses, resumes or ends).
## The portal uses it to know when it may show its own interface over the game.
func set_playing(playing: bool) -> void:
	if playing == _playing:
		return
	_playing = playing
	if _bridge:
		_bridge.send("gameplayStart" if playing else "gameplayStop")


func _on_mute_changed(args: Array) -> void:
	_set_muted(bool(args[0]))


func _set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), muted)
