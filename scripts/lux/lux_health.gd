extends RefCounted
class_name LuxHealth

var max_health: int = 5
var health: float = 5.0
var invincible_time: float = 1.6
var _inv_timer: float = 0.0

var hurt_threshold: float = 950.0
var mid_threshold: float = 1150.0
var heavy_threshold: float = 1350.0
var lethal_threshold: float = 1650.0
var insta_threshold: float = 1900.0

func setup(p: CharacterBody2D) -> void:
	max_health = p.max_health if "max_health" in p else 3
	health = max_health
	if "fall_hurt_threshold" in p: hurt_threshold = p.fall_hurt_threshold
	if "fall_heavy_threshold" in p: heavy_threshold = p.fall_heavy_threshold

func update(delta: float) -> void:
	if _inv_timer > 0:
		_inv_timer -= delta

func can_take_damage() -> bool:
	return _inv_timer <= 0.0 and health > 0

func take_damage(amount: float = 1.0) -> bool:
	if not can_take_damage():
		return false
	health = max(health - amount, 0.0)
	_inv_timer = invincible_time
	return true

func heal(amount: float = 1.0) -> void:
	health = min(health + amount, float(max_health))

func is_dead() -> bool:
	return health <= 0.0

func is_invincible() -> bool:
	return _inv_timer > 0.0

func get_fall_damage(vel_y: float) -> float:
	if vel_y < hurt_threshold:
		return 0.0
	if vel_y >= insta_threshold:
		return float(max_health)
	if vel_y >= lethal_threshold:
		return 3.0
	if vel_y >= heavy_threshold:
		return 2.0
	if vel_y >= mid_threshold:
		return 1.0
	return 0.5

func reset() -> void:
	health = max_health
	_inv_timer = 0.0