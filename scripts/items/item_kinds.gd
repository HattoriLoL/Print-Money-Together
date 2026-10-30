extends RefCounted
## Tipos de objeto carregável: aparência, colisão, peso e nome na tela.
##
##   "ream"   resma de papel (vira folhas na impressora)
##   "sheet"  folha A4 impressa com 2 x 3 notas; data.wet = tinta ainda fresca

const BILL := preload("res://assets/textures/bill.png")

const SIZES := {
	"ream": Vector3(0.3, 0.052, 0.21),
	"sheet": Vector3(0.297, 0.003, 0.21),
}
const MASS := {"ream": 2.5, "sheet": 0.05}

static var _materials := {}


## Como o item fica na mão, em relação ao ponto Hold (a folha vem inclinada para quem segura
## ver as notas).
static func hold_offset(kind: String) -> Transform3D:
	match kind:
		"sheet":
			return Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(-0.05, 0.08, 0.0))
	return Transform3D.IDENTITY


static func label(item: Node) -> String:
	match item.kind:
		"ream":
			return "paper ream"
		"sheet":
			return "wet sheet" if item.data.get("wet", false) else "printed sheet"
	return item.kind


## Monta a malha e a colisão do item (filhos do RigidBody3D).
static func build(item: RigidBody3D) -> void:
	var size: Vector3 = SIZES.get(item.kind, Vector3(0.2, 0.2, 0.2))
	item.mass = MASS.get(item.kind, 1.0)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	item.add_child(col)
	match item.kind:
		"ream":
			_box(item, size, _mat("paper", Color(0.96, 0.96, 0.93), 0.8))
			_box(item, Vector3(0.12, size.y + 0.002, size.z + 0.004), _mat("band", Color(0.15, 0.3, 0.6), 0.5))
		"sheet":
			item.continuous_cd = true
			var mat := sheet_material(item.data.get("wet", false))
			for flip in [false, true]:
				var quad := QuadMesh.new()
				quad.size = Vector2(size.x, size.z)
				quad.material = mat
				var mesh := MeshInstance3D.new()
				mesh.mesh = quad
				mesh.rotation.x = PI / 2 if flip else -PI / 2
				mesh.position.y = (-1 if flip else 1) * size.y / 2
				item.add_child(mesh)
		_:
			_box(item, size, _mat("unknown", Color.MAGENTA, 0.5))


## Atualiza a aparência quando o estado muda (folha secou).
static func refresh(item: RigidBody3D) -> void:
	if item.kind == "sheet":
		var mat := sheet_material(item.data.get("wet", false))
		for child in item.get_children():
			if child is MeshInstance3D:
				(child.mesh as QuadMesh).material = mat


static func sheet_material(wet: bool) -> StandardMaterial3D:
	var key := "sheet_wet" if wet else "sheet_dry"
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = BILL
		mat.uv1_scale = Vector3(2, 3, 1)
		if wet:
			# Tinta fresca: mais escura e brilhando.
			mat.albedo_color = Color(0.7, 0.8, 0.7)
			mat.roughness = 0.12
			mat.metallic_specular = 0.9
		else:
			mat.roughness = 0.8
		_materials[key] = mat
	return _materials[key]


static func _mat(key: String, color: Color, roughness: float) -> StandardMaterial3D:
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_materials[key] = mat
	return _materials[key]


static func _box(item: Node3D, size: Vector3, mat: Material) -> void:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	item.add_child(mesh)
