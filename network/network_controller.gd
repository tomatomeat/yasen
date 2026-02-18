extends Node
class_name NetworkController

signal connected_to_peer(peer_id: int)
signal disconnected_from_peer(peer_id: int)

var peer := ENetMultiplayerPeer.new()

func host(port := 19090, max_clients := 2) -> int:
	var result := peer.create_server(port, max_clients)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(func(id): connected_to_peer.emit(id))
	multiplayer.peer_disconnected.connect(func(id): disconnected_from_peer.emit(id))
	return OK

func join(ip: String, port := 19090) -> int:
	var result := peer.create_client(ip, port)
	if result != OK:
		return result
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(func(): connected_to_peer.emit(multiplayer.get_unique_id()))
	multiplayer.server_disconnected.connect(func(): disconnected_from_peer.emit(1))
	return OK

func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
