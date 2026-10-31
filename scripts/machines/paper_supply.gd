extends Node3D
## Caixas de resma (filha do SUPPLY_Paper do kitnet.glb): [E] de mão vazia pega uma resma.
## O estoque da noite é limitado; o host conta e repassa.

const InteractZone := preload("res://scripts/interact_zone.gd")
## Resmas por noite (depois vem do catálogo do fornecedor).
const START_STOCK := 12

var stock := START_STOCK
var zone: Area3D
var _kitnet: Node


func _ready() -> void:
	name = "PaperSupply"
	add_to_group("station")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	zone = InteractZone.new()
	zone.setup(self, "Zone_Take", Vector3(0, 0.4, 0), Vector3(0.7, 0.82, 0.6))
	zone.prompt_fn = _prompt
	zone.press_fn = _take


func _prompt(player: Node) -> String:
	if stock <= 0:
		return "No paper left"
	if player.held_item() != null:
		return "Paper reams: %d left" % stock
	if player.hands_left() < 2:
		return "Needs both hands to carry a ream"
	return "[E] Take a paper ream (%d left)" % stock


func _take(peer: int) -> void:
	var player: Node = _kitnet.players.get(peer)
	if stock <= 0 or _kitnet.items.held_by(peer) != null or player == null or player.hands_left() < 2:
		return
	stock -= 1
	_kitnet.items.give(peer, "ream")
	_kitnet.rpc_roster(self, &"_set_stock", [stock])


func send_state_to(peer: int) -> void:
	_set_stock.rpc_id(peer, stock)


@rpc("authority", "call_remote", "reliable")
func _set_stock(value: int) -> void:
	stock = value
