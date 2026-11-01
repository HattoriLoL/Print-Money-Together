extends Node3D
## Esconderijo de gente para a batida policial (police.gd, cop.gd): [E] entra e [E] sai. Lá
## dentro o jogador não anda, só olha em volta um pouco, pela fresta (o HUD tampa a tela com o
## jeito de cada um: `view`).
##
## Fechados (guarda-roupa, box, sofá-cama) somem com o boneco; expostos (parapeito da janela,
## atrás do lixo do 302) deixam ele à vista, agachado ou em pé. Os policiais não veem quem está
## escondido: só acham se revistarem o lugar (a chance fica no police.gd).
##
## O host decide quem está dentro (`occupants`, os ids na ordem) e repassa para todos. Cada
## jogador lê o próprio lugar em `slot_of` e o dono dele trava o corpo lá (player.gd, hiding).
##
## Referencial: o do nó pai. Guarda-roupa e sofá-cama ficam presos no móvel do modelo (frente para
## +Z local); o box, a janela e o corredor, na kitnet (coordenadas do mundo).

const InteractZone := preload("res://scripts/interact_zone.gd")

## Cada esconderijo: nome na tela, quantos cabem, se fica à vista, o jeito de olhar (HUD), a zona
## de [E] (centro e tamanho), onde o corpo fica (um ponto por vaga), a altura do olho acima dele,
## para onde olha (no referencial), quanto o olho vai para a frente (até a fresta: a porta do
## guarda-roupa, o vão do sofá, a cortina), por onde sai, e se fica agachado.
const SPOTS := {
	"wardrobe": {
		"name": "the wardrobe", "capacity": 1, "exposed": false, "view": "slit",
		"zone": [Vector3(0.35, 1.05, 0.31), Vector3(0.62, 1.5, 0.08)],
		"inside": [Vector3(0.35, 0.05, 0.02)], "eye": 1.55, "look": Vector3(0, 0, 1), "peek": 0.36,
		"exit": Vector3(0.35, 0.05, 0.85), "crouch": false,
	},
	"sofa": {
		"name": "the sofa bed", "capacity": 1, "exposed": false, "view": "low",
		"zone": [Vector3(0.42, 0.5, 0.05), Vector3(0.75, 0.22, 0.6)],
		"inside": [Vector3(0.2, 0.05, 0.0)], "eye": 0.3, "look": Vector3(0, 0, 1), "peek": 0.52,
		"exit": Vector3(-0.3, 0.05, 1.0), "crouch": true,
	},
	"shower": {
		"name": "the shower", "capacity": 2, "exposed": false, "view": "curtain",
		"zone": [Vector3(6.3, 1.0, -1.0), Vector3(0.65, 1.8, 0.12)],
		"inside": [Vector3(6.6, 0.05, -0.4), Vector3(6.3, 0.05, -0.55)], "eye": 1.55, "look": Vector3(0, 0, -1), "peek": 0.42,
		"exit": Vector3(5.8, 0.05, -1.3), "crouch": false,
	},
	"window": {
		"name": "the window ledge", "capacity": 1, "exposed": true, "view": "",
		"zone": [Vector3(2.5, 1.75, -4.92), Vector3(1.5, 0.7, 0.1)],
		"inside": [Vector3(2.5, 0.72, -5.45)], "eye": 1.55, "look": Vector3(0, 0, -1),
		"exit": Vector3(2.5, 0.05, -3.75), "crouch": false,
	},
	"hall": {
		"name": "the trash bags by 302", "capacity": 2, "exposed": true, "view": "",
		"zone": [Vector3(9.35, 0.45, 0.5), Vector3(0.7, 0.9, 0.7)],
		"inside": [Vector3(9.75, 0.05, 0.6), Vector3(9.75, 0.05, 1.05)], "eye": 0.9, "look": Vector3(-1, 0, 0),
		"exit": Vector3(8.9, 0.05, 0.95), "crouch": true,
	},
}

var key := ""
var spot_name := ""
var capacity := 1
var exposed := false
var view := ""
var crouch := false
## Ids dos jogadores lá dentro, na ordem em que entraram (vale em todas as máquinas).
var occupants: Array = []
var zone: Area3D
var _spec: Dictionary
var _kitnet: Node


## Chame antes de pôr na árvore.
func setup(spot_key: String) -> void:
	key = spot_key
	_spec = SPOTS[spot_key]
	name = "Hideout_" + spot_key
	spot_name = _spec["name"]
	capacity = _spec["capacity"]
	exposed = _spec["exposed"]
	view = _spec["view"]
	crouch = _spec["crouch"]
	zone = InteractZone.new()
	zone.setup(self, "Zone_Hide", _spec["zone"][0], _spec["zone"][1])
	zone.prompt_fn = _prompt
	zone.press_fn = _press


func _ready() -> void:
	add_to_group("station")
	add_to_group("hideout")
	_kitnet = get_tree().get_first_node_in_group("kitnet")


# --- Onde fica cada um (todas as máquinas) ------------------------------------------------------

## Vaga do jogador `peer` aqui (-1 = não está).
func slot_of(peer: int) -> int:
	return occupants.find(peer)


## Onde o corpo de quem está na vaga `slot` fica (no mundo).
func body_point(slot: int) -> Vector3:
	var points: Array = _spec["inside"]
	return global_transform * (points[clampi(slot, 0, points.size() - 1)] as Vector3)


## Onde fica o olho (no mundo): em cima do corpo, encostado na fresta.
func eye_point(slot: int) -> Vector3:
	var forward: Vector3 = global_basis * (_spec["look"] as Vector3) * float(_spec.get("peek", 0.0))
	return body_point(slot) + Vector3.UP * float(_spec["eye"]) + forward


## Para onde quem está aqui olha (giro em Y do jogador, que olha para -Z).
func look_yaw() -> float:
	var dir: Vector3 = global_basis * (_spec["look"] as Vector3)
	return atan2(-dir.x, -dir.z)


## Por onde sai (no mundo).
func exit_point() -> Vector3:
	return global_transform * (_spec["exit"] as Vector3)


## O meio do esconderijo (os policiais vão revistar olhando para cá).
func center() -> Vector3:
	return global_transform * (_spec["zone"][0] as Vector3)


func full() -> bool:
	return occupants.size() >= capacity


# --- [E] -----------------------------------------------------------------------------------

func _prompt(player: Node) -> String:
	if slot_of(player.name.to_int()) >= 0:
		return ""
	if player.get("arrest_stage") != "":
		return ""
	if full():
		return "Someone is already hiding in %s" % spot_name
	return "[E] Hide in %s" % spot_name


## Host: [E] na zona: entra (se couber).
func _press(peer: int) -> void:
	enter(peer)


## Host: põe o jogador aqui dentro (sai de qualquer outro esconderijo).
func enter(peer: int) -> bool:
	if full() or slot_of(peer) >= 0:
		return false
	var player: Node = _kitnet.players.get(peer)
	if player == null or player.get("arrest_stage") != "" or player.get("fallen"):
		return false
	for other in get_tree().get_nodes_in_group("hideout"):
		if other != self and other.slot_of(peer) >= 0:
			other.leave(peer)
	occupants.append(peer)
	_broadcast("", [peer])
	return true


## Qualquer máquina: o jogador local quer sair.
func request_leave() -> void:
	if multiplayer.is_server():
		leave(multiplayer.get_unique_id())
	else:
		_rpc_leave.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave() -> void:
	if multiplayer.is_server():
		leave(multiplayer.get_remote_sender_id())


## Host: tira o jogador daqui (sai pela frente).
func leave(peer: int) -> void:
	if slot_of(peer) < 0:
		return
	occupants.erase(peer)
	_broadcast("", [peer])


## Host: a polícia abriu o esconderijo: todo mundo que estava aqui sai, pego. Devolve os ids.
func flush() -> Array:
	var found := occupants.duplicate()
	if found.is_empty():
		return found
	occupants.clear()
	_broadcast("found", found)
	return found


func drop_peer(peer: int) -> void:
	if slot_of(peer) >= 0:
		occupants.erase(peer)
		_broadcast("", [peer])


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, occupants, "", [])


## Repassa a lista para todos. `who` são os que acabaram de entrar ou sair (no host a lista já
## mudou antes daqui, então quem saiu só aparece em `who`).
func _broadcast(event: String, who: Array = []) -> void:
	_kitnet.rpc_roster(self, &"_sync", [occupants, event, who])
	_sync(occupants, event, who)


@rpc("authority", "call_remote", "reliable")
func _sync(list: Array, event: String, who: Array) -> void:
	var before := occupants.duplicate()
	occupants = list.duplicate()
	# Cada jogador que entrou ou saiu fica sabendo (o dono trava ou solta o corpo).
	for peer in before + occupants + who:
		var player: Node = _kitnet.players.get(peer)
		if player != null:
			player.update_hiding(self, slot_of(peer) >= 0, event == "found" and peer in who)
