extends Node2D

# the online match scene, it reuses the offline level as the stage
# and spawns one fighter per player (ours is real, the others are puppets)

const LEVEL_SCENE: PackedScene = preload("res://scenes/level.tscn")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const MENU_PATH: String = "res://scenes/online_menu.tscn"

var fighters: Dictionary = {} # peer id -> Lux
var stats: Dictionary = {} # peer id -> {name, health, stocks}
var hud: OnlineHud

func _ready() -> void:
	if Net.match_info.is_empty():
		# opened this scene directly, nothing to play
		get_tree().change_scene_to_file.call_deferred(MENU_PATH)
		return

	_build_stage()
	hud = OnlineHud.new()
	add_child(hud)
	for info: Dictionary in Net.match_info:
		_spawn_fighter(info)

	Net.snapshot_received.connect(_on_snapshot)
	Net.player_hit.connect(_on_hit)
	Net.player_ko.connect(_on_ko)
	Net.player_respawned.connect(_on_respawn)
	Net.player_left.connect(_on_player_left)
	Net.fight_started.connect(_on_fight_started)
	Net.match_over.connect(_on_match_over)
	Net.back_to_lobby.connect(_go_to_menu)
	Net.lost_connection.connect(_on_lost_connection)

	hud.show_message("get ready", Net.match_countdown)
	hud.set_stats(stats)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Net.leave()
		_go_to_menu()

func _build_stage() -> void:
	var stage: Node = LEVEL_SCENE.instantiate()
	# the level comes with an offline player and the debug tools, we dont want those here
	for node_name: String in ["Player", "DebugUI"]:
		var extra: Node = stage.get_node_or_null(node_name)
		if extra:
			extra.free()
	add_child(stage)

func _spawn_fighter(info: Dictionary) -> void:
	var id: int = info["id"]
	var fighter: Lux = PLAYER_SCENE.instantiate()
	fighter.setup_online(id, info["name"], id == Net.my_id)
	fighter.position = info["pos"]
	add_child(fighter)
	fighters[id] = fighter
	stats[id] = {"name": info["name"], "health": info["health"], "stocks": info["stocks"]}

func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_PATH)

# ---- events from the server

func _on_snapshot(states: Dictionary) -> void:
	for id: int in states:
		if id != Net.my_id and fighters.has(id):
			fighters[id].push_state(states[id])

func _on_hit(victim_id: int, _attacker_id: int, health: float, knockback: Vector2) -> void:
	if not fighters.has(victim_id):
		return
	stats[victim_id]["health"] = health
	fighters[victim_id].net_hit(health, knockback)
	hud.set_stats(stats)

func _on_ko(id: int, stocks: int) -> void:
	if not fighters.has(id):
		return
	stats[id]["health"] = 0.0
	stats[id]["stocks"] = stocks
	fighters[id].net_ko()
	hud.set_stats(stats)
	if id == Net.my_id:
		hud.show_message("ko!", 1.5)

func _on_respawn(id: int, pos: Vector2, health: float, inv_time: float) -> void:
	if not fighters.has(id):
		return
	stats[id]["health"] = health
	fighters[id].net_respawn(pos, health, inv_time)
	hud.set_stats(stats)

func _on_player_left(id: int) -> void:
	if fighters.has(id):
		fighters[id].queue_free()
		fighters.erase(id)
		stats.erase(id)
		hud.set_stats(stats)

func _on_fight_started() -> void:
	hud.show_message("go!", 1.0)

func _on_match_over(winner_id: int) -> void:
	var text: String = "nobody won"
	if stats.has(winner_id):
		text = "%s wins!" % stats[winner_id]["name"]
	hud.show_message(text, 10.0)

func _on_lost_connection(_reason: String) -> void:
	_go_to_menu()
