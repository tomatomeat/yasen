extends RefCounted
class_name UnitState

enum Facing {
	NORTH,
	EAST,
	SOUTH,
	WEST
}

var unit_instance_id := 0
var owner_id := 0
var data: UnitData
var position := Vector2i.ZERO
var facing: Facing = Facing.NORTH
var half_dead := false
var dead := false
var in_extra := false
var extra_wait_turns := 0

func _init(p_id := 0, p_owner := 0, p_data: UnitData = null, p_position := Vector2i.ZERO, p_facing := Facing.NORTH) -> void:
	unit_instance_id = p_id
	owner_id = p_owner
	data = p_data if p_data != null else UnitData.new()
	position = p_position
	facing = p_facing

func rotate_left() -> void:
	facing = wrapi(facing - 1, 0, 4) as Facing

func rotate_right() -> void:
	facing = wrapi(facing + 1, 0, 4) as Facing

func get_forward_vector() -> Vector2i:
	match facing:
		Facing.NORTH:
			return Vector2i(0, -1)
		Facing.EAST:
			return Vector2i(1, 0)
		Facing.SOUTH:
			return Vector2i(0, 1)
		Facing.WEST:
			return Vector2i(-1, 0)
	return Vector2i.ZERO

func get_back_vector() -> Vector2i:
	return -get_forward_vector()

func get_world_offset(local_offset: Vector2i) -> Vector2i:
	match facing:
		Facing.NORTH:
			return local_offset
		Facing.EAST:
			return Vector2i(-local_offset.y, local_offset.x)
		Facing.SOUTH:
			return Vector2i(-local_offset.x, -local_offset.y)
		Facing.WEST:
			return Vector2i(local_offset.y, -local_offset.x)
	return local_offset

func get_candidate_moves() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in data.move_offsets:
		result.append(position + get_world_offset(offset))
	return result

func get_visible_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in data.vision_offsets:
		result.append(position + get_world_offset(offset))
	return result

func get_blind_cells() -> Array[Vector2i]:
	# Three cells directly behind this unit are blind.
	var behind := get_back_vector()
	var left := get_world_offset(Vector2i(-1, 0))
	var right := get_world_offset(Vector2i(1, 0))
	return [position + behind, position + behind + left, position + behind + right]

func to_debug_string() -> String:
	return "%s owner=%d pos=%s facing=%d half=%s dead=%s" % [data.unit_id, owner_id, position, facing, half_dead, dead]
