extends CanvasLayer

var _enabled: bool = false
var _flying: bool = false
var _slowmo: bool = false
var _godmode: bool = false
var _player: CharacterBody2D
var _label: RichTextLabel
var _fly_speed: float = 360.0

func _ready() -> void:
	_label = $DebugLabel as RichTextLabel
	_player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if not _player:
		_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	visible = false
	_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			_enabled = not _enabled
			visible = _enabled
			if _label:
				_label.visible = _enabled
			if not _enabled:
				_flying = false
				if _player:
					_player.set_meta("debug_flying", false)
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_1:
			_flying = not _flying
			if _player:
				_player.set_meta("debug_flying", _flying)
				_player.velocity = Vector2.ZERO
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_2:
			var cur: bool = get_tree().debug_collisions_hint
			get_tree().debug_collisions_hint = not cur
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_3:
			_slowmo = not _slowmo
			Engine.time_scale = 0.3 if _slowmo else 1.0
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_4:
			_spawn_platform()
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_5:
			if _player and _player.has_method("heal"):
				_player.heal(5.0)
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_6:
			if _player and _player.has_method("damage"):
				_player.damage(0.5)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_7:
			if _player:
				var a = _player.get("_attack")
				if a and a.has_method("_trigger_swoon"):
					var anim = _player.get_node_or_null("AnimatedSprite2D")
					var hb = _player.get_node_or_null("AttackHitbox")
					a._trigger_swoon(_player, anim, hb)
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_0:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
		elif _enabled and event.keycode == KEY_G:
			_godmode = not _godmode
			if _player:
				_player.set_meta("debug_godmode", _godmode)
			get_viewport().set_input_as_handled()
	if _enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player:
			var mouse_global: Vector2 = _player.get_global_mouse_position()
			_player.global_position = mouse_global
			_player.velocity = Vector2.ZERO
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not _enabled or not _player or not _label:
		return
	var fps: int = Engine.get_frames_per_second()
	var pos: Vector2 = _player.global_position
	var vel: Vector2 = _player.velocity
	var on_floor: bool = _player.is_on_floor()
	var on_wall: bool = _player.is_on_wall_only() if _player.has_method("is_on_wall_only") else _player.is_on_wall()
	var on_ceiling: bool = _player.is_on_ceiling()
	var health: String = ""
	if "health" in _player:
		health = str(_player.health) if "health" in _player else ""
	else:
		var h = _player.get("_health")
		if h:
			health = "%.1f/%d" % [h.health, h.max_health]
		else:
			health = "?"
	var bonus: float = 0.0
	var streak: float = 0.0
	var eff_speed: float = 0.0
	if "_momentum" in _player and _player._momentum:
		bonus = _player._momentum.get_bonus()
		streak = _player._momentum.get_streak() if _player._momentum.has_method("get_streak") else 0.0
		eff_speed = _player._momentum.effective_speed(_player.speed) if _player.has_method("get") else 0.0
	elif "_streak_bonus" in _player:
		bonus = _player._streak_bonus
	var wall_slide: bool = false
	if "_wall" in _player and _player._wall:
		wall_slide = _player._wall.is_sliding()
	elif "_is_wall_sliding" in _player:
		wall_slide = _player._is_wall_sliding
	var wall_coyote: float = 0.0
	if "_wall" in _player and _player._wall and "_wall_coyote" in _player._wall:
		wall_coyote = _player._wall._wall_coyote
	var air_jumps: int = 0
	var max_air: int = 0
	if "_movement" in _player and _player._movement:
		air_jumps = _player._movement._air_jumps_left
		max_air = _player._movement.max_air_jumps
	var hit_timer: float = _get_timer("_hit_timer")
	var inv: bool = false
	if "_health" in _player and _player._health:
		inv = _player._health.is_invincible()

	_label.text = "fps: %d\n" % fps
	_label.text += "pos: (%.1f, %.1f) tile: (%d,%d)\n" % [pos.x, pos.y, int(pos.x/16), int(pos.y/16)]
	_label.text += "vel: (%.1f, %.1f) spd: %.1f eff: %.1f\n" % [vel.x, vel.y, vel.length(), eff_speed]
	_label.text += "floor:%s wall:%s ceil:%s slide:%s\n" % [str(on_floor).to_lower(), str(on_wall).to_lower(), str(on_ceiling).to_lower(), str(wall_slide).to_lower()]
	_label.text += "health: %s inv:%s hit:%.2f god:%s\n" % [health.to_lower(), str(inv).to_lower(), hit_timer, str(_godmode).to_lower()]
	_label.text += "streak: %.1fx (%.2f/%.1fs) \n" % [1.0 + bonus, bonus, streak]
	_label.text += "coyote: %.2f buffer: %.2f wcoy: %.2f\n" % [_get_timer("_coyote_timer"), _get_timer("_jump_buffer_timer"), wall_coyote]
	_label.text += "air jumps: %d/%d\n" % [air_jumps, max_air]
	_label.text += "fall vel: %.1f hurt:950 heavy:1300 insta:1900\n" % vel.y
	_label.text += "fly:%s [1]  teleport:[click]  god:[g] coll:[2] slow:[3] plat:[4] heal:[5] hurt:[6] reset:[0] swoon:[7]\n" % str(_flying).to_lower()
	_label.text += "fly spd:%.0f%s slow:%s\n" % [_fly_speed, " (shift 2x)" if Input.is_key_pressed(KEY_SHIFT) else "", str(_slowmo).to_lower()]

func _spawn_platform() -> void:
	if not _player:
		return
	var level: Node = get_parent()
	var plat: StaticBody2D = StaticBody2D.new()
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(220, 20)
	col.shape = shape
	var vis: ColorRect = ColorRect.new()
	vis.offset_left = -110
	vis.offset_top = -10
	vis.offset_right = 110
	vis.offset_bottom = 10
	vis.color = Color(0.6, 0.9, 0.4, 1)
	plat.position = _player.get_global_mouse_position()
	plat.add_child(col)
	plat.add_child(vis)
	level.add_child(plat)

func _get_timer(var_name: String) -> float:
	if not _player:
		return 0.0
	var m = _player.get("_movement")
	if m and var_name in m:
		return m.get(var_name)
	if var_name in _player:
		return _player.get(var_name)
	return 0.0
