extends SceneTree
## Renders the app icon SVG to the PNG sizes the stores and export presets need.
## Run: godot --headless --path . -s res://scripts/dev/render_icons.gd

const SOURCE := "res://icons/icon.svg"
const OUT := "res://icons/"


func _init() -> void:
	var svg := FileAccess.get_file_as_string(SOURCE)
	# App Store and Play Store listing icons (no transparency).
	_render(svg, 1024, "icon_1024.png")
	_render(svg, 512, "icon_512.png")
	# Android launcher icons: legacy 192 px, adaptive foreground and background at 432 px.
	_render(svg, 192, "android_main_192.png")
	_render(svg, 432, "android_foreground_432.png", true)
	var background := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	background.fill(Color("5A3CE4"))
	background.save_png(OUT + "android_background_432.png")
	print("icons written to ", ProjectSettings.globalize_path(OUT))
	quit()


## `inset` shrinks the art into Android's 66% adaptive-icon safe zone.
func _render(svg: String, size: int, file: String, inset := false) -> void:
	var image := Image.new()
	var scale := size / 1024.0 * (0.72 if inset else 1.0)
	image.load_svg_from_string(svg, scale)
	if inset:
		var canvas := Image.create(size, size, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		var offset := (Vector2i(size, size) - image.get_size()) / 2
		canvas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), offset)
		image = canvas
	else:
		image.convert(Image.FORMAT_RGB8)
	image.save_png(OUT + file)
