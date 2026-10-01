class_name FrameProbe
extends RefCounted
## Debug builds on phones only: logs frame-pacing stats every few seconds, so stutter can be
## measured on real hardware. Lines go to the console (`adb logcat`; on iOS, the system log) and
## to user://frame_pacing.log, which on iOS can be copied off with
## `xcrun devicectl device copy from --domain-type appDataContainer ...`.

const REPORT_EVERY := 5.0
const LOG_PATH := "user://frame_pacing.log"

var _times := PackedFloat32Array()
var _elapsed := 0.0
var _file: FileAccess


func _init() -> void:
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE)


func tick(delta: float) -> void:
	_times.append(delta)
	_elapsed += delta
	if _elapsed < REPORT_EVERY:
		return
	var sorted := _times.duplicate()
	sorted.sort()
	var total := 0.0
	for t in _times:
		total += t
	var avg := total / _times.size()
	# A hitch is a frame held for noticeably longer than the typical one.
	var hitches := 0
	for t in _times:
		if t > avg * 1.5:
			hitches += 1
	var line := "[pace] fps=%.1f avg=%.1fms p95=%.1fms max=%.1fms hitches=%d refresh=%.0fHz" % [
		_times.size() / _elapsed, avg * 1000.0, sorted[int(sorted.size() * 0.95)] * 1000.0,
		sorted[sorted.size() - 1] * 1000.0, hitches, DisplayServer.screen_get_refresh_rate()]
	print(line)
	if _file:
		_file.store_line(line)
		_file.flush()
	_times.clear()
	_elapsed = 0.0
