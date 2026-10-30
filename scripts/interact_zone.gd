extends Area3D
## Zona de interação de uma máquina: uma caixa invisível que a mira do jogador acerta (camada 4,
## "interact"), um pouco maior que a peça para ser achada antes da colisão do modelo.
##
## A máquina dona preenche:
##   prompt_fn(player) -> String   texto na tela, calculado em cada máquina com o estado dela
##   press_fn(peer_id)             [E] apertado: roda só no host
## Zonas de segurar (is_hold, "Hold [E]") não têm press: o host lê `holders` a cada quadro.
## Quem aperta ou segura avisa o host por RPC, e o host confere se o jogador está perto.

const LAYER := 8  # camada 4
const MAX_REACH := 3.5

var prompt_fn: Callable
var press_fn: Callable
var is_hold := false
## Só no host: peers segurando [E] nesta zona agora.
var holders := {}


func setup(parent: Node3D, zone_name: String, center: Vector3, size: Vector3, hold := false) -> void:
	name = zone_name
	is_hold = hold
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	position = center
	parent.add_child(self)
	add_to_group("interact_zone")


func get_prompt(player: Node) -> String:
	return prompt_fn.call(player) if prompt_fn.is_valid() else ""


## [E] do jogador local numa zona de apertar.
func interact(_player: Node) -> void:
	if is_hold:
		return
	if multiplayer.is_server():
		_do_press(multiplayer.get_unique_id())
	else:
		_rpc_press.rpc_id(1)


## Começou / parou de segurar [E] (jogador local numa zona de segurar).
func begin_hold(_player: Node) -> void:
	if multiplayer.is_server():
		_do_hold(multiplayer.get_unique_id(), true)
	else:
		_rpc_hold.rpc_id(1, true)


func end_hold(_player: Node) -> void:
	if multiplayer.is_server():
		_do_hold(multiplayer.get_unique_id(), false)
	else:
		_rpc_hold.rpc_id(1, false)


## Host: alguém saiu da sala.
func drop_peer(peer: int) -> void:
	holders.erase(peer)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_press() -> void:
	if multiplayer.is_server():
		_do_press(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_hold(down: bool) -> void:
	if multiplayer.is_server():
		_do_hold(multiplayer.get_remote_sender_id(), down)


func _do_press(peer: int) -> void:
	if press_fn.is_valid() and _in_reach(peer):
		press_fn.call(peer)


func _do_hold(peer: int, down: bool) -> void:
	if down and _in_reach(peer):
		holders[peer] = true
	else:
		holders.erase(peer)


func _in_reach(peer: int) -> bool:
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	var player: Node3D = kitnet.players.get(peer) if kitnet else null
	return player != null and player.global_position.distance_to(global_position) < MAX_REACH
