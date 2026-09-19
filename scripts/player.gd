extends CharacterBody2D

@export var speed: float = 240.0
@export var jump_velocity: float = -460.0
@export var gravity: float = 1250.0
@export var fall_gravity_multiplier: float = 1.35
@export var coyote_time: float = 0.28
@export var jump_buffer_time: float = 0.22
@export var wall_slide_max_speed: float = 65.0
@export var wall_jump_horizontal: float = 340.0
@export var wall_jump_vertical: float = -440.0
@export var wall_jump_lock_time: float = 0.16
@export var ground_accel: float = 2200.0
@export var air_accel: float = 1100.0
@export var ground_friction: float = 1800.0
@export var air_friction: float = 550.0
@export var hit_stun_time: float = 0.35
@export var max_air_jumps: int = 1
@export var max_health: int = 5
@export var fall_hurt_threshold: float = 950.0
@export var fall_heavy_threshold: float = 1300.0
@export var streak_rate: float = 0.22
@export var streak_max_bonus: float = 1.0
@export var streak_decay_rate: float = 1.8
@export var streak_top_speed: float = 480.0

var _was_on_floor: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var footsteps: AudioStreamPlayer = $Footsteps
@onready var jump_sound: AudioStreamPlayer = $JumpSound

var _momentum: PlayerMomentum = PlayerMomentum.new()
var _movement: PlayerMovement = PlayerMovement.new()
var _wall: PlayerWall = PlayerWall.new()
var _anim: PlayerAnim = PlayerAnim.new()
var _audio: PlayerAudio = PlayerAudio.new()
var _health: PlayerHealth = PlayerHealth.new()

func _ready() -> void:
	_momentum.setup(streak_rate, streak_max_bonus, streak_decay_rate, streak_top_speed)
	_movement.coyote_time = coyote_time
	_movement.jump_buffer_time = jump_buffer_time
	_movement.wall_jump_lock_time = wall_jump_lock_time
	_movement.hit_stun_time = hit_stun_time
	_movement.gravity = gravity
	_movement.fall_gravity_multiplier = fall_gravity_multiplier
	_movement.ground_accel = ground_accel
	_movement.air_accel = air_accel
	_movement.ground_friction = ground_friction
	_movement.air_friction = air_friction
	_movement.max_air_jumps = max_air_jumps
	_health.setup(self)
	_wall.setup(self)
	_update_health_label()

func _physics_process(delta: float) -> void:
	var dir: float = Input.get_axis("move_left", "move_right")

	_movement.update_timers(self, delta)
	_health.update(delta)
	var in_hit_stun: bool = _movement.is_in_hit_stun()
	if _health.is_invincible():
		anim.modulate.a = 0.35 if int(Time.get_ticks_msec() / 80) % 2 == 0 else 1.0
	else:
		anim.modulate.a = 1.0
	if _health.is_dead():
		anim.play("hit")
		await get_tree().create_timer(0.35).timeout
		get_tree().reload_current_scene()
		return

	_wall.update_slide(self, delta, dir, in_hit_stun, gravity)
	var is_wall_sliding: bool = _wall.is_sliding()

	_momentum.update(delta, dir, velocity, is_on_floor(), is_on_wall(), is_wall_sliding, in_hit_stun)
	var streak_bonus: float = _momentum.get_bonus()
	var effective_speed: float = _momentum.effective_speed(speed)

	_movement.handle_horizontal(self, delta, dir, effective_speed)
	_anim.handle_flip(self, anim, dir, is_wall_sliding, in_hit_stun)

	_movement.handle_gravity(self, delta, is_wall_sliding)

	if _wall.try_wall_jump(self, _movement, anim, jump_sound):
		pass
	elif _movement.try_jump(self, is_wall_sliding, footsteps, jump_sound):
		pass
	elif _movement.try_double_jump(self, footsteps, jump_sound):
		pass

	_movement.handle_variable_jump(self)

	var pre_vel_y: float = velocity.y
	var pre_was_on_floor: bool = _was_on_floor
	var pre_vel_x: float = velocity.x

	move_and_slide()

	if is_on_wall() and absf(pre_vel_x) > 80.0:
		_momentum.reset_on_wall()

	var just_landed: bool = not pre_was_on_floor and is_on_floor()
	if just_landed and pre_vel_y > _health.hurt_threshold:
		var dmg: float = _health.get_fall_damage(pre_vel_y)
		if dmg > 0 and _health.can_take_damage():
			_health.take_damage(dmg)
			_update_health_label()
		var stun: float = 0.8 + clamp((pre_vel_y - _health.hurt_threshold) / 750.0, 0.0, 1.0) * 2.4
		_movement.trigger_hit_for(stun)
		_momentum.reset()
		anim.play("hit")
		if footsteps.playing:
			footsteps.stop()
		if _health.is_dead():
			anim.play("hit")
			await get_tree().create_timer(0.35).timeout
			get_tree().reload_current_scene()
			return

	_was_on_floor = is_on_floor()

	_anim.update(self, anim, dir, is_wall_sliding, _movement._hit_timer, streak_bonus)
	_audio.update(self, footsteps, dir, effective_speed, streak_bonus, is_wall_sliding, _movement._hit_timer)

	if global_position.y > 2000:
		_health.take_damage(_health.max_health)
		get_tree().reload_current_scene()

func _update_health_label() -> void:
	var hearts: HBoxContainer = get_tree().get_first_node_in_group("health_label") as HBoxContainer
	if hearts:
		var tex_full: Texture2D = preload("res://assets/heart_full.png")
		var tex_half: Texture2D = preload("res://assets/heart_half.png")
		var tex_empty: Texture2D = preload("res://assets/heart_empty.png")
		for i: int in range(hearts.get_child_count()):
			var rect: TextureRect = hearts.get_child(i) as TextureRect
			if rect:
				var remaining: float = _health.health - float(i)
				if remaining >= 1.0:
					rect.texture = tex_full
				elif remaining >= 0.5:
					rect.texture = tex_half
				else:
					rect.texture = tex_empty
				rect.modulate = Color(1, 0.35, 0.35, 0.7) if _health.is_invincible() and remaining > 0 else Color(1,1,1)
				rect.visible = i < _health.max_health
		hearts.visible = true
		return
	var label: Label = get_tree().get_first_node_in_group("health_label") as Label
	if label:
		var hearts_text: String = ""
		for i: int in range(_health.max_health):
			hearts_text += "♥" if i < _health.health else "♡"
		label.text = hearts_text

func heal(amount: float = 1.0) -> void:
	_health.heal(amount)
	_update_health_label()

func damage(amount: float = 1.0) -> void:
	if _health.take_damage(amount):
		_update_health_label()
		_movement.trigger_hit()
		anim.play("hit")