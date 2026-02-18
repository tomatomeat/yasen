extends Node2D
class_name BoardView

@export var cell_size := 24.0

var _state: GameState

func bind_state(state: GameState) -> void:
	_state = state
	queue_redraw()

func _draw() -> void:
	if _state == null:
		return
	var visible := _state.get_visible_cells_for_player(_state.active_player)
	var blind := _state.get_blind_cells_for_player(_state.active_player)
	for y in _state.setup.board_size.y:
		for x in _state.setup.board_size.x:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(x, y) * cell_size, Vector2.ONE * cell_size)
			if _state.setup.is_extra_row(y):
				draw_rect(rect, Color(0.2, 0.2, 0.28, 0.18), true)
			elif cell in visible:
				draw_rect(rect, Color(0.4, 0.85, 0.5, 0.2), true)
			if cell in blind:
				draw_rect(rect, Color(0.1, 0.1, 0.1, 0.4), true)
