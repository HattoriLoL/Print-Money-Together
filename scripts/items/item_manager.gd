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


## Solta (ou arremessa) o que o jogador local segura em `xform`, com velocidade `velocity` e
## giro `spin`.
func request_drop(xform: Transform3D, velocity: Vector3, spin := Vector3.ZERO) -> void:
	if multiplayer.is_server():
		_drop(multiplayer.get_unique_id(), xform, velocity, spin)
	else:
		_rpc_drop.rpc_id(1, xform, velocity, spin)


## Abre a caixa da entrega: o que veio dentro sai pulando e a caixa some.
func request_open(id: int) -> void:
	if multiplayer.is_server():
		_open(multiplayer.get_unique_id(), id)
	else:
		_rpc_open.rpc_id(1, id)


## Põe o que o jogador local segura (maço ou montinho) no saco de lixo `id`.
func request_bag_put(id: int) -> void:
	if multiplayer.is_server():
		_bag_put(multiplayer.get_unique_id(), id)
	else:
		_rpc_bag_put.rpc_id(1, id)


## Abre ou dá o nó no saco de lixo que o jogador local segura.
func request_bag_toggle() -> void:
	if multiplayer.is_server():
		_bag_toggle(multiplayer.get_unique_id())
	else:
		_rpc_bag_toggle.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_bag_toggle() -> void:
	if multiplayer.is_server():
		_bag_toggle(multiplayer.get_remote_sender_id())


func _bag_toggle(peer: int) -> void:
	var bag := held_by(peer)
	if bag == null or bag.kind != "trashbag":
		return
	set_data(bag, "open", not bag.data.get("open", false))


## Host: o saco aberto pegou um maço ou montinho que caiu na boca dele.
func catch_into_bag(bag: Node, item: Node) -> void:
	var contents: Array = bag.data.get("contents", []).duplicate(true)
	if contents.size() >= ItemKinds.BAG_CAPACITY:
		return
	var data: Dictionary = item.data.duplicate(true)
	data.erase("resting")
	contents.append([item.kind, data])
	consume(item)
	_set_bag(bag, contents)


## Host: o saco aberto e tombado derrama o último que entrou: sai pela boca, com o empurrão e a
## velocidade do saco. Devolve o item que saiu (ou null).
func spill_from_bag(bag: Node) -> Node:
	var contents: Array = bag.data.get("contents", []).duplicate(true)
	if contents.is_empty():
		return null
	var last: Array = contents.pop_back()
	_set_bag(bag, contents)
	var up: Vector3 = bag.global_basis.y.normalized()
	var at: Vector3 = ItemKinds.bag_mouth(bag) + up * 0.06
	var spin := Basis(Vector3.UP, randf() * TAU)
	var out := spawn(last[0], Transform3D(spin, at), last[1])
	out.linear_velocity = bag.linear_velocity + up * ItemKinds.BAG_SPILL_PUSH \
			+ Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
	out.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	return out


## Tira a última coisa que entrou no saco `id` para a mão (vazia) do jogador local.
func request_bag_take(id: int) -> void:
	if multiplayer.is_server():
		_bag_take(multiplayer.get_unique_id(), id)
	else:
		_rpc_bag_take.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_bag_put(id: int) -> void:
	if multiplayer.is_server():
		_bag_put(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_bag_take(id: int) -> void:
	if multiplayer.is_server():
		_bag_take(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_open(id: int) -> void:
	if multiplayer.is_server():
		_open(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_pickup(id: int) -> void:
	if multiplayer.is_server():
		_pickup(multiplayer.get_remote_sender_id(), id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_drop(xform: Transform3D, velocity: Vector3, spin: Vector3) -> void:
	if multiplayer.is_server():
		_drop(multiplayer.get_remote_sender_id(), xform, velocity, spin)


func _pickup(peer: int, id: int) -> void:
	var item: Node = items.get(id)
	var player: Node3D = _kitnet.players.get(peer)
	if item == null or player == null or item.holder != 0 or held_by(peer) != null:
		return
	if item.kind in ItemKinds.NOT_CARRIED:
		return
	if item.kind in ItemKinds.TWO_HANDED and player.hands_left() < 2:
		return
	if player.global_position.distance_to(item.global_position) > REACH:
		return
	_set_holder(id, peer, item.global_transform, Vector3.ZERO, Vector3.ZERO)
	_kitnet.rpc_roster(self, &"_set_holder", [id, peer, item.global_transform, Vector3.ZERO, Vector3.ZERO])


func _open(peer: int, id: int) -> void:
	var item: Node = items.get(id)
	var player: Node3D = _kitnet.players.get(peer)
	if item == null or player == null or item.kind != "parcel" or item.holder != 0:
		return
	if player.global_position.distance_to(item.global_position) > REACH:
		return
	# Saem por cima da caixa, um em cima do outro (nascer dentro de outro item, como as resmas de
	# outra caixa aberta do lado, dava um tranco que jogava o cartucho através do chão).
	var top: Vector3 = item.global_position + Vector3.UP * (ItemKinds.SIZES["parcel"].y / 2.0 + 0.06)
	var contents: Array = item.data.get("contents", [])
	consume(item)
	for i in contents.size():
		var entry: Array = contents[i]
		var xform := Transform3D(Basis(Vector3.UP, randf() * TAU), top + Vector3(randf_range(-0.05, 0.05), i * 0.08, randf_range(-0.05, 0.05)))
		var spawned := spawn(entry[0], xform, entry[1])
		spawned.linear_velocity = Vector3(randf_range(-0.4, 0.4), randf_range(0.8, 1.4), randf_range(-0.4, 0.4))
		spawned.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))


## O saco no chão perto do jogador (ou null).
func _bag_near(peer: int, id: int) -> Node:
	var bag: Node = items.get(id)
	var player: Node3D = _kitnet.players.get(peer)
	if bag == null or player == null or bag.kind != "trashbag" or bag.holder != 0:
		return null
	if player.global_position.distance_to(bag.global_position) > REACH:
		return null
	return bag


func _bag_put(peer: int, id: int) -> void:
	var bag := _bag_near(peer, id)
	var held := held_by(peer)
	if bag == null or held == null or held.kind not in ItemKinds.BAG_KINDS:
		return
	var contents: Array = bag.data.get("contents", []).duplicate(true)
	if contents.size() >= ItemKinds.BAG_CAPACITY:
		return
	var data: Dictionary = held.data.duplicate(true)
	data.erase("resting")
	contents.append([held.kind, data])
	consume(held)
	_set_bag(bag, contents)


func _bag_take(peer: int, id: int) -> void:
	var bag := _bag_near(peer, id)
	if bag == null or held_by(peer) != null:
		return
	var contents: Array = bag.data.get("contents", []).duplicate(true)
	if contents.is_empty():
		return
	var last: Array = contents.pop_back()
	_set_bag(bag, contents)
	give(peer, last[0], last[1])


## O saco com o que tem dentro agora: cresce para cima (o fundo fica no chão), e todos veem.
func _set_bag(bag: Node, contents: Array) -> void:
	var before: float = ItemKinds.bag_size(bag.data).y
	set_data(bag, "contents", contents)
	var grow: float = ItemKinds.bag_size(bag.data).y - before
	if grow > 0.0 and bag.holder == 0:
		bag.snap(bag.global_transform.translated(Vector3.UP * grow / 2.0))
		_kitnet.rpc_roster(bag, &"_remote_xform", [bag.global_transform])
	bag.sleeping = false


func _drop(peer: int, xform: Transform3D, velocity: Vector3, spin: Vector3) -> void:
	var item := held_by(peer)
	var player: Node3D = _kitnet.players.get(peer)
	if item == null or player == null:
		return
	# Não deixa soltar longe de onde o jogador está (cliente trapaceando ou lag grande).
	if player.global_position.distance_to(xform.origin) > 2.5:
		xform.origin = player.hold_point.global_position
	_release(item, xform, velocity.limit_length(9.0), spin.limit_length(15.0))
	item.ignore_briefly(player)


func _release(item: Node, xform: Transform3D, velocity: Vector3, spin := Vector3.ZERO) -> void:
	_set_holder(item.id, 0, xform, velocity, spin)
	_kitnet.rpc_roster(self, &"_set_holder", [item.id, 0, xform, velocity, spin])


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
		item.data_changed(key)


@rpc("authority", "call_remote", "reliable")
func _set_holder(id: int, holder: int, xform: Transform3D, velocity: Vector3, spin: Vector3) -> void:
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
		item.angular_velocity = spin
	elif holder != 0:
		picked.emit(item)
