class_name ChaseCamera
extends Camera3D
## Smoothly chases a target transform, with screen shake.

## Lens shift in metres, used to frame the vehicle off-centre on the home screen.
var frame_offset := Vector2.ZERO
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _process(delta: float) -> void:
	_shake = move_toward(_shake, 0.0, delta * 2.0)
	var amount := _shake * _shake * 0.6
	h_offset = frame_offset.x + _rng.randf_range(-1.0, 1.0) * amount
	v_offset = frame_offset.y + _rng.randf_range(-1.0, 1.0) * amount


## Moves toward `target`. `min_pos_weight` of 1 snaps the position.
func follow(target: Transform3D, delta: float, rot_sharpness: float, pos_sharpness: float, min_pos_weight := 0.0) -> void:
	var rot_w := 1.0 - exp(-rot_sharpness * delta)
	var pos_w := maxf(1.0 - exp(-pos_sharpness * delta), min_pos_weight)
	var current := global_transform
	var rot := current.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), rot_w)
	global_transform = Transform3D(Basis(rot), current.origin.lerp(target.origin, pos_w))


func ease_fov(target: float, delta: float) -> void:
	fov = lerpf(fov, target, 1.0 - exp(-3.0 * delta))


func shake(amount: float) -> void:
	if Settings.reduce_motion:
		return
	_shake = maxf(_shake, amount)
