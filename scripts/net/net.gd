extends Node

# this is the Net autoload, all the network stuff goes through here
# browsers cant host or use udp, so the server is a dedicated (headless) godot
# process and everybody connects to it with websockets
# run it with: godot --headless -- --server --port=9080

signal joined
signal join_failed(reason: String)
signal lost_connection(reason: String)
signal roster_changed
signal match_started
signal fight_started
signal snapshot_received(states: Dictionary)
signal player_hit(victim_id: int, attacker_id: int, health: float, knockback: Vector2)
signal player_ko(id: int, stocks: int)
signal player_respawned(id: int, pos: Vector2, health: float, inv_time: float)
signal player_left(id: int)
signal match_over(winner_id: int)
signal back_to_lobby

const DEFAULT_PORT: int = 9080
const SEND_RATE: float = 30.0 # how many times a second we send our fighter state
const INTERP_DELAY: float = 0.1 # remote fighters are shown this many seconds in the past
const CONNECT_TIMEOUT: float = 8.0

# put your real server here before exporting, like "wss://play.example.com"
# an https page can only talk to wss:// so you need tls (a reverse proxy is the easy way)
const PUBLIC_SERVER_URL: String = ""

var is_dedicated_server: bool = false
var my_id: int = 0
var my_name: String = "Lux"
var roster: Array = [] # [{id, name}]
var host_id: int = 0
var match_running: bool = false
var match_info: Array = []
var match_countdown: float = 0.0
var ping_ms: int = 0
var notice: String = "" # the menu shows this once (why we got disconnected etc)

var _server: NetServer = null
var _connecting: bool = false
var _connected: bool = false
var _joined: bool = false
var _connect_timer: float = 0.0
var _ping_timer: float = 0.0
var _ping_count: int = 0
var _clock_offset: float = 0.0
var _got_clock: bool = false

func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if OS.has_feature("dedicated_server") or "--server" in _all_args():
		start_server()

func _physics_process(delta: float) -> void:
	if _server != null:
		_server.tick(delta)
		return
	if _connecting:
		_connect_timer -= delta
		if _connect_timer <= 0.0:
			_handle_lost("could not reach the server")
	elif _connected:
		_ping_timer -= delta
		if _ping_timer <= 0.0:
			# ping a lot at the start so the clock settles fast, then slow down
			_ping_count += 1
			_ping_timer = 0.3 if _ping_count < 8 else 2.0
			srv_ping.rpc_id(1, Time.get_ticks_msec())

# ---- helpers

func is_joined() -> bool:
	return _joined

func is_host() -> bool:
	return _joined and my_id == host_id

func server_time() -> float:
	return Time.get_ticks_msec() / 1000.0 + _clock_offset

func default_server_url() -> String:
	if PUBLIC_SERVER_URL != "":
		return PUBLIC_SERVER_URL
	if OS.has_feature("web"):
		var host: String = str(JavaScriptBridge.eval("window.location.hostname"))
		var secure: bool = str(JavaScriptBridge.eval("window.location.protocol")) == "https:"
		if secure:
			return "wss://%s" % host
		return "ws://%s:%d" % [host, DEFAULT_PORT]
	return "ws://127.0.0.1:%d" % DEFAULT_PORT

# args after the -- only show up in the user args, so look at both
func _all_args() -> PackedStringArray:
	return OS.get_cmdline_args() + OS.get_cmdline_user_args()

func _get_arg(key: String) -> String:
	for arg: String in _all_args():
		if arg.begins_with(key + "="):
			return arg.substr(key.length() + 1)
	return ""

# ---- server side setup

func start_server() -> void:
	is_dedicated_server = true
	var port: int = DEFAULT_PORT
	# hosting sites like to give the port through an env variable
	if OS.get_environment("PORT").is_valid_int():
		port = OS.get_environment("PORT").to_int()
	if _get_arg("--port").is_valid_int():
		port = _get_arg("--port").to_int()

	# optional, only needed if you dont put a reverse proxy in front for wss
	var tls: TLSOptions = null
	if _get_arg("--cert") != "" and _get_arg("--key") != "":
		var cert: X509Certificate = X509Certificate.new()
		var key: CryptoKey = CryptoKey.new()
		if cert.load(_get_arg("--cert")) == OK and key.load(_get_arg("--key")) == OK:
			tls = TLSOptions.server(key, cert)
		else:
			push_error("could not load the tls cert or key")

	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_server(port, "*", tls)
	if err != OK:
		push_error("could not start server: " + error_string(err))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	my_id = 1
	_server = NetServer.new()
	_server.setup(self)
	print("server is up on port ", port)

# ---- client side connecting

func join(url: String, player_name: String) -> void:
	leave()
	my_name = player_name.strip_edges().left(16)
	if my_name == "":
		my_name = "Lux"
	var peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var err: Error = peer.create_client(url)
	if err != OK:
		notice = "bad server address"
		join_failed.emit(notice)
		return
	multiplayer.multiplayer_peer = peer
	_connecting = true
	_connect_timer = CONNECT_TIMEOUT

func leave() -> void:
	if _server != null:
		return
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	_reset_client_state()

func _reset_client_state() -> void:
	_connecting = false
	_connected = false
	_joined = false
	_got_clock = false
	_ping_count = 0
	my_id = 0
	host_id = 0
	roster = []
	match_running = false
	match_info = []
	ping_ms = 0

func _on_connected() -> void:
	_connecting = false
	_connected = true
	my_id = multiplayer.get_unique_id()
	_ping_timer = 0.0
	srv_join.rpc_id(1, my_name)

func _on_connection_failed() -> void:
	_handle_lost("could not reach the server")

func _on_server_disconnected() -> void:
	_handle_lost("lost connection to the server")

func _on_peer_disconnected(id: int) -> void:
	if _server != null:
		_server.on_leave(id)

func _handle_lost(reason: String) -> void:
	if not _connecting and not _connected:
		return
	var was_joined: bool = _joined
	notice = reason
	_reset_client_state()
	call_deferred("leave") # closing the peer inside its own signal is asking for trouble
	if was_joined:
		lost_connection.emit(reason)
	else:
		join_failed.emit(reason)

# ---- stuff the game calls

func send_state(state: FighterState) -> void:
	if _connected:
		srv_state.rpc_id(1, state.to_array())

func report_hit(victim_id: int, amount: float, dir: float) -> void:
	if _connected:
		srv_hit.rpc_id(1, victim_id, amount, dir)

func report_self_ko() -> void:
	if _connected:
		srv_self_ko.rpc_id(1)

func request_start() -> void:
	if _connected:
		srv_start.rpc_id(1)

# ---- rpc: client -> server

@rpc("any_peer", "call_remote", "reliable")
func srv_join(player_name: String) -> void:
	if _server == null:
		return
	_server.on_join(multiplayer.get_remote_sender_id(), player_name)

@rpc("any_peer", "call_remote", "reliable")
func srv_start() -> void:
	if _server == null:
		return
	_server.on_start_request(multiplayer.get_remote_sender_id())

# unreliable_ordered because a lost state does not matter, the next one replaces it
# (websockets are always reliable anyway, but this helps if we switch to webrtc later)
@rpc("any_peer", "call_remote", "unreliable_ordered")
func srv_state(arr: Array) -> void:
	if _server == null:
		return
	_server.on_state(multiplayer.get_remote_sender_id(), arr)

@rpc("any_peer", "call_remote", "reliable")
func srv_hit(victim_id: int, amount: float, dir: float) -> void:
	if _server == null:
		return
	_server.on_hit(multiplayer.get_remote_sender_id(), victim_id, amount, dir)

@rpc("any_peer", "call_remote", "reliable")
func srv_self_ko() -> void:
	if _server == null:
		return
	_server.on_self_ko(multiplayer.get_remote_sender_id())

@rpc("any_peer", "call_remote", "unreliable")
func srv_ping(client_ms: int) -> void:
	if _server == null:
		return
	cl_pong.rpc_id(multiplayer.get_remote_sender_id(), client_ms, server_time())

# ---- rpc: server -> client

@rpc("authority", "call_remote", "unreliable")
func cl_pong(client_ms: int, server_t: float) -> void:
	var now_ms: int = Time.get_ticks_msec()
	var rtt: float = (now_ms - client_ms) / 1000.0
	ping_ms = int(rtt * 1000.0)
	# assume the trip back took half of the round trip
	var sample: float = server_t + rtt * 0.5 - now_ms / 1000.0
	if not _got_clock:
		_clock_offset = sample
		_got_clock = true
	else:
		_clock_offset = lerpf(_clock_offset, sample, 0.1)

@rpc("authority", "call_remote", "reliable")
func cl_rejected(reason: String) -> void:
	notice = reason
	_reset_client_state()
	call_deferred("leave")
	join_failed.emit(reason)

@rpc("authority", "call_remote", "reliable")
func cl_roster(list: Array, host: int, running: bool) -> void:
	roster = list
	host_id = host
	match_running = running
	if not _joined:
		_joined = true
		joined.emit()
	roster_changed.emit()

@rpc("authority", "call_remote", "reliable")
func cl_match_start(info: Array, countdown: float) -> void:
	match_info = info
	match_countdown = countdown
	match_running = true
	match_started.emit()

@rpc("authority", "call_remote", "reliable")
func cl_fight_start() -> void:
	fight_started.emit()

@rpc("authority", "call_remote", "unreliable_ordered")
func cl_snapshot(server_t: float, list: Array) -> void:
	if not _got_clock:
		# snapshot beat the first pong, good enough until the real clock arrives
		_clock_offset = server_t - Time.get_ticks_msec() / 1000.0
		_got_clock = true
	var states: Dictionary = {}
	for entry: Array in list:
		var state: FighterState = FighterState.from_array(entry[1])
		if state != null:
			state.time = server_t
			states[entry[0]] = state
	snapshot_received.emit(states)

@rpc("authority", "call_remote", "reliable")
func cl_hit(victim_id: int, attacker_id: int, health: float, knockback: Vector2) -> void:
	player_hit.emit(victim_id, attacker_id, health, knockback)

@rpc("authority", "call_remote", "reliable")
func cl_ko(id: int, stocks: int) -> void:
	player_ko.emit(id, stocks)

@rpc("authority", "call_remote", "reliable")
func cl_respawn(id: int, pos: Vector2, health: float, inv_time: float) -> void:
	player_respawned.emit(id, pos, health, inv_time)

@rpc("authority", "call_remote", "reliable")
func cl_player_left(id: int) -> void:
	player_left.emit(id)

@rpc("authority", "call_remote", "reliable")
func cl_match_over(winner_id: int) -> void:
	match_over.emit(winner_id)

@rpc("authority", "call_remote", "reliable")
func cl_back_to_lobby() -> void:
	match_running = false
	back_to_lobby.emit()
