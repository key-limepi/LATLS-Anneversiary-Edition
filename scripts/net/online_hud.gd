extends CanvasLayer
class_name OnlineHud

# simple text hud for online matches, everything is made in code

var _list: Label
var _ping: Label
var _message: Label
var _message_timer: float = 0.0
var _ping_timer: float = 0.0

func _ready() -> void:
	layer = 5

	_ping = _make_label(14)
	_ping.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ping.anchor_left = 1.0
	_ping.anchor_right = 1.0
	_ping.offset_left = -200
	_ping.offset_right = -16
	_ping.offset_top = 10

	_list = _make_label(16)
	_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_list.anchor_left = 1.0
	_list.anchor_right = 1.0
	_list.offset_left = -400
	_list.offset_right = -16
	_list.offset_top = 34

	_message = _make_label(48)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.offset_bottom = -140
	_message.visible = false

func _make_label(font_size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_child(label)
	return label

func _process(delta: float) -> void:
	_ping_timer -= delta
	if _ping_timer <= 0.0:
		_ping_timer = 0.5
		_ping.text = "ping %d ms" % Net.ping_ms
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message.visible = false

func show_message(text: String, seconds: float) -> void:
	_message.text = text
	_message.visible = true
	_message_timer = seconds

# stats is id -> {name, health, stocks}
func set_stats(stats: Dictionary) -> void:
	var lines: PackedStringArray = []
	var ids: Array = stats.keys()
	ids.sort()
	for id in ids:
		var s: Dictionary = stats[id]
		var mark: String = "> " if id == Net.my_id else ""
		lines.append("%s%s   hp %.1f   stocks %d" % [mark, s["name"], s["health"], s["stocks"]])
	_list.text = "\n".join(lines)
