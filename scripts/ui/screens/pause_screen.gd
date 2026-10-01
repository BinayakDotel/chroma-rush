extends UiScreen
## Pause menu over a frozen run, in symbols: resume (big), then restart, settings and home.

var _content: VBoxContainer


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.5)
	_content = centered_card(400)
	var resume := UiKit.button("", "primary", Vector2(0, 120), 72, "play")
	resume.pressed.connect(_resume)
	_content.add_child(resume)
	var row := UiKit.hbox(14)
	_content.add_child(row)
	var restart := UiKit.button("", "sky", Vector2(0, 84), 42, "retry")
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart.pressed.connect(func() -> void:
		close()
		ui.restart_requested.emit())
	row.add_child(restart)
	var settings := UiKit.button("", "light", Vector2(0, 84), 42, "gear")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(ui.open_settings)
	row.add_child(settings)
	var home := UiKit.button("", "light", Vector2(0, 84), 42, "home")
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home.pressed.connect(func() -> void:
		close()
		ui.home_requested.emit())
	row.add_child(home)


func handle_back() -> bool:
	_resume()
	return true


func _resume() -> void:
	close()
	ui.resume_requested.emit()


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 420.0)
