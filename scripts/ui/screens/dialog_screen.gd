extends UiScreen
## Yes / no confirmation.

var _title: Label
var _message: Label
var _confirm: Button
var _on_confirm := Callable()


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.6)
	var content := centered_card(480)
	_title = UiKit.centered(UiKit.title("", 48, UiKit.INK, Color(1, 1, 1, 0)))
	content.add_child(_title)
	_message = UiKit.wrapped(UiKit.centered(UiKit.text("", 24, true, 700)))
	content.add_child(_message)
	var row := UiKit.hbox(14)
	content.add_child(row)
	var cancel := UiKit.button("CANCEL", "light", Vector2(0, 70), 28)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(close)
	row.add_child(cancel)
	_confirm = UiKit.button("OK", "primary", Vector2(0, 70), 28)
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.pressed.connect(func() -> void:
		close()
		if _on_confirm.is_valid():
			_on_confirm.call())
	row.add_child(_confirm)


func configure(title: String, message: String, confirm_text: String, on_confirm: Callable, danger: bool) -> void:
	_title.text = title
	_message.text = message
	_confirm.text = confirm_text
	_on_confirm = on_confirm
	if danger:
		var red := UiKit.button(confirm_text, "danger", Vector2(0, 70), 28)
		for state in ["normal", "hover", "pressed"]:
			_confirm.add_theme_stylebox_override(state, red.get_theme_stylebox(state))
		red.free()


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 500.0)
