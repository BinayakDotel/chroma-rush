class_name AdsBackend
extends Node
## Interface between Ads and an ad network. Backends preload one rewarded and one
## interstitial ad and report back when each has closed.

@warning_ignore("unused_signal")
signal rewarded_done(granted: bool)
@warning_ignore("unused_signal")
signal interstitial_done


func start() -> void:
	pass


func is_rewarded_ready() -> bool:
	return false


func is_interstitial_ready() -> bool:
	return false


func show_rewarded() -> void:
	pass


func show_interstitial() -> void:
	pass
