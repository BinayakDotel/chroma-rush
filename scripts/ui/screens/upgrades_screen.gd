extends UiScreen
## Upgrades: spend shards on longer Overdrive and Magnet, a bigger fuel tank and more power
## gems. Five levels each (see Economy.UPGRADES). Also shows banked revives (Phoenix gems).

var _list: VBoxContainer
var _shards: HBoxContainer
var _tokens: HBoxContainer


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	closes_on_outside_tap = true
	var content := centered_card(600, 24)
	var pill := UiKit.pill(Color(0.1, 0.05, 0.22, 0.85), Vector2(14, 4))
	_shards = UiKit.shard_amount(Profile.shards, 24)
	pill.add_child(_shards)
	content.add_child(header("UPGRADES", pill))
	_list = scroll_list(content)
	# Banked revives (Phoenix gems): a heart, then a gem for each slot, lit when it is filled.
	_tokens = UiKit.hbox(10)
	_tokens.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(_tokens)
	# Method callables (not lambdas) so these disconnect automatically when the overlay closes.
	Profile.shards_changed.connect(_on_shards_changed)
	Profile.upgrades_changed.connect(_rebuild)
	_rebuild()


func _on_shards_changed(total: int) -> void:
	(_shards.get_node("Amount") as Label).text = UiKit.thousands(total)
	_rebuild()


func _rebuild() -> void:
	if not is_instance_valid(_list):
		return
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	fit_scroll.call_deferred(maxf(get_viewport_rect().size.y - 330.0, 260.0))
	for id: String in Economy.UPGRADES:
		_list.add_child(_card(id))
	for child in _tokens.get_children():
		child.queue_free()
	_tokens.add_child(UiIcon.make("heart", UiKit.STYLES.pink[0], Vector2(30, 30)))
	for i in Profile.MAX_REVIVE_TOKENS:
		var lit := i < Profile.revive_tokens
		_tokens.add_child(UiIcon.make("gem", Powers.info(Powers.Kind.PHOENIX).color if lit else Color(0.84, 0.82, 0.92), Vector2(34, 34)))


func _card(id: String) -> Control:
	var spec: Dictionary = Economy.UPGRADES[id]
	var level := Profile.upgrade_level(id)
	var top := Economy.max_level(id)
	var card := UiKit.card(16, UiKit.CARD_TINT, 26)
	(card.get_theme_stylebox("panel") as StyleBoxFlat).shadow_size = 0
	var row := UiKit.hbox(14)
	card.add_child(row)
	var badge := UiKit.pill(UiKit.STYLES.sky[0], Vector2(10, 10))
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(UiIcon.make(spec.icon, Color.WHITE, Vector2(40, 40)))
	row.add_child(badge)
	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UiKit.text(spec.name, 26, true, 900))
	var pips := UiKit.hbox(6)
	for i in top:
		pips.add_child(UiIcon.make("circle", UiKit.STYLES.sky[0] if i < level else Color(0.82, 0.8, 0.9), Vector2(18, 18)))
	var now := UiKit.text("  %s" % Economy.upgrade_label(id, level), 22, true, 900)
	now.label_settings.font_color = UiKit.INK
	pips.add_child(now)
	if level < top:
		var next := UiKit.text("→ %s" % Economy.upgrade_label(id, level + 1), 22, true, 900)
		next.label_settings.font_color = UiKit.STYLES.primary[1]
		pips.add_child(next)
	info.add_child(pips)
	var cost := Economy.upgrade_cost(id, level)
	var buy: Button
	if cost < 0:
		buy = UiKit.button("", "light", Vector2(132, 64), 30, "check")
		buy.disabled = true
	else:
		buy = UiKit.button(UiKit.thousands(cost), "gold", Vector2(132, 64), 24, "shard")
		buy.disabled = Profile.shards < cost
		buy.pressed.connect(func() -> void:
			if Profile.buy_upgrade(id):
				ui.toast("%s  LEVEL %d!" % [spec.name, Profile.upgrade_level(id)], UiKit.GOLD))
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)
	return card


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 640.0)
	fit_scroll.call_deferred(maxf(get_viewport_rect().size.y - 330.0, 260.0))
