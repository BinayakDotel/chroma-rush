extends UiScreen
## Shop: one-time purchases (Supporter Pack, World Pass, No Ads) and shard packs when enabled.
## Every product is cosmetic or convenience; nothing changes how hard a run is.

const PERKS := {
	"supporter_pack": [["film", "No ads between runs"], ["star", "Every world, now and future"], ["shard", "Double shards forever"]],
	"world_pass": [["star", "Unlock all 5 worlds instantly"], ["check", "Includes future worlds"]],
	"no_ads": [["film", "No ads between runs"], ["check", "Rewarded ads stay optional"]],
	"shards_small": [["shard", "1,000 shards"]],
	"shards_large": [["shard", "6,000 shards"]],
}

var _list: VBoxContainer
var _shards: HBoxContainer


func _is_modal() -> bool:
	return true


func build() -> void:
	dim(0.55)
	closes_on_outside_tap = true
	var content := centered_card(600, 24)
	var pill := UiKit.pill(Color(0.1, 0.05, 0.22, 0.85), Vector2(14, 4))
	_shards = UiKit.shard_amount(Profile.shards, 24)
	pill.add_child(_shards)
	content.add_child(header("SHOP", pill))
	_list = scroll_list(content, 14)
	var restore := UiKit.button("RESTORE PURCHASES", "light", Vector2(0, 56), 22, "restore")
	restore.pressed.connect(Store.restore)
	restore.disabled = not Store.is_available()
	content.add_child(restore)
	# Method callables (not lambdas) so these disconnect automatically when the overlay closes.
	Store.products_updated.connect(_rebuild)
	Store.purchase_finished.connect(_on_purchase_finished)
	Profile.entitlements_changed.connect(_rebuild)
	Profile.shards_changed.connect(_on_shards_changed)
	_rebuild()


func _on_purchase_finished(_id: String, _ok: bool, _message: String) -> void:
	_rebuild()


func _on_shards_changed(total: int) -> void:
	(_shards.get_node("Amount") as Label).text = UiKit.thousands(total)


func _rebuild() -> void:
	if not is_instance_valid(_list):
		return
	for child in _list.get_children():
		child.queue_free()
	if not Store.is_available():
		var note := UiKit.wrapped(UiKit.centered(UiKit.text(
			"The store isn't available right now. Check your connection and try again.", 22, true, 700)))
		_list.add_child(note)
		return
	for id in Store.live_products():
		_list.add_child(_product_card(id))


func _product_card(id: String) -> Control:
	var product: Dictionary = Store.PRODUCTS[id]
	var featured := id == "supporter_pack"
	var card := UiKit.card(18, Color(1.0, 0.94, 0.97) if featured else UiKit.CARD_TINT, 26)
	var box: StyleBoxFlat = card.get_theme_stylebox("panel")
	box.shadow_size = 0
	if featured:
		box.set_border_width_all(4)
		box.border_color = UiKit.STYLES.pink[0]
	var row := UiKit.hbox(14)
	card.add_child(row)
	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var title_row := UiKit.hbox(10)
	info.add_child(title_row)
	title_row.add_child(UiKit.text(product.title, 28, true, 900))
	if featured:
		var badge := UiKit.pill(UiKit.STYLES.pink[0], Vector2(10, 2))
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		badge.add_child(UiKit.text("BEST VALUE", 14, false, 900))
		title_row.add_child(badge)
	for perk: Array in PERKS.get(id, []):
		var line := UiKit.hbox(8)
		line.add_child(UiIcon.make(perk[0], UiKit.INK_SOFT, Vector2(20, 20)))
		var label := UiKit.text(perk[1], 18, true, 700)
		label.label_settings.font_color = UiKit.INK_SOFT
		line.add_child(label)
		info.add_child(line)
	if Store.is_owned(id):
		var owned := UiKit.button("OWNED", "light", Vector2(150, 64), 24, "check")
		owned.disabled = true
		owned.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(owned)
	else:
		var buy := UiKit.button(Store.price(id), "pink" if featured else "gold", Vector2(150, 70), 28)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.disabled = Store.is_busy()
		buy.pressed.connect(func() -> void:
			buy.disabled = true
			Store.purchase(id))
		row.add_child(buy)
	return card


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 640.0)
	var scroll: Control = find_child("Scroll", true, false)
	if scroll:
		scroll.custom_minimum_size.y = clampf(get_viewport_rect().size.y - 330.0, 260.0, 760.0)
