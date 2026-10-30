extends RefCounted
## Tipos de objeto carregável: aparência, colisão, peso, nome na tela e como fica na mão.
##
##   "ream"   resma de papel embrulhada (vira folhas na impressora)
##   "sheet"  folha A4 impressa com 2 x 3 notas; data.wet = tinta ainda fresca
##
## As texturas saem do art_source/paper_textures.py (assets/textures/).

const PAPER_SHADER := preload("res://shaders/paper.gdshader")
const SHEET_FRONT := preload("res://assets/textures/sheet_front.png")
const SHEET_BACK := preload("res://assets/textures/sheet_back.png")
const PAPER_NORMAL := preload("res://assets/textures/paper_normal.png")
const REAM_WRAPPER := preload("res://assets/textures/ream_wrapper.png")

const SIZES := {
	"ream": Vector3(0.3, 0.052, 0.21),
	"sheet": Vector3(0.297, 0.003, 0.21),
}
## Uma resma de 500 folhas pesa uns 2,5 kg; uma folha A4 de 75 g/m², 5 g.
const MASS := {"ream": 2.5, "sheet": 0.005}
## Atrito, quique e amortecimento do giro de cada tipo.
const PHYSICS := {
	"ream": {"friction": 0.8, "bounce": 0.12, "angular_damp": 0.6},
	"sheet": {"friction": 0.9, "bounce": 0.0, "angular_damp": 1.0},
}
## Ar na folha (ver item.gd, _paper_air). Arrasto da face: 0,5 · ρ · Cd · área (1,2 · 1,2 · 0,062 / 2),
## o que dá ~1 m/s de velocidade final caindo deitada. O de lado (pela borda) é bem menor.
const PAPER_FACE_DRAG := 0.045
const PAPER_EDGE_DRAG := 0.002
## Quanto a face vira contra o vento (passa do ponto e volta: a folha balança ao cair).
const PAPER_ALIGN := 0.0004
## Tremor aleatório do ar.
const PAPER_FLUTTER := 0.00004
## Quanto a borda de longe da folha cai quando alguém segura pela de perto (m).
const SHEET_DROOP := 0.03

static var _cache := {}


static func label(item: Node) -> String:
	match item.kind:
		"ream":
			return "paper ream"
		"sheet":
			return "wet sheet" if item.data.get("wet", false) else "printed sheet"
	return item.kind


## Como o item fica na mão, em relação ao ponto Hold: a folha inclinada para quem segura ver as
## notas (a borda de perto embaixo, nas mãos), a resma um pouco virada para mostrar a tampa.
static func hold_offset(kind: String) -> Transform3D:
	match kind:
		"sheet":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.06, 0.0))
		"ream":
			return Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, -0.05, -0.06))
	return Transform3D.IDENTITY


## Onde fica o pulso de cada luva (side 1 = direita, -1 = esquerda), no referencial do item. A
## palma vira para o centro e o polegar para cima: a folha fica presa entre o polegar e o
## indicador nos cantos de perto; a resma, apertada pelos lados.
static func hand_offset(kind: String, side: int) -> Transform3D:
	var basis := Basis(Vector3.BACK, -side * PI / 2)
	match kind:
		"sheet":
			return Transform3D(basis, Vector3(side * 0.135, -0.03, 0.17))
		"ream":
			return Transform3D(basis, Vector3(side * 0.176, -0.02, 0.11))
	return Transform3D(basis, Vector3(side * 0.15, 0.0, 0.1))


## Monta a malha e a colisão do item (filhos do RigidBody3D).
static func build(item: RigidBody3D) -> void:
	var size: Vector3 = SIZES.get(item.kind, Vector3(0.2, 0.2, 0.2))
	item.mass = MASS.get(item.kind, 1.0)
	var phys: Dictionary = PHYSICS.get(item.kind, {})
	var material := PhysicsMaterial.new()
	material.friction = phys.get("friction", 0.7)
	material.bounce = phys.get("bounce", 0.1)
	item.physics_material_override = material
	item.angular_damp = phys.get("angular_damp", 0.5)
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	item.add_child(col)
	var mesh: MeshInstance3D
	if item.kind == "sheet":
		item.continuous_cd = true
		mesh = sheet_mesh_instance(item.data.get("wet", false))
	else:
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
		if item.kind == "ream":
			mesh.mesh = _ream_mesh()
		else:
			var box := BoxMesh.new()
			box.size = size
			mesh.mesh = box
	item.add_child(mesh)


## Atualiza a aparência quando o estado muda (folha secou).
static func refresh(item: RigidBody3D) -> void:
	var mesh: MeshInstance3D = item.get_node_or_null("Mesh")
	if item.kind == "sheet" and mesh:
		mesh.set_instance_shader_parameter("wet", 1.0 if item.data.get("wet", false) else 0.0)


## Uma folha (a do item e a que a impressora mostra saindo pela fenda).
static func sheet_mesh_instance(wet: bool) -> MeshInstance3D:
	if not _cache.has("sheet_mesh"):
		var plane := PlaneMesh.new()
		plane.size = Vector2(SIZES["sheet"].x, SIZES["sheet"].z)
		plane.subdivide_width = 14
		plane.subdivide_depth = 10
		var mat := ShaderMaterial.new()
		mat.shader = PAPER_SHADER
		mat.set_shader_parameter("front_tex", SHEET_FRONT)
		mat.set_shader_parameter("back_tex", SHEET_BACK)
		mat.set_shader_parameter("paper_normal", PAPER_NORMAL)
		mat.set_shader_parameter("sheet_size", plane.size)
		plane.material = mat
		_cache["sheet_mesh"] = plane
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = _cache["sheet_mesh"]
	mesh.set_instance_shader_parameter("wet", 1.0 if wet else 0.0)
	return mesh


## Resma embrulhada: caixa com a embalagem (ream_wrapper.png) mapeada face a face. O atlas está
## descrito no paper_textures.py: tampa, lateral comprida, ponta dobrada e fundo.
static func _ream_mesh() -> Mesh:
	if _cache.has("ream_mesh"):
		return _cache["ream_mesh"]
	var h: Vector3 = SIZES["ream"] / 2.0
	var top := Rect2(0, 0, 1, 716.0 / 1024.0)
	var side := Rect2(0, 716.0 / 1024.0, 1, 176.0 / 1024.0)
	var tip := Rect2(0, 892.0 / 1024.0, 528.0 / 1024.0, 132.0 / 1024.0)
	var bottom := Rect2(528.0 / 1024.0, 892.0 / 1024.0, 496.0 / 1024.0, 132.0 / 1024.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Cada face: cantos de cima-esquerda, cima-direita, baixo-direita, baixo-esquerda de quem olha
	# de fora, e a região do atlas.
	_face(st, Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)], top)
	_face(st, Vector3.DOWN, [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)], bottom)
	_face(st, Vector3.BACK, [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)], side)
	_face(st, Vector3.FORWARD, [Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)], side)
	_face(st, Vector3.RIGHT, [Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)], tip)
	_face(st, Vector3.LEFT, [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)], tip)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = REAM_WRAPPER
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	st.set_material(mat)
	var mesh := st.commit()
	_cache["ream_mesh"] = mesh
	return mesh


static func _face(st: SurfaceTool, normal: Vector3, corners: Array, region: Rect2) -> void:
	var uvs := [region.position, region.position + Vector2(region.size.x, 0), region.end,
			region.position + Vector2(0, region.size.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
