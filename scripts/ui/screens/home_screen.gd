extends UiScreen
## Landing page. Shards and settings sit quietly in the top corners; the logo is the hero; and
## everything the player does next is in thumb reach at the bottom: MISSIONS, UPGRADES and SHOP
## in a dock, then the world picker with its PLAY or unlock button. The 3D scene behind shows
## the current world's vehicle circling.

var _logo: VBoxContainer
var _mark: GameLogo
var _tagline: Label
var _column: VBoxContainer
var _dock: HBoxContainer
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


func build() -> void:
	_top_shade()
	var top := UiKit.hbox(10)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)
	var pill := UiKit.pill(Color(0.1, 0.05, 0.22, 0.75), Vector2(18, 8))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_shards = UiKit.shard_amount(Profile.shards, 30)
	pill.add_child(_shards)
	top.add_child(pill)
	# Banked revives from Phoenix gems, shown once there are any.
	_tokens = UiKit.pill(Color(0.1, 0.05, 0.22, 0.75), Vector2(14, 8))
	_tokens.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var token_row := UiKit.hbox(6)
	token_row.add_child(UiIcon.make("gem", Powers.info(Powers.Kind.PHOENIX).color, Vector2(30, 30)))
	var token_count := UiKit.text("0", 30, false, 900)
	token_count.name = "Count"
	token_row.add_child(token_count)
	_tokens.add_child(token_row)
	top.add_child(_tokens)
	top.add_child(UiKit.spacer())
	var settings := UiKit.icon_button("gear", "light", 64)
	settings.pressed.connect(ui.open_settings)
	top.add_child(settings)

	_logo = UiKit.vbox(10)
	_logo.alignment = BoxContainer.ALIGNMENT_CENTER
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo)
	_mark = GameLogo.new()
	_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_logo.add_child(_mark)
	_tagline = UiKit.centered(UiKit.text("Match the gate. Dodge the rest.", 26, false, 900))
	_logo.add_child(_tagline)

	# Dock and world picker, centred along the bottom edge.
	_column = UiKit.vbox(14)
	UiKit.full_rect(_column)
	_column.offset_bottom = -28
	_column.alignment = BoxContainer.ALIGNMENT_END
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_column)
	_dock = UiKit.hbox(12)
	_dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_dock)
	_dock_button("MISSIONS", "sky", "target", ui.open_missions)
	var upgrades := _dock_button("UPGRADES", "gold", "upgrade", ui.open_upgrades)
	# A dot on the button while some upgrade is affordable.
	_upgrade_dot = UiIcon.make("circle", UiKit.STYLES.pink[0], Vector2(22, 22))
	_upgrade_dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_upgrade_dot.position += Vector2(-16, -6)
	upgrades.add_child(_upgrade_dot)
	_dock_button("SHOP", "pink", "bag", ui.open_shop)

	_panel = UiKit.card(24)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_child(_panel)
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
	_world_name = UiKit.centered(UiKit.title("", 50, UiKit.INK, Color(1, 1, 1, 0)))
	_world_name.label_settings.shadow_color = Color(0, 0, 0, 0)
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

	_play = UiKit.button("PLAY", "primary", Vector2(0, 104), 54, "play")
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


## One of the three dock buttons: an icon and a word, all the same width.
func _dock_button(label: String, style: String, icon: String, action: Callable) -> Button:
	var button := UiKit.button(label, style, Vector2(0, 72), 22, icon)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	_dock.add_child(button)
	return button


## A soft dark wash down from the top edge, so the white logo reads against any sky.
func _top_shade() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.1, 0.05, 0.3, 0.5))
	gradient.set_color(1, Color(0.1, 0.05, 0.3, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_top = -200
	shade.offset_bottom = 560
	add_child(shade)


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


## Portrait: logo on top, dock and world card along the bottom, vehicle in between. Landscape:
## logo, dock and card stacked on the left, the vehicle framed on the right (see Game._menu_tick).
func layout(portrait: bool) -> void:
	if not _panel:
		return
	_mark.font_size = 112 if portrait else 78
	_tagline.visible = portrait
	var width := card_width(true) if portrait else 520.0
	_panel.custom_minimum_size = Vector2(width, 0)
	_dock.custom_minimum_size = Vector2(width, 0)
	if portrait:
		_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_logo.offset_top = 120
		_column.offset_left = 0
		_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_dock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		_logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		_logo.offset_left = 32
		_logo.offset_top = 96
		_logo.custom_minimum_size.x = 520
		_column.offset_left = 32
		_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_dock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
