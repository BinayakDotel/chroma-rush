extends UiScreen
## Pause menu over a frozen run.

var _content: VBoxContainer


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.5)
	_content = centered_card(460)
	_content.add_child(UiKit.centered(UiKit.title("PAUSED", 64, UiKit.INK, Color(1, 1, 1, 0))))
	var resume := UiKit.button("RESUME", "primary", Vector2(0, 92), 42, "play")
	resume.pressed.connect(_resume)
	_content.add_child(resume)
	var restart := UiKit.button("RESTART", "sky", Vector2(0, 72), 32, "retry")
	restart.pressed.connect(func() -> void:
		close()
		ui.restart_requested.emit())
	_content.add_child(restart)
	var row := UiKit.hbox(14)
	_content.add_child(row)
	var settings := UiKit.button("SETTINGS", "light", Vector2(0, 68), 26, "gear")
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.pressed.connect(ui.open_settings)
	row.add_child(settings)
	var home := UiKit.button("HOME", "light", Vector2(0, 68), 26, "home")
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
		card.custom_minimum_size.x = minf(card_width(portrait), 480.0)
