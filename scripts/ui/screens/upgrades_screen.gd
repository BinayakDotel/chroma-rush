extends UiScreen
## Upgrades: spend shards on longer Overdrive and Magnet, a bigger fuel tank and more power
## gems. Five levels each (see Economy.UPGRADES). Also shows banked revives (Phoenix gems).

var _list: VBoxContainer
var _shards: HBoxContainer
var _tokens: Label


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
	var bank := UiKit.hbox(10)
	bank.alignment = BoxContainer.ALIGNMENT_CENTER
	bank.add_child(UiIcon.make("gem", Powers.info(Powers.Kind.PHOENIX).color, Vector2(30, 30)))
	_tokens = UiKit.text("", 20, true, 800)
	_tokens.label_settings.font_color = UiKit.INK_SOFT
	bank.add_child(_tokens)
	content.add_child(bank)
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
		child.queue_free()
	for id: String in Economy.UPGRADES:
		_list.add_child(_card(id))
	_tokens.text = "Revives saved: %d of %d  (find Phoenix Gems on the road)" % [
		Profile.revive_tokens, Profile.MAX_REVIVE_TOKENS]


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
	var blurb := UiKit.text(spec.blurb, 17, true, 700)
	blurb.label_settings.font_color = UiKit.INK_SOFT
	info.add_child(blurb)
	var pips := UiKit.hbox(6)
	for i in top:
		pips.add_child(UiIcon.make("circle", UiKit.STYLES.sky[0] if i < level else Color(0.82, 0.8, 0.9), Vector2(16, 16)))
	var now := UiKit.text("  %s" % Economy.upgrade_label(id, level), 17, true, 900)
	now.label_settings.font_color = UiKit.INK
	pips.add_child(now)
	if level < top:
		var next := UiKit.text("→ %s" % Economy.upgrade_label(id, level + 1), 17, true, 900)
		next.label_settings.font_color = UiKit.STYLES.primary[1]
		pips.add_child(next)
	info.add_child(pips)
	var cost := Economy.upgrade_cost(id, level)
	var buy: Button
	if cost < 0:
		buy = UiKit.button("MAX", "light", Vector2(132, 64), 24, "check")
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
	var scroll: Control = find_child("Scroll", true, false)
	if scroll:
		scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 330.0, 260.0, 620.0)
