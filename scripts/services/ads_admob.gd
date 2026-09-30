class_name AdMobAds
extends AdsBackend
## Google AdMob through the godot-admob plugin (godot-sdk-integrations). The plugin's node
## script is loaded by path and driven by method name, so this file parses without the plugin.
##
## Startup order follows Google's guidance: consent (UMP) first, then Apple's tracking prompt on
## iOS, then SDK initialisation, then ad loading. Ad unit ids are set on the plugin node through
## its exported properties; fill them in `_configure` before release.

const SCRIPT_PATH := "res://addons/AdmobPlugin/Admob.gd"
const RETRY_DELAY := 30.0

var _admob: Node
var _ready_to_load := false
var _earned := false


static func is_installed() -> bool:
	return (OS.has_feature("android") or OS.has_feature("ios")) and ResourceLoader.exists(SCRIPT_PATH)


func start() -> void:
	_admob = (load(SCRIPT_PATH) as Script).new()
	_configure(_admob)
	add_child(_admob)
	_admob.connect("consent_info_updated", _on_consent_info_updated)
	_admob.connect("consent_info_update_failed", _on_consent_skipped.unbind(1))
	_admob.connect("consent_form_loaded", func() -> void: _admob.call("show_consent_form"))
	_admob.connect("consent_form_failed_to_load", _on_consent_skipped.unbind(1))
	_admob.connect("consent_form_dismissed", _on_consent_skipped.unbind(1))
	_admob.connect("initialization_completed", _on_initialized.unbind(1))
	for answer in ["tracking_authorization_granted", "tracking_authorization_denied"]:
		if _admob.has_signal(answer):
			_admob.connect(answer, _initialize)
	_admob.connect("rewarded_ad_user_earned_reward", func(_info: Object, _reward: Object) -> void: _earned = true)
	_admob.connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_closed.unbind(1))
	_admob.connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_closed.unbind(2))
	_admob.connect("rewarded_ad_failed_to_load", _retry.bind("load_rewarded_ad").unbind(2))
	_admob.connect("interstitial_ad_dismissed_full_screen_content", _on_interstitial_closed.unbind(1))
	_admob.connect("interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_closed.unbind(2))
	_admob.connect("interstitial_ad_failed_to_load", _retry.bind("load_interstitial_ad").unbind(2))
	_admob.call("update_consent_info")


func is_rewarded_ready() -> bool:
	return _ready_to_load and bool(_admob.call("is_rewarded_ad_loaded"))


func is_interstitial_ready() -> bool:
	return _ready_to_load and bool(_admob.call("is_interstitial_ad_loaded"))


func show_rewarded() -> void:
	_earned = false
	_admob.call("show_rewarded_ad")


func show_interstitial() -> void:
	_admob.call("show_interstitial_ad")


## Real ad unit ids go here (the plugin's defaults are Google's test units).
func _configure(node: Node) -> void:
	node.set("is_real", not OS.is_debug_build())
	node.set("android_real_application_id", "")
	node.set("android_real_rewarded_id", "")
	node.set("android_real_interstitial_id", "")
	node.set("ios_real_application_id", "")
	node.set("ios_real_rewarded_id", "")
	node.set("ios_real_interstitial_id", "")


func _on_consent_info_updated() -> void:
	if bool(_admob.call("is_consent_form_available")):
		_admob.call("load_consent_form")
	else:
		_on_consent_skipped()


## Consent resolved (given, not required, or unavailable): ask for tracking on iOS, then start.
func _on_consent_skipped() -> void:
	if OS.has_feature("ios") and _admob.has_method("request_tracking_authorization"):
		_admob.call("request_tracking_authorization")
	else:
		_initialize()


func _initialize() -> void:
	if not _ready_to_load:
		_admob.call("initialize")


func _on_initialized() -> void:
	_ready_to_load = true
	_admob.call("load_rewarded_ad")
	_admob.call("load_interstitial_ad")


func _on_rewarded_closed() -> void:
	rewarded_done.emit(_earned)
	_admob.call("load_rewarded_ad")


func _on_interstitial_closed() -> void:
	interstitial_done.emit()
	_admob.call("load_interstitial_ad")


func _retry(method: String) -> void:
	await get_tree().create_timer(RETRY_DELAY).timeout
	if is_instance_valid(_admob):
		_admob.call(method)
