extends Node3D
## Esconderijo (filho de um HIDE_* ou do KEEP_BathHatch do kitnet.glb): [E] com um item na mão
## guarda ele lá dentro (some do mapa), e [E] de mão vazia tira o último que entrou. O vizinho
## (neighbor.gd) não vê. A polícia (police.gd) só acha se revistar este móvel (cada um tem uma
## chance): aí leva o dinheiro (`seize`), menos o saco de lixo fechado, que passa por lixo.
##
## O host guarda a lista ([kind, data] de cada item) e repassa para todos (o aviso da tela conta
## quantos tem).

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const _Police := preload("res://scripts/police.gd")

## Cada esconderijo: o nome que aparece, quantos itens cabem, e a zona (centro e tamanho, no
## referencial do nó do modelo; a frente dos móveis é o +Z local).
const SPOTS := {
	# A porta da esquerda; a da direita é para gente se esconder (hideout.gd).
	"HIDE_Wardrobe": ["the wardrobe", 8, Vector3(-0.35, 1.05, 0.31), Vector3(0.62, 1.5, 0.08)],
	"HIDE_SofaBed": ["under the sofa bed", 5, Vector3(0.0, 0.07, 0.5), Vector3(1.7, 0.14, 0.1)],
	"HIDE_Fridge": ["the fridge", 4, Vector3(0.0, 0.8, 0.41), Vector3(0.62, 1.0, 0.08)],
	"KEEP_BathHatch": ["the ceiling hatch", 10, Vector3(0.0, -0.02, 0.0), Vector3(0.5, 0.06, 0.5)],
}

var spot_name := ""
var capacity := 0
## [[kind, data], ...] na ordem em que entraram.
var contents: Array = []
var zone: Area3D
var _kitnet: Node


## Chame antes de pôr na árvore: `key` é o nome do nó do modelo (uma chave de SPOTS).
func setup(key: String) -> void:
	var spec: Array = SPOTS[key]
	name = "Stash"
	spot_name = spec[0]
	capacity = spec[1]
	zone = InteractZone.new()
	zone.setup(self, "Zone_Stash", spec[2], spec[3])
	zone.prompt_fn = _prompt
	zone.press_fn = _use


func _ready() -> void:
	add_to_group("station")
	add_to_group("stash")
	_kitnet = get_tree().get_first_node_in_group("kitnet")


func _prompt(player: Node) -> String:
	var held: Node = player.held_item()
	if held != null:
		if held.kind in ItemKinds.NOT_CARRIED:
			return ""
		if contents.size() >= capacity:
			return "%s is full" % spot_name.capitalize()
		return "[E] Hide the %s in %s" % [ItemKinds.label(held), spot_name]
	if contents.is_empty():
		return "Hiding spot: %s (empty)" % spot_name
	var last: Array = contents[-1]
	return "[E] Take the %s from %s  (%d hidden)" % [ItemKinds.label_of(last[0], last[1]), spot_name, contents.size()]


## Host: [E] no esconderijo.
func _use(peer: int) -> void:
	var held: Node = _kitnet.items.held_by(peer)
	if held != null:
		if held.kind in ItemKinds.NOT_CARRIED or contents.size() >= capacity:
			return
		var data: Dictionary = held.data.duplicate(true)
		data.erase("resting")
		data.erase("hanging")
		contents.append([held.kind, data])
		_kitnet.items.consume(held)
	elif not contents.is_empty():
		var last: Array = contents.pop_back()
		_kitnet.items.give(peer, last[0], last[1])
	else:
		return
	_kitnet.rpc_roster(self, &"_sync", [contents])


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, contents)


## Host: a polícia revistou e achou. Leva folhas, notas, maços e o dinheiro de saco de lixo
## aberto (o saco fica, vazio); o saco fechado passa por lixo e o resto (frigideira, resma) fica.
## Devolve o que levou.
func seize() -> Dictionary:
	var got := {"sheets": 0, "bills": 0, "bundles": 0}
	var keep: Array = []
	for entry: Array in contents:
		var kind: String = entry[0]
		var data: Dictionary = entry[1]
		var money: bool = kind in ["sheet", "bills", "bundle"] or (kind == "trashbag" and data.get("open", false))
		if not money:
			keep.append(entry)
			continue
		var counted: Dictionary = _Police._count(kind, data)
		for key in counted:
			got[key] += counted[key]
		if kind == "trashbag":
			var empty := data.duplicate(true)
			empty["contents"] = []
			keep.append([kind, empty])
	contents = keep
	_kitnet.rpc_roster(self, &"_sync", [contents])
	return got


@rpc("authority", "call_remote", "reliable")
func _sync(inside: Array) -> void:
	contents = inside
