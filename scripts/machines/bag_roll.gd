extends Node3D
## Rolo de sacos de lixo pretos deitado na bancada da cozinha, entre a pia e o fogão (filho da
## kitnet, em SPOT). [E] de mão vazia destaca um saco: ele vem dobrado para a mão (item
## "trashbag", ver item_kinds.gd). O rolo não acaba.
##
## A malha é feita aqui mesmo: o rolo preto, o tubo de papelão aparecendo nas pontas e a ponta
## do saco de fora caída na frente.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")

## Em cima do granito, no vão livre entre a cuba e o cooktop (furniture.py, kitchen).
const SPOT := Vector3(1.93, 0.9, -0.42)
const RADIUS := 0.042
const LENGTH := 0.22
const CORE_RADIUS := 0.017
const CARDBOARD := Color(0.62, 0.48, 0.32)
## A cinta de papel da marca em volta do rolo (sem ela, o rolo preto some no granito preto).
const SLEEVE := Color(0.98, 0.6, 0.12)
const SLEEVE_STRIPE := Color(0.97, 0.95, 0.88)
const SLEEVE_WIDTH := 0.09

var zone: Area3D
var _kitnet: Node


func _ready() -> void:
	name = "BagRoll"
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	_build()
	zone = InteractZone.new()
	zone.setup(self, "Zone_BagRoll", Vector3(0.0, RADIUS, 0.03), Vector3(LENGTH + 0.06, RADIUS * 2.0 + 0.04, 0.16))
	zone.prompt_fn = _prompt
	zone.press_fn = _tear
	Toon.apply(self)


func _prompt(player: Node) -> String:
	if player.held_item() != null:
		return "Trash bags (hands full)"
	return "[E] Tear off a trash bag"


## Host: [E] no rolo.
func _tear(peer: int) -> void:
	if _kitnet.items.held_by(peer) != null:
		return
	_kitnet.items.give(peer, "trashbag", {"contents": []})


func _build() -> void:
	var roll := CylinderMesh.new()
	roll.top_radius = RADIUS
	roll.bottom_radius = RADIUS
	roll.height = LENGTH
	roll.radial_segments = 20
	roll.material = ItemKinds._flat_material(ItemKinds.BAG_COLOR, ItemKinds.BAG_ROUGHNESS)
	_part(roll, Vector3(0.0, RADIUS, 0.0))
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = RADIUS + 0.002
	sleeve.bottom_radius = RADIUS + 0.002
	sleeve.height = SLEEVE_WIDTH
	sleeve.radial_segments = 20
	sleeve.material = ItemKinds._flat_material(SLEEVE, 0.8)
	_part(sleeve, Vector3(0.0, RADIUS, 0.0))
	var stripe := CylinderMesh.new()
	stripe.top_radius = RADIUS + 0.003
	stripe.bottom_radius = RADIUS + 0.003
	stripe.height = 0.018
	stripe.radial_segments = 20
	stripe.material = ItemKinds._flat_material(SLEEVE_STRIPE, 0.8)
	_part(stripe, Vector3(0.0, RADIUS, 0.0))
	# O tubo de papelão, um pouco mais comprido que o rolo, e o furo escuro dele.
	var core := CylinderMesh.new()
	core.top_radius = CORE_RADIUS
	core.bottom_radius = CORE_RADIUS
	core.height = LENGTH + 0.006
	core.radial_segments = 14
	core.material = ItemKinds._flat_material(CARDBOARD, 0.9)
	_part(core, Vector3(0.0, RADIUS, 0.0))
	var hole := CylinderMesh.new()
	hole.top_radius = CORE_RADIUS * 0.75
	hole.bottom_radius = CORE_RADIUS * 0.75
	hole.height = LENGTH + 0.008
	hole.radial_segments = 12
	hole.material = ItemKinds._flat_material(Color(0.08, 0.06, 0.05), 1.0)
	_part(hole, Vector3(0.0, RADIUS, 0.0))
	# A ponta do saco de fora: desce do rolo e fica caída na frente, no granito.
	var tail := BoxMesh.new()
	tail.size = Vector3(LENGTH - 0.01, 0.002, 0.07)
	tail.material = roll.material
	var flap := _part(tail, Vector3(0.0, 0.003, RADIUS + 0.03))
	flap.rotation.x = 0.06


func _part(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	if mesh is CylinderMesh:
		# Deitado ao longo do X.
		node.rotation.z = PI / 2.0
	add_child(node)
	return node
