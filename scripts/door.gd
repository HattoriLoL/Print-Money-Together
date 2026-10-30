extends AnimatableBody3D
## Porta de dobradiça vinda do kitnet.glb (KEEP_Door_<n>). A folha já vem com a origem na
## dobradiça, a folha para +X local e o lado de fora para +Z local (o -Y do Blender). Abre
## sempre para dentro (-Z local: a 301 para dentro da kitnet, a do banheiro para dentro do
## banheiro), girando no Y local, e o estado vai para todos os jogadores.

const OPEN_ANGLE := 100.0
const SWING_TIME := 0.45

var key := ""
var is_open := false
var locked := false

var _closed: Basis
var _angle := 0.0
var _swing := 0.0:
	set(value):
		_swing = value
		basis = _closed * Basis(Vector3.UP, value)
var _tween: Tween


## Troca a folha `leaf` por esta porta no mesmo lugar, com uma caixa de colisão do tamanho dela.
func adopt(leaf: MeshInstance3D) -> void:
	key = String(leaf.name).trim_prefix("KEEP_Door_")
	name = "Door_" + key
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	leaf.get_parent().add_child(self)
	transform = leaf.transform
	_closed = basis
	leaf.reparent(self, false)
	leaf.transform = Transform3D.IDENTITY
	var box := leaf.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = box.size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = box.get_center()
	add_child(col)


func get_prompt(_player: Node) -> String:
	if locked:
		return "Locked"
	return "[E] Close" if is_open else "[E] Open"


func interact(_player: Node3D) -> void:
	if locked:
		return
	# Girar +Y leva a folha (+X) para -Z: para dentro.
	var angle := 0.0 if is_open else deg_to_rad(OPEN_ANGLE)
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	kitnet.rpc_roster(self, &"_set_state", [not is_open, angle, false])
	_set_state(not is_open, angle, false)


## Manda o estado atual para quem acabou de entrar.
func send_state_to(peer: int) -> void:
	_set_state.rpc_id(peer, is_open, _angle, true)


@rpc("any_peer", "call_remote", "reliable")
func _set_state(open: bool, angle: float, instant: bool) -> void:
	is_open = open
	_angle = angle if open else 0.0
	if _tween:
		_tween.kill()
	if instant:
		_swing = _angle
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_swing", _angle, SWING_TIME)
