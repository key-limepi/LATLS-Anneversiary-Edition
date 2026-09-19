extends Camera2D

@export_group("Follow")
@export var follow_speed_x: float = 8.0
@export var follow_speed_y: float = 5.0
@export var vertical_offset: float = -40.0

@export_group("Look Ahead")
@export var look_ahead_max: float = 150.0
@export var look_ahead_speed_reference: float = 480.0
@export var look_ahead_min_speed: float = 30.0
@export var look_ahead_smoothing: float = 3.5

@export_group("Vertical Dead Zone")
@export var dead_zone_up: float = 70.0
@export var dead_zone_down: float = 35.0

@export_group("Fall Look-Down")
@export var fall_look_start_speed: float = 400.0
@export var fall_look_full_speed: float = 1200.0
@export var fall_look_distance: float = 260.0
@export var fall_follow_speed_y: float = 14.0

@export_group("Teleport")
@export var snap_distance: float = 1500.0

var _player: CharacterBody2D
var _look_x: float = 0.0
var _anchor_y: float = 0.0

func _ready() -> void:
	_player = get_parent() as CharacterBody2D
	if _player == null:
		push_warning("PlayerCamera must be a child of a CharacterBody2D. Camera controller disabled.")
		set_physics_process(false)
		return
	top_level = true
	snap_to_target()

func _physics_process(delta: float) -> void:
	var pos: Vector2 = _player.global_position
	var vel: Vector2 = _player.velocity

	var look_target: float = 0.0
	if absf(vel.x) > look_ahead_min_speed:
		look_target = clampf(vel.x / look_ahead_speed_reference, -1.0, 1.0) * look_ahead_max
	_look_x = _damp(_look_x, look_target, look_ahead_smoothing, delta)

	var focus_y: float = pos.y + vertical_offset
	if _player.is_on_floor() or _player.is_on_wall_only():
		_anchor_y = focus_y
	else:
		_anchor_y = clampf(_anchor_y, focus_y - dead_zone_down, focus_y + dead_zone_up)

	var fall_t: float = clampf(inverse_lerp(fall_look_start_speed, fall_look_full_speed, vel.y), 0.0, 1.0)

	var target := Vector2(pos.x + _look_x, _anchor_y + fall_t * fall_look_distance)
	var rate_y: float = lerpf(follow_speed_y, fall_follow_speed_y, fall_t)

	if global_position.distance_to(target) > snap_distance:
		global_position = target
		reset_physics_interpolation()
		return

	global_position.x = _damp(global_position.x, target.x, follow_speed_x, delta)
	global_position.y = _damp(global_position.y, target.y, rate_y, delta)

func snap_to_target() -> void:
	if _player == null:
		return
	_look_x = 0.0
	_anchor_y = _player.global_position.y + vertical_offset
	global_position = Vector2(_player.global_position.x, _anchor_y)
	reset_physics_interpolation()

static func _damp(current: float, target: float, rate: float, delta: float) -> float:
	return lerpf(current, target, 1.0 - exp(-rate * delta))
