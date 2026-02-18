extends RefCounted
class_name GameState

# board: x in [0..board_width-1], y in [0..board_height+extra_rows*2]
# we treat main playable rows as y = 1..board_height (extra rows are y=0 and y=board_height+1)
var board_width: int = 7
var board_height: int = 7
var extra_rows: int = 1

var units: Dictionary = {} # id -> UnitState
var current_player: int = 1
var winner: int = 0
var turn_count: int = 1

# =========================================
# 初期化（GameSetup から）
# =========================================
func setup_from_game_setup(setup: GameSetup) -> void:
	board_width = setup.board_width
	board_height = setup.board_height
	extra_rows = setup.extra_rows
	current_player = setup.starting_player
	units.clear()

	var x_positions := [1, 3, 5] # 等間隔（0ベースなら +? 調整は UI に合わせて）
	for i in range(3):
		var p1_pos = Vector2i(x_positions[i], 1) # initial rows: y=1 (since y=0 is extra)
		var p2_pos = Vector2i(x_positions[i], board_height)

		var u1 := UnitState.new(setup.player1_unit_ids[i], 1, p1_pos, UnitState.Facing.SOUTH)
		var u2 := UnitState.new(setup.player2_unit_ids[i], 2, p2_pos, UnitState.Facing.NORTH)

		units[u1.id] = u1
		units[u2.id] = u2

# =========================================
# 行動生成（そのユニットが取れる手を列挙）
# - rotate (向き変更)
# - move (十字1マス)
# - place_extra (半死からエクストラでX位置を指定するアクション) ※owner が行う
# =========================================
func get_possible_actions(unit_id: String) -> Array:
	var res := []
	var unit: UnitState = units.get(unit_id)
	if unit == null:
		return res
	if unit.owner != current_player:
		return res
	if unit.is_dead:
		return res

	# 半死中は、owner が place_extra を選べる（まだ未配置なら）
	if unit.is_half_dead:
		# 空きエクストラX位置を列挙して選択肢にする
		for x in range(board_width):
			if not _is_extra_occupied(unit.owner, x):
				res.append({"type":"place_extra","x":x})
		return res

	# 回転（4方向）
	for f in UnitState.Facing.values():
		if f != unit.facing:
			res.append({"type":"rotate","facing":f})

	# 移動（十字）
	var dirs = [Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
	for d in dirs:
		var tgt = unit.position + d
		# 移動先がメイン盤内であること（エクストラには移動不可）
		if is_inside_main_board(tgt):
			res.append({"type":"move","dir":d})
	return res

# =========================================
# 行動適用（サーバー側で検証して呼ぶのが正しい）
# action は上で列挙した辞書
# =========================================
func apply_action(unit_id: String, action: Dictionary) -> bool:
	# 戦闘中に勝者出てたら無視
	if winner != 0:
		return false

	var unit: UnitState = units.get(unit_id)
	if unit == null:
		return false
	if unit.owner != current_player:
		return false
	if unit.is_dead:
		return false

	match action.get("type",""):
		"rotate":
			unit.facing = action["facing"]
		"move":
			var target = unit.position + action["dir"]
			if not is_inside_main_board(target):
				return false
			var enemy: UnitState = get_unit_at(target)
			if enemy != null:
				_handle_attack(unit, enemy)
			else:
				unit.position = target
		"place_extra":
			# 半死かつ未配置状態の駒のみ
			if not unit.is_half_dead:
				return false
			var x:int = int(action.get("x", -1))
			if x < 0 or x >= board_width:
				return false
			# その X が空いているか
			if _is_extra_occupied(unit.owner, x):
				return false
			# place in extra row
			var y = 0 if unit.owner == 1 else board_height + 1
			unit.position = Vector2i(x, y)
			# ensure facing forward
			unit.facing = UnitState.Facing.SOUTH if unit.owner == 1 else UnitState.Facing.NORTH
			# give wait turns before auto re-entering
			unit.extra_wait_turns = 1
		_:
			return false

	# 行動完了 → ターン終了処理
	_end_turn_process()
	return true

# =========================================
# 攻撃処理（内部）
# - 背後1マスは即死
# - それ以外は半死（未配置）→ place_extra で owner が配置。もう一度攻撃されたら死亡
# =========================================
func _handle_attack(attacker: UnitState, defender: UnitState) -> void:
	# attacker は移動先に入る（結果的に attacker.position == defender.position）
	if _is_behind(defender, attacker.position):
		# 背後からの一撃で死亡
		defender.is_dead = true
	else:
		if defender.is_half_dead:
			defender.is_dead = true
		else:
			# 半死化：一旦フラグを立て、owner が place_extra を呼ぶまでメイン上には居ない扱いとする
			defender.is_half_dead = true
			# temporarily mark position to an invalid extra-flag position to avoid being targetable on main board
			# we keep x so that owner can choose same x if they want; but actual extra placement requires place_extra action
			var y = 0 if defender.owner == 1 else board_height + 1
			defender.position = Vector2i(defender.position.x, y)
			defender.extra_wait_turns = 0 # will be set when owner places via place_extra

	# attacker steps into defender's previous position (capture-style)
	attacker.position = defender.position

# =========================================
# ターン終了処理（勝利判定／half-dead 復帰カウント処理）
# =========================================
func _end_turn_process() -> void:
	# 勝利チェック（全滅判定）
	_check_victory()

	# advance turn
	current_player = 2 if current_player == 1 else 1
	turn_count += 1

	# half-dead の自動復帰カウント（owner のターン開始時にカウントを減らす設計）
	# 仕様：エクストラに置かれた駒は1ターン後に自動で前に出る
	for u in units.values():
		if u.is_half_dead and u.position.y == (0 if u.owner == 1 else board_height + 1) and u.extra_wait_turns > 0:
			u.extra_wait_turns -= 1
			if u.extra_wait_turns <= 0:
				# 前に出る（エクストラの前のメイン行に出す）
				var target_y = 1 if u.owner == 1 else board_height
				# find nearest empty cell in that row (prefer same x, else nearest)
				var placed := false
				for dx in [0,1,-1,2,-2,3,-3]:
					var nx = u.position.x + dx
					if nx >= 0 and nx < board_width:
						var candidate = Vector2i(nx, target_y)
						if get_unit_at(candidate) == null:
							u.position = candidate
							u.is_half_dead = false
							placed = true
							break
				# if cannot place (row full), keep in extra and wait another turn
				if not placed:
					u.extra_wait_turns = 1

# =========================================
# 補助関数群
# =========================================
func get_unit_at(pos: Vector2i) -> UnitState:
	for u in units.values():
		# メイン盤上にいるユニットのみを返す（半死・死亡は対象外）
		if not u.is_dead and not u.is_half_dead and u.position == pos:
			return u
	return null

func is_inside_main_board(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < board_width and pos.y >= 1 and pos.y <= board_height

func _is_extra_occupied(owner: int, x: int) -> bool:
	var y = 0 if owner == 1 else board_height + 1
	for u in units.values():
		if not u.is_dead and u.position.x == x and u.position.y == y:
			return true
	return false

func get_visible_cells(player_id: int) -> Array:
	var visible := []
	for u in units.values():
		if u.owner != player_id:
			continue
		if u.is_dead or u.is_half_dead:
			continue
		visible.append(u.position)
		for cell in _get_unit_vision(u):
			if not visible.has(cell):
				visible.append(cell)
	return visible

func _get_unit_vision(unit: UnitState) -> Array:
	var res := []
	var fwd = _get_forward_direction(unit.facing)
	# 前1
	res.append(unit.position + fwd)
	# 横2（正確には左右1マス? 要調整。仕様: "横2マス" とあったので左右1ずつ＋前斜めを追加）
	var left = Vector2i(-fwd.y, fwd.x)
	var right = Vector2i(fwd.y, -fwd.x)
	res.append(unit.position + left)
	res.append(unit.position + right)
	# 前斜め
	res.append(unit.position + fwd + left)
	res.append(unit.position + fwd + right)
	return res

func _get_forward_direction(facing: int) -> Vector2i:
	match facing:
		UnitState.Facing.NORTH: return Vector2i(0, -1)
		UnitState.Facing.SOUTH: return Vector2i(0, 1)
		UnitState.Facing.EAST:  return Vector2i(1, 0)
		UnitState.Facing.WEST:  return Vector2i(-1, 0)
	return Vector2i.ZERO

func _is_behind(unit: UnitState, pos: Vector2i) -> bool:
	return unit.position + (-_get_forward_direction(unit.facing)) == pos

func _check_victory() -> void:
	var p1_alive := false
	var p2_alive := false
	for u in units.values():
		if not u.is_dead:
			if u.owner == 1:
				p1_alive = true
			elif u.owner == 2:
				p2_alive = true
	if not p1_alive:
		winner = 2
	elif not p2_alive:
		winner = 1
