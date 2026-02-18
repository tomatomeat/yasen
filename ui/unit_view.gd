extends Node2D
class_name UnitView

@export var cell_size := 24.0

var _unit_nodes: Dictionary = {}

func sync_units(units: Array[UnitState]) -> void:
	var existing_ids := _unit_nodes.keys()
	for unit in units:
		var node := _unit_nodes.get(unit.unit_instance_id) as Node2D
		if node == null:
			node = _create_unit_node(unit)
			_unit_nodes[unit.unit_instance_id] = node
		add_child(node)
		_update_unit_node(node, unit)
		existing_ids.erase(unit.unit_instance_id)

	for stale_id in existing_ids:
		var stale := _unit_nodes[stale_id] as Node
		if stale != null:
			stale.queue_free()
		_unit_nodes.erase(stale_id)

func _create_unit_node(unit: UnitState) -> Node2D:
	var body := Node2D.new()
	body.name = "Unit_%d" % unit.unit_instance_id
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/unit_01.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.add_child(sprite)
	return body

func _update_unit_node(node: Node2D, unit: UnitState) -> void:
	node.visible = not unit.dead
	node.position = Vector2((unit.position.x + 0.5) * cell_size, (unit.position.y + 0.5) * cell_size)
	node.rotation = _rotation_for_facing(unit.facing)
	var sprite := node.get_child(0) as Sprite2D
	sprite.modulate = Color(0.6, 0.8, 1.0) if unit.owner_id == 0 else Color(1.0, 0.7, 0.7)
	if unit.half_dead:
		sprite.modulate = sprite.modulate.darkened(0.35)

func _rotation_for_facing(facing: int) -> float:
	match facing:
		UnitState.Facing.NORTH:
			return 0.0
		UnitState.Facing.EAST:
			return PI * 0.5
		UnitState.Facing.SOUTH:
			return PI
		UnitState.Facing.WEST:
			return PI * 1.5
	return 0.0
