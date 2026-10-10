extends UiScreen
## Once-a-day gift card. The gift is granted when the card opens.


func _is_modal() -> bool:
	return true


func build() -> void:
	var grant := Profile.claim_daily()
	dim(0.55)
	closes_on_outside_tap = true
	var content := centered_card(480, 28)
	content.add_child(UiKit.centered(UiKit.title(str(grant.get("day", "")), 40, UiKit.INK_SOFT, Color(1, 1, 1, 0))))
	content.add_child(UiKit.centered(UiKit.title(str(grant.get("gift", "")), 52, UiKit.INK, Color(1, 1, 1, 0))))
	var tomorrow := UiKit.centered(UiKit.text(str(grant.get("tomorrow", "")), 22, true, 700))
	tomorrow.label_settings.font_color = UiKit.INK_SOFT
	content.add_child(tomorrow)
	var nice := UiKit.button("NICE", "primary", Vector2(0, 76), 32)
	nice.pressed.connect(close)
	content.add_child(nice)


func layout(portrait: bool) -> void:
	var card: Control = find_child("Card", true, false)
	if card:
		card.custom_minimum_size.x = minf(card_width(portrait), 480.0)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		get_viewport().set_input_as_handled()
		close()
