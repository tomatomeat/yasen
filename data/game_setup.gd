extends Resource
class_name GameSetup

enum Side { TOP, BOTTOM }

@export var board_width: int = 7
@export var board_height: int = 7
@export var extra_rows: int = 1

@export var player1_unit_ids: Array[String] = []
@export var player2_unit_ids: Array[String] = []

@export var starting_player: int = 1
