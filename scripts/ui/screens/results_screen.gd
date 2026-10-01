extends UiScreen
## End of a run, laid out like a scoreboard and told in symbols and numbers, not words. A badge
## shows how the run ended (a crash or an empty tank); the score is the hero, straight on the
## dimmed scene, with the best score under it. One card holds the rest: distance, gates and
## shards as three numbers; the missions as progress rings (tap them for the details); and how
## close the shards are to the next upgrade or world. Then at most one row of offers (a second
## chance, double shards) and the retry button.

var _cause: UiIcon
var _score: Label
var _best: PanelContainer
var _best_icon: UiIcon
var _best_label: Label
var _column: VBoxContainer
var _stats: HBoxContainer
var _shards_value: Label
var _mission_box: VBoxContainer
var _missions: HBoxContainer
var _goal_box: VBoxContainer
var _goal_icon: UiIcon
var _goal_label: Label
var _goal_bar: ProgressBar
var _goal_ready: Button
var _offers: HBoxContainer
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

	var cause_row := CenterContainer.new()
	_column.add_child(cause_row)
	var cause_badge := UiKit.pill(UiKit.STYLES.pink[0], Vector2(18, 18))
	_cause = UiIcon.make("burst", Color.WHITE, Vector2(52, 52))
	cause_badge.add_child(_cause)
	cause_row.add_child(cause_badge)
	_score = UiKit.centered(UiKit.title("0", 128, Color.WHITE))
	_column.add_child(_score)
	var best_row := CenterContainer.new()
	_column.add_child(best_row)
	_best = UiKit.pill(UiKit.GOLD, Vector2(20, 6))
	var best_content := UiKit.hbox(8)
	_best.add_child(best_content)
	_best_icon = UiIcon.make("trophy", Color.WHITE, Vector2(30, 30))
	_best_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	best_content.add_child(_best_icon)
	_best_label = UiKit.title("0", 30, Color.WHITE, Color(0.55, 0.3, 0.05))
	best_content.add_child(_best_label)
	best_row.add_child(_best)

	var card := UiKit.card(22, UiKit.CARD, 32)
	_column.add_child(card)
	var inner := UiKit.vbox(16)
	card.add_child(inner)
	_stats = UiKit.hbox(0)
	inner.add_child(_stats)
	_mission_box = UiKit.vbox(14)
	inner.add_child(_mission_box)
	_mission_box.add_child(_divider())
	_missions = UiKit.hbox(8)
	_mission_box.add_child(_missions)
	# The rings carry no description, so a tap on them opens the missions screen.
	_mission_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_mission_box.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			Sfx.click()
			ui.open_missions())
	# What the shards are for: progress towards the next upgrade or world, or a button straight
	# to the upgrades once one can be afforded.
	_goal_box = UiKit.vbox(10)
	inner.add_child(_goal_box)
	_goal_box.add_child(_divider())
	var goal_row := UiKit.hbox(12)
	_goal_box.add_child(goal_row)
	_goal_icon = UiIcon.make("upgrade", UiKit.STYLES.sky[1], Vector2(30, 30))
	_goal_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_row.add_child(_goal_icon)
	_goal_bar = UiKit.bar(0, 14, UiKit.GOLD, Color(0.9, 0.88, 0.96))
	(_goal_bar.get_theme_stylebox("background") as StyleBoxFlat).set_border_width_all(0)
	_goal_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	goal_row.add_child(_goal_bar)
	var goal_count := UiKit.shard_amount(0, 22, true)
	_goal_label = goal_count.get_node("Amount")
	goal_row.add_child(goal_count)
	_goal_ready = UiKit.button("!", "gold", Vector2(0, 66), 34, ["upgrade", "bolt"])
	_goal_ready.pressed.connect(func() -> void: ui.open_upgrades())
	inner.add_child(_goal_ready)

	_offers = UiKit.hbox(12)
	_column.add_child(_offers)
	_token = _offer("sky", ["gem", "heart"], func() -> void: ui.revive_token_requested.emit())
	_revive = _offer("pink", ["film", "heart"], func() -> void: ui.revive_requested.emit())
	_double = _offer("gold", ["film", "shard"], func() -> void: ui.double_shards_requested.emit())
	UiKit.set_text(_double, "x2")
	var row := UiKit.hbox(14)
	_column.add_child(row)
	var home := UiKit.icon_button("home", "light", 100)
	home.pressed.connect(ui.home_requested.emit)
	row.add_child(home)
	var retry := UiKit.button("", "primary", Vector2(0, 100), 60, "retry")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(ui.restart_requested.emit)
	row.add_child(retry)
	_sections = [cause_row, _score, best_row, card, _offers, row]


## `summary` keys: cause (icon for how the run ended), score, best, new_best, metres, gates,
## shards, can_revive, revive_tokens (banked Phoenix gems usable now, 0 if none), can_double,
## missions (a list of {mission, value}), goal ({name, cost, have, icon, upgrade}, or {} when
## there is nothing left to buy).
func show_summary(summary: Dictionary) -> void:
	_cause.set_icon(summary.get("cause", "burst"), Color.WHITE)
	# The best score, in gold with a star when this run set it.
	_best_icon.set_icon("star" if summary.new_best else "trophy", Color.WHITE)
	_best_label.text = UiKit.thousands(maxi(summary.best, summary.score))
	_best.get_theme_stylebox("panel").bg_color = UiKit.GOLD if summary.new_best else Color(0.3, 0.24, 0.5, 0.85)

	for child in _stats.get_children():
		child.queue_free()
	_stat("motion", "%s m" % UiKit.thousands(summary.metres))
	_stats.add_child(_divider(true))
	_stat("check", str(summary.gates))
	_stats.add_child(_divider(true))
	_shards_value = _stat("shard", "+0")

	for child in _missions.get_children():
		child.queue_free()
	var entries: Array = summary.get("missions", [])
	for entry: Dictionary in entries:
		_missions.add_child(_mission(entry.mission, int(entry.value)))
	_mission_box.visible = _portrait and not entries.is_empty()

	var goal: Dictionary = summary.get("goal", {})
	var affordable := not goal.is_empty() and int(goal.have) >= int(goal.cost)
	_goal_ready.visible = _portrait and affordable and bool(goal.get("upgrade", false))
	_goal_box.visible = _portrait and not goal.is_empty() and not _goal_ready.visible
	if not goal.is_empty():
		(_goal_ready.get_meta("icons")[1] as UiIcon).set_icon(str(goal.icon))
		_goal_icon.set_icon(str(goal.icon), UiKit.STYLES.sky[1])
		_goal_bar.value = clampf(float(goal.have) / maxf(float(goal.cost), 1.0), 0.0, 1.0)
		_goal_label.text = "%s / %s" % [UiKit.thousands(mini(int(goal.have), int(goal.cost))), UiKit.thousands(int(goal.cost))]

	# One second chance on offer at a time: a banked revive comes before the ad.
	var tokens: int = summary.get("revive_tokens", 0)
	_token.visible = tokens > 0
	_token.disabled = false
	UiKit.set_text(_token, str(tokens))
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
	_shards_value.text = "+%s" % UiKit.thousands(total)
	_bounce(_shards_value)


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
	_column.custom_minimum_size.x = minf(card_width(portrait), 580.0)
	# A wide, short screen keeps to the score, the three numbers and the buttons.
	if not portrait:
		_mission_box.visible = false
		_goal_box.visible = false
		_goal_ready.visible = false


## The sections arrive one after another, the numbers count up and the rings fill.
func _celebrate(summary: Dictionary) -> void:
	for i in _sections.size():
		var section := _sections[i]
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


## One number with its icon. Returns the number's label.
func _stat(icon: String, value: String) -> Label:
	var cell := UiKit.hbox(10)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.alignment = BoxContainer.ALIGNMENT_CENTER
	var glyph := UiIcon.make(icon, UiKit.GOLD.darkened(0.1) if icon == "shard" else UiKit.STYLES.sky[1], Vector2(30, 30))
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(glyph)
	var number := UiKit.title(value, 40, UiKit.INK, Color(1, 1, 1, 0))
	number.label_settings.shadow_color = Color(0, 0, 0, 0)
	cell.add_child(number)
	_stats.add_child(cell)
	return number


## One mission: its ring and how far along it is, or what it paid.
func _mission(mission: Dictionary, value: int) -> Control:
	var done := value >= int(mission.target)
	var cell := UiKit.vbox(4)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := CenterContainer.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.add_child(MissionBadge.make(mission, value, 88.0))
	cell.add_child(ring)
	var count: Control
	if done:
		count = UiKit.shard_amount(Missions.payout(mission), 22, true)
		(count.get_node("Amount") as Label).text = "+%d" % Missions.payout(mission)
	else:
		count = UiKit.centered(UiKit.text("%s / %s" % [UiKit.thousands(value), UiKit.thousands(int(mission.target))], 22, true, 900))
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(count)
	return cell


func _offer(style: String, icons: Array, action: Callable) -> Button:
	var button := UiKit.button("", style, Vector2(0, 76), 34, icons)
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
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if upright:
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line
