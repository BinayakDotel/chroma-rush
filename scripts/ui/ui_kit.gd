class_name UiKit
## Shared look for every screen: fonts, colours, candy buttons, cards, pills and toggles.
## Style: bubbly and bright (see the reference images), chunky rounded shapes with a darker
## "lip" under buttons, white cards with deep-purple ink, and white titles with thick outlines.

const TITLE_FONT := preload("res://fonts/LilitaOne-Regular.ttf")
const BODY_FONT_FILE := preload("res://fonts/Nunito.ttf")

const INK := Color(0.17, 0.12, 0.3)
const INK_SOFT := Color(0.4, 0.35, 0.55)
const CARD := Color(1.0, 1.0, 1.0, 0.97)
const CARD_TINT := Color(0.95, 0.93, 1.0)
const OUTLINE := Color(0.17, 0.1, 0.32)
const SHADE := Color(0.07, 0.04, 0.16, 0.45)
const GOLD := Color(1.0, 0.8, 0.22)

## Button styles: [face, lip, text].
const STYLES := {
	"primary": [Color(0.32, 0.86, 0.46), Color(0.16, 0.6, 0.3), Color.WHITE],
	"pink": [Color(1.0, 0.46, 0.66), Color(0.78, 0.25, 0.47), Color.WHITE],
	"sky": [Color(0.36, 0.7, 1.0), Color(0.2, 0.45, 0.82), Color.WHITE],
	"gold": [Color(1.0, 0.78, 0.2), Color(0.82, 0.55, 0.1), Color(0.35, 0.2, 0.05)],
	"light": [Color(1.0, 1.0, 1.0), Color(0.78, 0.76, 0.88), INK],
	"ghost": [Color(1.0, 1.0, 1.0, 0.22), Color(0.0, 0.0, 0.1, 0.25), Color.WHITE],
	"danger": [Color(1.0, 0.42, 0.4), Color(0.75, 0.22, 0.22), Color.WHITE],
}

static var _body_fonts := {}


## Nunito at a given weight (400 regular ... 900 black).
static func body_font(weight := 800) -> Font:
	if not _body_fonts.has(weight):
		var variation := FontVariation.new()
		variation.base_font = BODY_FONT_FILE
		# The axis is keyed by its OpenType tag, not its name; with the name the weight is ignored
		# and every label falls back to the font's lightest default.
		variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
		_body_fonts[weight] = variation
	return _body_fonts[weight]


## Label in the title font with a thick outline, for headings and big numbers.
static func title(text: String, size: int, color := Color.WHITE, outline := OUTLINE) -> Label:
	var label := Label.new()
	label.text = text
	var settings := LabelSettings.new()
	settings.font = TITLE_FONT
	settings.font_size = size
	settings.font_color = color
	settings.outline_size = maxi(4, size / 7)
	settings.outline_color = outline
	settings.shadow_color = Color(0.05, 0.02, 0.12, 0.35)
	settings.shadow_offset = Vector2(0, maxf(2.0, size / 14.0))
	settings.shadow_size = 0
	label.label_settings = settings
	return label


## Body text in Nunito. `on_card` switches to dark ink without an outline.
static func text(value: String, size: int, on_card := false, weight := 800) -> Label:
	var label := Label.new()
	label.text = value
	var settings := LabelSettings.new()
	settings.font = body_font(weight)
	settings.font_size = size
	if on_card:
		settings.font_color = INK
	else:
		settings.font_color = Color.WHITE
		settings.outline_size = maxi(3, size / 6)
		settings.outline_color = Color(0.1, 0.05, 0.2, 0.75)
	label.label_settings = settings
	return label


static func centered(label: Label) -> Label:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


static func wrapped(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## Chunky rounded button with a darker lip underneath that squashes when pressed.
static func button(label: String, style := "primary", size := Vector2(0, 76), font_size := 34, icon := "") -> Button:
	var colors: Array = STYLES[style]
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = size
	b.add_theme_font_override("font", TITLE_FONT)
	b.add_theme_font_size_override("font_size", font_size)
	var text_color: Color = colors[2]
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, text_color)
	b.add_theme_color_override("font_disabled_color", Color(text_color, 0.55))
	if text_color == Color.WHITE:
		b.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
		b.add_theme_color_override("font_outline_color", Color(colors[1]).darkened(0.35))
	var radius := int(minf(size.y, 80.0) * 0.36)
	b.add_theme_stylebox_override("normal", _candy(colors[0], colors[1], radius, 7))
	b.add_theme_stylebox_override("hover", _candy(Color(colors[0]).lightened(0.08), colors[1], radius, 7))
	b.add_theme_stylebox_override("pressed", _candy(Color(colors[0]).darkened(0.05), colors[1], radius, 2))
	b.add_theme_stylebox_override("disabled", _candy(Color(colors[0], 0.5), Color(colors[1], 0.5), radius, 7))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not icon.is_empty():
		# Icon (and optional label) centred in the button; the lip squash nudges them down.
		b.text = ""
		var center := CenterContainer.new()
		full_rect(center)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.offset_bottom = -6
		b.add_child(center)
		var row := hbox(12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(row)
		var glyph := UiIcon.make(icon, text_color, Vector2(font_size, font_size) * 0.95)
		row.add_child(glyph)
		b.set_meta("icon", glyph)
		if not label.is_empty():
			var caption := Label.new()
			caption.text = label
			caption.add_theme_font_override("font", TITLE_FONT)
			caption.add_theme_font_size_override("font_size", font_size)
			caption.add_theme_color_override("font_color", text_color)
			if text_color == Color.WHITE:
				caption.add_theme_constant_override("outline_size", maxi(4, font_size / 6))
				caption.add_theme_color_override("font_outline_color", Color(colors[1]).darkened(0.35))
			row.add_child(caption)
			b.set_meta("caption", caption)
		b.button_down.connect(func() -> void: center.offset_top = 5; center.offset_bottom = -1)
		b.button_up.connect(func() -> void: center.offset_top = 0; center.offset_bottom = -6)
	b.pressed.connect(func() -> void: Sfx.click())
	return b


## Changes a button's label whether or not it has an icon.
static func set_text(b: Button, value: String) -> void:
	if b.has_meta("caption"):
		(b.get_meta("caption") as Label).text = value
	else:
		b.text = value


## Round button showing only an icon (pause, settings, back...).
static func icon_button(icon: String, style := "light", diameter := 68.0) -> Button:
	var b := button("", style, Vector2(diameter, diameter), 30, icon)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = b.get_theme_stylebox(state)
		box.set_corner_radius_all(int(diameter * 0.5))
	var glyph: Control = b.get_meta("icon")
	glyph.custom_minimum_size = Vector2(diameter, diameter) * 0.46
	glyph.size = glyph.custom_minimum_size
	return b


## White rounded card with a soft drop shadow.
static func card(padding := 26, color := CARD, radius := 34) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.shadow_color = SHADE
	box.shadow_size = 18
	box.shadow_offset = Vector2(0, 8)
	box.set_content_margin_all(padding)
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Small rounded capsule, e.g. the shard counter or a status chip.
static func pill(color: Color, padding := Vector2(18, 6)) -> PanelContainer:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(999)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	panel.add_theme_stylebox_override("panel", box)
	return panel


## Horizontal bar with rounded ends. Returns the ProgressBar; recolour its "fill" stylebox.
static func bar(width: float, height: float, fill: Color, back := Color(0.05, 0.02, 0.15, 0.4)) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.step = 0.0
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(width, height)
	var background := StyleBoxFlat.new()
	background.bg_color = back
	background.set_corner_radius_all(int(height))
	background.set_border_width_all(3)
	background.border_color = Color(1, 1, 1, 0.85)
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.set_corner_radius_all(int(height))
	progress.add_theme_stylebox_override("background", background)
	progress.add_theme_stylebox_override("fill", front)
	return progress


## On/off switch styled like the buttons.
static func toggle(on: bool) -> CheckButton:
	var check := CheckButton.new()
	check.button_pressed = on
	check.focus_mode = Control.FOCUS_NONE
	check.add_theme_icon_override("checked", _switch_texture(true))
	check.add_theme_icon_override("unchecked", _switch_texture(false))
	check.toggled.connect(func(_on: bool) -> void: Sfx.click())
	return check


static func slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(220, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.85, 0.83, 0.93)
	track.set_corner_radius_all(8)
	track.content_margin_top = 7
	track.content_margin_bottom = 7
	var filled := track.duplicate()
	filled.bg_color = STYLES.sky[0]
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)
	var knob := _circle_texture(30, Color.WHITE, STYLES.sky[1])
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	return s


## Shard icon + amount, used in the top bar and on prices.
static func shard_amount(amount: int, size := 30, on_card := false) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UiIcon.make("shard", GOLD, Vector2(size, size)))
	var label := text(_thousands(amount), size, on_card, 900)
	label.name = "Amount"
	row.add_child(label)
	return row


## One mission on a card: icon, what to do, a progress bar with "value / target", and the
## shards it pays. `value` is the progress to show (see Missions.progress).
static func mission_row(mission: Dictionary, value: int) -> PanelContainer:
	var target := int(mission.target)
	var done := value >= target
	var chip := card(12, CARD_TINT, 22)
	(chip.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	var row := hbox(12)
	chip.add_child(row)
	var badge := pill(STYLES.primary[0] if done else STYLES.sky[0], Vector2(9, 9))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiIcon.make("check" if done else Missions.icon(mission), Color.WHITE, Vector2(28, 28)))
	row.add_child(badge)
	var info := vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(wrapped(text(Missions.describe(mission), 21, true, 800)))
	var progress := hbox(10)
	info.add_child(progress)
	var meter := bar(0, 12, STYLES.primary[0] if done else GOLD, Color(0.84, 0.82, 0.92))
	(meter.get_theme_stylebox("background") as StyleBoxFlat).set_border_width_all(0)
	meter.value = float(value) / maxf(target, 1.0)
	meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress.add_child(meter)
	var count := text("DONE" if done else "%s / %s" % [_thousands(value), _thousands(target)], 18, true, 900)
	count.label_settings.font_color = STYLES.primary[1] if done else INK_SOFT
	progress.add_child(count)
	var reward := shard_amount(Missions.payout(mission), 22, true)
	(reward.get_node("Amount") as Label).text = "+" + (reward.get_node("Amount") as Label).text
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(reward)
	return chip


## Lets a touch that starts on `node` or anything inside it also reach the scroll container
## around it. Panels and buttons normally keep a touch to themselves, which is why a list would
## only scroll when dragged by the gaps between its rows. Buttons still work: when a drag turns
## into a scroll, the engine cancels the press. Sliders keep their touches, so adjusting one
## never scrolls the list.
static func pass_touches(node: Node) -> void:
	if node is Control and not node is Slider and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		pass_touches(child)


static func vbox(separation := 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func hbox(separation := 16) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", separation)
	return box


static func spacer(expand_vertical := false) -> Control:
	var c := Control.new()
	if expand_vertical:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func full_rect(control: Control) -> Control:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return control


static func _thousands(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


static func thousands(value: int) -> String:
	return _thousands(value)


static func _candy(face: Color, lip: Color, radius: int, lip_height: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.set_corner_radius_all(radius)
	box.border_width_bottom = lip_height
	box.border_color = lip
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 8 + (7 - lip_height)
	box.content_margin_bottom = 8
	box.shadow_color = Color(0.05, 0.02, 0.15, 0.25)
	box.shadow_size = 6
	box.shadow_offset = Vector2(0, 4)
	box.anti_aliasing_size = 1.2
	return box


static func _switch_texture(on: bool) -> Texture2D:
	var w := 84
	var h := 46
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track_color: Color = STYLES.primary[0] if on else Color(0.8, 0.78, 0.88)
	for y in h:
		for x in w:
			var cx := clampf(x, h * 0.5, w - h * 0.5)
			var d := Vector2(x - cx, y - h * 0.5).length()
			var a := clampf(h * 0.5 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(track_color, a))
	var knob_x := w - h * 0.5 if on else h * 0.5
	for y in h:
		for x in w:
			var d := Vector2(x - knob_x, y - h * 0.5).length()
			var a := clampf(h * 0.5 - 5.0 - d, 0.0, 1.0)
			if a > 0.0:
				image.set_pixel(x, y, image.get_pixel(x, y).blend(Color(1, 1, 1, a)))
	return ImageTexture.create_from_image(image)


static func _circle_texture(diameter: int, fill: Color, ring: Color) -> Texture2D:
	var image := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := diameter * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var c := ring if d > r - 4.0 else fill
			image.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(image)
