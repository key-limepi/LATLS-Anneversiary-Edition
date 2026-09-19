extends RefCounted
class_name PlayerMomentum

var _move_streak: float = 0.0
var _streak_bonus: float = 0.0

@export var streak_rate: float = 0.22
@export var streak_max_bonus: float = 1.0
@export var streak_decay_rate: float = 1.8
@export var streak_top_speed: float = 480.0

func setup(rate: float, max_bonus: float, decay: float, top: float) -> void:
	streak_rate = rate
	streak_max_bonus = max_bonus
	streak_decay_rate = decay
	streak_top_speed = top

func update(delta: float, dir: float, velocity: Vector2, is_on_floor: bool, is_on_wall: bool, is_wall_sliding: bool, in_hit_stun: bool) -> float:
	var is_moving: bool = absf(dir) > 0.05 and absf(velocity.x) > 30.0 and is_on_floor and not in_hit_stun and not is_wall_sliding
	var hit_something: bool = is_on_wall or in_hit_stun or is_wall_sliding
	var dir_sign: int = signi(int(dir * 10.0))
	var vel_sign: int = signi(int(velocity.x))
	var flipped: bool = dir_sign != 0 and vel_sign != 0 and dir_sign != vel_sign and absf(velocity.x) > 60.0

	if hit_something or flipped:
		_move_streak = max(_move_streak - delta * 3.0, 0.0)
		if is_on_wall or flipped:
			_move_streak = 0.0
	elif is_moving:
		_move_streak += delta
	else:
		if absf(dir) < 0.05:
			_move_streak = move_toward(_move_streak, 0.0, delta * streak_decay_rate)
		else:
			_move_streak = move_toward(_move_streak, 0.0, delta * 0.7)

	_streak_bonus = clamp(_move_streak * streak_rate, 0.0, streak_max_bonus)
	return _streak_bonus

func get_bonus() -> float:
	return _streak_bonus

func get_streak() -> float:
	return _move_streak

func reset_on_wall() -> void:
	_move_streak = 0.0
	_streak_bonus = 0.0

func reset() -> void:
	_move_streak = 0.0
	_streak_bonus = 0.0

func effective_speed(base_speed: float) -> float:
	return min(base_speed * (1.0 + _streak_bonus), streak_top_speed)