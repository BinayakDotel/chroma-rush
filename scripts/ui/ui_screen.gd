class_name UiScreen
extends Control
## Base for every screen. Subclasses build their controls in build(), adapt to orientation in
## layout(), and may override handle_back(). Overlays call dim() to darken what is behind them.

var ui: UiRoot
var _tween: Tween


func build() -> void:
	pass


func layout(_portrait: bool) -> void:
	pass


## Back button pressed while this screen is on top. Return true if handled here; an overlay
## that returns false is simply closed.
func handle_back() -> bool:
	return false


## Called when the overlays above this base screen have all closed.
func on_uncovered() -> void:
	pass


func appear() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE if not _is_modal() else Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.16)


func disappear(free_after: bool) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	if free_after:
		_tween.tween_callback(queue_free)
	else:
		_tween.tween_callback(hide)


func close() -> void:
	ui.close_overlay(self)


## Overlays block input to what is behind them; base screens let touches through to the game.
func _is_modal() -> bool:
	return false


## Full-screen dark backdrop for overlays.
func dim(alpha := 0.55) -> ColorRect:
	var shade := ColorRect.new()
	shade.color = Color(0.06, 0.02, 0.16, alpha)
	UiKit.full_rect(shade)
	# Cover the safe-area margins too.
	shade.offset_left = -200
	shade.offset_top = -200
	shade.offset_right = 200
	shade.offset_bottom = 200
	add_child(shade)
	return shade


## A centred card that is at most `max_width` wide and scrolls if taller than the screen.
func centered_card(max_width: float, padding := 30) -> VBoxContainer:
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	var card := UiKit.card(padding)
	card.custom_minimum_size.x = max_width
	card.name = "Card"
	center.add_child(card)
	var content := UiKit.vbox(18)
	card.add_child(content)
	return content


func card_width(portrait: bool, landscape_width := 620.0) -> float:
	var available := get_viewport_rect().size.x - 48.0
	return minf(available, 660.0) if portrait else minf(landscape_width, available)


## Header row for overlays: back button, title and an optional right-hand control.
func header(title_text: String, right: Control = null) -> HBoxContainer:
	var row := UiKit.hbox(14)
	var back := UiKit.icon_button("back", "light", 60)
	back.pressed.connect(close)
	row.add_child(back)
	var title := UiKit.title(title_text, 44, UiKit.INK, Color(1, 1, 1, 0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	if right:
		row.add_child(right)
	return row
