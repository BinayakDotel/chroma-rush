extends UiScreen
## Settings: audio, feedback and accessibility, graphics quality, purchases, about and reset.

const PRIVACY_URL := "https://whitehatengineering.com/chroma-rush/privacy"
const SUPPORT_URL := "mailto:support@whitehatengineering.com"

var _quality_buttons: Array[Button] = []


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	closes_on_outside_tap = true
	var content := centered_card(600, 24)
	content.add_child(header("SETTINGS"))
	var list := scroll_list(content)

	_slider_row(list, "music", &"music_volume")
	_slider_row(list, "sound", &"sfx_volume")

	if OS.has_feature("mobile"):
		_toggle_row(list, "vibrate", "Vibration", &"haptics")
	_toggle_row(list, "eye", "Colour shapes", &"color_symbols")
	_toggle_row(list, "motion", "Reduce motion", &"reduce_motion")
	_toggle_row(list, "graphics", "Show FPS", &"show_fps")

	var quality := UiKit.hbox(10)
	for i in 3:
		var b := UiKit.button(["LOW", "MEDIUM", "HIGH"][i], "light", Vector2(0, 60), 24)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			Settings.set_value(&"quality", i)
			_refresh_quality())
		quality.add_child(b)
		_quality_buttons.append(b)
	list.add_child(quality)
	_refresh_quality()

	var actions := UiKit.hbox(10)
	var how := UiKit.button("", "light", Vector2(96, 64), 34, "help")
	how.pressed.connect(func() -> void: ui.open_howto(false))
	actions.add_child(how)
	var restore := UiKit.button("RESTORE", "sky", Vector2(0, 64), 24, "restore")
	restore.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restore.pressed.connect(Store.restore)
	restore.disabled = not Store.is_available()
	actions.add_child(restore)
	list.add_child(actions)
	var links := UiKit.hbox(10)
	var privacy := UiKit.button("PRIVACY", "light", Vector2(0, 60), 22, "link")
	privacy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	privacy.pressed.connect(func() -> void: OS.shell_open(PRIVACY_URL))
	links.add_child(privacy)
	var support := UiKit.button("SUPPORT", "light", Vector2(0, 60), 22, "link")
	support.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	support.pressed.connect(func() -> void: OS.shell_open(SUPPORT_URL))
	links.add_child(support)
	list.add_child(links)
	var credits := UiKit.wrapped(UiKit.text(
		"Chroma Rush %s  -  Made with Godot Engine. Fonts: Lilita One and Nunito (SIL Open Font License)." %
		ProjectSettings.get_setting("application/config/version", "1.0.0"), 18, true, 600))
	credits.label_settings.font_color = UiKit.INK_SOFT
	list.add_child(credits)
	var reset := UiKit.button("RESET", "danger", Vector2(0, 60), 22, "reset")
	reset.pressed.connect(func() -> void:
		ui.confirm("RESET?", "This clears your shards, unlocked worlds and best scores. Purchases are kept.",
			"RESET", Profile.reset_progress, true))
	list.add_child(reset)


func _row(list: VBoxContainer, icon: String, title_text: String) -> HBoxContainer:
	var chip := UiKit.card(14, UiKit.CARD_TINT, 22)
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	list.add_child(chip)
	var row := UiKit.hbox(14)
	chip.add_child(row)
	var glyph := UiIcon.make(icon, UiKit.INK, Vector2(34, 34))
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(glyph)
	if not title_text.is_empty():
		var label := UiKit.text(title_text, 24, true, 800)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
	return row


func _toggle_row(list: VBoxContainer, icon: String, title_text: String, key: StringName) -> void:
	var row := _row(list, icon, title_text)
	var toggle := UiKit.toggle(Settings.get(key))
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	row.add_child(toggle)


## A volume slider: the icon says which one, so there is no label.
func _slider_row(list: VBoxContainer, icon: String, key: StringName) -> void:
	var row := _row(list, icon, "")
	var s := UiKit.slider(Settings.get(key))
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
	row.add_child(s)


func _refresh_quality() -> void:
	for i in _quality_buttons.size():
		var b := _quality_buttons[i]
		var style := "sky" if i == Settings.quality else "light"
		var ref := UiKit.button("", style, Vector2(0, 60), 24)
		for state in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(state, ref.get_theme_stylebox(state))
		var ink: Color = UiKit.STYLES[style][2]
		for state in ["font_color", "font_hover_color", "font_pressed_color"]:
			b.add_theme_color_override(state, ink)
		b.add_theme_constant_override("outline_size", 4 if style == "sky" else 0)
		ref.free()


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 640.0)
	fit_scroll.call_deferred(maxf(get_viewport_rect().size.y - 260.0, 300.0))
