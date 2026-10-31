extends Node
## Entregas das compras do PC (nó "Deliveries" do mapa). Cada loja do pedido manda uma caixa
## ("parcel") que chega Catalog.DELIVERY_SECONDS depois: o entregador deixa no chão do corredor,
## na frente da 301 (POINT_Knock), e toca a campainha. Alguém tem que ir buscar (a porta abre com
## [E]) e abrir a caixa ([E] nela): o que veio dentro sai pulando.
##
## O host conta o tempo e repassa a lista dos pedidos a caminho (o navegador mostra a contagem).

const Catalog := preload("res://scripts/shop/catalog.gd")
## Caixas que chegam juntas ficam lado a lado no corredor (m).
const PARCEL_STEP := 0.5

## Só no host: [{id, store, contents: [[kind, data], ...], left}].
var _pending: Array[Dictionary] = []
## Em todas as máquinas: [{id, store, arrives}] (arrives no relógio desta máquina, s).
var on_the_way: Array[Dictionary] = []
var _next_order := 1041
var _kitnet: Node
var _bell: AudioStreamPlayer3D


func _ready() -> void:
	name = "Deliveries"
	add_to_group("station")
	_kitnet = get_parent()
	_build_bell()


## Host: faz o pedido do carrinho (product_id -> quantidade). Devolve os números dos pedidos (um
## por loja).
func order(cart: Dictionary) -> Array[int]:
	var ids: Array[int] = []
	for store in Catalog.stores_in(cart):
		var contents := []
		for product_id in Catalog.PRODUCT_ORDER:
			var product: Dictionary = Catalog.PRODUCTS[product_id]
			if product["store"] != store:
				continue
			for i in int(cart.get(product_id, 0)):
				contents.append([product["kind"], product["data"].duplicate()])
		_pending.append({"id": _next_order, "store": store, "contents": contents, "left": Catalog.DELIVERY_SECONDS})
		ids.append(_next_order)
		_next_order += 1
	_broadcast()
	return ids


## Segundos até o pedido chegar (0 = chegou ou não existe).
func seconds_left(entry: Dictionary) -> float:
	return maxf(entry["arrives"] - Time.get_ticks_msec() / 1000.0, 0.0)


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _pending.is_empty():
		return
	var arrived: Array[Dictionary] = []
	for entry in _pending:
		entry["left"] -= delta
		if entry["left"] <= 0.0:
			arrived.append(entry)
	for i in arrived.size():
		_pending.erase(arrived[i])
		_arrive(arrived[i], i)
	if not arrived.is_empty():
		_broadcast()


## Host: a caixa aparece no corredor e a campainha toca para todos.
func _arrive(entry: Dictionary, index: int) -> void:
	var store_name: String = Catalog.STORES[entry["store"]]["name"]
	var at := _door_point() + Vector3(index * PARCEL_STEP, 0.25, 0.0)
	var xform := Transform3D(Basis(Vector3.UP, randf_range(-0.3, 0.3)), at)
	_kitnet.items.spawn("parcel", xform, {"order": entry["id"], "from": store_name, "contents": entry["contents"]})
	_ring(store_name)
	_kitnet.rpc_roster(self, &"_ring", [store_name])


func _door_point() -> Vector3:
	var marker: Node3D = _kitnet.model.find_child("POINT_Knock", true, false)
	return marker.global_position if marker else Vector3.ZERO


func _broadcast() -> void:
	var view := _view()
	_set_on_the_way(view)
	_kitnet.rpc_roster(self, &"_set_on_the_way", [view])


func _view() -> Array:
	return _pending.map(func(e): return [e["id"], e["store"], e["left"]])


func send_state_to(peer: int) -> void:
	_set_on_the_way.rpc_id(peer, _view())


@rpc("authority", "call_remote", "reliable")
func _set_on_the_way(view: Array) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	on_the_way.clear()
	for e in view:
		on_the_way.append({"id": e[0], "store": e[1], "arrives": now + float(e[2])})


@rpc("authority", "call_remote", "reliable")
func _ring(store_name: String) -> void:
	var door: Node3D = _kitnet.doors.get("301")
	if door:
		_bell.global_position = door.global_position + Vector3.UP * 1.6
	_bell.play()
	var me: Node = _kitnet.local_player()
	if me != null:
		me.hud.show_message("Ding-dong!\nA parcel from %s is at the door." % store_name, 3.0)


## A campainha, feita aqui mesmo: "ding-dong", duas notas de sino descendo.
func _build_bell() -> void:
	const RATE := 22050
	var count := int(RATE * 1.6)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var s := _chime(t, 659.3) + _chime(t - 0.45, 523.3)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 24000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_bell = AudioStreamPlayer3D.new()
	_bell.name = "Doorbell"
	_bell.stream = wav
	_bell.unit_size = 6.0
	add_child(_bell)


static func _chime(t: float, freq: float) -> float:
	if t < 0.0:
		return 0.0
	var attack := minf(t / 0.008, 1.0)
	return attack * exp(-t * 3.2) * (0.55 * sin(TAU * freq * t) + 0.2 * sin(TAU * freq * 2.0 * t)
			+ 0.08 * sin(TAU * freq * 3.01 * t))
