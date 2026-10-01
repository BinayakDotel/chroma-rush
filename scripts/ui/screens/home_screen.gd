extends UiScreen
## Landing page: logo, shard counter, missions / upgrades / settings / shop / help, and the
## world picker with its PLAY or unlock button. The 3D scene behind shows the current world's vehicle circling.

var _logo_letters: Array[Label] = []
var _logo: VBoxContainer
var _logo_top: HBoxContainer
var _tagline: Label
var _rush: Label
var _column: VBoxContainer
var _center: CenterContainer
var _shards: HBoxContainer
var _tokens: PanelContainer
var _upgrade_dot: Control
var _panel: PanelContainer
var _world_name: Label
var _character: Label
var _status: HBoxContainer
var _dots: HBoxContainer
var _play: Button
var _unlock: Button
var _pass: Button
var _world := {}
var _t := 0.0


func build() -> void:
	var top := UiKit.hbox(10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)
	var pill := UiKit.pill(Color(0.1, 0.05, 0.22, 0.75), Vector2(18, 6))
	_shards = UiKit.shard_amount(Profile.shards, 30)
	pill.add_child(_shards)
	top.add_child(pill)
	# Banked revives from Phoenix gems, shown once there are any.
	_tokens = UiKit.pill(Color(0.1, 0.05, 0.22, 0.75), Vector2(14, 6))
	var token_row := UiKit.hbox(6)
	token_row.add_child(UiIcon.make("gem", Powers.info(Powers.Kind.PHOENIX).color, Vector2(30, 30)))
	var token_count := UiKit.text("0", 30, false, 900)
	token_count.name = "Count"
	token_row.add_child(token_count)
	_tokens.add_child(token_row)
	top.add_child(_tokens)
	top.add_child(UiKit.spacer())
	var missions := UiKit.icon_button("target", "primary", 64)
	missions.pressed.connect(ui.open_missions)
	top.add_child(missions)
	var upgrades := UiKit.icon_button("upgrade", "gold", 64)
	upgrades.pressed.connect(ui.open_upgrades)
	top.add_child(upgrades)
	# A dot on the button while some upgrade is affordable.
	_upgrade_dot = UiIcon.make("circle", UiKit.STYLES.pink[0], Vector2(20, 20))
	_upgrade_dot.position = Vector2(46, -2)
	upgrades.add_child(_upgrade_dot)
	var help := UiKit.icon_button("help", "light", 64)
	help.pressed.connect(func() -> void: ui.open_howto(false))
	top.add_child(help)
	var shop := UiKit.icon_button("bag", "pink", 64)
	shop.pressed.connect(ui.open_shop)
	top.add_child(shop)
	var settings := UiKit.icon_button("gear", "light", 64)
	settings.pressed.connect(ui.open_settings)
	top.add_child(settings)

	_logo = UiKit.vbox(8)
	_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_logo.offset_top = 100
	_logo.alignment = BoxContainer.ALIGNMENT_CENTER
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	var words := UiKit.vbox(-22)
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.add_child(words)
	_logo_top = UiKit.hbox(2)
	_logo_top.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_child(_logo_top)
	var word := "CHROMA"
	for i in word.length():
		var letter := UiKit.title(word[i], 100, Defs.COLORS[i % 3].lightened(0.1))
		_logo_top.add_child(letter)
		_logo_letters.append(letter)
	_rush = UiKit.centered(UiKit.title("RUSH", 100))
	words.add_child(_rush)
	_tagline = UiKit.centered(UiKit.text("Match the gate. Dodge the rest.", 26, false, 900))
	_logo.add_child(_tagline)

	# World picker card, centred along the bottom edge.
	_column = UiKit.vbox(0)
	UiKit.full_rect(_column)
	_column.offset_bottom = -28
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_center = CenterContainer.new()
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_center)
	_panel = UiKit.card(24)
	_center.add_child(_panel)
	var content := UiKit.vbox(14)
	_panel.add_child(content)
	var picker := UiKit.hbox(10)
	content.add_child(picker)
	var prev := UiKit.icon_button("back", "light", 64)
	prev.pressed.connect(func() -> void: ui.world_browsed.emit(-1))
	picker.add_child(prev)
	var info := UiKit.vbox(2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_child(info)
	_world_name = UiKit.centered(UiKit.title("", 50))
	info.add_child(_world_name)
	_character = UiKit.centered(UiKit.text("", 21, true, 700))
	_character.label_settings.font_color = UiKit.INK_SOFT
	info.add_child(_character)
	_status = UiKit.hbox(8)
	_status.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_child(_status)
	var next := UiKit.icon_button("next", "light", 64)
	next.pressed.connect(func() -> void: ui.world_browsed.emit(1))
	picker.add_child(next)
	_dots = UiKit.hbox(10)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_dots)

	_play = UiKit.button("PLAY", "primary", Vector2(0, 100), 52, "play")
	_play.pressed.connect(ui.play_requested.emit)
	content.add_child(_play)
	_unlock = UiKit.button("UNLOCK", "gold", Vector2(0, 88), 38, "lock")
	_unlock.pressed.connect(ui.unlock_requested.emit)
	content.add_child(_unlock)
	_pass = UiKit.button("GET WORLD PASS", "sky", Vector2(0, 68), 28, "bag")
	_pass.pressed.connect(ui.open_shop)
	content.add_child(_pass)

	Profile.shards_changed.connect(func(_total: int) -> void: _refresh())
	Profile.upgrades_changed.connect(_refresh)
	Profile.revive_tokens_changed.connect(func(_count: int) -> void: _refresh())
	Profile.worlds_changed.connect(_refresh)
	Profile.entitlements_changed.connect(_refresh)
	Store.products_updated.connect(_refresh)


func show_world(world: Dictionary, index: int, count: int) -> void:
	_world = world
	for dot in _dots.get_children():
		dot.queue_free()
	for i in count:
		var d := UiIcon.make("circle", UiKit.STYLES.sky[0] if i == index else Color(0.82, 0.8, 0.9), Vector2(14, 14))
		_dots.add_child(d)
	_refresh()


func _refresh() -> void:
	if _world.is_empty():
		return
	(_shards.get_node("Amount") as Label).text = UiKit.thousands(Profile.shards)
	_tokens.visible = Profile.revive_tokens > 0
	(_tokens.find_child("Count", true, false) as Label).text = str(Profile.revive_tokens)
	_upgrade_dot.visible = Profile.can_buy_upgrade()
	_world_name.text = _world.name
	_character.text = _world.character
	for child in _status.get_children():
		child.queue_free()
	var unlocked := Profile.is_unlocked(_world.id)
	var cost := Economy.world_cost(_world.id)
	if unlocked:
		var best := Profile.best(_world.id)
		_status.add_child(UiIcon.make("trophy", UiKit.GOLD.darkened(0.15), Vector2(26, 26)))
		_status.add_child(UiKit.text("BEST  %s" % UiKit.thousands(best) if best > 0 else "NEW WORLD - SET A SCORE", 22, true, 900))
	else:
		_status.add_child(UiIcon.make("lock", UiKit.INK_SOFT, Vector2(24, 24)))
		_status.add_child(UiKit.text("LOCKED", 22, true, 900))
	_play.visible = unlocked
	_unlock.visible = not unlocked
	_pass.visible = not unlocked and Store.is_available() and not Store.is_owned("world_pass")
	if not unlocked:
		var affordable := Profile.shards >= cost
		UiKit.set_text(_unlock, ("UNLOCK  %s" if affordable else "NEED  %s") % UiKit.thousands(cost))
		(_unlock.get_meta("icon") as UiIcon).set_icon("shard" if affordable else "lock", Color(0.35, 0.2, 0.05))
		_unlock.disabled = not affordable
		UiKit.set_text(_pass, "ALL WORLDS  %s" % Store.price("world_pass"))


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _logo_letters.size():
		_logo_letters[i].position.y = sin(_t * 3.0 + i * 0.6) * 6.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible or ui.has_overlay():
		return
	if event.is_action_pressed("move_left"):
		ui.world_browsed.emit(-1)
	elif event.is_action_pressed("move_right"):
		ui.world_browsed.emit(1)
	elif event.is_action_pressed("start") and _play.visible:
		ui.play_requested.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func handle_back() -> bool:
	if OS.has_feature("mobile"):
		ui.confirm("LEAVING?", "Your progress is saved.", "QUIT", ui.quit_requested.emit)
		return true
	return false


## Portrait: logo on top, world card along the bottom, vehicle in between. Landscape: logo and
## card stacked on the left, the vehicle framed on the right (see Game._menu_tick).
func layout(portrait: bool) -> void:
	if not _panel:
		return
	var logo_size := 108 if portrait else 80
	for letter in _logo_letters:
		letter.label_settings.font_size = logo_size
		letter.label_settings.outline_size = logo_size / 7
	_rush.label_settings.font_size = logo_size
	_rush.label_settings.outline_size = logo_size / 7
	if portrait:
		_panel.custom_minimum_size = Vector2(card_width(true), 0)
		_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_logo.offset_top = 110
		_column.offset_left = 0
		_center.size_flags_horizontal = Control.SIZE_FILL
	else:
		_panel.custom_minimum_size = Vector2(520, 0)
		_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_logo.offset_left = 32
		_logo.offset_top = 70
		_logo.custom_minimum_size.x = 520
		_column.offset_left = 32
		_center.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
