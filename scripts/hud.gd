class_name Hud
extends CanvasLayer
## Score, colour selector, Prism meter, and the title / game-over screens.

signal prism_pressed
## Emitted with -1 / +1 when a theme arrow is pressed.
signal theme_step(step: int)

const KEYS := ["J", "K", "L"]
const INK := Color.WHITE
## Fixed UI accent (title shadow, multiplier, game-over title); independent of the gate palette.
const ACCENT := Color(1.0, 0.36, 0.45)

var _font := SystemFont.new()
var _title_font := SystemFont.new()
var _score: Label
var _mult: Label
var _dist: Label
var _speed: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _swatches: Array[PanelContainer] = []
var _meter: ProgressBar
var _meter_fill := StyleBoxFlat.new()
var _meter_label: Label
var _prism_button: Button
var _buttons: Array[Button] = []
var _theme_labels: Array[Label] = []
var _play_ui: Control
var _play_root: Control
var _menu: Control
var _menu_best: Label
var _menu_prompt: Label
var _over: Control
var _over_title: Label
var _over_score: Label
var _over_best: Label
var _over_prompt: Label
var _fuel_bar: ProgressBar
var _fuel_fill := StyleBoxFlat.new()
var _fuel_label: Label
var _fuel_level := 1.0
var _meter_ready := false
var _meter_active := false
var _t := 0.0


func _ready() -> void:
	_font.font_names = PackedStringArray(["Avenir Next", "Futura", "Helvetica Neue", "Arial"])
	_font.font_weight = 700
	_title_font.font_names = _font.font_names
	_title_font.font_weight = 900
	_title_font.font_italic = true
	_play_ui = _build_play_ui()
	_menu = _build_menu()
	_over = _build_game_over()
	for control in find_children("*", "Control", true, false):
		if not control is Button:
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var blink := 0.7 + 0.3 * sin(_t * 5.0)
	_menu_prompt.modulate.a = blink
	_over_prompt.modulate.a = blink
	if _meter_ready or _meter_active:
		_meter_fill.bg_color = Color.from_hsv(fmod(_t * 0.8, 1.0), 0.7, 1.0)
	if _fuel_level < 0.25:
		var flash := 0.5 + 0.5 * sin(_t * 12.0)
		_fuel_fill.bg_color = Color(1.0, 0.3 + 0.2 * flash, 0.25)
		_fuel_label.modulate.a = 0.5 + 0.5 * flash
	else:
		_fuel_label.modulate.a = 1.0


func show_menu(best: int) -> void:
	_menu_best.text = "BEST  %d" % best if best > 0 else ""
	_menu.visible = true
	_over.visible = false
	_play_ui.visible = false


func show_playing() -> void:
	_menu.visible = false
	_over.visible = false
	_play_ui.visible = true


func show_game_over(score: int, best: int, new_best: bool, title := "CRASHED") -> void:
	_over_title.text = title
	_over_score.text = "SCORE  %d" % score
	_over_best.text = "NEW BEST!" if new_best else "BEST  %d" % best
	_over_best.label_settings.font_color = Color(1.0, 0.85, 0.3) if new_best else Color.WHITE
	_over.visible = true
	_play_ui.visible = false


func set_score(score: float, multiplier: int) -> void:
	_score.text = str(int(score))
	_mult.text = "x%d" % multiplier
	_mult.visible = multiplier > 1


func set_fuel(level: float) -> void:
	_fuel_level = level
	_fuel_bar.value = level
	if level >= 0.25:
		_fuel_fill.bg_color = Color(0.4, 0.9, 0.45) if level > 0.5 else Color(1.0, 0.8, 0.25)


func set_distance(metres: int, speed: float) -> void:
	_dist.text = "%d m" % metres
	_speed.text = "%d km/h" % int(speed * 3.6)


func set_color(index: int) -> void:
	for i in _swatches.size():
		var selected := i == index
		var swatch := _swatches[i]
		swatch.custom_minimum_size = Vector2(76, 76) if selected else Vector2(58, 58)
		# Dim rather than fade, so the true colour never blends with the scene behind it.
		swatch.modulate = Color.WHITE if selected else Color(0.62, 0.62, 0.62)
		var style: StyleBoxFlat = swatch.get_theme_stylebox("panel")
		style.set_border_width_all(4 if selected else 0)


func set_meter(value: float, is_ready: bool, active: bool) -> void:
	_meter.value = value
	_meter_ready = is_ready and not active
	_meter_active = active
	_prism_button.visible = _meter_ready
	if active:
		_meter_label.text = "PRISM OVERDRIVE"
	elif is_ready:
		_meter_label.text = "PRISM READY!  PRESS SHIFT"
	else:
		_meter_label.text = "PRISM"
		_meter_fill.bg_color = Color(1, 1, 1, 0.9)


## Short message in a small pill under the fuel gauge, clear of the track ahead.
func popup(text: String, color := INK) -> void:
	_toast_label.text = text
	_toast_label.label_settings.font_color = color
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.1)
	_toast_tween.tween_interval(0.9)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)


## Recolours the colour-selector swatches for the current theme's gate palette.
func set_palette(colors: Array[Color]) -> void:
	for i in _swatches.size():
		var style: StyleBoxFlat = _swatches[i].get_theme_stylebox("panel")
		style.bg_color = colors[i]
		var key: Label = _swatches[i].get_child(0)
		key.label_settings.font_color = Color(0.06, 0.04, 0.12) if colors[i].get_luminance() > 0.45 else Color.WHITE


## True when a touch at `pos` lands on an on-screen button rather than the play field.
func is_over_button(pos: Vector2) -> bool:
	for button in _buttons:
		if button.is_visible_in_tree() and button.get_global_rect().has_point(pos):
			return true
	return false


func set_theme_name(theme_name: String) -> void:
	for label in _theme_labels:
		label.text = theme_name


func _label(text: String, size: int, color := Color.WHITE, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = font if font else _font
	settings.font_size = size
	settings.font_color = color
	settings.shadow_color = Color(0.05, 0.03, 0.15, 0.5)
	settings.shadow_offset = Vector2(0, 3)
	settings.shadow_size = 4
	label.label_settings = settings
	return label


func _full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


## Soft dark gradient along a screen edge so white HUD text reads on any sky.
func _edge_shade(top: bool) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.02, 0.01, 0.08, 0.42))
	gradient.set_color(1, Color(0.02, 0.01, 0.08, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0 if top else 1.0)
	texture.fill_to = Vector2(0.5, 1.0 if top else 0.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	shade.custom_minimum_size = Vector2(0, 150)
	if top:
		shade.offset_bottom = 150
	else:
		shade.offset_top = -150
	_play_root.add_child(shade)


func _build_play_ui() -> Control:
	_play_root = _full_rect(Control.new())
	add_child(_play_root)
	_edge_shade(true)
	_edge_shade(false)
	var margin: MarginContainer = _full_rect(MarginContainer.new())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_play_root.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)

	var top := HBoxContainer.new()
	column.add_child(top)
	var left := VBoxContainer.new()
	top.add_child(left)
	_score = _label("0", 56, INK)
	left.add_child(_score)
	_mult = _label("x1", 30, ACCENT)
	left.add_child(_mult)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	# Top centre: fuel gauge.
	var fuel_box := VBoxContainer.new()
	fuel_box.add_theme_constant_override("separation", 4)
	top.add_child(fuel_box)
	_fuel_label = _centered(_label("FUEL", 18))
	fuel_box.add_child(_fuel_label)
	_fuel_bar = ProgressBar.new()
	_fuel_bar.min_value = 0.0
	_fuel_bar.max_value = 1.0
	_fuel_bar.step = 0.0
	_fuel_bar.value = 1.0
	_fuel_bar.show_percentage = false
	_fuel_bar.custom_minimum_size = Vector2(280, 18)
	var fuel_back := StyleBoxFlat.new()
	fuel_back.bg_color = Color(0.0, 0.0, 0.1, 0.35)
	fuel_back.set_corner_radius_all(9)
	fuel_back.set_border_width_all(2)
	fuel_back.border_color = Color(1, 1, 1, 0.7)
	_fuel_fill.set_corner_radius_all(9)
	_fuel_fill.bg_color = Color(0.4, 0.9, 0.45)
	_fuel_bar.add_theme_stylebox_override("background", fuel_back)
	_fuel_bar.add_theme_stylebox_override("fill", _fuel_fill)
	fuel_box.add_child(_fuel_bar)
	_toast = PanelContainer.new()
	var pill := StyleBoxFlat.new()
	pill.bg_color = Color(0.05, 0.03, 0.12, 0.6)
	pill.set_corner_radius_all(16)
	pill.content_margin_left = 18
	pill.content_margin_right = 18
	pill.content_margin_top = 4
	pill.content_margin_bottom = 6
	_toast.add_theme_stylebox_override("panel", pill)
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast.visible = false
	_toast_label = _centered(_label("", 24, INK, _title_font))
	_toast_label.label_settings.shadow_color = Color.TRANSPARENT
	_toast.add_child(_toast_label)
	fuel_box.add_child(_toast)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer_right)
	var right := VBoxContainer.new()
	top.add_child(right)
	_dist = _label("0 m", 32, INK)
	_dist.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_dist)
	_speed = _label("0 km/h", 20, Color(1, 1, 1, 0.85))
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_speed)

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)

	# Bottom-left: colour selector and Prism meter, clear of the vehicle in the middle.
	var bottom_row := HBoxContainer.new()
	column.add_child(bottom_row)
	var bottom := VBoxContainer.new()
	bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_theme_constant_override("separation", 10)
	bottom_row.add_child(bottom)
	var swatch_row := HBoxContainer.new()
	swatch_row.custom_minimum_size = Vector2(0, 76)
	swatch_row.add_theme_constant_override("separation", 12)
	bottom.add_child(swatch_row)
	for i in Defs.COLORS.size():
		var swatch := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Defs.COLORS[i]
		style.border_color = Color.WHITE
		style.set_corner_radius_all(14)
		swatch.add_theme_stylebox_override("panel", style)
		var key := _label(KEYS[i], 24, Color(0.05, 0.0, 0.1))
		key.label_settings.shadow_color = Color.TRANSPARENT
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		swatch.add_child(key)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch_row.add_child(swatch)
		_swatches.append(swatch)

	_prism_button = Button.new()
	_prism_button.text = "PRISM!"
	_prism_button.add_theme_font_override("font", _title_font)
	_prism_button.add_theme_font_size_override("font_size", 24)
	_prism_button.custom_minimum_size = Vector2(150, 72)
	_prism_button.focus_mode = Control.FOCUS_NONE
	_prism_button.visible = false
	_prism_button.pressed.connect(prism_pressed.emit)
	_buttons.append(_prism_button)

	_meter = ProgressBar.new()
	_meter.min_value = 0.0
	_meter.max_value = 1.0
	_meter.step = 0.0
	_meter.show_percentage = false
	_meter.custom_minimum_size = Vector2(250, 14)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.0, 0.0, 0.1, 0.3)
	background.set_corner_radius_all(7)
	_meter_fill.set_corner_radius_all(7)
	_meter.add_theme_stylebox_override("background", background)
	_meter.add_theme_stylebox_override("fill", _meter_fill)
	bottom.add_child(_meter)
	_meter_label = _label("PRISM", 18, INK)
	bottom.add_child(_meter_label)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(bottom_spacer)
	_prism_button.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.add_child(_prism_button)
	return _play_root


## Full-screen overlay: `top` box under the top edge, `bottom` box above the bottom edge,
## leaving the middle clear so the vehicle and scenery show through.
func _build_screen(dim: Color) -> Array[VBoxContainer]:
	var root: Control = _full_rect(Control.new())
	add_child(root)
	var shade: ColorRect = _full_rect(ColorRect.new())
	shade.color = dim
	root.add_child(shade)
	var margin: MarginContainer = _full_rect(MarginContainer.new())
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	root.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	column.add_child(bottom)
	return [top, bottom]


func _centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _round_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(64, 64)
	button.add_theme_font_override("font", _title_font)
	button.add_theme_font_size_override("font_size", 34)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.25 if state == "normal" else 0.45)
		style.set_corner_radius_all(32)
		button.add_theme_stylebox_override(state, style)
	_buttons.append(button)
	return button


## "<  THEME  >" picker shown on the title and game-over screens.
func _theme_row() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	var prev := _round_button("<")
	prev.pressed.connect(theme_step.emit.bind(-1))
	row.add_child(prev)
	var name_label := _centered(_label("", 40, Color.WHITE, _title_font))
	name_label.custom_minimum_size = Vector2(380, 0)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_label)
	_theme_labels.append(name_label)
	var next := _round_button(">")
	next.pressed.connect(theme_step.emit.bind(1))
	row.add_child(next)
	return row


func _build_menu() -> Control:
	var boxes := _build_screen(Color(0.1, 0.08, 0.25, 0.15))
	var top := boxes[0]
	var bottom := boxes[1]
	var title := _centered(_label("CHROMA RUSH", 96, Color.WHITE, _title_font))
	title.label_settings.shadow_color = ACCENT
	title.label_settings.shadow_offset = Vector2(6, 6)
	top.add_child(title)
	top.add_child(_centered(_label("Match the gate. Dodge the rest. Grab fuel. Don't stop.", 24)))
	bottom.add_child(_centered(_label("CHOOSE YOUR WORLD  (T)", 18, Color(1, 1, 1, 0.85))))
	bottom.add_child(_theme_row())
	_menu_prompt = _centered(_label("PRESS SPACE OR TAP TO RUN", 32))
	bottom.add_child(_menu_prompt)
	_menu_best = _centered(_label("", 22))
	bottom.add_child(_menu_best)
	var help := _centered(_label(
		"A/D  lanes     W  jump     S  slam     SPACE  colour     J K L  pick colour     SHIFT  prism     (swipe / tap on touch)", 16,
		Color(1, 1, 1, 0.85)))
	bottom.add_child(help)
	return top.get_parent().get_parent().get_parent()


func _build_game_over() -> Control:
	var boxes := _build_screen(Color(0.15, 0.05, 0.15, 0.3))
	var top := boxes[0]
	var bottom := boxes[1]
	_over_title = _centered(_label("CRASHED", 96, ACCENT, _title_font))
	top.add_child(_over_title)
	_over_score = _centered(_label("", 44))
	top.add_child(_over_score)
	_over_best = _centered(_label("", 30))
	top.add_child(_over_best)
	bottom.add_child(_theme_row())
	_over_prompt = _centered(_label("PRESS SPACE OR TAP TO RUN AGAIN", 30))
	bottom.add_child(_over_prompt)
	var root: Control = top.get_parent().get_parent().get_parent()
	root.visible = false
	return root
