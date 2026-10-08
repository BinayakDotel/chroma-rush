class_name UiRoot
extends CanvasLayer
## Owns every screen and the navigation between them. One base screen is shown at a time
## (home, in-run HUD or results); overlays (pause, settings, shop, how to play, dialogs) stack
## on top and close in reverse order. The Android back button and Escape close the top overlay,
## or ask the base screen what to do.
##
## The game talks to the UI through the show_* methods and `hud`; the UI reports player intent
## through the signals below.

signal play_requested
signal world_browsed(step: int)
signal unlock_requested
signal pause_requested
signal resume_requested
signal restart_requested
signal home_requested
signal color_pressed(index: int)
signal prism_pressed
signal revive_requested
## Second chance paid with a banked Phoenix gem instead of an ad.
signal revive_token_requested
signal double_shards_requested
signal quit_requested
## Fired when the splash tween ends, or at once when there is no splash to play.
signal intro_finished

const HomeScreen = preload("res://scripts/ui/screens/home_screen.gd")
const HudScreen = preload("res://scripts/ui/screens/hud_screen.gd")
const PauseScreen = preload("res://scripts/ui/screens/pause_screen.gd")
const ResultsScreen = preload("res://scripts/ui/screens/results_screen.gd")
const SettingsScreen = preload("res://scripts/ui/screens/settings_screen.gd")
const ShopScreen = preload("res://scripts/ui/screens/shop_screen.gd")
const UpgradesScreen = preload("res://scripts/ui/screens/upgrades_screen.gd")
const MissionsScreen = preload("res://scripts/ui/screens/missions_screen.gd")
const HowToScreen = preload("res://scripts/ui/screens/howto_screen.gd")
const DialogScreen = preload("res://scripts/ui/screens/dialog_screen.gd")
## The boot splash (see project.godot) and the colour behind it, repeated here so the game can
## open by lifting that same picture away instead of cutting to the home screen.
const SPLASH_PATH := "res://icons/splash.png"
const SPLASH_COLOR := Color(0.525, 0.314, 0.941)

var home: UiScreen
var hud: UiScreen
var results: UiScreen
var portrait := false

var _root := Control.new()
var _base: UiScreen
var _overlays: Array[UiScreen] = []
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _fps: Label
var intro_done := false
var start_prompt: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	UiKit.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	home = _make(HomeScreen)
	hud = _make(HudScreen)
	results = _make(ResultsScreen)
	_build_toast()
	_fps = UiKit.text("", 18, false, 700)
	_fps.position = Vector2(12, 4)
	_fps.visible = Settings.show_fps
	add_child(_fps)
	Settings.changed.connect(_on_setting_changed)
	Store.purchase_finished.connect(func(_id: String, ok: bool, message: String) -> void:
		toast(message, Color(0.6, 1.0, 0.65) if ok else Color(1.0, 0.7, 0.6)))
	Store.restore_finished.connect(func(_ok: bool, message: String) -> void: toast(message))
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	if not DevMode.active() or "--intro" in OS.get_cmdline_user_args():
		_play_intro()
	else:
		_finish_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and handle_back():
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# Android back button / gesture.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_back()


func _process(_delta: float) -> void:
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


## Opening: the first frame looks exactly like the boot splash (the same picture, filling the
## screen the same way), then it swells a little and fades to show the home screen.
func _play_intro() -> void:
	if not ResourceLoader.exists(SPLASH_PATH):
		_finish_intro()
		return
	var cover := ColorRect.new()
	cover.color = SPLASH_COLOR
	UiKit.full_rect(cover)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(cover)
	var logo := TextureRect.new()
	logo.texture = load(SPLASH_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UiKit.full_rect(logo)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(logo)
	await get_tree().process_frame
	logo.pivot_offset = logo.size * 0.5
	var lift := cover.create_tween()
	lift.tween_interval(0.35)
	lift.tween_property(logo, "scale", Vector2.ONE * 1.08, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	lift.parallel().tween_property(cover, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	lift.tween_callback(func() -> void:
		cover.queue_free()
		_finish_intro())


func _finish_intro() -> void:
	if intro_done:
		return
	intro_done = true
	intro_finished.emit()


## One centred line over the road. The game shows it when a new profile may start.
func show_start_prompt(message: String) -> void:
	if start_prompt == null:
		start_prompt = UiKit.centered(UiKit.text("", 36))
		UiKit.full_rect(start_prompt)
		start_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(start_prompt)
	start_prompt.text = message
	start_prompt.visible = true


func hide_start_prompt() -> void:
	if start_prompt:
		start_prompt.visible = false


func show_home(world: Dictionary, index: int, count: int) -> void:
	_close_all_overlays()
	_set_base(home)
	home.call("show_world", world, index, count)


func refresh_home(world: Dictionary, index: int, count: int) -> void:
	home.call("show_world", world, index, count)


func show_hud() -> void:
	_close_all_overlays()
	_set_base(hud)


func show_results(summary: Dictionary) -> void:
	_close_all_overlays()
	_set_base(results)
	results.call("show_summary", summary)


func show_pause() -> void:
	open_overlay(PauseScreen)


func open_settings() -> void:
	open_overlay(SettingsScreen)


func open_shop() -> void:
	open_overlay(ShopScreen)


func open_upgrades() -> void:
	open_overlay(UpgradesScreen)


func open_missions() -> void:
	open_overlay(MissionsScreen)


## How to play. With `then_play`, its last button starts a run (first-time players).
func open_howto(then_play := false) -> void:
	var screen := open_overlay(HowToScreen)
	screen.call("configure", then_play)


## Modal confirmation. `on_confirm` runs only if the player confirms.
func confirm(title: String, message: String, confirm_text: String, on_confirm: Callable, danger := false) -> void:
	var screen := open_overlay(DialogScreen)
	screen.call("configure", title, message, confirm_text, on_confirm, danger)


func open_overlay(script: Script) -> UiScreen:
	var screen := _make(script)
	_overlays.append(screen)
	screen.appear()
	return screen


func close_overlay(screen: UiScreen) -> void:
	if not screen in _overlays:
		return
	_overlays.erase(screen)
	screen.disappear(true)
	if _overlays.is_empty() and _base:
		_base.on_uncovered()


func top_overlay() -> UiScreen:
	return null if _overlays.is_empty() else _overlays.back()


func has_overlay() -> bool:
	return not _overlays.is_empty()


## Back button / Escape. Returns true when the UI handled it.
func handle_back() -> bool:
	var top := top_overlay()
	if top:
		if not top.handle_back():
			close_overlay(top)
		return true
	return _base != null and _base.handle_back()


## Short message in a pill near the top of the screen.
func toast(text: String, color := Color.WHITE) -> void:
	if text.is_empty():
		return
	_toast_label.text = text
	_toast_label.label_settings.font_color = color
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)


## True when a touch at `pos` lands on a button, so the game should not treat it as a swipe.
func is_over_button(pos: Vector2) -> bool:
	for button in _root.find_children("*", "BaseButton", true, false):
		var b := button as BaseButton
		if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(pos):
			return true
	return false


func _make(script: Script) -> UiScreen:
	var screen: UiScreen = script.new()
	screen.ui = self
	UiKit.full_rect(screen)
	screen.visible = false
	_root.add_child(screen)
	screen.build()
	screen.layout(portrait)
	return screen


func _set_base(screen: UiScreen) -> void:
	if _base == screen:
		screen.on_uncovered()
		return
	if _base:
		_base.disappear(false)
	_base = screen
	screen.appear()
	_root.move_child(screen, 0)


func _close_all_overlays() -> void:
	for screen in _overlays.duplicate():
		close_overlay(screen)


func _build_toast() -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	holder.offset_top = 120
	holder.offset_bottom = 180
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_toast = UiKit.pill(Color(0.1, 0.05, 0.22, 0.85), Vector2(24, 10))
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_toast)
	_toast_label = UiKit.text("", 24, false, 800)
	_toast_label.label_settings.outline_size = 0
	_toast.add_child(_toast_label)


## Keeps every screen inside the display's safe area (notches, rounded corners, home bar) and
## tells screens whether the layout is portrait or landscape.
func _relayout() -> void:
	var visible_size := _root.get_viewport_rect().size
	portrait = visible_size.x < visible_size.y
	var insets := _safe_insets(visible_size)
	_root.offset_left = insets.position.x
	_root.offset_top = insets.position.y
	_root.offset_right = -insets.size.x
	_root.offset_bottom = -insets.size.y
	for child in _root.get_children():
		if child is UiScreen:
			(child as UiScreen).layout(portrait)


## Safe-area insets in canvas units: position = left/top, size = right/bottom.
func _safe_insets(canvas_size: Vector2) -> Rect2:
	if not OS.has_feature("mobile"):
		return Rect2()
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return Rect2()
	var k := canvas_size / Vector2(screen)
	return Rect2(Vector2(safe.position) * k,
		(Vector2(screen) - Vector2(safe.position) - Vector2(safe.size)) * k)


func _on_setting_changed(key: StringName) -> void:
	if key == &"show_fps":
		_fps.visible = Settings.show_fps
