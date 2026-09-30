extends UiScreen
## Settings: audio, feedback and accessibility, graphics quality, purchases, about and reset.

const PRIVACY_URL := "https://whitehatengineering.com/chroma-rush/privacy"
const SUPPORT_URL := "mailto:support@whitehatengineering.com"

var _quality_buttons: Array[Button] = []


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	var content := centered_card(600, 24)
	content.add_child(header("SETTINGS"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 520
	scroll.name = "Scroll"
	content.add_child(scroll)
	var list := UiKit.vbox(12)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	_section(list, "AUDIO")
	_slider_row(list, "music", "Music", &"music_volume")
	_slider_row(list, "sound", "Sound effects", &"sfx_volume")

	_section(list, "GAMEPLAY")
	if OS.has_feature("mobile"):
		_toggle_row(list, "vibrate", "Vibration", "", &"haptics")
	_toggle_row(list, "eye", "Colour shapes", "Circle, triangle and square on gates and buttons", &"color_symbols")
	_toggle_row(list, "motion", "Reduce motion", "No camera shake or speed lines", &"reduce_motion")
	_toggle_row(list, "graphics", "Show FPS", "", &"show_fps")

	_section(list, "GRAPHICS")
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

	_section(list, "PURCHASES")
	var restore := UiKit.button("RESTORE PURCHASES", "sky", Vector2(0, 64), 26, "restore")
	restore.pressed.connect(Store.restore)
	restore.disabled = not Store.is_available()
	list.add_child(restore)

	_section(list, "ABOUT")
	var how := UiKit.button("HOW TO PLAY", "light", Vector2(0, 60), 24, "help")
	how.pressed.connect(func() -> void: ui.open_howto(false))
	list.add_child(how)
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
		ProjectSettings.get_setting("application/config/version", "1.0.0"), 16, true, 600))
	credits.label_settings.font_color = UiKit.INK_SOFT
	list.add_child(credits)
	var reset := UiKit.button("RESET PROGRESS", "danger", Vector2(0, 60), 22, "reset")
	reset.pressed.connect(func() -> void:
		ui.confirm("RESET?", "This clears your shards, unlocked worlds and best scores. Purchases are kept.",
			"RESET", Profile.reset_progress, true))
	list.add_child(reset)


func _section(list: VBoxContainer, title_text: String) -> void:
	var label := UiKit.text(title_text, 18, true, 900)
	label.label_settings.font_color = UiKit.INK_SOFT
	list.add_child(label)


func _row(list: VBoxContainer, icon: String, title_text: String, subtitle: String) -> HBoxContainer:
	var chip := UiKit.card(14, UiKit.CARD_TINT, 22)
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	list.add_child(chip)
	var row := UiKit.hbox(14)
	chip.add_child(row)
	row.add_child(UiIcon.make(icon, UiKit.INK, Vector2(32, 32)))
	var text_col := UiKit.vbox(0)
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text_col)
	text_col.add_child(UiKit.text(title_text, 24, true, 800))
	if not subtitle.is_empty():
		var sub := UiKit.wrapped(UiKit.text(subtitle, 16, true, 600))
		sub.label_settings.font_color = UiKit.INK_SOFT
		text_col.add_child(sub)
	return row


func _toggle_row(list: VBoxContainer, icon: String, title_text: String, subtitle: String, key: StringName) -> void:
	var row := _row(list, icon, title_text, subtitle)
	var toggle := UiKit.toggle(Settings.get(key))
	toggle.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	row.add_child(toggle)


func _slider_row(list: VBoxContainer, icon: String, title_text: String, key: StringName) -> void:
	var row := _row(list, icon, title_text, "")
	var s := UiKit.slider(Settings.get(key))
	s.custom_minimum_size.x = 220
	s.size_flags_horizontal = Control.SIZE_SHRINK_END
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
	var scroll: Control = find_child("Scroll", true, false)
	if scroll:
		scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 260.0, 300.0, 900.0)
