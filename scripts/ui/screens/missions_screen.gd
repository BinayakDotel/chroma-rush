extends UiScreen
## Missions: the three current goals with their progress and rewards (see Missions).

var _list: VBoxContainer
var _done: Label


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	closes_on_outside_tap = true
	var content := centered_card(600, 24)
	content.add_child(header("MISSIONS"))
	_list = UiKit.vbox(12)
	content.add_child(_list)
	# Missions completed so far: a tick and the number.
	var tally := UiKit.hbox(8)
	tally.alignment = BoxContainer.ALIGNMENT_CENTER
	tally.add_child(UiIcon.make("check", UiKit.STYLES.primary[1], Vector2(26, 26)))
	_done = UiKit.text("0", 24, true, 900)
	_done.label_settings.font_color = UiKit.INK_SOFT
	tally.add_child(_done)
	content.add_child(tally)
	# A method callable (not a lambda), so it disconnects automatically when the overlay closes.
	Profile.missions_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	for mission: Dictionary in Profile.missions:
		_list.add_child(UiKit.mission_row(mission, Missions.progress(mission, {})))
	_done.text = str(Profile.missions_done)


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 640.0)
