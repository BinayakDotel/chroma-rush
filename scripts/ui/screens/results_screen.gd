extends UiScreen
## End of a run, laid out like a scoreboard rather than a form. The score is the hero, straight
## on the dimmed scene. Under it one card holds everything else: three numbers (distance, gates,
## shards), the missions as progress rings, and what the shards are building towards. Then at
## most one row of offers (a second chance, double shards) and RETRY.

var _title: Label
var _score: Label
var _best: PanelContainer
var _best_label: Label
var _column: VBoxContainer
var _stats: HBoxContainer
var _shards_value: Label
var _mission_box: VBoxContainer
var _missions: HBoxContainer
var _best_row: Control
var _card: PanelContainer
var _inner: VBoxContainer
var _split: HBoxContainer
var _left: VBoxContainer
var _right: VBoxContainer
var _goal_box: VBoxContainer
var _goal_label: Label
var _goal_bar: ProgressBar
var _goal_ready: Button
var _goal: Dictionary = {}
var _shown_shards := 0
var _offers: HBoxContainer
var _actions: HBoxContainer
var _revive: Button
var _token: Button
var _double: Button
var _sections: Array[Control] = []
var _portrait := true


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.5)
	var center := CenterContainer.new()
	UiKit.full_rect(center)
	add_child(center)
	_column = UiKit.vbox(14)
	_column.name = "Card"
	_column.custom_minimum_size.x = 560
	center.add_child(_column)

	_title = UiKit.centered(UiKit.title("CRASHED!", 52, UiKit.STYLES.pink[0]))
	_column.add_child(_title)
	_score = UiKit.centered(UiKit.title("0", 128, Color.WHITE))
	_column.add_child(_score)
	_best_row = CenterContainer.new()
	_column.add_child(_best_row)
	_best = UiKit.pill(UiKit.GOLD, Vector2(22, 6))
	_best_label = UiKit.title("NEW BEST!", 28, Color.WHITE, Color(0.55, 0.3, 0.05))
	_best.add_child(_best_label)
	_best_row.add_child(_best)

	_card = UiKit.card(22, UiKit.CARD, 32)
	_column.add_child(_card)
	_inner = UiKit.vbox(16)
	_card.add_child(_inner)
	_split = UiKit.hbox(24)
	_left = UiKit.vbox(10)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right = UiKit.vbox(8)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_split.add_child(_left)
	_split.add_child(_right)
	_stats = UiKit.hbox(0)
	_inner.add_child(_stats)
	_mission_box = UiKit.vbox(14)
	_inner.add_child(_mission_box)
	_mission_box.add_child(_divider())
	_missions = UiKit.hbox(8)
	_mission_box.add_child(_missions)
	# What the shards are for: progress towards the next upgrade or world, or a button straight
	# to the upgrades once one can be afforded.
	_goal_box = UiKit.vbox(6)
	_inner.add_child(_goal_box)
	_goal_box.add_child(_divider())
	_goal_label = UiKit.centered(UiKit.text("", 19, true, 800))
	_goal_label.label_settings.font_color = UiKit.INK_SOFT
	_goal_box.add_child(_goal_label)
	_goal_bar = UiKit.bar(0, 10, UiKit.GOLD, Color(0.9, 0.88, 0.96))
	(_goal_bar.get_theme_stylebox("background") as StyleBoxFlat).set_border_width_all(0)
	_goal_box.add_child(_goal_bar)
	_goal_ready = UiKit.button("UPGRADE READY", "gold", Vector2(0, 62), 24, "upgrade")
	_goal_ready.pressed.connect(_on_goal_pressed)
	_inner.add_child(_goal_ready)

	_offers = UiKit.hbox(12)
	_column.add_child(_offers)
	_token = _offer("FREE REVIVE", "sky", "gem", func() -> void: ui.revive_token_requested.emit())
	_revive = _offer("SECOND CHANCE", "pink", "film", func() -> void: ui.revive_requested.emit())
	_double = _offer("DOUBLE SHARDS", "gold", "film", func() -> void: ui.double_shards_requested.emit())
	_actions = UiKit.hbox(14)
	_column.add_child(_actions)
	var home := UiKit.icon_button("home", "light", 96)
	home.pressed.connect(ui.home_requested.emit)
	_actions.add_child(home)
	var retry := UiKit.button("RETRY", "primary", Vector2(0, 96), 48, "retry")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(ui.restart_requested.emit)
	_actions.add_child(retry)
	_sections = [_title, _score, _best_row, _card, _offers, _actions]


## `summary` keys: title, score, best, new_best, metres, gates, shards, can_revive,
## revive_tokens (banked Phoenix gems usable now, 0 if none), can_double, missions (a list of
## {mission, value}), goal ({name, cost, have, upgrade, id for a world}, or {} when nothing is left).
func show_summary(summary: Dictionary) -> void:
	_title.text = summary.title
	_best_label.text = "NEW BEST!" if summary.new_best else "BEST  %s" % UiKit.thousands(summary.best)
	_best.get_theme_stylebox("panel").bg_color = UiKit.GOLD if summary.new_best else Color(0.3, 0.24, 0.5, 0.85)

	for child in _stats.get_children():
		child.queue_free()
	_stat("motion", "%s m" % UiKit.thousands(summary.metres), "DISTANCE")
	_stats.add_child(_divider(true))
	_stat("check", str(summary.gates), "GATES")
	_stats.add_child(_divider(true))
	_shards_value = _stat("shard", "+0", "SHARDS")

	for child in _missions.get_children():
		child.queue_free()
	var entries: Array = summary.get("missions", [])
	for entry: Dictionary in entries:
		_missions.add_child(_mission(entry.mission, int(entry.value)))
	_mission_box.visible = _portrait and not entries.is_empty()

	_goal = (summary.get("goal", {}) as Dictionary).duplicate()
	_shown_shards = int(summary.shards)
	_apply_goal()

	# One second chance on offer at a time: a banked revive comes before the ad.
	var tokens: int = summary.get("revive_tokens", 0)
	_token.visible = tokens > 0
	_token.disabled = false
	UiKit.set_text(_token, "FREE REVIVE  (%d)" % tokens)
	_revive.visible = summary.can_revive and tokens <= 0
	_revive.disabled = false
	_double.visible = summary.can_double
	_double.disabled = false
	_offers.visible = _token.visible or _revive.visible or _double.visible
	_celebrate(summary)


## Shards were doubled after watching an ad.
func show_doubled(total: int) -> void:
	_double.visible = false
	_offers.visible = _token.visible or _revive.visible
	if not _goal.is_empty():
		_goal.have = int(_goal.have) + (total - _shown_shards)
	_shown_shards = total
	_shards_value.text = "+%s" % UiKit.thousands(total)
	_apply_goal()
	_bounce(_shards_value)


func _apply_goal() -> void:
	var affordable := not _goal.is_empty() and int(_goal.have) >= int(_goal.cost)
	var is_upgrade := bool(_goal.get("upgrade", false))
	_goal_ready.visible = affordable
	_goal_box.visible = not _goal.is_empty() and not affordable
	if not affordable:
		if not _goal.is_empty():
			_goal_bar.value = clampf(float(_goal.have) / maxf(float(_goal.cost), 1.0), 0.0, 1.0)
			_goal_label.text = "%s more shards for  %s" % [
				UiKit.thousands(int(_goal.cost) - int(_goal.have)), _goal.name]
		return
	UiKit.set_text(_goal_ready, ("UPGRADE READY:  %s" % _goal.name) if is_upgrade else ("UNLOCK %s" % _goal.name))


func _on_goal_pressed() -> void:
	if bool(_goal.get("upgrade", false)):
		ui.open_upgrades()
	else:
		ui.goal_unlock_requested.emit(str(_goal.get("id", "")))


func hide_revive() -> void:
	_revive.visible = false
	_token.visible = false
	_offers.visible = _double.visible


func handle_back() -> bool:
	ui.home_requested.emit()
	return true


func layout(portrait: bool) -> void:
	_portrait = portrait
	if not _column:
		return
	_column.custom_minimum_size.x = minf(card_width(portrait), 580.0) if portrait else card_width(false, 1080.0)
	_mission_box.visible = portrait and _missions.get_child_count() > 0
	if portrait:
		_adopt(_column, [_title, _score, _best_row, _card, _offers, _actions])
		_adopt(_inner, [_stats, _mission_box, _goal_box, _goal_ready])
		if _split.get_parent() == _card:
			_card.remove_child(_split)
		if _inner.get_parent() != _card:
			_card.add_child(_inner)
	else:
		_adopt(_column, [_title, _card, _offers, _actions])
		_adopt(_left, [_score, _best_row, _stats])
		_adopt(_right, [_goal_box, _goal_ready])
		if _inner.get_parent() == _card:
			_card.remove_child(_inner)
		if _split.get_parent() != _card:
			_card.add_child(_split)
	_apply_goal()


func _adopt(parent: Node, nodes: Array) -> void:
	for node: Node in nodes:
		if node.get_parent() != parent:
			node.reparent(parent)
	for i in nodes.size():
		parent.move_child(nodes[i], i)


## The sections arrive one after another, the numbers count up and the rings fill.
func _celebrate(summary: Dictionary) -> void:
	for i in _sections.size():
		var section := _sections[i]
		if section.get_parent() != _column:
			section.modulate.a = 1.0
			continue
		section.modulate.a = 0.0
		section.create_tween().tween_property(section, "modulate:a", 1.0, 0.22).set_delay(0.05 + i * 0.07)
	var count := create_tween().set_parallel()
	count.tween_method(func(v: float) -> void: _score.text = UiKit.thousands(int(v)), 0.0, float(summary.score), 0.7)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	count.tween_method(func(v: float) -> void: _shards_value.text = "+%s" % UiKit.thousands(int(v)),
		0.0, float(summary.shards), 0.7).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for ring in _missions.find_children("*", "MissionBadge", true, false):
		var badge := ring as MissionBadge
		var target := badge.progress
		badge.progress = 0.0
		badge.create_tween().tween_property(badge, "progress", target, 0.6).set_delay(0.45)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if summary.new_best:
		_bounce(_best, 3)


func _bounce(control: Control, times := 1) -> void:
	control.pivot_offset = control.size * 0.5
	var pop := control.create_tween().set_loops(times)
	pop.tween_property(control, "scale", Vector2.ONE * 1.14, 0.16)
	pop.tween_property(control, "scale", Vector2.ONE, 0.16)


## One number with its icon and a small caption. Returns the number's label.
func _stat(icon: String, value: String, caption: String) -> Label:
	var cell := UiKit.vbox(0)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UiKit.hbox(8)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(top)
	var glyph := UiIcon.make(icon, UiKit.GOLD.darkened(0.1) if icon == "shard" else UiKit.STYLES.sky[1], Vector2(26, 26))
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(glyph)
	var number := UiKit.title(value, 36, UiKit.INK, Color(1, 1, 1, 0))
	number.label_settings.shadow_color = Color(0, 0, 0, 0)
	top.add_child(number)
	var label := UiKit.centered(UiKit.text(caption, 17, true, 900))
	label.label_settings.font_color = UiKit.INK_SOFT
	cell.add_child(label)
	_stats.add_child(cell)
	return number


## One mission: its ring, how far along it is (or what it paid), and what it asks for.
func _mission(mission: Dictionary, value: int) -> Control:
	var done := value >= int(mission.target)
	var cell := UiKit.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ring := CenterContainer.new()
	ring.add_child(MissionBadge.make(mission, value, 84.0))
	cell.add_child(ring)
	var count := UiKit.centered(UiKit.text(
		"+%d" % Missions.payout(mission) if done else "%s / %s" % [UiKit.thousands(value), UiKit.thousands(int(mission.target))],
		21, true, 900))
	if done:
		count.label_settings.font_color = UiKit.GOLD.darkened(0.25)
	cell.add_child(count)
	var what := UiKit.centered(UiKit.wrapped(UiKit.text(Missions.brief(mission), 18, true, 700)))
	what.label_settings.font_color = UiKit.INK_SOFT
	cell.add_child(what)
	return cell


func _offer(label: String, style: String, icon: String, action: Callable) -> Button:
	var button := UiKit.button(label, style, Vector2(0, 72), 22, icon)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void:
		button.disabled = true
		action.call())
	_offers.add_child(button)
	return button


## A hairline between groups: across the card, or upright between two numbers.
func _divider(upright := false) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.9, 0.88, 0.96)
	line.custom_minimum_size = Vector2(2, 44) if upright else Vector2(0, 2)
	if upright:
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line
