extends RefCounted
class_name LuxAnim

var _base_scale: Vector2 = Vector2(0.32, 0.32)

func squash(anim: AnimatedSprite2D, sx: float, sy: float, time1: float = 0.09, time2: float = 0.14) -> void:
	if not anim:
		return
	_base_scale = anim.scale if anim.scale.length() > 0.1 else _base_scale
	var target: Vector2 = Vector2(_base_scale.x * sx, _base_scale.y * sy)
	var tw: Tween = anim.get_tree().create_tween() if anim.is_inside_tree() else null
	if tw:
		tw.tween_property(anim, "scale", target, time1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(anim, "scale", _base_scale, time2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func update(player: CharacterBody2D, anim: AnimatedSprite2D, dir: float, is_wall_sliding: bool, hit_timer: float, streak_bonus: float) -> void:
	if hit_timer > 0.0:
		if anim.animation != &"hit":
			anim.play("hit")
		return
	if is_wall_sliding:
		if anim.animation != &"slide":
			anim.play("slide")
		return
	if not player.is_on_floor():
		if player.velocity.y < 0:
			if anim.animation != &"jump":
				anim.play("jump")
		else:
			var holding_jump: bool = Input.is_action_pressed("jump")
			if not holding_jump:
				if anim.animation != &"fall":
					anim.play("fall")
			else:
				if anim.animation != &"jump":
					anim.play("jump")
		return
	if absf(player.velocity.x) > 10.0 and absf(dir) > 0.05:
		if anim.animation != &"run":
			anim.play("run")
		var speed: float = player.speed if "speed" in player else 220.0
		var streak_mult: float = 1.0 + streak_bonus * 0.6
		var run_speed: float = clamp(absf(player.velocity.x) / speed * streak_mult, 0.7, 2.0)
		anim.speed_scale = run_speed
	else:
		if anim.animation != &"idle":
			anim.play("idle")
		anim.speed_scale = 1.0

func handle_flip(player: CharacterBody2D, anim: AnimatedSprite2D, dir: float, is_wall_sliding: bool, in_hit_stun: bool) -> void:
	if is_wall_sliding:
		var n: float = player.get_wall_normal().x
		if absf(n) < 0.1 and player.is_on_wall_only():
			n = player.get_wall_normal().x
		anim.flip_h = n > 0
	elif dir != 0 and not in_hit_stun:
		anim.flip_h = dir < 0