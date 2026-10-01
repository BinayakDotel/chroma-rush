extends UiScreen
## How to play, as six swipe-through cards. Shown automatically before a first-time player's
## first run (then its last button starts the run), and from the home and settings screens.

var _pages: Array[Dictionary] = []
var _page := 0
var _then_play := false
var _art: HBoxContainer
var _title: Label
var _body: Label
var _controls: Label
var _dots: HBoxContainer
var _next: Button


func _is_modal() -> bool:
	return true


func build() -> void:
	var touch := OS.has_feature("mobile")
	_pages = [
		{"title": "MATCH THE GATE", "icons": ["circle", "triangle", "square"], "colors": Defs.COLORS,
			"body": "Be the gate's colour before you reach it.",
			"controls": "Tap a colour button" if touch else "J K L or 1 2 3 picks a colour, SPACE cycles"},
		{"title": "DODGE BLOCKS", "icons": ["back", "next"],
			"body": "Change lanes to get around them.",
			"controls": "Swipe left or right" if touch else "A / D or the arrow keys"},
		{"title": "JUMP HURDLES", "icons": ["up"],
			"body": "Jump over anything low.",
			"controls": "Swipe up to jump, down to slam" if touch else "W to jump, S to slam"},
		{"title": "KEEP YOUR TANK FULL", "icons": ["fuel"],
			"body": "Grab fuel before the tank runs dry.",
			"controls": "Steer into the pickup's lane"},
		{"title": "POWER GEMS", "icons": ["shield", "magnet", "gem"],
			"colors": [Powers.info(Powers.Kind.SHIELD).color, Powers.info(Powers.Kind.MAGNET).color,
				Powers.info(Powers.Kind.PHOENIX).color],
			"body": "A shield, a magnet, or a free revive.",
			"controls": "Steer into the gem's lane"},
		{"title": "PRISM OVERDRIVE", "icons": ["bolt"],
			"body": "Fill the meter, then smash through everything.",
			"controls": "Tap PRISM" if touch else "SHIFT or E"},
	]
	dim(0.6)
	var content := centered_card(560, 28)
	var art_card := UiKit.card(20, UiKit.CARD_TINT, 28)
	(art_card.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	art_card.custom_minimum_size.y = 170
	content.add_child(art_card)
	var center := CenterContainer.new()
	art_card.add_child(center)
	_art = UiKit.hbox(24)
	center.add_child(_art)
	_title = UiKit.centered(UiKit.title("", 46, UiKit.INK, Color(1, 1, 1, 0)))
	content.add_child(_title)
	_body = UiKit.wrapped(UiKit.centered(UiKit.text("", 24, true, 700)))
	content.add_child(_body)
	var control_pill := CenterContainer.new()
	content.add_child(control_pill)
	var pill := UiKit.pill(UiKit.STYLES.sky[0], Vector2(18, 6))
	control_pill.add_child(pill)
	_controls = UiKit.text("", 20, false, 900)
	pill.add_child(_controls)
	_dots = UiKit.hbox(10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_dots)
	var row := UiKit.hbox(14)
	content.add_child(row)
	var skip := UiKit.button("", "light", Vector2(110, 80), 34, "close")
	skip.pressed.connect(_finish)
	row.add_child(skip)
	_next = UiKit.button("", "primary", Vector2(0, 80), 44, "next")
	_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_next.pressed.connect(_advance)
	row.add_child(_next)
	_show_page(0)


func configure(then_play: bool) -> void:
	_then_play = then_play
	_show_page(_page)


func _show_page(index: int) -> void:
	_page = index
	var page: Dictionary = _pages[index]
	for child in _art.get_children():
		child.queue_free()
	var icons: Array = page.icons
	for i in icons.size():
		var tint: Color = page.colors[i] if page.has("colors") else UiKit.STYLES.sky[1]
		var glyph := UiIcon.make(icons[i], tint, Vector2(96, 96))
		if page.has("colors"):
			glyph.outline = tint.darkened(0.45)
		_art.add_child(glyph)
	_title.text = page.title
	_body.text = page.body
	_controls.text = page.controls
	for child in _dots.get_children():
		child.queue_free()
	for i in _pages.size():
		_dots.add_child(UiIcon.make("circle", UiKit.STYLES.sky[0] if i == index else Color(0.82, 0.8, 0.9), Vector2(14, 14)))
	var last := index == _pages.size() - 1
	(_next.get_meta("icon") as UiIcon).set_icon(("play" if _then_play else "check") if last else "next")


func _advance() -> void:
	if _page < _pages.size() - 1:
		_show_page(_page + 1)
	else:
		_finish()


func _finish() -> void:
	Profile.mark_tutorial_done()
	close()
	if _then_play:
		ui.play_requested.emit()


func _gui_input(event: InputEvent) -> void:
	# Horizontal swipes page through the cards.
	if event is InputEventScreenDrag and absf(event.relative.x) > 30.0 and absf(event.velocity.x) > 800.0:
		if event.relative.x < 0.0:
			_advance()
		elif _page > 0:
			_show_page(_page - 1)
		accept_event()


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 580.0)
