extends RigidBody3D
## Objeto que os jogadores carregam, um por vez (resma, folha impressa...). Tipos em item_kinds.gd.
##
## Rede: o host manda. Ele simula a física dos que estão soltos e manda a posição para os outros,
## que só seguem. O que está na mão de alguém segue o ponto Hold desse jogador em todas as
## máquinas (sem física nem colisão), com um atraso suave: ao pegar ele voa até a mão, e ao
## virar a câmera ele vem um pouco atrás. "resting" = parado onde a máquina pôs (bandeja da
## impressora), congelado até alguém pegar.
##
## Camadas: 3 = itens (bate no mundo e em outros itens; os jogadores passam por eles).

const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const LAYER := 4  # camada 3
const MASK := 1 | 4
const SEND_RATE := 20.0
## Quão rápido o item na mão alcança a pose (por segundo); menor = mais solto.
const HOLD_FOLLOW := 16.0

var id := 0
var kind := ""
var data := {}
## Peer segurando (0 = solto).
var holder := 0

var _kitnet: Node
var _target := Transform3D.IDENTITY
var _send_timer := 0.0
## Pose atual na mão, relativa ao ponto Hold de quem segura (anda até ItemKinds.hold_offset).
var _held_local := Transform3D.IDENTITY
var _holder_node: Node3D = null
var _last_hold_pos := Vector3.ZERO
var _hold_speed := 0.0
var _mesh: MeshInstance3D


func setup(item_id: int, item_kind: String, item_data: Dictionary, xform: Transform3D, held_by: int) -> void:
	id = item_id
	kind = item_kind
	data = item_data.duplicate()
	holder = held_by
	name = "Item_%d" % id
	transform = xform
	_target = xform


func _ready() -> void:
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Antes dos jogadores: as luvas deles leem a pose do item já atualizada no quadro.
	process_priority = -10
	ItemKinds.build(self)
	_mesh = get_node_or_null("Mesh")
	sleeping_state_changed.connect(_on_sleeping_changed)
	apply_mode()


## Liga ou desliga a física e a colisão conforme está na mão, parado ou solto.
func apply_mode() -> void:
	var held := holder != 0
	collision_layer = 0 if held else LAYER
	collision_mask = 0 if held else MASK
	freeze = held or data.get("resting", false) or not multiplayer.is_server()
	_holder_node = _kitnet.players.get(holder) if held else null
	if _holder_node != null:
		# Começa de onde estava no mundo: o item voa até a mão.
		_held_local = _holder_node.hold_point.global_transform.affine_inverse() * global_transform
		_last_hold_pos = _holder_node.hold_point.global_position
	if kind == "sheet" and _mesh:
		_mesh.set_instance_shader_parameter("droop", ItemKinds.SHEET_DROOP if held else 0.0)
		_mesh.set_instance_shader_parameter("flutter", 0.0)


func get_prompt(player: Node) -> String:
	if holder != 0 or player.held_item() != null:
		return ""
	return "[E] Pick up " + ItemKinds.label(self)


func interact(_player: Node) -> void:
	_kitnet.items.request_pickup(id)


## Na mão: segue o ponto Hold a cada quadro de tela (suave mesmo acima de 60 fps).
func _process(delta: float) -> void:
	if holder == 0 or _holder_node == null or not is_instance_valid(_holder_node):
		return
	var hold: Transform3D = _holder_node.hold_point.global_transform
	_held_local = _held_local.interpolate_with(ItemKinds.hold_offset(kind), clampf(HOLD_FOLLOW * delta, 0.0, 1.0))
	global_transform = hold * _held_local
	if kind == "sheet" and _mesh and delta > 0.0:
		# A folha tremula mais quanto mais rápido quem segura anda.
		var speed := hold.origin.distance_to(_last_hold_pos) / delta
		_hold_speed = lerpf(_hold_speed, speed, clampf(6.0 * delta, 0.0, 1.0))
		_mesh.set_instance_shader_parameter("flutter", clampf(_hold_speed / 5.0, 0.0, 1.0) * 0.008)
	_last_hold_pos = hold.origin


func _physics_process(delta: float) -> void:
	if holder != 0:
		return
	if not multiplayer.is_server():
		global_transform = global_transform.interpolate_with(_target, clampf(20.0 * delta, 0.0, 1.0))
		return
	if not freeze and not sleeping:
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 1.0 / SEND_RATE
			_kitnet.rpc_roster(self, &"_remote_xform", [global_transform])


## Quando para de rolar, manda a posição final (o envio contínuo para junto).
func _on_sleeping_changed() -> void:
	if multiplayer.is_server() and sleeping and holder == 0:
		_kitnet.rpc_roster(self, &"_remote_xform", [global_transform])


@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_xform(xform: Transform3D) -> void:
	_target = xform


## Coloca o item num lugar na hora (sem interpolar), em todas as máquinas.
func snap(xform: Transform3D) -> void:
	global_transform = xform
	_target = xform
