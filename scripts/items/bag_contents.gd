extends Node3D
## O dinheiro dentro do saco de lixo aberto, com física (filho "Inside" do item "trashbag"). É só
## de enfeite: cada máquina simula o seu, e quem manda no que está dentro é o data.contents do
## host (item_manager.gd). Um corpo por coisa dentro (maço ou montinho), na ordem em que entrou.
##
## O saco vira uma casca (AnimatableBody3D com a própria malha do saco aberto, ConcavePolygonShape3D)
## que acompanha o item, e os maços são RigidBody3D soltos que só batem nela e uns nos outros
## (camada 5, "bag_inside"): caem lá dentro, se empilham e escorregam quando o saco anda, balança
## ou cai. O que entra agora cai da boca; o que sai (tirado ou derramado) é o de cima.
##
## Fechado, não tem nada aqui (não dá para ver dentro); ao abrir, eles nascem deitados no fundo e
## se acomodam. Um corpo que escapar (o saco virou rápido demais) volta para o fundo.

const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")

const LAYER := 16  # camada 5
## Colisão um pouco mais grossa que o maço de verdade (lâmina fina atravessa a casca).
const MIN_THICKNESS := 0.012
const MASS := 0.05
## Folga em volta do saco antes de achar que um corpo escapou (m).
const ESCAPE_MARGIN := 0.06

var _bag: RigidBody3D
var _shell: AnimatableBody3D
var _shell_col: CollisionShape3D
var _shell_key := ""
## Os corpos, na ordem do contents.
var _bodies: Array[RigidBody3D] = []
## [kind, data] de cada corpo (para saber se mudou alguma coisa além da quantidade).
var _kinds: Array = []


func _ready() -> void:
	name = "Inside"
	_bag = get_parent()
	_shell = AnimatableBody3D.new()
	_shell.name = "Shell"
	_shell.top_level = true
	_shell.sync_to_physics = true
	_shell.collision_layer = LAYER
	_shell.collision_mask = 0
	_shell_col = CollisionShape3D.new()
	_shell.add_child(_shell_col)
	add_child(_shell)
	_shell.global_transform = _bag.global_transform


## Quantos corpos estão simulando agora (o teste usa).
func count() -> int:
	return _bodies.size()


## Os corpos (o teste confere que ficaram dentro).
func bodies() -> Array[RigidBody3D]:
	return _bodies


func _physics_process(_delta: float) -> void:
	var open: bool = _bag.data.get("open", false)
	var contents: Array = _bag.data.get("contents", [])
	if not open:
		_clear()
		_shell.process_mode = Node.PROCESS_MODE_DISABLED
		return
	_shell.process_mode = Node.PROCESS_MODE_INHERIT
	_update_shell(contents.size())
	_shell.global_transform = _bag.global_transform
	var fresh := _bodies.is_empty()
	# Tirou ou derramou: some o de cima (o mais perto da boca).
	while _bodies.size() > contents.size():
		_remove_top()
	# Entrou: cai da boca (ou, abrindo agora, nasce deitado no fundo).
	while _bodies.size() < contents.size():
		_add(contents[_bodies.size()], fresh)
	_rescue()


func _update_shell(count_inside: int) -> void:
	var key := "%d" % count_inside
	if key == _shell_key:
		return
	_shell_key = key
	var shape: ConcavePolygonShape3D = ItemKinds.bag_shell_shape(count_inside)
	_shell_col.shape = shape


func _add(entry: Array, stacked: bool) -> void:
	var kind: String = entry[0]
	var data: Dictionary = entry[1]
	var body := RigidBody3D.new()
	body.top_level = true
	body.collision_layer = LAYER
	body.collision_mask = LAYER
	body.mass = MASS
	body.continuous_cd = true
	body.angular_damp = 1.5
	var material := PhysicsMaterial.new()
	material.friction = 0.7
	material.bounce = 0.1
	body.physics_material_override = material
	var mesh := MeshInstance3D.new()
	var size: Vector3
	if kind == "bundle":
		mesh.mesh = ItemKinds._bundle_mesh(data.get("top_offcolor", false), data.get("top_worn", false), ItemKinds.grade(data))
		size = ItemKinds.SIZES["bundle"]
	else:
		var height := maxf(int(data.get("count", 1)) * ItemKinds.BILL_THICKNESS, 0.0015)
		mesh.mesh = ItemKinds._bills_mesh(false, Rect2(), data.get("top_offcolor", false), data.get("top_worn", false))
		mesh.scale = Vector3(1.0, height, 1.0)
		size = Vector3(ItemKinds.SIZES["bills"].x, height, ItemKinds.SIZES["bills"].z)
	body.add_child(mesh)
	Toon.apply_one(mesh)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, maxf(size.y, MIN_THICKNESS), size.z)
	col.shape = box
	body.add_child(col)
	add_child(body)
	var size_bag := ItemKinds.bag_size(_bag.data)
	var i := _bodies.size()
	var local: Vector3
	if stacked:
		# Abrindo: deitados no fundo, uns em cima dos outros, meio tortos.
		local = Vector3(0.02 * sin(i * 2.7), -size_bag.y / 2.0 + 0.012 + i * 0.018, 0.02 * cos(i * 1.9))
	else:
		local = Vector3(0.0, size_bag.y / 2.0 - 0.05, 0.0)
	body.global_transform = _bag.global_transform * Transform3D(Basis.from_euler(Vector3(0.1 * sin(i), i * 1.3 + 0.4, 0.08 * cos(i))), local)
	if not stacked:
		body.linear_velocity = _bag.global_basis.y * -1.2
	_bodies.append(body)
	_kinds.append(entry)


func _remove_top() -> void:
	var top := 0
	var best := -INF
	var up := _bag.global_basis.y
	for i in _bodies.size():
		var height := (_bodies[i].global_position - _bag.global_position).dot(up)
		if height > best:
			best = height
			top = i
	_bodies[top].queue_free()
	_bodies.remove_at(top)
	_kinds.remove_at(top)


## Um corpo que escapou da casca volta para o fundo, parado.
func _rescue() -> void:
	var size := ItemKinds.bag_size(_bag.data)
	var inv := _bag.global_transform.affine_inverse()
	for i in _bodies.size():
		var body := _bodies[i]
		var p := inv * body.global_position
		var out := absf(p.y) > size.y / 2.0 + ESCAPE_MARGIN \
				or Vector2(p.x, p.z).length() > size.x / 2.0 + ESCAPE_MARGIN
		if out:
			body.global_transform = _bag.global_transform * Transform3D(Basis(Vector3.UP, i * 1.3), Vector3(0.0, -size.y / 2.0 + 0.03 + i * 0.018, 0.0))
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO


func _clear() -> void:
	for body in _bodies:
		body.queue_free()
	_bodies.clear()
	_kinds.clear()
