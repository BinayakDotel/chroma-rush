extends SceneTree
## Fills publish/listing.md from publish/listing.template.md.
##   godot --headless --path . -s res://scripts/dev/write_listing.gd
## Keyboard lines come from the project's InputMap. Touch lines come from HowToScreen.
## Pause is P, matching the KEY_P check in scripts/game.gd.

const TEMPLATE := "res://publish/listing.template.md"
const OUT := "res://publish/listing.md"
const ORIENTATION := "Portrait on a phone; the layout also adapts when the window is landscape."
const _ACTIONS := ["move_left", "move_right", "jump", "slam", "color_1", "color_2", "color_3", "color_next", "prism"]


func _initialize() -> void:
	var how_to: GDScript = load("res://scripts/ui/screens/howto_screen.gd")
	var touch: Dictionary = how_to.TOUCH_CONTROLS
	var text := FileAccess.get_file_as_string(TEMPLATE)
	text = text.replace("{{controls}}", _controls(touch))
	text = text.replace("{{orientation}}", ORIENTATION)
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(text)
	print("Wrote publish/listing.md")
	quit()


func _controls(touch: Dictionary) -> String:
	var keys := {}
	for action in _ACTIONS:
		keys[action] = _keys(action)
	var lines: PackedStringArray = [
		"Keyboard:",
		"",
		"- %s or %s: change lane" % [keys.move_left, keys.move_right],
		"- %s: jump" % keys.jump,
		"- %s: slam down while in the air" % keys.slam,
		"- %s, %s or %s: pick red, yellow or blue (%s cycles through the colours)" % [keys.color_1, keys.color_2, keys.color_3, keys.color_next],
		"- %s: Prism Overdrive when the meter is full" % keys.prism,
		"- P: pause",
		"",
		"Touch (phones and tablets):",
		"",
		"- %s: change lane" % touch.lane,
		"- %s" % touch.jump,
		"- %s: pick that colour" % touch.colour,
		"- %s: Prism Overdrive when the meter is full" % touch.prism,
	]
	return "\n".join(lines)


func _keys(action: String) -> String:
	var names: PackedStringArray = []
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			names.append(_key_name(event))
	return " / ".join(names)


func _key_name(event: InputEventKey) -> String:
	var code := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match code:
		KEY_LEFT:
			return "Left arrow"
		KEY_RIGHT:
			return "Right arrow"
		KEY_UP:
			return "Up arrow"
		KEY_DOWN:
			return "Down arrow"
		KEY_SHIFT:
			return "Shift"
		KEY_SPACE:
			return "Space"
		_:
			return OS.get_keycode_string(code)
