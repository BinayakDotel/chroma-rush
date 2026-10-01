class_name MissionBadge
extends Control
## A mission as a ring: its icon in the middle and its progress around the edge. A completed
## mission is a full green ring around a tick. Used where a full mission row would be too much.

const TRACK := Color(0.86, 0.84, 0.94)
const DONE := Color(0.32, 0.86, 0.46)

## 0..1; animate it to fill the ring.
var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()
var done := false
var _icon: UiIcon


static func make(mission: Dictionary, value: int, diameter := 76.0) -> MissionBadge:
	var badge := MissionBadge.new()
	badge.custom_minimum_size = Vector2(diameter, diameter)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.done = value >= int(mission.target)
	badge.progress = float(value) / maxf(float(mission.target), 1.0)
	var glyph := diameter * 0.42
	badge._icon = UiIcon.make("check" if badge.done else Missions.icon(mission),
		Color.WHITE if badge.done else UiKit.STYLES.sky[1], Vector2(glyph, glyph))
	badge._icon.position = (Vector2(diameter, diameter) - Vector2(glyph, glyph)) * 0.5
	badge.add_child(badge._icon)
	return badge


func _draw() -> void:
	var centre := size * 0.5
	var width := minf(size.x, size.y) * 0.1
	var radius := minf(size.x, size.y) * 0.5 - width * 0.5
	draw_circle(centre, radius, DONE if done else UiKit.CARD_TINT)
	draw_arc(centre, radius, 0.0, TAU, 48, DONE.darkened(0.25) if done else TRACK, width, true)
	if not done and progress > 0.0:
		draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * progress, 48, UiKit.GOLD, width, true)
