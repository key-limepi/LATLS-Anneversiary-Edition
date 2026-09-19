extends RefCounted
class_name Score

var score: int = 0
var _accum: float = 0.0

func add_streak_points(velocity_x: float, delta: float, streak_bonus: float) -> void:
	_accum += absf(velocity_x) * delta * 0.12 * (1.0 + streak_bonus * 2.5)
	if _accum >= 1.0:
		score += int(_accum)
		_accum -= int(_accum)

func add_wall_jump_bonus(streak_bonus: float) -> void:
	score += 25 + int(streak_bonus * 30)

func reset(): score = 0; _accum = 0.0