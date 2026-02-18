extends Node
class_name NetworkController

# シンプルな host/client wrapper
signal connected(peer_id)
signal disconnected(peer_id)
signal server_started()
signal client_connected_to_server()

var port := 43500
var max_clients := 1
var state: GameState = null

# ============== ENet 起動/接続 ==============
func host(p_port: int = 43500, p_max_clients: int = 1) -> void:
	port = p_port
	max_clients = p_max_clients
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		push_error("Failed to create ENet server: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	print("Hosting on port %d" % port)
	# server is authority (peer_id == 1)
	emit_signal("server_started")

func connect_to(host_ip: String, p_port: int = 43500) -> void:
	port = p_port
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host_ip, port)
	if err != OK:
		push_error("Failed to create ENet client: " + str(err))
		return
	multiplayer.multiplayer_peer = peer
	print("Client connecting to %s:%d" % [host_ip, port])

# 接続イベントハンドラ（必要なら接続確認をこの Node で bind ）
func _ready() -> void:
	# Multiplayer API のシグナルを使う場合はここで connect する
	if multiplayer:
		multiplayer.peer_connected.connect(self._on_peer_connected)
		multiplayer.peer_disconnected.connect(self._on_peer_disconnected)
		multiplayer.connection_succeeded.connect(self._on_connection_succeeded)
		multiplayer.connection_failed.connect(self._on_connection_failed)
		multiplayer.server_disconnected.connect(self._on_server_disconnected)

func _on_peer_connected(id: int) -> void:
	print("Peer connected: ", id)
	emit_signal("connected", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected: ", id)
	emit_signal("disconnected", id)

func _on_connection_succeeded() -> void:
	print("Connected to server")
	emit_signal("client_connected_to_server")

func _on_connection_failed() -> void:
	print("Connection failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")

# ============== クライアント -> サーバー: 行動送信 ==============
# クライアントはこの関数をローカルで呼ぶ（ローカル側では validate しない、サーバーへ送るのみ）
func client_submit_action(unit_id: String, action: Dictionary) -> void:
	# send to server (server has peer_id == 1)
	# use rpc_id to call server RPC
	rpc_id(1, "server_receive_action", get_tree().get_multiplayer().get_unique_id(), unit_id, action)

# ============== サーバー側 RPC: クライアントからの申請を受け取る ==============
# any_peer + call_remote: any client can call this RPC and it will execute on authority (server)
@rpc("any_peer", "call_remote", "reliable")
func server_receive_action(from_peer: int, unit_id: String, action: Dictionary) -> void:
	# sanity: only server should execute validation (this function runs on server)
	if not multiplayer.is_server():
		return
	print("Server received action from peer %d: %s" % [from_peer, str(action)])
	# TODO: map peer -> player id mapping (here assuming peer 1 <-> player1, peer 2 <-> player2).
	# Validate that the from_peer is actually owner of unit (you need a player mapping system).
	# For now we just attempt to apply and broadcast if success.
	if state == null:
		push_error("No GameState set on server")
		return
	var ok = state.apply_action(unit_id, action)
	if ok:
		# broadcast action to all peers (including server) so everyone applies it in the same order
		# sync_action is flagged to be called locally too.
		rpc("sync_action", unit_id, action)
	else:
		# could send a reject message to client
		rpc_id(from_peer, "client_action_rejected", unit_id, action)

# ============== 全員へ配信: action を順番に再生させる（call_local: server 実行も含む） ==============
@rpc("authority", "call_local", "reliable")
func sync_action(unit_id: String, action: Dictionary) -> void:
	# この RPC は server が呼ぶ（authority）ことで全員に届く
	# 受け取ったらローカルでも apply_action を呼ぶ（ただし二重適用を避けるため、 server が既に適用済みなら適宜 skip）
	# simplest: everyone just calls apply_action (server already applied; applying again must be deterministic / idempotent or we must avoid double apply)
	if state == null:
		return
	# NOTE: server already applied before rpc; clients will apply here.
	# server will also execute this because call_local: thus server must ignore duplicate application.
	# To handle: only apply on peers where multiplayer.get_unique_id() != 1 OR make apply_action idempotent.
	if multiplayer.is_server():
		# server has already applied; skip (server_receive_action applied it)
		return
	state.apply_action(unit_id, action)

@rpc("any_peer", "call_local", "reliable")
func client_action_rejected(unit_id: String, action: Dictionary) -> void:
	print("Your action was rejected by server: ", unit_id, action)

# ============== ヘルパ: GameState をセットする ==============
func set_gamestate(gs: GameState) -> void:
	state = gs
