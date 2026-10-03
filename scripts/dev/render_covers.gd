extends "res://scripts/dev/render_icons.gd"
## Renders the store cover art in the same picture as the icon and splash (sky, glow, colour
## trail, the fox in its kart, the wordmark):
##   publish/covers/cover_landscape_1920x1080.png
##   publish/covers/cover_portrait_800x1200.png
##   publish/covers/cover_square_800x800.png
## It draws with the GPU, so it needs a window:
##   godot --path . -s res://scripts/dev/render_covers.gd
## Options (after `--`):
##   --out=<dir>       write somewhere else
##   --video-intro     also write intro_portrait_1080x1620.png, the portrait cover at the size
##                     of the portrait preview video (used by tools/record_previews.sh)

## Layouts are in final pixels; everything is drawn at this scale and reduced, for clean edges.
const SUPERSAMPLE := 2.0
const DEFAULT_OUT := "res://publish/covers"
const VIDEO_INTRO_SIZE := Vector2i(1080, 1620)

## Portals lay their own labels over the top-left corner of a cover, so nothing that matters
## goes there: the words sit at the bottom, and only the trail crosses that corner.
const COVERS := {
	"cover_landscape_1920x1080": {
		"size": Vector2i(1920, 1080), "glow": Rect2(820, 60, 1150, 1150),
		"trail": [Vector2(-220, 40), Vector2(560, 300), Vector2(1335, 560)], "trail_width": 92.0, "trail_spacing": 104.0,
		"kart": Rect2(930, 180, 910, 910), "logo_font": 205, "logo": Rect2(50, 610, 900, 0),
	},
	"cover_portrait_800x1200": {
		"size": Vector2i(800, 1200), "glow": Rect2(-110, 20, 1020, 1020),
		"trail": [Vector2(-140, 190), Vector2(130, 320), Vector2(365, 459)], "trail_width": 74.0, "trail_spacing": 83.0,
		"kart": Rect2(40, 150, 730, 730), "logo_font": 172, "logo": Rect2(0, 830, 800, 0),
	},
	"cover_square_800x800": {
		"size": Vector2i(800, 800), "glow": Rect2(50, -90, 760, 760),
		"trail": [Vector2(-140, 60), Vector2(140, 160), Vector2(399, 257)], "trail_width": 58.0, "trail_spacing": 65.0,
		"kart": Rect2(150, 20, 560, 560), "logo_font": 128, "logo": Rect2(0, 535, 800, 0),
	},
}


func _render_all() -> void:
	var out := DEFAULT_OUT
	var video_intro := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg == "--video-intro":
			video_intro = true
	DirAccess.make_dir_recursive_absolute(out)
	var mascot := ImageTexture.create_from_image(await _render_mascot())
	for name: String in COVERS:
		var cover: Dictionary = COVERS[name]
		var image := await _render_cover(mascot, cover)
		if video_intro and name.contains("portrait"):
			_save(image, VIDEO_INTRO_SIZE, out.path_join("intro_portrait_1080x1620.png"))
		_save(image, cover.size, out.path_join(name + ".png"))


func _render_cover(mascot: Texture2D, cover: Dictionary) -> Image:
	var k := SUPERSAMPLE
	var size := Vector2(cover.size) * k
	var viewport := _viewport(Vector2i(size))
	var glow: Rect2 = cover.glow
	_add_sky(viewport, size, SPLASH_TOP, Rect2(glow.position * k, glow.size * k))
	var path: Array = (cover.trail as Array).map(func(point: Vector2) -> Vector2: return point * k)
	_add_trail(viewport, path, cover.trail_width * k, cover.trail_spacing * k)
	var kart: Rect2 = cover.kart
	_add_kart(viewport, mascot, Rect2(kart.position * k, kart.size * k))
	var logo := GameLogo.new()
	logo.mascot = mascot
	logo.animated = false
	logo.show_kart = false
	logo.font_size = int(cover.logo_font * k)
	viewport.add_child(logo)
	var at: Rect2 = cover.logo
	logo.size = Vector2(at.size.x * k, logo.custom_minimum_size.y)
	logo.position = at.position * k
	return await _capture(viewport)


func _save(image: Image, size: Vector2i, path: String) -> void:
	var copy: Image = image.duplicate()
	copy.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	copy.convert(Image.FORMAT_RGB8)
	copy.save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))
