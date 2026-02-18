extends Node2D
@onready var board_view: Node2D = $BoardView
@onready var units_root: Node2D = $Units
@onready var action_panel: VBoxContainer = $UI/Control/ActionPanel
@onready var turn_label: Label = $UI/Control/HBoxContainer/TurnLabel
@onready var info_label: Label = $UI/Control/HBoxContainer/InfoLabel
@onready var network: Node = $NetworkController setget _set_network

# cell size must match BoardView/UnitView
const CELL_SIZE := 64

var state: GameState = null
var local_player_id: int = 1 # テスト用：起動時に自分がplayer1か2か設定する
var selected_unit_id: String = ""
var visible_cells: Array = []
var possible_targets: Array = []

func _ready() -> void:
	# Load a GameSetup resource (用意しておく)
	var setup_res_path = "res://data/default_game_setup.tres"
	var setup_res: Resource = null
	if ResourceLoader.exists(setup_res_path):
		setup_res = load(setup_res_path)
	else:
		# fallback quick setup
		setup_res = preload("res://data/GameSetup.gd").new()
		setup_res.player1_unit_ids = ["u_a","u_b","u_c"]
		setup_res.player2_unit_ids = ["v_a","v_b","v_c"]
		setup_res.starting_player = 1

	# create and configure GameState
	state = preload("res://state/GameState.gd").new()
	state.setup_from_game_setup(setup_res)

	# attach GameState to network controller if exists
	if network:
		if network.has_method("set_gamestate"):
			network.set_gamestate(state)

	# connect board clicks
	if board_view.has_signal("cell_clicked"):
		board_view.connect("cell_clicked", Callable(self, "_on_board_cell_clicked"))

	# initial draw
	_update_all_views()

	# Example: allow pressing 1/2 to toggle local player for testing visibility
	set_process_input(true)

func _set_network(n: Node) -> void:
	network = n

func _process(delta):
	# refresh views if needed (cheap for small board)
	_update_all_views()

func _on_board_cell_clicked(cell: Vector2i) -> void:
	# clicked a cell on board
	# if there's a visible unit owned by local_player -> select it
	var u = _get_visible_unit_at(cell)
	if u != null and u.owner == local_player_id:
		selected_unit_id = u.id
		_show_actions_for(selected_unit_id)
		return
	# else: if an action is selected that requires target cell, handle here (we use buttons flow, so ignore)
	# deselect if click empty
	selected_unit_id = ""
	_clear_action_panel()

# update UI and spawn unit views (visibility respected)
func _update_all_views() -> void:
	# compute visible cells for local player
	visible_cells = state.get_visible_cells(local_player_id)
	# redraw board
	if board_view:
		board_view.clear() if board_view.has_method("clear") else null
		board_view.redraw(state)
		# draw visible overlay and possible targets
		board_view.draw_visible_cells(visible_cells)
		if possible_targets.size() > 0:
			board_view.draw_possible_cells(possible_targets)

	# sync unit views: destroy all and respawn (cheap for small #)
	for c in units_root.get_children():
		c.queue_free()
	for u in state.units.values():
		# show if owned by local player OR visible
		var show = (u.owner == local_player_id) or (visible_cells.has(u.position))
		if show and not u.is_dead:
			var uv = preload("res://ui/UnitView.gd").new()
			uv.cell_size = CELL_SIZE
			units_root.add_child(uv)
			uv.set_unit(u)

	# update labels
	turn_label.text = "Turn: %d (Player %d)" % [state.turn_count, state.current_player]
	info_label.text = "You: Player %d" % local_player_id

func _get_visible_unit_at(cell: Vector2i) -> UnitState:
	for u in state.units.values():
		if u.position == cell and not u.is_dead and not u.is_half_dead:
			# show only if visible or owned
			if u.owner == local_player_id or state.get_visible_cells(local_player_id).has(cell):
				return u
	return null

# ---------- Actions UI ----------
func _show_actions_for(unit_id: String) -> void:
	_clear_action_panel()
	var actions = state.get_possible_actions(unit_id)
	for a in actions:
		var btn = Button.new()
		btn.text = _action_to_label(a)
		btn.pressed.connect(Callable(self, "_on_action_pressed").bind(unit_id, a))
		action_panel.add_child(btn)
	# also add cancel button
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(Callable(self, "_on_cancel_pressed"))
	action_panel.add_child(cancel)

func _clear_action_panel() -> void:
	for c in action_panel.get_children():
		c.queue_free()
	possible_targets.clear()

func _action_to_label(action: Dictionary) -> String:
	match action.get("type",""):
		"rotate":
			return "Rotate: %s" % str(action.get("facing"))
		"move":
			var d = action.get("dir")
			if d == Vector2i(0,1): return "Move ↓"
			if d == Vector2i(0,-1): return "Move ↑"
			if d == Vector2i(1,0): return "Move →"
			if d == Vector2i(-1,0): return "Move ←"
			return "Move"
		"place_extra":
			return "Place at x=%d" % action.get("x")
		_:
			return "Action"

func _on_action_pressed(unit_id: String, action: Dictionary) -> void:
	# if network present and we are client -> send to server; if we are server or no network, apply locally
	if network != null and multiplayer != null and not multiplayer.is_server():
		# send to server
		if network.has_method("client_submit_action"):
			network.client_submit_action(unit_id, action)
	else:
		# apply locally (singleplayer or server)
		var ok = state.apply_action(unit_id, action)
		if not ok:
			# rejected
			print("Action rejected")
	# UI reset selection
	selected_unit_id = ""
	_clear_action_panel()
	# views will be refreshed on _process

func _on_cancel_pressed() -> void:
	selected_unit_id = ""
	_clear_action_panel()

# helper for debugging: press 1/2 to change local player id
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.scancode == KEY_1:
			local_player_id = 1
		elif event.scancode == KEY_2:
			local_player_id = 2
