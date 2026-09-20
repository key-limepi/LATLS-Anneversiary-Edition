extends RefCounted
class_name LuxWall

var _is_wall_sliding: bool = false
var wall_slide_max_speed: float = 80.0
var wall_jump_horizontal: float = 320.0
var wall_jump_vertical: float = -420.0
var _wall_coyote: float = 0.0
var _last_wall_n: float = 0.0

func setup(p: CharacterBody2D) -> void:
	wall_slide_max_speed = p.wall_slide_max_speed if "wall_slide_max_speed" in p else 80.0
	wall_jump_horizontal = p.wall_jump_horizontal if "wall_jump_horizontal" in p else 280.0
	wall_jump_vertical = p.wall_jump_vertical if "wall_jump_vertical" in p else -400.0

func update_slide(player: CharacterBody2D, delta: float, dir: float, in_hit_stun: bool, gravity: float) -> bool:
	_is_wall_sliding = false
	if player.is_on_wall_only():
		_last_wall_n = player.get_wall_normal().x
		_wall_coyote = 0.22
	else:
		_wall_coyote = max(_wall_coyote - delta, 0.0)

	if not player.is_on_floor() and not in_hit_stun:
		var on_wall: bool = player.is_on_wall_only() or _wall_coyote > 0.0
		if on_wall:
			var n: float = _last_wall_n if not player.is_on_wall_only() else player.get_wall_normal().x
			var pressing_into: bool = (n > 0 and dir < -0.05) or (n < 0 and dir > 0.05)
			var moving_into: bool = (n > 0 and player.velocity.x < -20.0) or (n < 0 and player.velocity.x > 20.0)
			var should_slide: bool = pressing_into or moving_into or player.is_on_wall_only()
			if should_slide and player.velocity.y >= -40.0:
				_is_wall_sliding = true
				if player.velocity.y > wall_slide_max_speed:
					player.velocity.y = move_toward(player.velocity.y, wall_slide_max_speed, gravity * delta * 2.0)
				else:
					player.velocity.y = min(player.velocity.y + gravity * 0.25 * delta, wall_slide_max_speed)
	return _is_wall_sliding

func is_sliding() -> bool:
	return _is_wall_sliding

func try_wall_jump(player: CharacterBody2D, movement: LuxMovement, anim: AnimatedSprite2D, jump_sound: AudioStreamPlayer = null) -> bool:
	var can_wall_jump: bool = _is_wall_sliding or _wall_coyote > 0.0
	if can_wall_jump and Input.is_action_just_pressed("jump"):
		var n: float = _last_wall_n
		if player.is_on_wall_only():
			n = player.get_wall_normal().x
		if absf(n) < 0.1:
			return false
		player.velocity.x = n * wall_jump_horizontal
		player.velocity.y = wall_jump_vertical
		movement.consume_wall_jump(player)
		_wall_coyote = 0.0
		_is_wall_sliding = false
		if jump_sound:
			jump_sound.pitch_scale = randf_range(0.97, 1.08)
			jump_sound.play()
		if anim:
			anim.play("jump")
			anim.flip_h = player.velocity.x < 0
		return true
	return false

func reset() -> void:
	_is_wall_sliding = false