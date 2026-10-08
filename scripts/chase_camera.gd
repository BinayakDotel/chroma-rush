class_name ChaseCamera
extends Camera3D
## Smoothly chases a target transform, with a short screen bump.

## Lens shift in metres, used to frame the vehicle off-centre on the home screen.
var frame_offset := Vector2.ZERO

const _BUMP_T := 1.0 / 3.0
var _peak := 0.0
var _t := 0.0
var _angle := 0.0


func _process(delta: float) -> void:
	if Settings.reduce_motion or _peak <= 0.0:
		_clear_bump()
		_write_frame()
		return
	_t += delta / maxf(Engine.time_scale, 0.01)
	if _t >= _BUMP_T:
		_clear_bump()
		_write_frame()
		return
	var remain := _remaining()
	h_offset = frame_offset.x + cos(_angle) * remain
	v_offset = frame_offset.y + sin(_angle) * remain


## Moves toward `target`. `min_pos_weight` of 1 snaps the position.
func follow(target: Transform3D, delta: float, rot_sharpness: float, pos_sharpness: float, min_pos_weight := 0.0) -> void:
	var rot_w := 1.0 - exp(-rot_sharpness * delta)
	var pos_w := maxf(1.0 - exp(-pos_sharpness * delta), min_pos_weight)
	var current := global_transform
	var rot := current.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), rot_w)
	global_transform = Transform3D(Basis(rot), current.origin.lerp(target.origin, pos_w))


func ease_fov(target: float, delta: float) -> void:
	fov = lerpf(fov, target, 1.0 - exp(-3.0 * delta))


## One bump: jump to `peak` metres, then ease back over a third of a second of real time.
func shake(peak: float) -> void:
	if Settings.reduce_motion:
		return
	if peak <= _remaining():
		return
	_peak = peak
	_t = 0.0
	_angle = randf() * PI
	h_offset = frame_offset.x + cos(_angle) * peak
	v_offset = frame_offset.y + sin(_angle) * peak


func _remaining() -> float:
	if _peak <= 0.0 or _t >= _BUMP_T:
		return 0.0
	return _peak * (1.0 - _t / _BUMP_T) ** 2


func _clear_bump() -> void:
	_peak = 0.0
	_t = 0.0


func _write_frame() -> void:
	h_offset = frame_offset.x
	v_offset = frame_offset.y
