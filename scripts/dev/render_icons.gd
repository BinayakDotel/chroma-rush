extends SceneTree
## Renders the game's brand art from the game itself, so the icon, the splash and the logo all
## show the real vehicle and driver:
##   icons/mascot.png            the fox in its kart on a clear background (used by the logo)
##   icons/icon_1024.png, _512   app icon: the mascot racing out of a three-colour trail
##   icons/android_*.png         Android launcher icons (legacy, adaptive foreground/background)
##   icons/splash.png            full-screen splash: the icon's sky, trail and kart under the logo
## It draws with the GPU, so it needs a window:
##   godot --path . -s res://scripts/dev/render_icons.gd
## then `godot --headless --path . --import` so the new images are picked up.

const OUT := "res://icons/"
const SKY_TOP := Color("3526C9")
## The splash is tall, so its sky starts a little warmer than the icon's: less blue at the top.
const SPLASH_TOP := Color("5330D8")
const SPLASH_SIZE := Vector2i(1242, 2688)
const SKY_MID := Color("8650F0")
const SKY_LOW := Color("FF8AB8")
const TRAIL: Array[Color] = [Color(0.96, 0.22, 0.3), Color(1.0, 0.82, 0.14), Color(0.2, 0.44, 1.0)]


func _initialize() -> void:
	await _render_all()
	quit()


func _render_all() -> void:
	var mascot := await _render_mascot()
	mascot.save_png(OUT + "mascot.png")
	var texture := ImageTexture.create_from_image(mascot)

	var icon := await _render_icon(texture, true)
	icon.convert(Image.FORMAT_RGB8)
	icon.save_png(OUT + "icon_1024.png")
	_resized(icon, 512).save_png(OUT + "icon_512.png")
	_resized(icon, 192).save_png(OUT + "android_main_192.png")
	# Android adaptive icon: the art sits in the middle two thirds, over a plain background.
	var foreground := await _render_icon(texture, false)
	var inset := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	var art := _resized(foreground, 300)
	inset.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), Vector2i(66, 66))
	inset.save_png(OUT + "android_foreground_432.png")
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(SKY_MID)
	background.save_png(OUT + "android_background_432.png")

	var splash := await _render_splash(texture)
	splash.convert(Image.FORMAT_RGB8)
	splash.save_png(OUT + "splash.png")
	print("brand art written to ", ProjectSettings.globalize_path(OUT))


## The kart and its driver, seen from the front right so it heads to the right of the picture.
func _render_mascot() -> Image:
	var viewport := _viewport(Vector2i(1024, 1024))
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.82, 1.0)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.15
	viewport.add_child(sun)
	sun.look_at_from_position(Vector3(2.5, 4.0, -3.0), Vector3.ZERO)

	var look := {"rim_color": Color(1.0, 0.95, 0.85)}
	var vehicle := Vehicles.build("kart", {
		"paint": Look.soft(look, {"gloss": 1.0, "rim": 0.45, "tint": Defs.COLORS[0]}),
		"detail": Look.soft(look, {"rim": 0.3}),
		"glow": Look.glowing(1.5),
		"glass": Look.glass(),
	})
	viewport.add_child(vehicle)
	(vehicle.get_meta("head") as Node3D).rotation = Vector3(0.0, -0.35, 0.05)
	for pivot: Node3D in vehicle.get_meta("steer"):
		pivot.rotation.y = -0.25
	var shadow := MeshInstance3D.new()
	shadow.mesh = Look.patch(3.0, Vehicles.ROAD + 0.01, Look.blob())
	shadow.set_instance_shader_parameter("shade", Color(0.08, 0.04, 0.25, 0.5))
	viewport.add_child(shadow)

	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(3.3, 1.75, -3.6), Vector3(0.0, -0.12, -0.05))
	return _trimmed(await _capture(viewport), 24)


## The icon: a sky gradient, a glow, the three gate colours as a trail, and the mascot racing
## out of it towards the viewer. Without `with_sky` the background is left clear.
func _render_icon(mascot: Texture2D, with_sky: bool) -> Image:
	var viewport := _viewport(Vector2i(1024, 1024))
	if with_sky:
		_add_sky(viewport, Vector2(1024, 1024), SKY_TOP, Rect2(140, 150, 900, 900))
	_add_trail(viewport, [Vector2(-160, 150), Vector2(180, 300), Vector2(470, 470)], 92.0, 104.0)
	_add_kart(viewport, mascot, Rect2(34, 96, 980, 980))
	return await _capture(viewport)


## The splash: the same picture as the icon (sky, glow, trail, kart), tall enough to fill a
## phone screen, with the words above the kart. Everything that matters sits in the middle, so
## the picture can be cropped to cover any screen shape.
func _render_splash(mascot: Texture2D) -> Image:
	var viewport := _viewport(SPLASH_SIZE)
	var size := Vector2(SPLASH_SIZE)
	_add_sky(viewport, size, SPLASH_TOP, Rect2(-180, 900, 1600, 1600))
	_add_trail(viewport, [Vector2(-200, 1120), Vector2(200, 1330), Vector2(560, 1560)], 112.0, 126.0)
	_add_kart(viewport, mascot, Rect2(66, 1090, 1110, 1110))
	var logo := GameLogo.new()
	logo.mascot = mascot
	logo.animated = false
	logo.show_kart = false
	logo.font_size = 262
	viewport.add_child(logo)
	logo.size = Vector2(size.x, logo.custom_minimum_size.y)
	logo.position = Vector2(0, 640)
	return await _capture(viewport)


func _add_sky(viewport: SubViewport, size: Vector2, top: Color, glow_rect: Rect2) -> void:
	var sky := TextureRect.new()
	sky.texture = _gradient([top, SKY_MID, SKY_LOW], [0.0, 0.5, 1.0], false)
	sky.size = size
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	viewport.add_child(sky)
	var glow := TextureRect.new()
	glow.texture = _gradient([Color(1.0, 0.95, 0.75, 0.75), Color(1.0, 0.95, 0.75, 0.0)], [0.0, 1.0], true)
	glow.size = glow_rect.size
	glow.position = glow_rect.position
	glow.stretch_mode = TextureRect.STRETCH_SCALE
	viewport.add_child(glow)


## Three bands in the gate colours sweeping through `path` and ending behind the kart.
func _add_trail(viewport: SubViewport, path: Array, width: float, spacing: float) -> void:
	for i in TRAIL.size():
		var line := Line2D.new()
		line.default_color = TRAIL[i]
		line.width = width
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		var lane := (i - 1) * spacing
		line.points = PackedVector2Array([path[0] + Vector2(0, lane * 0.7), path[1] + Vector2(0, lane * 0.85), path[2] + Vector2(0, lane)])
		var taper := Curve.new()
		taper.add_point(Vector2(0.0, 0.5))
		taper.add_point(Vector2(1.0, 1.0))
		line.width_curve = taper
		viewport.add_child(line)


func _add_kart(viewport: SubViewport, mascot: Texture2D, rect: Rect2) -> void:
	var kart := TextureRect.new()
	kart.texture = mascot
	kart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	kart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	kart.size = rect.size
	kart.position = rect.position
	viewport.add_child(kart)


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport


## Waits for the viewport to draw, returns its picture and frees it.
func _capture(viewport: SubViewport) -> Image:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	viewport.queue_free()
	return image


## Crops to what was drawn, plus a margin.
func _trimmed(image: Image, margin: int) -> Image:
	var used := image.get_used_rect().grow(margin).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	return image.get_region(used)


func _resized(image: Image, size: int) -> Image:
	var copy: Image = image.duplicate()
	copy.resize(size, size, Image.INTERPOLATE_LANCZOS)
	return copy


func _gradient(colors: Array, offsets: Array, radial: bool) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray(colors)
	gradient.offsets = PackedFloat32Array(offsets)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 256
	if radial:
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(0.5, 0.0)
	else:
		texture.fill_from = Vector2(0.5, 0.0)
		texture.fill_to = Vector2(0.5, 1.0)
	return texture
