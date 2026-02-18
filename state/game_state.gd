extends RefCounted
class_name GameState

signal unit_changed(unit: UnitState)
signal unit_removed(unit_id: int)
signal turn_changed(active_player: int)
signal game_initialized()

var setup := GameSetup.new()
var active_player := 0
var turn_number := 1

var _next_unit_id := 1
var _units: Dictionary = {}

func initialize(game_setup: GameSetup = null) -> void:
	setup = game_setup if game_setup != null else GameSetup.new()
	active_player = 0
	turn_number = 1
	_next_unit_id = 1
	_units.clear()
	_spawn_default_units()
	game_initialized.emit()
	turn_changed.emit(active_player)

func _spawn_default_units() -> void:
	var data := setup.get_default_unit_data()
	for player_id in setup.player_count:
		var row := setup.get_home_row_for_player(player_id)
		var face := UnitState.Facing.SOUTH if player_id == 0 else UnitState.Facing.NORTH
		for col in setup.initial_columns:
			var unit := UnitState.new(_next_unit_id, player_id, data, Vector2i(col, row), face)
			_units[unit.unit_instance_id] = unit
			_next_unit_id += 1

func get_units() -> Array[UnitState]:
	var result: Array[UnitState] = []
	for value in _units.values():
		if value is UnitState:
			result.append(value)
	return result

func get_units_for_player(player_id: int) -> Array[UnitState]:
	return get_units().filter(func(unit: UnitState): return unit.owner_id == player_id and not unit.dead)

func get_unit_at(cell: Vector2i) -> UnitState:
	for unit in get_units():
		if unit.dead:
			continue
		if unit.position == cell:
			return unit
	return null

func apply_rotate(unit_id: int, clockwise := true) -> bool:
	var unit := _units.get(unit_id) as UnitState
	if unit == null or unit.dead or unit.owner_id != active_player:
		return false
	if clockwise:
		unit.rotate_right()
	else:
		unit.rotate_left()
	unit_changed.emit(unit)
	_end_turn()
	return true

func apply_move(unit_id: int, target: Vector2i) -> bool:
	var unit := _units.get(unit_id) as UnitState
	if unit == null or unit.dead or unit.owner_id != active_player:
		return false
	if unit.in_extra:
		return false
	if not setup.is_inside_board(target):
		return false
	if not (target in unit.get_candidate_moves()):
		return false
	var occupant := get_unit_at(target)
	if occupant != null and occupant.owner_id == unit.owner_id:
		return false

	if occupant != null:
		_resolve_attack(unit, occupant)
	else:
		if not setup.is_playable_cell(target):
			return false
		unit.position = target
		unit_changed.emit(unit)

	_end_turn()
	return true

func _resolve_attack(attacker: UnitState, defender: UnitState) -> void:
	var attacker_from := attacker.position
	attacker.position = defender.position
	unit_changed.emit(attacker)

	var rear_cell := defender.position + defender.get_back_vector()
	var is_backstab := attacker_from == rear_cell

	if is_backstab or defender.half_dead:
		defender.dead = true
		unit_removed.emit(defender.unit_instance_id)
		return

	defender.half_dead = true
	defender.in_extra = true
	defender.extra_wait_turns = 1
	defender.facing = UnitState.Facing.SOUTH if defender.owner_id == 0 else UnitState.Facing.NORTH
	defender.position = Vector2i(defender.position.x, setup.get_extra_row_for_player(defender.owner_id))
	unit_changed.emit(defender)

func get_visible_cells_for_player(player_id: int) -> Array[Vector2i]:
	var visible: Array[Vector2i] = []
	for unit in get_units_for_player(player_id):
		for cell in unit.get_visible_cells():
			if setup.is_inside_board(cell) and not (cell in visible):
				visible.append(cell)
	return visible

func get_blind_cells_for_player(player_id: int) -> Array[Vector2i]:
	var blind: Array[Vector2i] = []
	for unit in get_units_for_player(player_id):
		for cell in unit.get_blind_cells():
			if setup.is_inside_board(cell) and not (cell in blind):
				blind.append(cell)
	return blind

func _end_turn() -> void:
	active_player = (active_player + 1) % setup.player_count
	turn_number += 1
	_process_extra_row_units()
	turn_changed.emit(active_player)

func _process_extra_row_units() -> void:
	for unit in get_units_for_player(active_player):
		if not unit.in_extra:
			continue
		if unit.extra_wait_turns > 0:
			unit.extra_wait_turns -= 1
			continue
		var deploy_target := unit.position + unit.get_forward_vector()
		if not setup.is_playable_cell(deploy_target):
			continue
		if get_unit_at(deploy_target) != null:
			continue
		unit.position = deploy_target
		unit.in_extra = false
		unit_changed.emit(unit)
