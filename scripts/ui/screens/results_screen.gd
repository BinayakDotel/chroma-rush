extends UiScreen
## End of a run: score, best, stats and shards earned, how the missions stand and what the
## shards are building towards, with an optional second chance (a banked Phoenix gem, or a
## rewarded ad) and double-shards offer, then RETRY or HOME.

var _title: Label
var _score: Label
var _best: PanelContainer
var _best_label: Label
var _stats: GridContainer
var _missions: VBoxContainer
var _goal: PanelContainer
var _goal_label: Label
var _goal_bar: ProgressBar
var _revive: Button
var _token: Button
var _double: Button
var _content: VBoxContainer
var _summary := {}


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.35)
	_content = centered_card(560, 28)
	_title = UiKit.centered(UiKit.title("CRASHED!", 64, UiKit.STYLES.pink[0]))
	_content.add_child(_title)
	_score = UiKit.centered(UiKit.title("0", 96, Color.WHITE))
	_content.add_child(_score)
	var best_row := CenterContainer.new()
	_content.add_child(best_row)
	_best = UiKit.pill(UiKit.GOLD, Vector2(22, 6))
	_best_label = UiKit.title("NEW BEST!", 30, Color.WHITE, Color(0.55, 0.3, 0.05))
	_best.add_child(_best_label)
	best_row.add_child(_best)
	_stats = GridContainer.new()
	_stats.columns = 2
	_stats.add_theme_constant_override("h_separation", 14)
	_stats.add_theme_constant_override("v_separation", 10)
	_content.add_child(_stats)
	_missions = UiKit.vbox(8)
	_content.add_child(_missions)
	# What the shards are for: progress towards the next upgrade or world.
	_goal = UiKit.card(12, Color(1.0, 0.95, 0.78), 22)
	(_goal.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	var goal_box := UiKit.vbox(6)
	_goal.add_child(goal_box)
	_goal_label = UiKit.centered(UiKit.text("", 17, true, 900))
	goal_box.add_child(_goal_label)
	_goal_bar = UiKit.bar(0, 12, UiKit.GOLD, Color(0.9, 0.82, 0.6))
	(_goal_bar.get_theme_stylebox("background") as StyleBoxFlat).set_border_width_all(0)
	goal_box.add_child(_goal_bar)
	_content.add_child(_goal)

	_token = UiKit.button("REVIVE", "sky", Vector2(0, 76), 32, "gem")
	_token.pressed.connect(func() -> void:
		_token.disabled = true
		ui.revive_token_requested.emit())
	_content.add_child(_token)
	_revive = UiKit.button("SECOND CHANCE", "pink", Vector2(0, 76), 32, "film")
	_revive.pressed.connect(func() -> void:
		_revive.disabled = true
		ui.revive_requested.emit())
	_content.add_child(_revive)
	_double = UiKit.button("DOUBLE SHARDS", "gold", Vector2(0, 68), 28, "film")
	_double.pressed.connect(func() -> void:
		_double.disabled = true
		ui.double_shards_requested.emit())
	_content.add_child(_double)
	var row := UiKit.hbox(14)
	_content.add_child(row)
	var home := UiKit.icon_button("home", "light", 92)
	home.pressed.connect(ui.home_requested.emit)
	row.add_child(home)
	var retry := UiKit.button("RETRY", "primary", Vector2(0, 92), 46, "retry")
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry.pressed.connect(ui.restart_requested.emit)
	row.add_child(retry)


## `summary` keys: title, score, best, new_best, metres, gates, combo, shards, can_revive,
## revive_tokens (banked Phoenix gems usable now, 0 if none), can_double, missions (a list of
## {mission, value}), goal ({name, cost, have}, or {} when there is nothing left to buy).
func show_summary(summary: Dictionary) -> void:
	_summary = summary
	_title.text = summary.title
	_score.text = UiKit.thousands(summary.score)
	_best_label.text = "NEW BEST!" if summary.new_best else "BEST  %s" % UiKit.thousands(summary.best)
	_best.get_theme_stylebox("panel").bg_color = UiKit.GOLD if summary.new_best else Color(0.55, 0.5, 0.75)
	for child in _stats.get_children():
		child.queue_free()
	_stat("motion", "%s m" % UiKit.thousands(summary.metres), "DISTANCE")
	_stat("check", str(summary.gates), "GATES")
	_stat("star", "x%d" % summary.combo, "BEST COMBO")
	_stat("shard", "+%s" % UiKit.thousands(summary.shards), "SHARDS")
	for child in _missions.get_children():
		child.queue_free()
	for entry: Dictionary in summary.get("missions", []):
		_missions.add_child(UiKit.mission_row(entry.mission, int(entry.value)))
	var goal: Dictionary = summary.get("goal", {})
	_goal.visible = not goal.is_empty()
	if not goal.is_empty():
		var have := int(goal.have)
		var cost := int(goal.cost)
		_goal_bar.value = clampf(float(have) / maxf(cost, 1.0), 0.0, 1.0)
		if have >= cost:
			_goal_label.text = "YOU CAN AFFORD  %s!" % goal.name
			_goal_label.label_settings.font_color = UiKit.STYLES.primary[1]
		else:
			_goal_label.text = "%s MORE SHARDS FOR  %s" % [UiKit.thousands(cost - have), goal.name]
			_goal_label.label_settings.font_color = Color(0.5, 0.32, 0.05)
	var tokens: int = summary.get("revive_tokens", 0)
	_token.visible = tokens > 0
	_token.disabled = false
	UiKit.set_text(_token, "FREE REVIVE  (%d)" % tokens)
	_revive.visible = summary.can_revive
	_revive.disabled = false
	_double.visible = summary.can_double
	_double.disabled = false
	# Count the score up for a little celebration.
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _score.text = UiKit.thousands(int(v)), 0.0, float(summary.score), 0.6)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if summary.new_best:
		_best.pivot_offset = _best.size * 0.5
		var pop := create_tween().set_loops(3)
		pop.tween_property(_best, "scale", Vector2.ONE * 1.12, 0.18)
		pop.tween_property(_best, "scale", Vector2.ONE, 0.18)


## Shards were doubled after watching an ad.
func show_doubled(total: int) -> void:
	_double.visible = false
	for child in _stats.get_children():
		if child.has_meta("shards"):
			(child.get_meta("shards") as Label).text = "+%s" % UiKit.thousands(total)


func hide_revive() -> void:
	_revive.visible = false
	_token.visible = false


func _stat(icon: String, value: String, caption: String) -> void:
	var chip := UiKit.card(12, UiKit.CARD_TINT, 22)
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box: StyleBoxFlat = chip.get_theme_stylebox("panel")
	box.shadow_size = 0
	var row := UiKit.hbox(10)
	chip.add_child(row)
	row.add_child(UiIcon.make(icon, UiKit.GOLD.darkened(0.1) if icon == "shard" else UiKit.INK_SOFT, Vector2(30, 30)))
	var col := UiKit.vbox(-4)
	row.add_child(col)
	var number := UiKit.text(value, 28, true, 900)
	col.add_child(number)
	var label := UiKit.text(caption, 15, true, 800)
	label.label_settings.font_color = UiKit.INK_SOFT
	col.add_child(label)
	if icon == "shard":
		chip.set_meta("shards", number)
	_stats.add_child(chip)


func handle_back() -> bool:
	ui.home_requested.emit()
	return true


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 580.0)
	# A short screen has no room for the mission list; the missions screen still has it.
	if _missions:
		_missions.visible = portrait and get_viewport_rect().size.y >= 1400.0
