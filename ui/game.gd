extends Node2D

@onready var board := $Board as TileMapLayer
@onready var units := $Units as UnitView
@onready var board_view := $BoardView as BoardView

var _game_state := GameState.new()

func _ready() -> void:
	var setup := GameSetup.new()
	_game_state.initialize(setup)
	_game_state.unit_changed.connect(_on_unit_changed)
	_game_state.unit_removed.connect(_on_unit_removed)
	_game_state.turn_changed.connect(_on_turn_changed)
	units.sync_units(_game_state.get_units())
	board_view.bind_state(_game_state)
	set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var active_units: Array[UnitState] = _game_state.get_units_for_player(_game_state.active_player)
		if active_units.is_empty():
			return
		var first_unit: UnitState = active_units[0]
		if event.keycode == KEY_Q:
			_game_state.apply_rotate(first_unit.unit_instance_id, false)
		elif event.keycode == KEY_E:
			_game_state.apply_rotate(first_unit.unit_instance_id, true)
		elif event.keycode == KEY_W:
			_game_state.apply_move(first_unit.unit_instance_id, first_unit.position + first_unit.get_forward_vector())

func _on_unit_changed(_unit: UnitState) -> void:
	units.sync_units(_game_state.get_units())
	board_view.queue_redraw()

func _on_unit_removed(_unit_id: int) -> void:
	units.sync_units(_game_state.get_units())
	board_view.queue_redraw()

func _on_turn_changed(_active_player: int) -> void:
	board_view.queue_redraw()
