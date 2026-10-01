class_name GameLogo
extends Control
## The Chroma Rush wordmark, drawn in code so it is crisp at any size.
##
## It says what the game is: CHROMA in chunky white lettering on a deep lip (the same raised
## look as the buttons), then RUSH leaning forward beside the fox in its kart, which races to
## the right trailing the three gate colours. The kart is a picture of the real in-game model
## (icons/mascot.png, rendered by scripts/dev/render_icons.gd). Nothing is outlined; the lip
## and a soft shadow give the letters weight. The kart rocks and the trail streams a little,
## so the mark is alive on the home screen.

const MASCOT_PATH := "res://icons/mascot.png"
const LIP := Color(0.2, 0.13, 0.45)
const SHADOW := Color(0.05, 0.02, 0.15, 0.3)
const TRAIL: Array[Color] = [Color(0.96, 0.22, 0.3), Color(1.0, 0.82, 0.14), Color(0.2, 0.44, 1.0)]
## Height of a capital letter as a fraction of the font size (Lilita One).
const CAP := 0.7
## How far RUSH leans (x shift per unit of height).
const LEAN := 0.2

## Size of the CHROMA lettering in pixels. Everything else scales from it.
var font_size := 108:
	set(value):
		font_size = value
		_measure()
## The kart picture; set before adding to the tree to use another one.
var mascot: Texture2D
## Still (for rendering the splash) or gently moving.
var animated := true
## Without the kart, the mark is the two words over the colour trail (the splash has its own,
## much bigger, kart).
var show_kart := true

var _t := 0.0
var _font: Font = preload("res://fonts/LilitaOne-Regular.ttf")
var _chroma_width := 0.0
var _rush_size := 0
var _rush_width := 0.0
var _kart := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mascot == null and ResourceLoader.exists(MASCOT_PATH):
		mascot = load(MASCOT_PATH)
	_measure()


func _process(delta: float) -> void:
	if animated and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _measure() -> void:
	var s := float(font_size)
	_chroma_width = _text_width("CHROMA", font_size)
	_rush_size = int(s * 0.8)
	_rush_width = _text_width("RUSH", _rush_size) + s * 0.1
	_kart = Vector2.ZERO
	if mascot and show_kart:
		_kart = Vector2(s * 1.75 * mascot.get_width() / mascot.get_height(), s * 1.75)
	custom_minimum_size = Vector2(maxf(_chroma_width, _row_width()) + s * 0.5, s * CAP + s * 0.12 + maxf(_kart.y, s * 0.9))
	queue_redraw()


func _row_width() -> float:
	return _rush_width + _kart.x * 0.94


func _draw() -> void:
	var s := float(font_size)
	var lip := s * 0.075
	var baseline := s * CAP + s * 0.02
	_letters("CHROMA", Vector2((size.x - _chroma_width) * 0.5, baseline), font_size, lip)

	# Second row: RUSH, then the kart, with the trail streaming out behind it under the word.
	var top := baseline + lip - s * 0.04
	var row_height := maxf(_kart.y, s * 0.9)
	var left := (size.x - _row_width()) * 0.5
	var rush_baseline := top + row_height * 0.5 + _rush_size * CAP * 0.4
	var kart_at := Vector2(left + _rush_width - _kart.x * 0.05, top + sin(_t * 7.0) * s * 0.008)
	var trail_end := kart_at.x + _kart.x * 0.4 if show_kart else left + _rush_width + s * 0.2
	var bar := s * 0.05
	for i in TRAIL.size():
		var y := rush_baseline + lip + s * 0.07 + i * bar * 2.5
		var stagger: float = [0.0, 0.5, 0.22][i]
		var start := left - s * (0.3 - stagger * 0.5) + sin(_t * 3.0 + i * 2.1) * s * 0.06
		_bar(Vector2(start, y), Vector2(trail_end, y), bar, TRAIL[i])
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-LEAN, 1.0), Vector2(left + s * 0.14, rush_baseline)))
	_letters("RUSH", Vector2.ZERO, _rush_size, lip * 0.8, s * 0.025)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if mascot and show_kart:
		draw_set_transform(kart_at + _kart * 0.5, sin(_t * 3.5) * 0.015)
		draw_texture_rect(mascot, Rect2(-_kart * 0.5, _kart), false)
		draw_set_transform(Vector2.ZERO)


## Draws `text` with its lip and shadow, starting at `at` (on the baseline). Returns the x just
## past the last letter. `spacing` is added after each letter.
func _letters(text: String, at: Vector2, size_px: int, lip: float, spacing := 0.0) -> float:
	var x := at.x
	for i in text.length():
		var letter := text[i]
		var here := Vector2(x, at.y)
		draw_string(_font, here + Vector2(0.0, lip + size_px * 0.035), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, SHADOW)
		# The lip is the letter repeated downwards, which gives a solid edge at any size.
		var steps := maxi(int(lip), 1)
		for k in range(steps, 0, -1):
			draw_string(_font, here + Vector2(0.0, lip * k / steps), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, LIP)
		draw_string(_font, here, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)
		x += _text_width(letter, size_px) + spacing
	return x


## A bar with round ends.
func _bar(from: Vector2, to: Vector2, half: float, color: Color) -> void:
	draw_line(from, to, color, half * 2.0, true)
	draw_circle(from, half, color, true, -1.0, true)
	draw_circle(to, half, color, true, -1.0, true)


func _text_width(text: String, size_px: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
