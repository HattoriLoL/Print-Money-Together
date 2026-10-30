extends Node
## Todos os objetos carregáveis da sala (nó "Items" do mapa). O host cria, entrega, solta e
## consome; os outros pedem por RPC e só recebem o resultado. Cada jogador segura um por vez.

## Host: alguém pegou um item (a impressora usa para saber que a bandeja esvaziou).
signal picked(item: Node)

const Item := preload("res://scripts/items/item.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
## Distância máxima do jogador ao item para pegar (folga para a rede).
const REACH := 3.5

var items := {}
var _next_id := 1
var _kitnet: Node


func _ready() -> void:
	_kitnet = get_parent()


## Item que o peer está segurando, ou null.
func held_by(peer: int) -> Node:
	for item in items.values():
		if item.holder == peer:
			return item
	return null


# --- Só no host -------------------------------------------------------------------------------

func spawn(kind: String, xform: Transform3D, data := {}, holder := 0) -> Node:
	var id := _next_id
	_next_id += 1
	_spawn(id, kind, xform, data, holder)
	_kitnet.rpc_roster(self, &"_spawn", [id, kind, xform, data, holder])
	return items[id]


## Cria o item direto na mão do peer (pegou de uma caixa de suprimento).
func give(peer: int, kind: String, data := {}) -> Node:
	var player: Node3D = _kitnet.players.get(peer)
	var xform: Transform3D = player.hold_point.global_transform if player else Transform3D.IDENTITY
	return spawn(kind, xform, data, peer)


## Some com o item (virou papel dentro da impressora, por exemplo).
func consume(item: Node) -> void:
	_remove(item.id)
	_kitnet.rpc_roster(self, &"_remove", [item.id])


## Muda o estado do item em todas as máquinas (folha secou...).
func set_data(item: Node, key: String, value: Variant) -> void:
	_set_data(item.id, key, value)
	_kitnet.rpc_roster(self, &"_set_data", [item.id, key, value])


## Quem saiu da sala solta o que segurava onde estava.
func drop_all_of(peer: int) -> void:
	var item := held_by(peer)
	if item != null:
		_release(item, item.global_transform, Vector3.ZERO)


## Manda todos os itens para quem acabou de entrar.
func send_all_to(peer: int) -> void:
	for item in items.values():
		_spawn.rpc_id(peer, item.id, item.kind, item.global_transform, item.data, item.holder)


# --- Pedidos (qualquer jogador) ---------------------------------------------------------------

func request_pickup(id: int) -> void:
	if multiplayer.is_server():
		_pickup(multiplayer.get_unique_id(), id)
	else:
		_rpc_pickup.rpc_id(1, id)


## Solta o que o jogador local segura em `xform`, com velocidade `velocity`.
func request_drop(xform: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		_drop(multiplayer.get_unique_id(), xform, velocity)
	else:
		_rpc_drop.rpc_id(1, xform, velocity)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pickup(id: int) -> void:
	if multiplayer.is_server():
		_pickup(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop(xform: Transform3D, velocity: Vector3) -> void:
	if multiplayer.is_server():
		_drop(multiplayer.get_remote_sender_id(), xform, velocity)


func _pickup(peer: int, id: int) -> void:
	var item: Node = items.get(id)
	var player: Node3D = _kitnet.players.get(peer)
	if item == null or player == null or item.holder != 0 or held_by(peer) != null:
		return
	if player.global_position.distance_to(item.global_position) > REACH:
		return
	_set_holder(id, peer, item.global_transform, Vector3.ZERO)
	_kitnet.rpc_roster(self, &"_set_holder", [id, peer, item.global_transform, Vector3.ZERO])


func _drop(peer: int, xform: Transform3D, velocity: Vector3) -> void:
	var item := held_by(peer)
	var player: Node3D = _kitnet.players.get(peer)
	if item == null or player == null:
		return
	# Não deixa soltar longe de onde o jogador está (cliente trapaceando ou lag grande).
	if player.global_position.distance_to(xform.origin) > 2.5:
		xform.origin = player.hold_point.global_position
	_release(item, xform, velocity.limit_length(6.0))


func _release(item: Node, xform: Transform3D, velocity: Vector3) -> void:
	_set_holder(item.id, 0, xform, velocity)
	_kitnet.rpc_roster(self, &"_set_holder", [item.id, 0, xform, velocity])


# --- Aplicado em todas as máquinas ------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _spawn(id: int, kind: String, xform: Transform3D, data: Dictionary, holder: int) -> void:
	if items.has(id):
		return
	var item := Item.new()
	item.setup(id, kind, data, xform, holder)
	add_child(item)
	items[id] = item
	_next_id = maxi(_next_id, id + 1)


@rpc("authority", "call_remote", "reliable")
func _remove(id: int) -> void:
	var item: Node = items.get(id)
	if item != null:
		items.erase(id)
		item.queue_free()


@rpc("authority", "call_remote", "reliable")
func _set_data(id: int, key: String, value: Variant) -> void:
	var item: Node = items.get(id)
	if item != null:
		item.data[key] = value
		ItemKinds.refresh(item)


@rpc("authority", "call_remote", "reliable")
func _set_holder(id: int, holder: int, xform: Transform3D, velocity: Vector3) -> void:
	var item: Node = items.get(id)
	if item == null:
		return
	item.holder = holder
	item.data.erase("resting")
	if holder == 0:
		item.snap(xform)
	item.apply_mode()
	if holder == 0 and multiplayer.is_server():
		item.linear_velocity = velocity
		item.angular_velocity = Vector3.ZERO
	elif holder != 0:
		picked.emit(item)
