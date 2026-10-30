extends Node
## Rede (autoload "Net"): hospedar, entrar e sair. ENet direto por IP por enquanto (LAN, Radmin,
## Hamachi ou porta aberta); Steam fica para depois. Quem hospeda também joga (peer 1).
##
## Quem entra só troca para a cena do mapa depois de conectar; o mapa avisa o host quando
## terminou de carregar (ver kitnet.gd).

signal join_failed(reason: String)

const PORT := 7777
const MAX_PLAYERS := 4
const MAP := "res://scenes/kitnet.tscn"
const MENU := "res://scenes/main.tscn"
## Cor de cada vaga (1 a 4 = 0 a 3): boneco e nome na lista.
const PLAYER_COLORS: Array[Color] = [
	Color(0.85, 0.2, 0.2), Color(0.2, 0.45, 0.9), Color(0.95, 0.75, 0.1), Color(0.6, 0.25, 0.85),
]

var player_name := "Player"
## Por que a última partida acabou (o menu mostra e limpa).
var last_message := ""


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


## Sozinho, sem abrir porta nem rede (para testar). O peer offline já é o "servidor" (id 1),
## então o mapa funciona igual.
func play_solo() -> void:
	_reset()
	get_tree().change_scene_to_file.call_deferred(MAP)


func host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file.call_deferred(MAP)
	return OK


func join(address: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func is_online() -> bool:
	return not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


## Fecha a conexão e volta para o menu.
func leave(reason := "") -> void:
	last_message = reason
	_reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file.call_deferred(MENU)


func _reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


## Quem cai sem avisar (jogo fechado à força, internet) sai da sala em até ~8 s, não em 30.
func _on_peer_connected(id: int) -> void:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_peer(id) != null:
		enet.get_peer(id).set_timeout(32, 3000, 8000)


func _on_connected() -> void:
	get_tree().change_scene_to_file(MAP)


func _on_connection_failed() -> void:
	_reset()
	join_failed.emit("Could not reach the host (or the room is full).")


func _on_server_disconnected() -> void:
	leave("The host closed the room.")
