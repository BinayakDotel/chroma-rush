class_name UiIcon
extends Control
## Vector icons drawn in code, so they stay crisp at any screen density and need no image
## files. Shapes are laid out on a unit square and scaled to the control's size.

var icon := "circle"
var color := Color.WHITE
## Dark outline drawn behind symbol shapes (circle / triangle / square).
var outline := Color(0, 0, 0, 0)


static func make(name: String, tint: Color, box: Vector2) -> UiIcon:
	var c := UiIcon.new()
	c.icon = name
	c.color = tint
	c.custom_minimum_size = box
	c.size = box
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## The shape for a gate colour slot (see Defs.SYMBOLS).
static func symbol_name(slot: int) -> String:
	return ["circle", "triangle", "square"][Defs.SYMBOLS[slot]]


func set_icon(name: String, tint := color) -> void:
	icon = name
	color = tint
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	var w := s * 0.11
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match icon:
		"circle", "triangle", "square":
			_symbol(icon, o, s)
		"pause":
			draw_rect(Rect2(p.call(0.22, 0.15), Vector2(0.2, 0.7) * s), color)
			draw_rect(Rect2(p.call(0.58, 0.15), Vector2(0.2, 0.7) * s), color)
		"play":
			draw_colored_polygon(PackedVector2Array([p.call(0.25, 0.12), p.call(0.85, 0.5), p.call(0.25, 0.88)]), color)
		"home":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.1), p.call(0.92, 0.48), p.call(0.08, 0.48)]), color)
			draw_rect(Rect2(p.call(0.2, 0.46), Vector2(0.6, 0.44) * s), color)
			draw_rect(Rect2(p.call(0.42, 0.62), Vector2(0.16, 0.28) * s), _cut())
		"retry":
			draw_arc(p.call(0.5, 0.52), s * 0.32, deg_to_rad(-60), deg_to_rad(250), 24, color, w, true)
			draw_colored_polygon(PackedVector2Array([p.call(0.62, 0.06), p.call(0.9, 0.26), p.call(0.58, 0.38)]), color)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var dir := Vector2(cos(a), sin(a))
				draw_line(p.call(0.5, 0.5) + dir * s * 0.28, p.call(0.5, 0.5) + dir * s * 0.46, color, s * 0.14)
			draw_circle(p.call(0.5, 0.5), s * 0.32, color)
			draw_circle(p.call(0.5, 0.5), s * 0.13, _cut())
		"bag":
			draw_rect(Rect2(p.call(0.14, 0.34), Vector2(0.72, 0.56) * s), color)
			draw_arc(p.call(0.5, 0.34), s * 0.2, PI, TAU, 16, color, w, true)
		"help":
			draw_arc(p.call(0.5, 0.34), s * 0.2, deg_to_rad(180), deg_to_rad(400), 18, color, w * 1.3, true)
			draw_line(p.call(0.5, 0.52), p.call(0.5, 0.66), color, w * 1.3)
			draw_circle(p.call(0.5, 0.86), s * 0.08, color)
		"back":
			draw_polyline(PackedVector2Array([p.call(0.64, 0.14), p.call(0.3, 0.5), p.call(0.64, 0.86)]), color, w * 1.6, true)
		"next":
			draw_polyline(PackedVector2Array([p.call(0.36, 0.14), p.call(0.7, 0.5), p.call(0.36, 0.86)]), color, w * 1.6, true)
		"up":
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.06), p.call(0.92, 0.5), p.call(0.66, 0.5),
				p.call(0.66, 0.94), p.call(0.34, 0.94), p.call(0.34, 0.5), p.call(0.08, 0.5)]), color)
		"close":
			draw_line(p.call(0.2, 0.2), p.call(0.8, 0.8), color, w * 1.5, true)
			draw_line(p.call(0.8, 0.2), p.call(0.2, 0.8), color, w * 1.5, true)
		"lock":
			draw_arc(p.call(0.5, 0.42), s * 0.2, PI, TAU, 16, color, w * 1.1, true)
			draw_line(p.call(0.3, 0.42), p.call(0.3, 0.5), color, w * 1.1)
			draw_line(p.call(0.7, 0.42), p.call(0.7, 0.5), color, w * 1.1)
			draw_rect(Rect2(p.call(0.18, 0.46), Vector2(0.64, 0.46) * s), color)
		"shard":
			var pts := PackedVector2Array([p.call(0.5, 0.04), p.call(0.88, 0.38), p.call(0.5, 0.96), p.call(0.12, 0.38)])
			draw_colored_polygon(pts, color)
			draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.04), p.call(0.88, 0.38), p.call(0.5, 0.38)]), color.lightened(0.45))
			draw_colored_polygon(PackedVector2Array([p.call(0.12, 0.38), p.call(0.5, 0.38), p.call(0.5, 0.96)]), color.darkened(0.2))
			pts.append(pts[0])
			draw_polyline(pts, color.darkened(0.45), s * 0.06, true)
		"star":
			var star := PackedVector2Array()
			for i in 10:
				var a := -PI * 0.5 + TAU * i / 10.0
				var r := 0.48 if i % 2 == 0 else 0.2
				star.append(p.call(0.5 + cos(a) * r, 0.53 + sin(a) * r))
			draw_colored_polygon(star, color)
		"music":
			draw_line(p.call(0.38, 0.78), p.call(0.38, 0.14), color, w)
			draw_line(p.call(0.38, 0.14), p.call(0.8, 0.06), color, w * 1.4)
			draw_line(p.call(0.8, 0.06), p.call(0.8, 0.66), color, w)
			draw_circle(p.call(0.28, 0.78), s * 0.14, color)
			draw_circle(p.call(0.7, 0.68), s * 0.14, color)
		"sound":
			draw_colored_polygon(PackedVector2Array([p.call(0.08, 0.36), p.call(0.3, 0.36), p.call(0.54, 0.14),
				p.call(0.54, 0.86), p.call(0.3, 0.64), p.call(0.08, 0.64)]), color)
			draw_arc(p.call(0.54, 0.5), s * 0.2, -0.9, 0.9, 10, color, w * 0.8, true)
			draw_arc(p.call(0.54, 0.5), s * 0.36, -0.9, 0.9, 12, color, w * 0.8, true)
		"vibrate":
			draw_rect(Rect2(p.call(0.3, 0.1), Vector2(0.4, 0.8) * s), color, false, w * 0.9)
			for side in [-1.0, 1.0]:
				var x: float = 0.5 + side * 0.34
				draw_line(p.call(x, 0.3), p.call(x, 0.7), color, w * 0.8)
		"eye":
			draw_arc(p.call(0.5, 0.9), s * 0.62, deg_to_rad(-138), deg_to_rad(-42), 16, color, w, true)
			draw_arc(p.call(0.5, 0.1), s * 0.62, deg_to_rad(42), deg_to_rad(138), 16, color, w, true)
			draw_circle(p.call(0.5, 0.5), s * 0.15, color)
		"motion":
			for i in 3:
				var y := 0.25 + i * 0.25
				draw_line(p.call(0.12 + i * 0.1, y), p.call(0.88, y), color, w, true)
		"film":
			draw_rect(Rect2(p.call(0.08, 0.22), Vector2(0.84, 0.56) * s), color)
			draw_colored_polygon(PackedVector2Array([p.call(0.42, 0.36), p.call(0.64, 0.5), p.call(0.42, 0.64)]), _cut())
		"check":
			draw_polyline(PackedVector2Array([p.call(0.14, 0.52), p.call(0.4, 0.78), p.call(0.88, 0.22)]), color, w * 1.5, true)
		"fuel":
			draw_rect(Rect2(p.call(0.18, 0.22), Vector2(0.56, 0.7) * s), color)
			draw_rect(Rect2(p.call(0.3, 0.08), Vector2(0.3, 0.14) * s), color)
			draw_polyline(PackedVector2Array([p.call(0.74, 0.4), p.call(0.88, 0.5), p.call(0.88, 0.8)]), color, w * 0.8, true)
		"bolt":
			draw_colored_polygon(PackedVector2Array([p.call(0.58, 0.04), p.call(0.2, 0.56), p.call(0.46, 0.56),
				p.call(0.38, 0.96), p.call(0.8, 0.4), p.call(0.54, 0.4)]), color)
		"graphics":
			draw_rect(Rect2(p.call(0.08, 0.16), Vector2(0.84, 0.6) * s), color, false, w * 0.9)
			draw_colored_polygon(PackedVector2Array([p.call(0.2, 0.66), p.call(0.42, 0.36), p.call(0.58, 0.56),
				p.call(0.68, 0.46), p.call(0.82, 0.66)]), color)
			draw_line(p.call(0.3, 0.9), p.call(0.7, 0.9), color, w)
		"trophy":
			draw_rect(Rect2(p.call(0.26, 0.1), Vector2(0.48, 0.36) * s), color)
			draw_circle(p.call(0.5, 0.46), s * 0.24, color)
			draw_arc(p.call(0.26, 0.28), s * 0.14, PI * 0.5, PI * 1.5, 10, color, w * 0.8)
			draw_arc(p.call(0.74, 0.28), s * 0.14, -PI * 0.5, PI * 0.5, 10, color, w * 0.8)
			draw_rect(Rect2(p.call(0.44, 0.66), Vector2(0.12, 0.14) * s), color)
			draw_rect(Rect2(p.call(0.28, 0.8), Vector2(0.44, 0.12) * s), color)
		"restore":
			draw_arc(p.call(0.5, 0.5), s * 0.34, deg_to_rad(200), deg_to_rad(500), 24, color, w, true)
			draw_colored_polygon(PackedVector2Array([p.call(0.02, 0.38), p.call(0.3, 0.44), p.call(0.1, 0.66)]), color)
		"reset":
			draw_rect(Rect2(p.call(0.24, 0.3), Vector2(0.52, 0.62) * s), color)
			draw_rect(Rect2(p.call(0.14, 0.18), Vector2(0.72, 0.08) * s), color)
			draw_rect(Rect2(p.call(0.4, 0.08), Vector2(0.2, 0.1) * s), color)
		"link":
			draw_rect(Rect2(p.call(0.1, 0.3), Vector2(0.6, 0.6) * s), color, false, w * 0.9)
			draw_line(p.call(0.45, 0.55), p.call(0.9, 0.1), color, w, true)
			draw_polyline(PackedVector2Array([p.call(0.6, 0.1), p.call(0.9, 0.1), p.call(0.9, 0.4)]), color, w, true)


## Circle / triangle / square with an optional dark outline, sized to the box.
func _symbol(kind: String, o: Vector2, s: float) -> void:
	var c := o + Vector2(s, s) * 0.5
	var r := s * 0.44
	var pts: PackedVector2Array
	match kind:
		"circle":
			for i in 32:
				var a := TAU * i / 32.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
		"triangle":
			var t := r * 1.12
			pts = PackedVector2Array([c + Vector2(0, -t), c + Vector2(t * 0.95, t * 0.72), c + Vector2(-t * 0.95, t * 0.72)])
			pts = _offset(pts, c, Vector2(0, r * 0.08))
		_:
			var q := r * 0.86
			pts = PackedVector2Array([c + Vector2(-q, -q), c + Vector2(q, -q), c + Vector2(q, q), c + Vector2(-q, q)])
	if outline.a > 0.0:
		var ring := pts.duplicate()
		ring.append(pts[0])
		draw_polyline(ring, outline, s * 0.14, true)
	draw_colored_polygon(pts, color)


static func _offset(pts: PackedVector2Array, _c: Vector2, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in pts:
		out.append(point + by)
	return out


## Colour used for "holes" in icons: the button face behind, approximated as transparent-dark.
func _cut() -> Color:
	return Color(0.0, 0.0, 0.0, 0.0) if color.get_luminance() < 0.5 else Color(0.2, 0.15, 0.35, 0.55)
