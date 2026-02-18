@tool
extends Node2D
class_name BoardView

@export var cell_size: int = 16
@export var board_color: Color = Color(0.18,0.18,0.18)
@export var grid_color: Color = Color(0.1,0.1,0.1)
@export var visible_color: Color = Color(0.0, 0.6, 0.0, 0.25)
@export var possible_color: Color = Color(0.6, 0.6, 0.0, 0.35)

# board dimensions will be read from GameState via owner (Main)
# helper: convert board cell (Vector2i) -> world pos (top-left of cell)
func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * cell_size, cell.y * cell_size)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var x = int(world_pos.x / cell_size)
	var y = int(world_pos.y / cell_size)
	return Vector2i(x, y)

# Draw grid given width/height provided by owner (Main)
func _draw_board(width: int, height: int, extra_rows: int) -> void:
	# background
	draw_rect(Rect2(Vector2.ZERO, Vector2(width * cell_size, (height + extra_rows*2) * cell_size)), board_color)

	# grid lines
	for i in range(width+1):
		var x = i * cell_size
		draw_line(Vector2(x,0), Vector2(x,(height+extra_rows*2) * cell_size), grid_color, 1)
	for j in range((height + extra_rows*2)+1):
		var y = j * cell_size
		draw_line(Vector2(0,y), Vector2(width * cell_size, y), grid_color, 1)

func redraw(state) -> void:
	if state == null:
		update()
		return
	var w = state.board_width
	var h = state.board_height
	var e = state.extra_rows
	_clear_draw()
	_draw_board(w, h, e)
	update()

func _clear_draw():
	# nothing to clear; update() will trigger _draw
	pass

func _draw():
	# nothing here; Main will call draw overlays via helper functions if needed
	pass

# convenience: draw visible/fog overlays from a list of cells
func draw_visible_cells(cells: Array) -> void:
	for c in cells:
		var pos = cell_to_world(c)
		draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), visible_color)

func draw_possible_cells(cells: Array) -> void:
	for c in cells:
		var pos = cell_to_world(c)
		draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), possible_color)

# Handle input: translate click to cell and emit signal
signal cell_clicked(cell: Vector2i)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var wp = to_local(event.position)
		var cell = world_to_cell(wp)
		emit_signal("cell_clicked", cell)
