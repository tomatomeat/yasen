extends Resource
class_name UnitData

@export var unit_id: StringName = &"soldier"
@export var display_name := "Soldier"

# Relative offsets for movement and vision are interpreted from the unit's facing.
@export var move_offsets := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
@export var vision_offsets := [Vector2i(0, -1), Vector2i(-2, 0), Vector2i(2, 0), Vector2i(-1, -1), Vector2i(1, -1)]
