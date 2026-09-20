extends RefCounted
class_name NetServer

# all the server side rules live here (health, stocks, ko, respawn, winner)
# Net makes one of these when it runs as the dedicated server
# clients own their own movement, the server only decides what a hit does

enum Phase { LOBBY, COUNTDOWN, FIGHT, RESULTS }

const MAX_PLAYERS: int = 4
const MIN_PLAYERS_TO_START: int = 1 # TODO: make this 2 for real matches, 1 is handy for testing
const SNAPSHOT_RATE: float = 30.0

const MAX_HEALTH: float = 5.0
const STOCKS: int = 3
const HIT_INVINCIBLE_TIME: float = 1.6
const SPAWN_INVINCIBLE_TIME: float = 2.0
const RESPAWN_TIME: float = 2.0
const COUNTDOWN_TIME: float = 3.0
const RESULTS_TIME: float = 5.0

const MAX_HIT_RANGE: float = 400.0 # generous on purpose because of lag
const MAX_HIT_DAMAGE: float = 4.0 # the wink blast is the biggest hit right now
const KNOCKBACK: Vector2 = Vector2(420, -280) # TODO: tune this, should grow with damage later

# x from -800 to 4800, y from -2000 to 2000
const BLAST_ZONE: Rect2 = Rect2(-800, -2000, 5600, 4000)
# TODO: these should come from the stage instead of living here
const SPAWN_POINTS: Array = [Vector2(120, 300), Vector2(240, 300), Vector2(620, 300), Vector2(910, 300)]

class Slot:
	var id: int = 0
	var player_name: String = ""
	var in_match: bool = false
	var alive: bool = false
	var health: float = 5.0
	var stocks: int = 3
	var inv_timer: float = 0.0
	var respawn_timer: float = 0.0
	var state: FighterState = FighterState.new()

var net: Node # the Net autoload, it owns the rpc functions
var players: Dictionary = {} # peer id -> Slot
var host_id: int = 0
var phase: Phase = Phase.LOBBY
var _phase_timer: float = 0.0
var _snapshot_timer: float = 0.0
var _match_size: int = 0

func setup(net_node: Node) -> void:
	net = net_node

# ---- joining and leaving

func on_join(id: int, raw_name: String) -> void:
	if players.has(id):
		return
	if players.size() >= MAX_PLAYERS:
		net.cl_rejected.rpc_id(id, "server is full")
		net.multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var slot: Slot = Slot.new()
	slot.id = id
	slot.player_name = _clean_name(raw_name)
	players[id] = slot
	if host_id == 0:
		host_id = id
	print("player joined: ", slot.player_name, " (", id, ")")
	send_roster()

func on_leave(id: int) -> void:
	if not players.has(id):
		return
	var slot: Slot = players[id]
	var was_playing: bool = slot.in_match
	players.erase(id)
	print("player left: ", slot.player_name, " (", id, ")")
	if id == host_id:
		host_id = 0
		for other in players:
			if host_id == 0 or other < host_id:
				host_id = other
	send_roster()
	if was_playing and phase != Phase.LOBBY:
		for other in participants():
			net.cl_player_left.rpc_id(other, id)
		check_match_end()

func send_roster() -> void:
	var list: Array = []
	for id in players:
		var slot: Slot = players[id]
		list.append({"id": id, "name": slot.player_name})
	var running: bool = phase != Phase.LOBBY
	for id in players:
		net.cl_roster.rpc_id(id, list, host_id, running)

func _clean_name(raw: String) -> String:
	var result: String = raw.replace("\n", " ").strip_edges().left(16)
	if result == "":
		result = "Player"
	return result

func participants() -> Array:
	var ids: Array = []
	for id in players:
		var slot: Slot = players[id]
		if slot.in_match:
			ids.append(id)
	return ids

# ---- match flow

func on_start_request(id: int) -> void:
	if id != host_id or phase != Phase.LOBBY:
		return
	if players.size() < MIN_PLAYERS_TO_START:
		return
	start_match()

func start_match() -> void:
	var info: Array = []
	var index: int = 0
	for id in players:
		var slot: Slot = players[id]
		slot.in_match = true
		slot.alive = true
		slot.health = MAX_HEALTH
		slot.stocks = STOCKS
		slot.inv_timer = 0.0
		slot.state = FighterState.new()
		slot.state.pos = SPAWN_POINTS[index % SPAWN_POINTS.size()]
		info.append({"id": id, "name": slot.player_name, "pos": slot.state.pos, "health": slot.health, "stocks": slot.stocks})
		index += 1
	_match_size = info.size()
	phase = Phase.COUNTDOWN
	_phase_timer = COUNTDOWN_TIME
	print("match started with ", _match_size, " players")
	for id in participants():
		net.cl_match_start.rpc_id(id, info, COUNTDOWN_TIME)
	send_roster()

func check_match_end() -> void:
	if phase != Phase.FIGHT and phase != Phase.COUNTDOWN:
		return
	var still_in: Array = []
	for id in participants():
		var slot: Slot = players[id]
		if slot.stocks > 0:
			still_in.append(id)
	# a solo practice match only ends when that one player is out of stocks
	if still_in.size() > 1:
		return
	if still_in.size() == 1 and _match_size < 2:
		return
	var winner: int = 0
	if still_in.size() == 1:
		winner = still_in[0]
	end_match(winner)

func end_match(winner: int) -> void:
	phase = Phase.RESULTS
	_phase_timer = RESULTS_TIME
	print("match over, winner: ", winner)
	for id in participants():
		net.cl_match_over.rpc_id(id, winner)

func _back_to_lobby() -> void:
	for id in participants():
		net.cl_back_to_lobby.rpc_id(id)
	for id in players:
		var slot: Slot = players[id]
		slot.in_match = false
		slot.alive = false
	phase = Phase.LOBBY
	send_roster()

# ---- called every physics frame by Net

func tick(delta: float) -> void:
	if phase == Phase.LOBBY:
		return

	_snapshot_timer += delta
	if _snapshot_timer >= 1.0 / SNAPSHOT_RATE - 0.001:
		_snapshot_timer = 0.0
		_send_snapshots()

	_phase_timer -= delta
	match phase:
		Phase.COUNTDOWN:
			if _phase_timer <= 0.0:
				phase = Phase.FIGHT
				for id in participants():
					net.cl_fight_start.rpc_id(id)
		Phase.FIGHT:
			_tick_fighters(delta)
		Phase.RESULTS:
			if _phase_timer <= 0.0:
				_back_to_lobby()

func _tick_fighters(delta: float) -> void:
	for id in participants():
		if phase != Phase.FIGHT:
			return # match ended while we were looping
		var slot: Slot = players[id]
		if slot.inv_timer > 0.0:
			slot.inv_timer -= delta
		if slot.alive:
			if not BLAST_ZONE.has_point(slot.state.pos):
				knock_out(slot)
		elif slot.stocks > 0:
			slot.respawn_timer -= delta
			if slot.respawn_timer <= 0.0:
				respawn(slot)

func _send_snapshots() -> void:
	var packed: Dictionary = {}
	for id in participants():
		var slot: Slot = players[id]
		if slot.alive:
			packed[id] = slot.state.to_array()
	var now: float = net.server_time()
	for id in participants():
		# everybody gets everyone except themselves
		var list: Array = []
		for other in packed:
			if other != id:
				list.append([other, packed[other]])
		net.cl_snapshot.rpc_id(id, now, list)

# ---- messages from clients

func on_state(id: int, arr: Array) -> void:
	if not players.has(id):
		return
	var slot: Slot = players[id]
	if not slot.in_match or not slot.alive:
		return
	var state: FighterState = FighterState.from_array(arr)
	if state != null:
		slot.state = state

func on_hit(attacker_id: int, victim_id: int, amount: float, dir: float) -> void:
	if phase != Phase.FIGHT:
		return
	if attacker_id == victim_id or not players.has(attacker_id) or not players.has(victim_id):
		return
	var attacker: Slot = players[attacker_id]
	var victim: Slot = players[victim_id]
	if not (attacker.alive and victim.alive):
		return
	if not is_finite(amount) or not is_finite(dir):
		return
	# dodge flag comes from the victim's last state so it can be a bit late, fine for now
	if victim.inv_timer > 0.0 or victim.state.dodging:
		return
	if attacker.state.pos.distance_to(victim.state.pos) > MAX_HIT_RANGE:
		return

	amount = clampf(amount, 0.0, MAX_HIT_DAMAGE)
	victim.health = maxf(victim.health - amount, 0.0)
	victim.inv_timer = HIT_INVINCIBLE_TIME
	var power: float = 0.5 + amount * 0.5
	var knock: Vector2 = Vector2(signf(dir) * KNOCKBACK.x, KNOCKBACK.y) * power
	for id in participants():
		net.cl_hit.rpc_id(id, victim_id, attacker_id, victim.health, knock)
	if victim.health <= 0.0:
		knock_out(victim)

# the client tells us when it lost by itself (the swoon thing)
func on_self_ko(id: int) -> void:
	if phase != Phase.FIGHT or not players.has(id):
		return
	knock_out(players[id])

func knock_out(slot: Slot) -> void:
	if not slot.alive:
		return
	slot.alive = false
	slot.health = 0.0
	slot.stocks -= 1
	for id in participants():
		net.cl_ko.rpc_id(id, slot.id, slot.stocks)
	if slot.stocks > 0:
		slot.respawn_timer = RESPAWN_TIME
	else:
		check_match_end()

func respawn(slot: Slot) -> void:
	slot.alive = true
	slot.health = MAX_HEALTH
	slot.inv_timer = SPAWN_INVINCIBLE_TIME
	slot.state = FighterState.new()
	slot.state.pos = SPAWN_POINTS.pick_random()
	for id in participants():
		net.cl_respawn.rpc_id(id, slot.id, slot.state.pos, slot.health, SPAWN_INVINCIBLE_TIME)
