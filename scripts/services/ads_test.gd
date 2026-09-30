class_name TestAds
extends AdsBackend
## Desktop debug-build stand-in for an ad network: a full-screen card that closes itself after
## a few seconds, so revive and double-shard flows can be tested without a device.

const LENGTH := 2.5

var _layer: CanvasLayer
var _label: Label


func is_rewarded_ready() -> bool:
	return true


func is_interstitial_ready() -> bool:
	return true


func show_rewarded() -> void:
	await _play("TEST REWARDED AD")
	rewarded_done.emit(true)


func show_interstitial() -> void:
	await _play("TEST AD")
	interstitial_done.emit()


func _play(title: String) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.1, 0.96)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(shade)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 40)
	_layer.add_child(_label)
	var left := LENGTH
	while left > 0.0:
		_label.text = "%s\n%d" % [title, ceili(left)]
		await get_tree().create_timer(0.25, true, false, true).timeout
		left -= 0.25
	_layer.queue_free()
