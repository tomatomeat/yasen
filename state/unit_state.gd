extends RefCounted
class_name UnitState

enum Facing { NORTH, SOUTH, EAST, WEST }

var id: String
var owner: int
var position: Vector2i
var facing: Facing

var is_dead: bool = false
var is_half_dead: bool = false
# half_dead 時に自動復帰までのターンカウント（例: 1 ターン後に前に出る）
var extra_wait_turns: int = 0

func _init(_id: String, _owner: int, _pos: Vector2i, _facing: Facing):
	id = _id
	owner = _owner
	position = _pos
	facing = _facing
