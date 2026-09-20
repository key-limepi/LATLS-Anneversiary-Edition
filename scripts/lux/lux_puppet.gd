extends RefCounted
class_name LuxPuppet

# drives a remote fighter, it just plays back snapshots a little bit late
# so we always have two of them to blend between

const MAX_EXTRAPOLATE: float = 0.12
const MAX_BUFFER: int = 30

var _buffer: Array[FighterState] = []
var _gray_material: ShaderMaterial = null

func push(state: FighterState) -> void:
	if not _buffer.is_empty():
		var last: FighterState = _buffer.back()
		if state.time <= last.time:
			return # old or duplicate, ignore
	_buffer.append(state)
	if _buffer.size() > MAX_BUFFER:
		_buffer.pop_front()

func clear() -> void:
	_buffer.clear()

func update(fighter: Node2D, anim: AnimatedSprite2D) -> void:
	if _buffer.is_empty():
		return
	var render_time: float = Net.server_time() - Net.INTERP_DELAY
	# drop snapshots we already passed but keep one behind us
	while _buffer.size() > 2 and _buffer[1].time <= render_time:
		_buffer.pop_front()

	var a: FighterState = _buffer[0]
	var pos: Vector2 = a.pos
	var look: FighterState = a
	if _buffer.size() > 1:
		var b: FighterState = _buffer[1]
		if render_time >= b.time:
			# ran out of snapshots, guess a tiny bit
			var extra: float = minf(render_time - b.time, MAX_EXTRAPOLATE)
			pos = b.pos + b.vel * extra
			look = b
		else:
			var t: float = clampf(inverse_lerp(a.time, b.time, render_time), 0.0, 1.0)
			pos = a.pos.lerp(b.pos, t)
			look = b if t > 0.5 else a
	fighter.global_position = pos
	_apply_look(anim, look)

func _apply_look(anim: AnimatedSprite2D, s: FighterState) -> void:
	if String(anim.animation) != s.anim and anim.sprite_frames.has_animation(s.anim):
		anim.play(s.anim)
	anim.flip_h = s.flip
	anim.speed_scale = s.anim_speed
	anim.rotation = s.rot
	anim.modulate = s.tint
	if s.gray:
		if _gray_material == null:
			_gray_material = ShaderMaterial.new()
			_gray_material.shader = preload("res://scripts/grayscale.gdshader")
		anim.material = _gray_material
	else:
		anim.material = null
