class_name GameLogo
extends Control
## The Chroma Rush wordmark, drawn in code so it is crisp at any size.
##
## CHROMA is chunky white lettering on a deep lip (the same raised look as the buttons), with
## the game's own shapes standing in for letters: the red orb is the O and the yellow triangle
## the A. RUSH leans forward on a blue ribbon with speed streaks behind it, so the three gate
## colours are all in the mark. Nothing is outlined; the lip and a soft shadow give it weight.
## The orb bounces, the triangle rocks and the streaks slide a little, so the mark is alive.

const LIP := Color(0.2, 0.13, 0.45)
const SHADOW := Color(0.05, 0.02, 0.15, 0.3)
const RED := Color(0.96, 0.22, 0.3)
const YELLOW := Color(1.0, 0.82, 0.14)
const BLUE := Color(0.2, 0.44, 1.0)
## Height of a capital letter as a fraction of the font size (Lilita One).
const CAP := 0.7
## How far RUSH and its ribbon lean (x shift per unit of height).
const LEAN := 0.22

## Size of the CHROMA lettering in pixels. Everything else scales from it.
var font_size := 108:
	set(value):
		font_size = value
		_measure()

var _t := 0.0
var _font: Font = UiKit.TITLE_FONT
var _line_width := 0.0
var _rush_size := 0
var _rush_width := 0.0
var _ribbon := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_measure()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()


func _measure() -> void:
	var s := float(font_size)
	_line_width = _text_width("CHR", font_size) + _text_width("M", font_size) + s * CAP * 2.2 + s * 0.09
	_rush_size = int(s * 0.7)
	_rush_width = _text_width("RUSH", _rush_size) + s * 0.12
	_ribbon = Vector2(_rush_width + s * 0.62, _rush_size * 0.96)
	custom_minimum_size = Vector2(maxf(_line_width, _ribbon.x + s * 0.9), s * CAP + _ribbon.y + s * 0.3)
	queue_redraw()


func _draw() -> void:
	var s := float(font_size)
	var cap := s * CAP
	var lip := s * 0.075
	var x := (size.x - _line_width) * 0.5
	var baseline := cap + s * 0.02

	# CHROMA: letters, then the shapes that stand in for O and A.
	x = _letters("CHR", Vector2(x, baseline), font_size, lip) + s * 0.03
	var orb := cap * 1.04
	var bounce := absf(sin(_t * 2.6)) * s * 0.06
	_orb(Vector2(x + orb * 0.5, baseline - orb * 0.5 - bounce), orb * 0.5, lip)
	x += orb + s * 0.03
	x = _letters("M", Vector2(x, baseline), font_size, lip) + s * 0.015
	_triangle(Vector2(x + cap * 0.58, baseline), cap * 1.16, cap * 1.04, lip, sin(_t * 1.7) * 0.05)

	# RUSH: leaning white letters on a blue ribbon, streaks trailing to the left.
	var top := baseline + lip + s * 0.08
	var left := (size.x - _ribbon.x) * 0.5 + s * 0.12
	var lean := Vector2(-LEAN * _ribbon.y, _ribbon.y)
	var slide := sin(_t * 3.1)
	var streaks := [[RED, 0.2, 0.62 + 0.08 * slide], [YELLOW, 0.5, 0.86 - 0.06 * slide], [Color.WHITE, 0.8, 0.44 + 0.07 * slide]]
	for streak: Array in streaks:
		var at := Vector2(left, top) + lean * float(streak[1])
		var length := s * float(streak[2])
		_bar(at - Vector2(s * 0.1 + length, 0.0), at - Vector2(s * 0.1, 0.0), _ribbon.y * 0.085, streak[0])
	var corners := PackedVector2Array([Vector2(left, top), Vector2(left + _ribbon.x, top),
		Vector2(left + _ribbon.x, top) + lean, Vector2(left, top) + lean])
	var round := s * 0.07
	_plate(corners, round, lip, BLUE)
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-LEAN, 1.0), Vector2(left + _ribbon.y * LEAN, top)))
	var rush_baseline := _ribbon.y * 0.5 + _rush_size * CAP * 0.5
	_letters("RUSH", Vector2((_ribbon.x - _rush_width) * 0.5, rush_baseline), _rush_size, lip * 0.55, s * 0.04, BLUE.darkened(0.45))
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Draws `text` with its lip and shadow, starting at `at` (on the baseline). Returns the x just
## past the last letter. `spacing` is added after each letter.
func _letters(text: String, at: Vector2, size_px: int, lip: float, spacing := 0.0, lip_color := LIP) -> float:
	var x := at.x
	for i in text.length():
		var letter := text[i]
		var here := Vector2(x, at.y)
		draw_string(_font, here + Vector2(0.0, lip + size_px * 0.035), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, SHADOW)
		# The lip is the letter repeated downwards, which gives a solid edge at any size.
		var steps := maxi(int(lip), 1)
		for k in range(steps, 0, -1):
			draw_string(_font, here + Vector2(0.0, lip * k / steps), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, lip_color)
		draw_string(_font, here, letter, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color.WHITE)
		x += _text_width(letter, size_px) + spacing
	return x


## The O: a glossy red orb, like the ones on the road.
func _orb(centre: Vector2, radius: float, lip: float) -> void:
	draw_circle(centre + Vector2(0.0, lip * 1.6), radius * 0.92, SHADOW, true, -1.0, true)
	draw_circle(centre + Vector2(0.0, lip), radius, RED.darkened(0.42), true, -1.0, true)
	draw_circle(centre, radius, RED, true, -1.0, true)
	draw_circle(centre - Vector2(radius, radius) * 0.18, radius * 0.72, RED.lightened(0.16), true, -1.0, true)
	draw_circle(centre - Vector2(radius, radius) * 0.36, radius * 0.2, Color(1, 1, 1, 0.85), true, -1.0, true)


## The A: a yellow triangle standing on the baseline at `foot` (its bottom centre).
func _triangle(foot: Vector2, width: float, height: float, lip: float, tilt: float) -> void:
	var round := width * 0.09
	var points := PackedVector2Array()
	for p: Vector2 in [Vector2(0.0, -height + round), Vector2(width * 0.5 - round, -round), Vector2(-width * 0.5 + round, -round)]:
		points.append(foot + p.rotated(tilt))
	_plate(points, round, lip, YELLOW)
	var shine := PackedVector2Array()
	for p: Vector2 in [Vector2(0.0, -height * 0.74), Vector2(width * 0.2, -height * 0.34), Vector2(-width * 0.2, -height * 0.34)]:
		shine.append(foot + p.rotated(tilt))
	draw_colored_polygon(shine, YELLOW.lightened(0.35))


## A flat shape with rounded corners (`round` wider all the way round) on a lip and a shadow.
func _plate(points: PackedVector2Array, round: float, lip: float, color: Color) -> void:
	var outline: PackedVector2Array = Geometry2D.offset_polygon(points, round, Geometry2D.JOIN_ROUND)[0]
	for layer: Array in [[Vector2(0.0, lip * 1.7), SHADOW], [Vector2(0.0, lip), color.darkened(0.42)], [Vector2.ZERO, color]]:
		var moved := PackedVector2Array()
		for p in outline:
			moved.append(p + layer[0])
		draw_colored_polygon(moved, layer[1])
		# A thin line in the same colour smooths the polygon's edge.
		if float((layer[1] as Color).a) >= 1.0:
			moved.append(moved[0])
			draw_polyline(moved, layer[1], 1.5, true)


## A bar with round ends.
func _bar(from: Vector2, to: Vector2, half: float, color: Color) -> void:
	draw_line(from, to, color, half * 2.0, true)
	draw_circle(from, half, color, true, -1.0, true)
	draw_circle(to, half, color, true, -1.0, true)


func _text_width(text: String, size_px: int) -> float:
	return _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
