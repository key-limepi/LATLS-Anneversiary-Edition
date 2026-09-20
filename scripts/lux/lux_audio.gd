extends RefCounted
class_name LuxAudio

func update(player: CharacterBody2D, footsteps: AudioStreamPlayer, dir: float, effective_speed: float, streak_bonus: float, is_wall_sliding: bool, hit_timer: float) -> void:
	var in_hit: bool = hit_timer > 0.0
	var should_play: bool = player.is_on_floor() and not in_hit and not is_wall_sliding and absf(dir) > 0.05 and absf(player.velocity.x) > 25.0
	if should_play:
		var speed_ratio: float = clamp(absf(player.velocity.x) / effective_speed, 0.0, 1.2)
		var streak_pitch: float = 1.0 + streak_bonus * 0.45
		var target_pitch: float = lerp(0.85, 1.65, speed_ratio) * streak_pitch * randf_range(0.98, 1.02)
		target_pitch = clamp(target_pitch, 0.85, 1.9)
		footsteps.pitch_scale = lerp(footsteps.pitch_scale, target_pitch, 0.18)
		footsteps.volume_db = lerp(-10.0, -1.5, clamp(speed_ratio, 0.0, 1.0))
		if not footsteps.playing:
			footsteps.play()
	else:
		if footsteps.playing:
			footsteps.stop()