extends Camera2D
## Follows the player car. Fixed-north by default (best on phones); can rotate with the car.

## The car to follow.
@export var target_path: NodePath
## Seconds of velocity look-ahead (camera leads in the direction you're driving).
@export var look_ahead_time: float = 0.35
## Max look-ahead distance in pixels.
@export var max_look_ahead: float = 240.0
## Follow smoothing (higher = snappier camera).
@export var follow_smoothing: float = 6.0
## Base zoom (1.0 = default, >1 zooms in, <1 zooms out).
@export var base_zoom: float = 1.15
## Extra zoom-out at top speed (0.15 = 15% wider view at full speed).
@export_range(0.0, 0.5, 0.01) var speed_zoom_out: float = 0.2
## Rotate the camera so the car always points up (off = fixed north).
@export var rotate_with_car: bool = false
## Rotation smoothing when rotate_with_car is on.
@export var rotation_smoothing: float = 5.0

var target  # the followed car (Node2D)
var _lead := Vector2.ZERO


func _ready() -> void:
	target = get_node_or_null(target_path)
	ignore_rotation = not rotate_with_car
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	make_current()


func snap_to_target() -> void:
	zoom = Vector2(base_zoom, base_zoom)
	if target:
		global_position = target.global_position
		if rotate_with_car:
			rotation = target.rotation + PI * 0.5
		reset_smoothing()


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var vel: Vector2 = target.velocity if "velocity" in target else Vector2.ZERO
	var lead := vel * look_ahead_time
	if lead.length() > max_look_ahead:
		lead = lead.normalized() * max_look_ahead
	_lead = _lead.lerp(lead, 1.0 - exp(-3.0 * delta))
	var desired: Vector2 = target.global_position + _lead
	global_position = global_position.lerp(desired, 1.0 - exp(-follow_smoothing * delta))
	var max_speed: float = target.max_speed if "max_speed" in target else 800.0
	var z := base_zoom * (1.0 - speed_zoom_out * clampf(vel.length() / max_speed, 0.0, 1.0))
	var cur := zoom.x
	cur = lerp(cur, z, 1.0 - exp(-2.0 * delta))
	zoom = Vector2(cur, cur)
	if rotate_with_car:
		rotation = lerp_angle(rotation, target.rotation + PI * 0.5, 1.0 - exp(-rotation_smoothing * delta))
