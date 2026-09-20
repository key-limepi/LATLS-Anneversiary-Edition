extends RefCounted
class_name FighterState

# one snapshot of a fighter, this is what gets sent over the wire

var time: float = 0.0 # server time, only filled in on the receiving side
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var anim: String = "idle"
var flip: bool = false
var anim_speed: float = 1.0
var rot: float = 0.0
var tint: Color = Color(1, 1, 1, 1)
var gray: bool = false
var dodging: bool = false

# order matters here, keep it the same as to_array
const TYPES: Array = [TYPE_VECTOR2, TYPE_VECTOR2, TYPE_STRING, TYPE_BOOL, TYPE_FLOAT, TYPE_FLOAT, TYPE_COLOR, TYPE_BOOL, TYPE_BOOL]

func to_array() -> Array:
	return [pos, vel, anim, flip, anim_speed, rot, tint, gray, dodging]

# returns null if the data looks wrong, never trust what clients send
static func from_array(arr: Array) -> FighterState:
	if arr.size() != TYPES.size():
		return null
	for i: int in range(TYPES.size()):
		if typeof(arr[i]) != TYPES[i]:
			return null
	var s: FighterState = FighterState.new()
	s.pos = arr[0]
	s.vel = arr[1]
	s.anim = arr[2]
	s.flip = arr[3]
	s.anim_speed = arr[4]
	s.rot = arr[5]
	s.tint = arr[6]
	s.gray = arr[7]
	s.dodging = arr[8]
	if not s.pos.is_finite() or not s.vel.is_finite() or s.anim.length() > 32:
		return null
	return s
