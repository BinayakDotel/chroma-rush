extends UiScreen
## Missions: the three current goals with their progress and rewards (see Missions).

var _list: VBoxContainer
var _note: Label


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	var content := centered_card(600, 24)
	content.add_child(header("MISSIONS"))
	_list = UiKit.vbox(12)
	content.add_child(_list)
	_note = UiKit.centered(UiKit.wrapped(UiKit.text("", 18, true, 700)))
	_note.label_settings.font_color = UiKit.INK_SOFT
	content.add_child(_note)
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
	_note.text = "Finish a mission and a new one takes its place after the run.\nCompleted so far: %d" % Profile.missions_done


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 640.0)
