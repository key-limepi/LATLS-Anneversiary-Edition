extends RefCounted
class_name PlayerAnim

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