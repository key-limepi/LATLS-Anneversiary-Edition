extends Node2D

@export var texture: Texture2D
@export var flake_count: int = 220

@export_group("Depth")
@export var parallax_far: float = 1.0
@export var parallax_near: float = 1.0
@export var size_far: float = 1.0
@export var size_near: float = 3.4
@export var alpha_far: float = 0.35
@export var alpha_near: float = 1.0
@export var near_rarity: float = 1.6

@export_group("Motion")
@export var fall_speed_far: float = 40.0
@export var fall_speed_near: float = 140.0
@export var wind: float = 18.0
@export var sway_amount: float = 14.0
@export var sway_speed: float = 1.2
@export var wrap_margin: float = 30.0

var _base: PackedVector2Array = PackedVector2Array()
var _depth: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _sway_rate: PackedFloat32Array = PackedFloat32Array()
var _time: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var area: Vector2 = _wrap_area()

	var depths: Array[float] = []
	for i: int in range(flake_count):
		depths.append(pow(rng.randf(), near_rarity))
	depths.sort()

	for i: int in range(flake_count):
		_depth.append(depths[i])
		_base.append(Vector2(rng.randf() * area.x, rng.randf() * area.y))
		_phase.append(rng.randf() * TAU)
		_sway_rate.append(rng.randf_range(0.7, 1.3))

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	if texture == null:
		return
	var area: Vector2 = _wrap_area()
	var cam: Vector2 = get_viewport().get_canvas_transform().origin
	for i: int in range(_depth.size()):
		var pos: Vector2 = _flake_screen_position(i, area, cam)
		var z: float = _depth[i]
		var s: float = lerpf(size_far, size_near, z)
		var px: Vector2 = texture.get_size() * s
		draw_texture_rect(texture, Rect2(pos - px * 0.5, px), false, Color(1, 1, 1, lerpf(alpha_far, alpha_near, z)))

func flake_screen_position(i: int) -> Vector2:
	return _flake_screen_position(i, _wrap_area(), get_viewport().get_canvas_transform().origin)

func _flake_screen_position(i: int, area: Vector2, cam: Vector2) -> Vector2:
	var z: float = _depth[i]
	var near_scale: float = 0.5 + z
	var parallax: float = lerpf(parallax_far, parallax_near, z)
	var fall: float = lerpf(fall_speed_far, fall_speed_near, z)

	var x: float = _base[i].x + cam.x * parallax
	x += wind * near_scale * _time
	x += sin(_time * sway_speed * _sway_rate[i] + _phase[i]) * sway_amount * near_scale
	var y: float = _base[i].y + cam.y * parallax + fall * _time

	return Vector2(fposmod(x, area.x) - wrap_margin, fposmod(y, area.y) - wrap_margin)

func _wrap_area() -> Vector2:
	return get_viewport_rect().size + Vector2(wrap_margin, wrap_margin) * 2.0
