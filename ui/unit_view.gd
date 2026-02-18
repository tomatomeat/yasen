extends Node2D
class_name UnitView

@export var cell_size: int = 16
var unit_id: String
var owner_: int
var sprite: Sprite2D

func _init():
	pass

func _ready():
	# create a simple Sprite2D; replace with AnimatedSprite2D if needed
	sprite = Sprite2D.new()
	add_child(sprite)
	sprite.centered = true
	sprite.scale = Vector2(0.9, 0.9)

func set_unit(unit: Object) -> void:
	# unit is UnitState
	unit_id = unit.id
	owner = unit.owner
	_update_visual(unit)

func _update_visual(unit) -> void:
	# position
	position = Vector2(unit.position.x * cell_size + cell_size*0.5, unit.position.y * cell_size + cell_size*0.5)
	# sprite image: try load res://assets/units/{id}.png; fallback colored rectangle
	var path = "res://assets/units/%s.png" % unit.id
	if ResourceLoader.exists(path):
		var tex = load(path)
		sprite.texture = tex
	else:
		# simple generated texture for debug
		var img = Image.new()
		img.create(cell_size, cell_size, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.8,0.2,0.2) if owner_ == 1 else Color(0.2,0.2,0.8))
		var tex = ImageTexture.create_from_image(img)
		sprite.texture = tex
	# rotation for facing
	match unit.facing:
		UnitState.Facing.NORTH:
			rotation_degrees = 0
		UnitState.Facing.EAST:
			rotation_degrees = 90
		UnitState.Facing.SOUTH:
			rotation_degrees = 180
		UnitState.Facing.WEST:
			rotation_degrees = 270
	# visual for half-dead / dead:
	if unit.is_dead:
		modulate = Color(0.2,0.2,0.2,0.6)
	elif unit.is_half_dead:
		modulate = Color(1,1,1,0.6)
	else:
		modulate = Color(1,1,1,1)
