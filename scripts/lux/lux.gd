extends CharacterBody2D
class_name Lux

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

# online stuff, peer_id stays 0 when playing offline
var peer_id: int = 0
var is_puppet: bool = false # true for fighters that belong to other players
var player_name: String = ""
var hit_mask: int = 1 # physics layer our attacks look for
var _ko: bool = false
var _ko_sent: bool = false
var _send_timer: float = 0.0
var _puppet: LuxPuppet = LuxPuppet.new()

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var footsteps: AudioStreamPlayer = $Footsteps
@onready var jump_sound: AudioStreamPlayer = $JumpSound
@onready var hitbox: Area2D = $AttackHitbox

var _momentum: LuxMomentum = LuxMomentum.new()
var _movement: LuxMovement = LuxMovement.new()
var _wall: LuxWall = LuxWall.new()
var _anim: LuxAnim = LuxAnim.new()
var _audio: LuxAudio = LuxAudio.new()
var _health: LuxHealth = LuxHealth.new()
var _attack: LuxAttack = LuxAttack.new()

func _ready() -> void:
	_configure_components()
	if is_online():
		_setup_online_body()
	if is_puppet:
		return
	_update_health_label()
	hitbox.monitoring = false
	hitbox.body_entered.connect(_on_hitbox_hit)
	hitbox.area_entered.connect(_on_hitbox_hit_area)

func _configure_components() -> void:
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

func _physics_process(delta: float) -> void:
	if is_puppet:
		_puppet.update(self, anim)
		return
	if _ko:
		return

	if get_meta("debug_flying", false):
		var fly_dir: Vector2 = Input.get_vector("move_left", "move_right", "ui_up", "ui_down")
		if Input.is_action_pressed("jump"):
			fly_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
			fly_dir.y += 0.9
		if fly_dir.length() > 1.0:
			fly_dir = fly_dir.normalized()
		var fast: bool = Input.is_key_pressed(KEY_SHIFT)
		velocity = fly_dir * (360.0 * (2.2 if fast else 1.0))
		move_and_slide()
		anim.play("jump" if fly_dir.y < -0.1 else "fall" if fly_dir.y > 0.1 else "idle")
		anim.flip_h = fly_dir.x < 0 if absf(fly_dir.x) > 0.1 else anim.flip_h
		return

	var dir: float = Input.get_axis("move_left", "move_right")

	_movement.update_timers(self, delta)
	_health.update(delta)
	var in_hit_stun: bool = _movement.is_in_hit_stun()
	if _health.is_invincible():
		anim.modulate.a = 0.35 if int(Time.get_ticks_msec() / 80) % 2 == 0 else 1.0
	else:
		anim.modulate.a = 1.0
	if _health.is_dead():
		if is_online():
			# server decides about ko and respawn, we just wait
			# swoon is the only way we can die on our own, so we have to tell the server
			var swooning: bool = _attack.get_state() == "swoon"
			if swooning and not _ko_sent:
				_ko_sent = true
				Net.report_self_ko()
			anim.play("swoon" if swooning else "hit")
			return
		if _attack.get_state() == "swoon":
			anim.play("swoon")
			return
		anim.play("hit")
		await get_tree().create_timer(0.35).timeout
		get_tree().reload_current_scene()
		return

	_wall.update_slide(self, delta, dir, in_hit_stun, gravity)
	var is_wall_sliding: bool = _wall.is_sliding()

	_momentum.update(delta, dir, velocity, is_on_floor(), is_on_wall(), is_wall_sliding, in_hit_stun)
	var streak_bonus: float = _momentum.get_bonus()
	var effective_speed: float = _momentum.effective_speed(speed)

	_attack.update(self, delta, dir, anim, hitbox)
	if _attack.is_busy():
		_movement.handle_gravity(self, delta, is_wall_sliding)
		if _attack.is_invincible():
			anim.modulate.a = 0.5
	else:
		_movement.handle_horizontal(self, delta, dir, effective_speed)
		_anim.handle_flip(self, anim, dir, is_wall_sliding, in_hit_stun)

		_movement.handle_gravity(self, delta, is_wall_sliding)

		var jumped: bool = false
		if _attack.try_input(self, dir, anim, hitbox):
			jumped = false
		elif _wall.try_wall_jump(self, _movement, anim, jump_sound):
			_anim.squash(anim, 0.85, 1.25, 0.08, 0.12)
			jumped = true
		elif _movement.try_jump(self, is_wall_sliding, footsteps, jump_sound):
			_anim.squash(anim, 0.88, 1.22, 0.08, 0.12)
			jumped = true
		elif _movement.try_double_jump(self, footsteps, jump_sound):
			_anim.squash(anim, 0.92, 1.18, 0.07, 0.1)
			jumped = true

		_movement.handle_variable_jump(self)

	var pre_vel_y: float = velocity.y
	var pre_was_on_floor: bool = _was_on_floor
	var pre_vel_x: float = velocity.x

	move_and_slide()

	if is_on_wall() and absf(pre_vel_x) > 80.0:
		_momentum.reset_on_wall()

	var just_landed: bool = not pre_was_on_floor and is_on_floor()
	if just_landed:
		_momentum.reset()

	_was_on_floor = is_on_floor()

	if not _attack.is_busy():
		_anim.update(self, anim, dir, is_wall_sliding, _movement._hit_timer, streak_bonus)
	_audio.update(self, footsteps, dir, effective_speed, streak_bonus, is_wall_sliding, _movement._hit_timer)

	if is_online():
		_send_timer += delta
		if _send_timer >= 1.0 / Net.SEND_RATE - 0.001:
			_send_timer = 0.0
			Net.send_state(make_state())
		return

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
	if get_meta("debug_godmode", false) or _attack.is_invincible():
		return
	if _health.take_damage(amount):
		_update_health_label()
		_movement.trigger_hit()
		anim.play("hit")

func _on_hitbox_hit(body: Node) -> void:
	deal_hit(body, _attack.hit_damage)

func _on_hitbox_hit_area(area: Area2D) -> void:
	deal_hit(area.get_parent(), _attack.hit_damage)

# ---- online

func is_online() -> bool:
	return peer_id != 0

# call this right after instantiating and before add_child
func setup_online(id: int, display_name: String, is_local: bool) -> void:
	peer_id = id
	player_name = display_name
	is_puppet = not is_local
	name = "Fighter%d" % id
	if is_puppet:
		# a remote fighter must never grab our camera
		var cam: Node = get_node("Camera2D")
		remove_child(cam)
		cam.free()

func _setup_online_body() -> void:
	if is_puppet:
		# puppets get moved by snapshots, they only need to be findable by attacks
		collision_layer = 2
		collision_mask = 0
		remove_from_group("player")
		add_to_group("remote_player")
	else:
		# fighters walk through each other, the attacker does the hit checking
		collision_layer = 0
		collision_mask = 1
		hit_mask = 2
		hitbox.collision_mask = hit_mask

	var tag: Label = Label.new()
	tag.text = player_name
	tag.size = Vector2(200, 20)
	tag.position = Vector2(-100, -128)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_constant_override("outline_size", 4)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	if not is_puppet:
		tag.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(tag)

func make_state() -> FighterState:
	var s: FighterState = FighterState.new()
	s.pos = global_position
	s.vel = velocity
	s.anim = String(anim.animation)
	s.flip = anim.flip_h
	s.anim_speed = anim.speed_scale
	s.rot = anim.rotation
	s.tint = anim.modulate
	s.gray = anim.material != null
	s.dodging = _attack.is_invincible()
	return s

func push_state(state: FighterState) -> void:
	_puppet.push(state)

# our attacks call this when they touch something
func deal_hit(target: Node, amount: float) -> void:
	if target == null or target == self:
		return
	if is_online():
		# only other fighters count, and the server decides what really happens
		if target is Lux and target.is_puppet:
			Net.report_hit(target.peer_id, amount, -1.0 if anim.flip_h else 1.0)
	elif target.has_method("damage"):
		target.damage(amount)

# server says somebody got hit
func net_hit(new_health: float, knockback: Vector2) -> void:
	_health.health = new_health
	if is_puppet:
		return
	_health._inv_timer = _health.invincible_time
	_attack.interrupt(anim, hitbox) # otherwise the attack code would overwrite the knockback
	_movement.trigger_hit()
	velocity = knockback
	anim.play("hit")
	_update_health_label()

func net_ko() -> void:
	_health.health = 0.0
	visible = false
	if is_puppet:
		_puppet.clear()
		return
	_ko = true
	velocity = Vector2.ZERO
	footsteps.stop()
	hitbox.monitoring = false
	_update_health_label()

func net_respawn(pos: Vector2, new_health: float, inv_time: float) -> void:
	global_position = pos
	reset_physics_interpolation()
	visible = true
	if is_puppet:
		_puppet.clear()
		_health.health = new_health
		return
	# start from a clean slate
	_respawn_components()
	_health.health = new_health
	_health._inv_timer = inv_time
	_ko = false
	_ko_sent = false
	_was_on_floor = false
	velocity = Vector2.ZERO
	hitbox.monitoring = false
	hitbox.visible = false
	anim.rotation = 0.0
	anim.modulate = Color(1, 1, 1, 1)
	anim.material = null
	anim.play("idle")
	var cam: Node = get_node_or_null("Camera2D")
	if cam and cam.has_method("snap_to_target"):
		cam.snap_to_target()
	_update_health_label()

func _respawn_components() -> void:
	_momentum = LuxMomentum.new()
	_movement = LuxMovement.new()
	_wall = LuxWall.new()
	_attack = LuxAttack.new()
	_health = LuxHealth.new()
	_configure_components()
