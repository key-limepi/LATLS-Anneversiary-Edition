extends RefCounted
class_name LuxAttack

var _state: String = "none"
var _timer: float = 0.0
var _hitbox_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dir: float = 1.0

var dash_speed: float = 380.0
var dash_time: float = 0.32
var hit_active: float = 0.16
var hit_damage: float = 1.0
var dodge_time: float = 0.18
var dodge_speed: float = 520.0
var cooldown: float = 0.0
var _afterimage_tick: float = 0.0
var _dodge_used: bool = false
var _kick_is_dash: bool = false
var _air_normal_used: bool = false
var _air_special_used: bool = false
var _spam_time: float = 0.0
var _swoon_timer: float = 0.0

func is_busy() -> bool:
	return _state != "none"

func is_dodging() -> bool:
	return _state == "dodge"

func is_attacking() -> bool:
	return _state == "zlr"

func update(player: CharacterBody2D, delta: float, dir: float, anim: AnimatedSprite2D, hitbox: Area2D) -> void:
	if cooldown > 0:
		cooldown -= delta
	if _state == "swoon":
		_swoon_timer -= delta
		player.velocity.x = move_toward(player.velocity.x, 0, 900.0 * delta)
		player.velocity.y += 400.0 * delta if not player.is_on_floor() else 0
		if _swoon_timer <= 0:
			_state = "none"
			anim.play("idle")
		return
	if _state != "none" or cooldown > 0:
		_spam_time += delta
		if _spam_time >= 5.0:
			_trigger_swoon(player, anim, hitbox)
			return
	else:
		_spam_time = max(_spam_time - delta * 1.6, 0.0)
	if player.is_on_floor():
		if _state != "dodge":
			_dodge_used = false
		_air_normal_used = false
		_air_special_used = false
	if _timer > 0:
		_timer -= delta
		if _state == "zlr":
			player.velocity.x = _dir * dash_speed
			_afterimage_tick -= delta
			if _afterimage_tick <= 0:
				_afterimage_tick = 0.05
				_spawn_afterimage(player, anim, false)
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
				_afterimage_tick = 0
		elif _state == "jab":
			player.velocity.x = _dir * 80.0 if player.is_on_floor() else player.velocity.x * 0.9
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
		elif _state == "kick":
			if _kick_is_dash:
				player.velocity.x = _dir * dash_speed
				_afterimage_tick -= delta
				if _afterimage_tick <= 0:
					_afterimage_tick = 0.05
					_spawn_afterimage(player, anim, false)
			else:
				player.velocity.x = _dir * 120.0 if player.is_on_floor() else player.velocity.x * 0.92
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
				_afterimage_tick = 0
		elif _state == "down_z":
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
		elif _state == "special_up":
			_afterimage_tick -= delta
			if _afterimage_tick <= 0:
				_afterimage_tick = 0.035
				_spawn_afterimage(player, anim, false, Color(0.5, 0.7, 1.0, 0.45))
			player.velocity.y += -18.0 if player.velocity.y > -380 else 0
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
				anim.rotation = 0
				_afterimage_tick = 0
		elif _state == "charge":
			player.velocity.x = 0
			player.velocity.y = 0
			_afterimage_tick -= delta
			if _afterimage_tick <= 0:
				_afterimage_tick = 0.06
				_spawn_afterimage(player, anim, false, Color(0.4, 0.65, 1.0, 0.35))
			anim.modulate = Color(0.7, 0.85, 1.0)
			if not Input.is_action_pressed("attack_special"):
				_state = "none"
				anim.modulate = Color(1,1,1)
				cooldown = 0.4
				return
			_timer -= delta
			if _timer <= 0:
				_state = "wink"
				_timer = 0.42
				anim.play("wink")
				anim.modulate = Color(1,1,1)
				_spawn_blast(player)
				hit_damage = 4.0
				_setup_hitbox(hitbox, _dir)
				hitbox.monitoring = true
				hitbox.visible = true
				_hitbox_timer = 0.22
				if not player.is_on_floor():
					_air_special_used = true
		elif _state == "wink":
			_afterimage_tick -= delta
			if _afterimage_tick <= 0:
				_afterimage_tick = 0.04
				_spawn_afterimage(player, anim, false, Color(0.5, 0.75, 1.0, 0.5))
			if _timer <= 0:
				_state = "none"
				hitbox.monitoring = false
				hitbox.visible = false
				_afterimage_tick = 0
		elif _state == "dodge":
			_dodge_timer -= delta
			player.velocity.x = _dir * dodge_speed
			player.velocity.y = 0
			_set_grayscale(anim, true)
			_afterimage_tick -= delta
			if _afterimage_tick <= 0:
				_afterimage_tick = 0.045
				_spawn_afterimage(player, anim)
			if _timer <= 0 or _dodge_timer <= 0:
				_state = "none"
				_set_grayscale(anim, false)
				anim.modulate = Color(1, 1, 1, 1)
				_afterimage_tick = 0
	if _hitbox_timer > 0:
		_hitbox_timer -= delta
		if _hitbox_timer <= 0 and hitbox:
			hitbox.monitoring = false

var _charge_timer: float = 0.0

func try_input(player: CharacterBody2D, dir: float, anim: AnimatedSprite2D, hitbox: Area2D) -> bool:
	if cooldown > 0 or is_busy():
		return false
	if Input.is_action_just_pressed("attack_special") and not (Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		if not player.is_on_floor() and _air_special_used:
			return false
		_state = "charge"
		_timer = 2.0
		_charge_timer = 2.0
		cooldown = 0.2
		_dir = -1.0 if anim.flip_h else 1.0
		anim.play("charge")
		hitbox.monitoring = false
		_afterimage_tick = 0
		return true
	if Input.is_action_just_pressed("attack_special") and (Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		if not player.is_on_floor() and _air_special_used:
			return false
		_state = "special_up"
		if not player.is_on_floor():
			_air_special_used = true
		_timer = 0.52
		cooldown = 0.6
		_dir = -1.0 if anim.flip_h else 1.0
		anim.play("special_up")
		anim.rotation = 0
		var tw: Tween = anim.get_tree().create_tween()
		tw.tween_property(anim, "rotation", _dir * -TAU * 1.6, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(anim, "rotation", 0, 0.08)
		player.velocity = Vector2(_dir * 90.0, -520.0)
		hit_damage = 1.8
		_setup_hitbox(hitbox, _dir)
		hitbox.monitoring = true
		hitbox.visible = true
		_hitbox_timer = 0.22
		_afterimage_tick = 0
		return true
	if Input.is_action_just_pressed("dodge"):
		if _dodge_used and not player.is_on_floor():
			return false
		_state = "dodge"
		_timer = dodge_time
		_dodge_timer = dodge_time
		_dir = dir if dir != 0 else (-1.0 if anim.flip_h else 1.0)
		cooldown = 0.6
		_dodge_used = true
		anim.play("dodge")
		_set_grayscale(anim, true)
		_afterimage_tick = 0
		hitbox.monitoring = false
		anim.flip_h = _dir < 0
		return true
	if Input.is_action_just_pressed("attack_normal"):
		if not player.is_on_floor() and _air_normal_used:
			return false
		var down: bool = Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
		if down:
			if not player.is_on_floor():
				_air_normal_used = true
			_state = "down_z"
			_timer = 0.26
			cooldown = 0.3
			_dir = -1.0 if anim.flip_h else 1.0
			anim.play("down_z")
			var an2: LuxAnim = LuxAnim.new()
			an2.squash(anim, 1.18, 1.0, 0.06, 0.11)
			hit_damage = 1.0
			_setup_hitbox(hitbox, _dir)
			hitbox.monitoring = true
			hitbox.visible = true
			_hitbox_timer = 0.13
			return true
		var moving: bool = absf(dir) > 0.05 or absf(player.velocity.x) > 90.0
		var an: LuxAnim = LuxAnim.new()
		if moving:
			_state = "kick"
			_timer = 0.32
			cooldown = 0.38
			_dir = dir if dir != 0 else (-1.0 if anim.flip_h else 1.0)
			anim.play("kick")
			an.squash(anim, 1.18, 1.0, 0.06, 0.11)
			_kick_is_dash = true
			_afterimage_tick = 0
			player.velocity.x = _dir * dash_speed
			hit_damage = 1.5
			_setup_hitbox(hitbox, _dir)
			hitbox.monitoring = true
			hitbox.visible = true
			_hitbox_timer = 0.14
			anim.flip_h = _dir < 0
		else:
			_state = "jab"
			_timer = 0.26
			cooldown = 0.28
			_dir = -1.0 if anim.flip_h else 1.0
			anim.play("jab")
			an.squash(anim, 1.18, 1.0, 0.05, 0.1)
			_kick_is_dash = false
			hit_damage = 1.0
			_setup_hitbox(hitbox, _dir)
			hitbox.monitoring = true
			hitbox.visible = true
			_hitbox_timer = 0.12
		return true
	return false

func _setup_hitbox(hitbox: Area2D, dir: float) -> void:
	if not hitbox:
		return
	var shape: CollisionShape2D = hitbox.get_node_or_null("HitShape") as CollisionShape2D
	if shape:
		shape.position.x = absf(shape.position.x) * dir

func _set_grayscale(anim: AnimatedSprite2D, on: bool) -> void:
	if not anim:
		return
	if on:
		if not anim.material:
			var sh: Shader = preload("res://scripts/grayscale.gdshader")
			var mat: ShaderMaterial = ShaderMaterial.new()
			mat.shader = sh
			anim.material = mat
	else:
		anim.material = null

func _spawn_blast(player: CharacterBody2D) -> void:
	var blast: Area2D = Area2D.new()
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 18
	shape.shape = circle
	blast.add_child(shape)
	blast.global_position = player.global_position + Vector2(0, -18)
	blast.monitoring = true
	blast.monitorable = false
	blast.collision_layer = 0
	blast.collision_mask = player.hit_mask if "hit_mask" in player else 1
	blast.z_index = 10
	player.get_parent().add_child(blast)
	var vis: Sprite2D = Sprite2D.new()
	vis.texture = preload("res://assets/snow.png")
	vis.modulate = Color(0.35, 0.65, 1.0, 0.88)
	vis.scale = Vector2(0.6, 0.6)
	blast.add_child(vis)
	var inner: Sprite2D = Sprite2D.new()
	inner.texture = preload("res://assets/snow.png")
	inner.modulate = Color(0.9, 0.95, 1.0, 0.9)
	inner.scale = Vector2(0.35, 0.35)
	blast.add_child(inner)
	var tw2: Tween = blast.get_tree().create_tween()
	tw2.tween_property(vis, "scale", Vector2(22, 22), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(inner, "scale", Vector2(14, 14), 0.32)
	tw2.parallel().tween_property(shape.shape, "radius", 110, 0.38)
	tw2.parallel().tween_property(vis, "modulate:a", 0.0, 0.42)
	tw2.parallel().tween_property(inner, "modulate:a", 0.0, 0.38)
	blast.body_entered.connect(func(b: Node): _hit_target(player, b))
	blast.area_entered.connect(func(a: Area2D): _hit_target(player, a.get_parent()))
	var tw3: Tween = blast.get_tree().create_tween()
	tw3.tween_interval(0.45)
	tw3.tween_callback(blast.queue_free)

func _hit_target(player: CharacterBody2D, target: Node) -> void:
	if target == null or target == player:
		return
	if player.has_method("deal_hit"):
		player.deal_hit(target, hit_damage)
	elif target.has_method("damage"):
		target.damage(hit_damage)

# cancels whatever move we are doing, used when we get hit online
func interrupt(anim: AnimatedSprite2D, hitbox: Area2D) -> void:
	if _state == "none" or _state == "swoon":
		return
	_state = "none"
	_timer = 0.0
	_afterimage_tick = 0.0
	hitbox.monitoring = false
	hitbox.visible = false
	anim.rotation = 0.0
	anim.modulate = Color(1, 1, 1, 1)
	_set_grayscale(anim, false)

func _trigger_swoon(player: CharacterBody2D, anim: AnimatedSprite2D, hitbox: Area2D) -> void:
	_state = "swoon"
	_timer = 2.0
	_swoon_timer = 2.0
	_spam_time = 0.0
	anim.play("swoon")
	anim.rotation = 0
	anim.modulate = Color(1,1,1)
	hitbox.monitoring = false
	player.velocity = Vector2.ZERO
	var ground_y: float = 534.0
	player.global_position.y = ground_y
	if not player.is_on_floor():
		player.global_position.y = ground_y
	player.move_and_slide()
	var screen: CanvasLayer = player.get_tree().get_first_node_in_group("swoon_screen") as CanvasLayer
	if not screen:
		screen = player.get_tree().current_scene.get_node_or_null("SwoonScreen") as CanvasLayer
	if screen:
		screen.visible = true
		var bg: ColorRect = screen.get_node_or_null("Bg") as ColorRect
		if bg:
			bg.visible = true
		var img: TextureRect = screen.get_node_or_null("SwoonImage") as TextureRect
		if img:
			img.visible = true
			img.modulate = Color(1,1,1,1)
		var snd: AudioStreamPlayer = screen.get_node_or_null("SwoonSound") as AudioStreamPlayer
		if snd:
			snd.stop()
			snd.volume_db = 0.0
			snd.play()
		var tw: Tween = screen.get_tree().create_tween()
		tw.tween_interval(2.0)
		tw.tween_callback(func(): if is_instance_valid(screen): screen.visible = false)
	if "_health" in player and player._health:
		player._health.health = 0
		player._health._inv_timer = 1.6
		if player.has_method("_update_health_label"):
			player._update_health_label()
	elif player.has_method("damage"):
		player.set_meta("debug_godmode", false)
		player.damage(999.0)

func _spawn_afterimage(player: CharacterBody2D, anim: AnimatedSprite2D, grayscale: bool = true, color: Color = Color(1,1,1,0.32)) -> void:
	if not player or not anim or not anim.sprite_frames:
		return
	var ghost: Sprite2D = Sprite2D.new()
	var tex: Texture2D = anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if not tex:
		ghost.queue_free()
		return
	ghost.texture = tex
	ghost.global_position = anim.global_position
	ghost.scale = anim.global_scale
	ghost.flip_h = anim.flip_h
	ghost.flip_v = anim.flip_v
	ghost.centered = true
	if grayscale:
		ghost.modulate = Color(1, 1, 1, 0.32)
		var sh: Shader = preload("res://scripts/grayscale.gdshader")
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = sh
		ghost.material = mat
	else:
		ghost.modulate = color
		if color.b > 0.9 and color.r < 0.6:
			ghost.modulate.a = 0.45
	ghost.z_index = anim.z_index - 1
	player.get_parent().add_child(ghost)
	var tw: Tween = ghost.get_tree().create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ghost.queue_free)

func get_state() -> String:
	return _state

func is_invincible() -> bool:
	return _state == "dodge" and _timer > 0.05