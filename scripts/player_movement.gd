extends RefCounted
class_name PlayerMovement

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _wall_lock_timer: float = 0.0
var _hit_timer: float = 0.0
var _air_jumps_left: int = 1
var max_air_jumps: int = 1

var coyote_time: float = 0.18
var jump_buffer_time: float = 0.15
var wall_jump_lock_time: float = 0.16
var hit_stun_time: float = 0.35
var gravity: float = 1250.0
var fall_gravity_multiplier: float = 1.35
var ground_accel: float = 2200.0
var air_accel: float = 1100.0
var ground_friction: float = 1800.0
var air_friction: float = 550.0

func setup(p: CharacterBody2D) -> void:
	coyote_time = p.coyote_time if "coyote_time" in p else 0.12
	jump_buffer_time = p.jump_buffer_time if "jump_buffer_time" in p else 0.12

func update_timers(player: CharacterBody2D, delta: float) -> void:
	if player.is_on_floor():
		_coyote_timer = coyote_time
		_air_jumps_left = max_air_jumps
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta

	if _wall_lock_timer > 0:
		_wall_lock_timer -= delta
	if _hit_timer > 0:
		_hit_timer -= delta

func is_in_hit_stun() -> bool:
	return _hit_timer > 0.0

func trigger_hit() -> void:
	_hit_timer = hit_stun_time

func trigger_hit_for(duration: float) -> void:
	_hit_timer = max(_hit_timer, duration)

func handle_horizontal(player: CharacterBody2D, delta: float, dir: float, effective_speed: float) -> void:
	if is_in_hit_stun():
		player.velocity.x = move_toward(player.velocity.x, 0.0, ground_friction * 0.7 * delta)
		return
	var is_turning: bool = dir != 0 and signf(dir) != signf(player.velocity.x) and absf(player.velocity.x) > 35.0
	var turn_bonus: float = 1.7 if is_turning else 1.0
	if _wall_lock_timer <= 0:
		if dir != 0:
			var accel: float = (ground_accel if player.is_on_floor() else air_accel) * turn_bonus
			if is_turning and player.is_on_floor():
				player.velocity.x = move_toward(player.velocity.x, dir * effective_speed, accel * delta * 1.4)
			else:
				player.velocity.x = move_toward(player.velocity.x, dir * effective_speed, accel * delta)
		else:
			var fric: float = ground_friction if player.is_on_floor() else air_friction
			var stop_mult: float = 1.0 if player.is_on_floor() else 0.85
			player.velocity.x = move_toward(player.velocity.x, 0.0, fric * stop_mult * delta)
	else:
		if dir != 0:
			player.velocity.x = move_toward(player.velocity.x, dir * effective_speed, air_accel * 0.7 * delta)

func handle_gravity(player: CharacterBody2D, delta: float, is_wall_sliding: bool) -> void:
	if not player.is_on_floor() and not is_wall_sliding:
		var g: float = gravity * (fall_gravity_multiplier if player.velocity.y > 0 else 1.0)
		player.velocity.y += g * delta

func try_jump(player: CharacterBody2D, is_wall_sliding: bool, footsteps: AudioStreamPlayer, jump_sound: AudioStreamPlayer = null) -> bool:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not is_in_hit_stun():
		player.velocity.y = player.jump_velocity if "jump_velocity" in player else -420.0
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		if footsteps and footsteps.playing:
			footsteps.stop()
		if jump_sound:
			jump_sound.pitch_scale = randf_range(0.95, 1.05)
			jump_sound.play()
		return true
	return false

func try_double_jump(player: CharacterBody2D, footsteps: AudioStreamPlayer, jump_sound: AudioStreamPlayer = null) -> bool:
	if is_in_hit_stun():
		return false
	if not player.is_on_floor() and _coyote_timer <= 0.0 and _air_jumps_left > 0 and _jump_buffer_timer > 0.0:
		player.velocity.y = player.jump_velocity if "jump_velocity" in player else -420.0
		_air_jumps_left -= 1
		_jump_buffer_timer = 0.0
		if footsteps and footsteps.playing:
			footsteps.stop()
		if jump_sound:
			jump_sound.pitch_scale = randf_range(1.08, 1.18)
			jump_sound.play()
		return true
	return false

func reset_air_jumps() -> void:
	_air_jumps_left = max_air_jumps

func can_coyote_jump() -> bool:
	return _coyote_timer > 0.0

func has_buffered_jump() -> bool:
	return _jump_buffer_timer > 0.0

func handle_variable_jump(player: CharacterBody2D) -> void:
	if Input.is_action_just_released("jump") and player.velocity.y < 0:
		player.velocity.y *= 0.5

func lock_wall_jump() -> void:
	_wall_lock_timer = wall_jump_lock_time

func consume_wall_jump(player: CharacterBody2D) -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_wall_lock_timer = wall_jump_lock_time
	_air_jumps_left = max_air_jumps