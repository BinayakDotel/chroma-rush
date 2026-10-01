extends UiScreen
## In-run HUD: score and combo, fuel gauge, distance and pause along the top; the three colour
## buttons (each with its shape), the Prism meter and the Prism button along the bottom.
## Call-outs in the middle are symbols with at most a number beside them, not sentences.
## Portrait puts the colour buttons centred under the thumb; landscape puts them bottom-left.

const KEYS := ["J", "K", "L"]
const SPEED_LINES := """
shader_type canvas_item;
uniform float amount = 0.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float angle = atan(p.y, p.x);
	float slot = floor(angle * 30.0);
	float r = length(p);
	float streak = step(0.82, hash(slot + floor(TIME * 18.0) * 7.13));
	float band = smoothstep(0.34, 0.62, r) * streak;
	float thin = 1.0 - smoothstep(0.0, 0.35, abs(fract(angle * 30.0) - 0.5));
	COLOR = vec4(1.0, 1.0, 1.0, band * thin * amount * 0.35);
}
"""

var _score: Label
var _multiplier: PanelContainer
var _multiplier_label: Label
var _fuel_bar: ProgressBar
var _fuel_fill: StyleBoxFlat
var _fuel_icon: UiIcon
var _fuel_level := 1.0
var _distance: Label
var _shield_badge: PanelContainer
var _magnet_badge: PanelContainer
var _magnet_bar: ProgressBar
var _speed: Label
var _hint: PanelContainer
var _hint_label: Label
var _hint_icons: HBoxContainer
var _hint_tween: Tween
var _bottom: BoxContainer
var _swatch_row: HBoxContainer
var _swatches: Array[Button] = []
var _swatch_icons: Array[UiIcon] = []
var _key_labels: Array[Label] = []
var _meter: ProgressBar
var _meter_fill: StyleBoxFlat
var _meter_row: HBoxContainer
var _meter_icon: UiIcon
var _prism: Button
var _speed_fx: ColorRect
var _selected := 0
var _meter_ready := false
var _meter_active := false
var _portrait := false
var _t := 0.0
var _shown_score := -1
var _shown_multiplier := -1
var _shown_metres := -1
var _shown_kmh := -1


func build() -> void:
	_speed_fx = ColorRect.new()
	UiKit.full_rect(_speed_fx)
	_speed_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SPEED_LINES
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_speed_fx.material = mat
	add_child(_speed_fx)
	_edge_shade(true)
	_edge_shade(false)

	var top := UiKit.hbox(8)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 16
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var left := UiKit.vbox(0)
	left.custom_minimum_size.x = 170
	top.add_child(left)
	_score = UiKit.title("0", 64)
	left.add_child(_score)
	_multiplier = UiKit.pill(UiKit.STYLES.pink[0], Vector2(14, 2))
	_multiplier.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_multiplier_label = UiKit.title("x2", 28)
	_multiplier.add_child(_multiplier_label)
	left.add_child(_multiplier)
	top.add_child(UiKit.spacer())

	var center := UiKit.vbox(8)
	top.add_child(center)
	var fuel_row := UiKit.hbox(8)
	fuel_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(fuel_row)
	_fuel_icon = UiIcon.make("fuel", Color.WHITE, Vector2(30, 30))
	fuel_row.add_child(_fuel_icon)
	_fuel_bar = UiKit.bar(230, 24, Color(0.4, 0.9, 0.45))
	_fuel_fill = _fuel_bar.get_theme_stylebox("fill")
	fuel_row.add_child(_fuel_bar)
	# Active power gems, under the fuel gauge.
	var powers := UiKit.hbox(10)
	powers.alignment = BoxContainer.ALIGNMENT_CENTER
	powers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(powers)
	_shield_badge = _power_badge("shield", Powers.info(Powers.Kind.SHIELD).color)
	powers.add_child(_shield_badge)
	_magnet_badge = _power_badge("magnet", Powers.info(Powers.Kind.MAGNET).color)
	_magnet_bar = UiKit.bar(70, 10, Powers.info(Powers.Kind.MAGNET).color)
	_magnet_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_magnet_badge.get_child(0).add_child(_magnet_bar)
	powers.add_child(_magnet_badge)
	top.add_child(UiKit.spacer())

	var right := UiKit.vbox(2)
	right.custom_minimum_size.x = 170
	top.add_child(right)
	var pause := UiKit.icon_button("pause", "ghost", 64)
	pause.size_flags_horizontal = Control.SIZE_SHRINK_END
	pause.pressed.connect(ui.pause_requested.emit)
	right.add_child(pause)
	_distance = UiKit.title("0 m", 36)
	_distance.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_distance)
	_speed = UiKit.text("0 km/h", 20)
	_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_speed)

	# Tips and milestones float under the top bar, clear of the road ahead.
	var hint_holder := CenterContainer.new()
	hint_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hint_holder.offset_top = 150
	hint_holder.offset_bottom = 210
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_holder)
	_hint = UiKit.pill(Color(0.1, 0.05, 0.22, 0.7), Vector2(22, 8))
	_hint.visible = false
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint_row := UiKit.hbox(10)
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_child(hint_row)
	_hint_icons = UiKit.hbox(8)
	_hint_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_row.add_child(_hint_icons)
	_hint_label = UiKit.title("", 32)
	hint_row.add_child(_hint_label)
	hint_holder.add_child(_hint)

	_bottom = HBoxContainer.new()
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bottom)
	var controls := UiKit.vbox(10)
	controls.name = "Controls"
	_bottom.add_child(controls)
	# The Prism meter: a bolt and a bar. When it is full the bolt button appears.
	_meter_row = UiKit.hbox(8)
	controls.add_child(_meter_row)
	_meter_icon = UiIcon.make("bolt", Color.WHITE, Vector2(28, 28))
	_meter_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter_row.add_child(_meter_icon)
	_meter = UiKit.bar(300, 18, Color(1, 1, 1, 0.9))
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter_fill = _meter.get_theme_stylebox("fill")
	_meter_row.add_child(_meter)
	_swatch_row = UiKit.hbox(16)
	controls.add_child(_swatch_row)
	for i in Defs.COLORS.size():
		var swatch := _make_swatch(i)
		_swatch_row.add_child(swatch)
	var gap := UiKit.spacer()
	gap.name = "Gap"
	_bottom.add_child(gap)
	_prism = UiKit.button("", "gold", Vector2(150, 96), 60, "bolt")
	_prism.size_flags_vertical = Control.SIZE_SHRINK_END
	_prism.visible = false
	_prism.pressed.connect(ui.prism_pressed.emit)
	_bottom.add_child(_prism)
	Settings.changed.connect(func(key: StringName) -> void:
		if key == &"color_symbols":
			set_color(_selected))
	set_color(0)


func _make_swatch(i: int) -> Button:
	var face: Color = Defs.COLORS[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 88)
	for state in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = face if state != "pressed" else face.darkened(0.1)
		box.set_corner_radius_all(44)
		box.border_width_bottom = 7 if state != "pressed" else 2
		box.border_color = face.darkened(0.45)
		box.shadow_color = Color(0.05, 0.02, 0.15, 0.3)
		box.shadow_size = 6
		box.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override(state, box)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := UiIcon.make(UiIcon.symbol_name(i), Color.WHITE, Vector2(40, 40))
	b.add_child(icon)
	var key := UiKit.text(KEYS[i], 16, false, 900)
	key.visible = not OS.has_feature("mobile")
	b.add_child(key)
	b.resized.connect(func() -> void:
		var box := icon.custom_minimum_size
		icon.size = box
		icon.position = (b.size - box) * 0.5 - Vector2(0, 3)
		key.position = Vector2(b.size.x - 26, b.size.y - 34))
	b.button_down.connect(func() -> void: ui.color_pressed.emit(i))
	_swatches.append(b)
	_swatch_icons.append(icon)
	_key_labels.append(key)
	return b


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	if _meter_ready or _meter_active:
		_meter_fill.bg_color = Color.from_hsv(fmod(_t * 0.8, 1.0), 0.65, 1.0)
		if _meter_ready:
			_prism.scale = Vector2.ONE * (1.0 + 0.05 * sin(_t * 8.0))
			_prism.pivot_offset = _prism.size * 0.5
	if _fuel_level < 0.25:
		var flash := 0.5 + 0.5 * sin(_t * 12.0)
		_fuel_fill.bg_color = Color(1.0, 0.3 + 0.2 * flash, 0.25)
		_fuel_icon.modulate.a = 0.5 + 0.5 * flash
	else:
		_fuel_icon.modulate.a = 1.0


func reset() -> void:
	set_score(0.0, 1)
	set_distance(0, 0.0)
	set_fuel(1.0)
	set_powers(false, 0.0)
	set_meter(0.0, false, false)
	set_color(0)
	set_speed_fx(0.0)
	_hint.visible = false


## These are called every frame: text is only rebuilt when the number on screen changes.
func set_score(score: float, multiplier: int) -> void:
	if int(score) != _shown_score:
		_shown_score = int(score)
		_score.text = UiKit.thousands(_shown_score)
	if multiplier != _shown_multiplier:
		_shown_multiplier = multiplier
		_multiplier_label.text = "x%d" % multiplier
		_multiplier.visible = multiplier > 1


func set_distance(metres: int, speed: float) -> void:
	if metres != _shown_metres:
		_shown_metres = metres
		_distance.text = "%s m" % UiKit.thousands(metres)
	var kmh := int(speed * 3.6)
	if kmh != _shown_kmh:
		_shown_kmh = kmh
		_speed.text = "%d km/h" % kmh


func set_fuel(level: float) -> void:
	_fuel_level = level
	_fuel_bar.value = level
	if level >= 0.25:
		_fuel_fill.bg_color = Color(0.4, 0.9, 0.45) if level > 0.5 else Color(1.0, 0.8, 0.25)


## Shows the held shield and the magnet's time left (0..1, hidden at 0).
func set_powers(shield: bool, magnet: float) -> void:
	_shield_badge.visible = shield
	_magnet_badge.visible = magnet > 0.0
	_magnet_bar.value = magnet


func _power_badge(icon: String, tint: Color) -> PanelContainer:
	var badge := UiKit.pill(Color(0.1, 0.05, 0.22, 0.7), Vector2(10, 4))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.visible = false
	var row := UiKit.hbox(6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(row)
	row.add_child(UiIcon.make(icon, tint, Vector2(28, 28)))
	return badge


func set_color(index: int) -> void:
	_selected = index
	var big := 104.0 if _portrait else 88.0
	var small := 84.0 if _portrait else 70.0
	for i in _swatches.size():
		var selected := i == index
		var swatch := _swatches[i]
		swatch.custom_minimum_size = Vector2.ONE * (big if selected else small)
		# Unselected buttons are smaller and a touch quieter, but keep their true colour.
		swatch.modulate = Color.WHITE if selected else Color(0.9, 0.9, 0.9)
		for state in ["normal", "hover", "pressed"]:
			var box: StyleBoxFlat = swatch.get_theme_stylebox(state)
			box.set_corner_radius_all(int(swatch.custom_minimum_size.x * 0.5))
			box.set_border_width_all(5 if selected else 0)
			box.border_width_bottom = 7 if selected else 5
			box.border_color = Color.WHITE if selected else Defs.COLORS[i].darkened(0.45)
		var icon := _swatch_icons[i]
		icon.visible = Settings.color_symbols
		icon.custom_minimum_size = Vector2.ONE * swatch.custom_minimum_size.x * 0.42
		swatch.reset_size()


func set_meter(value: float, is_ready: bool, active: bool) -> void:
	_meter.value = value
	_meter_ready = is_ready and not active
	_meter_active = active
	_prism.visible = _meter_ready
	_meter_icon.modulate = UiKit.GOLD if is_ready or active else Color.WHITE
	if not is_ready and not active:
		_meter_fill.bg_color = Color(1, 1, 1, 0.9)


## Speed-line intensity 0..1 (off when the player asked for reduced motion).
func set_speed_fx(amount: float) -> void:
	var mat := _speed_fx.material as ShaderMaterial
	mat.set_shader_parameter("amount", 0.0 if Settings.reduce_motion else clampf(amount, 0.0, 1.0))


## Call-out for tips, milestones and pickups: `icons` (names from UiIcon) and, if a symbol
## cannot say it alone, a short `text` such as a number.
func hint(text: String, color := Color.WHITE, hold := 1.4, icons: Array = []) -> void:
	for child in _hint_icons.get_children():
		child.queue_free()
	for icon: String in icons:
		var glyph := UiIcon.make(icon, color, Vector2(40, 40))
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_hint_icons.add_child(glyph)
	_hint_icons.visible = not icons.is_empty()
	_hint_label.text = text
	_hint_label.visible = not text.is_empty()
	_hint_label.label_settings.font_color = color
	_hint.visible = true
	_hint.modulate.a = 0.0
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.1)
	_hint_tween.tween_interval(hold)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.3)
	_hint_tween.tween_callback(_hint.hide)


func handle_back() -> bool:
	ui.pause_requested.emit()
	return true


func layout(portrait: bool) -> void:
	_portrait = portrait
	if not _bottom:
		return
	var controls: VBoxContainer = _bottom.get_node("Controls")
	(_bottom.get_node("Gap") as Control).visible = not portrait
	if portrait:
		_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_bottom.offset_top = -330
		_bottom.offset_bottom = -30
		_bottom.offset_left = 24
		_bottom.offset_right = -24
		controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		controls.alignment = BoxContainer.ALIGNMENT_END
		_swatch_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_meter_row.alignment = BoxContainer.ALIGNMENT_CENTER
		# PRISM button sits above the colour buttons in portrait.
		if _prism.get_parent() != controls:
			_prism.reparent(controls)
			controls.move_child(_prism, 0)
		_prism.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_bottom.offset_top = -260
		_bottom.offset_bottom = -24
		_bottom.offset_left = 28
		_bottom.offset_right = -28
		controls.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		controls.alignment = BoxContainer.ALIGNMENT_END
		_swatch_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		_meter_row.alignment = BoxContainer.ALIGNMENT_BEGIN
		if _prism.get_parent() != _bottom:
			_prism.reparent(_bottom)
		_prism.size_flags_horizontal = Control.SIZE_SHRINK_END
	set_color(_selected)


## Soft dark gradient along a screen edge so white HUD text reads on any sky.
func _edge_shade(top: bool) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.01, 0.1, 0.45))
	gradient.set_color(1, Color(0.03, 0.01, 0.1, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0 if top else 1.0)
	texture.fill_to = Vector2(0.5, 1.0 if top else 0.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		shade.offset_top = -100
		shade.offset_bottom = 170
	else:
		shade.offset_top = -200
		shade.offset_bottom = 100
	add_child(shade)
