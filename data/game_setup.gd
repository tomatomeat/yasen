extends Resource
class_name GameSetup

const BOARD_COLS := 7
const BOARD_ROWS := 9
const EXTRA_ROWS := [0, 8]

@export var board_size := Vector2i(BOARD_COLS, BOARD_ROWS)
@export var player_count := 2
@export var units_per_player := 3
@export var initial_columns := PackedInt32Array([1, 3, 5])
@export var initial_rows := PackedInt32Array([1, 7])
@export var unit_catalog: Array[UnitData] = []

func get_default_unit_data() -> UnitData:
	if unit_catalog.is_empty():
		return UnitData.new()
	return unit_catalog[0]

func is_inside_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < board_size.x and cell.y >= 0 and cell.y < board_size.y

func is_extra_row(row: int) -> bool:
	return row in EXTRA_ROWS

func is_playable_cell(cell: Vector2i) -> bool:
	if not is_inside_board(cell):
		return false
	return not is_extra_row(cell.y)

func get_extra_row_for_player(player_id: int) -> int:
	return EXTRA_ROWS[player_id]

func get_home_row_for_player(player_id: int) -> int:
	return initial_rows[player_id]
