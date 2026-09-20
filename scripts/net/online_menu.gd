extends Control

# connect screen and lobby, all the ui is built in code so the scene stays empty

const GAME_SCENE: String = "res://scenes/online_game.tscn"
const OFFLINE_SCENE: String = "res://scenes/level.tscn"

var _name_edit: LineEdit
var _url_edit: LineEdit
var _join_button: Button
var _status: Label
var _connect_box: VBoxContainer
var _lobby_box: VBoxContainer
var _roster_label: Label
var _start_button: Button

func _ready() -> void:
	if Net.is_dedicated_server:
		return # nothing to show on the server
	_build_ui()
	Net.joined.connect(_show_lobby)
	Net.join_failed.connect(_on_connection_problem)
	Net.lost_connection.connect(_on_connection_problem)
	Net.roster_changed.connect(_refresh_lobby)
	Net.match_started.connect(_on_match_started)

	if Net.is_joined():
		_show_lobby()
	else:
		_show_connect()
	# tell the player why they ended up here (kicked, server went away, etc)
	if Net.notice != "":
		_status.text = Net.notice
		Net.notice = ""

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.121569, 0.141176, 0.223529, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title: Label = Label.new()
	title.text = "Lux And The Lightshard"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	# connect part
	_connect_box = VBoxContainer.new()
	_connect_box.add_theme_constant_override("separation", 8)
	box.add_child(_connect_box)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "your name"
	_name_edit.max_length = 16
	_name_edit.text = "Lux%d" % randi_range(1, 99)
	_connect_box.add_child(_name_edit)

	_url_edit = LineEdit.new()
	_url_edit.placeholder_text = "server address"
	_url_edit.text = Net.default_server_url()
	_connect_box.add_child(_url_edit)

	_join_button = Button.new()
	_join_button.text = "Play Online"
	_join_button.pressed.connect(_on_join_pressed)
	_connect_box.add_child(_join_button)

	var offline_button: Button = Button.new()
	offline_button.text = "Offline Practice"
	offline_button.pressed.connect(_on_offline_pressed)
	_connect_box.add_child(offline_button)

	# lobby part
	_lobby_box = VBoxContainer.new()
	_lobby_box.add_theme_constant_override("separation", 8)
	box.add_child(_lobby_box)

	_roster_label = Label.new()
	_lobby_box.add_child(_roster_label)

	_start_button = Button.new()
	_start_button.pressed.connect(_on_start_pressed)
	_lobby_box.add_child(_start_button)

	var leave_button: Button = Button.new()
	leave_button.text = "Leave"
	leave_button.pressed.connect(_on_leave_pressed)
	_lobby_box.add_child(leave_button)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

func _show_connect() -> void:
	_connect_box.visible = true
	_lobby_box.visible = false
	_join_button.disabled = false

func _show_lobby() -> void:
	_connect_box.visible = false
	_lobby_box.visible = true
	_status.text = ""
	_refresh_lobby()

func _refresh_lobby() -> void:
	if not _lobby_box.visible:
		return
	var lines: PackedStringArray = ["players:"]
	for entry: Dictionary in Net.roster:
		var line: String = "  " + entry["name"]
		if entry["id"] == Net.host_id:
			line += "  (host)"
		if entry["id"] == Net.my_id:
			line += "  (you)"
		lines.append(line)
	_roster_label.text = "\n".join(lines)

	if Net.match_running:
		_start_button.text = "Match in progress, wait for the next one"
		_start_button.disabled = true
	elif Net.is_host():
		_start_button.text = "Start Match"
		_start_button.disabled = false
	else:
		_start_button.text = "Waiting for the host to start"
		_start_button.disabled = true

func _on_join_pressed() -> void:
	var url: String = _url_edit.text.strip_edges()
	if not (url.begins_with("ws://") or url.begins_with("wss://")):
		url = "ws://" + url
	_status.text = "connecting..."
	_join_button.disabled = true
	Net.join(url, _name_edit.text)

func _on_offline_pressed() -> void:
	Net.leave()
	get_tree().change_scene_to_file(OFFLINE_SCENE)

func _on_start_pressed() -> void:
	Net.request_start()

func _on_leave_pressed() -> void:
	Net.leave()
	_show_connect()

func _on_connection_problem(reason: String) -> void:
	_show_connect()
	_status.text = reason
	Net.notice = ""

func _on_match_started() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
