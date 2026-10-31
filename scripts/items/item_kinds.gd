extends RefCounted
## Tipos de objeto carregável: aparência, colisão, peso, nome na tela e como fica na mão.
##
##   "ream"   resma de papel embrulhada (vira folhas na impressora)
##   "sheet"  folha A4 impressa com 2 x 3 notas; data.wet = tinta ainda fresca
##   "bills"  montinho de notas cortadas; data.count = quantas, data.smudged = quantas
##            borradas (cortadas molhadas), data.top_smudged = se a de cima está borrada,
##            data.crooked = quantas saíram tortas da guilhotina, data.worth = quanto o monte
##            vale em notas perfeitas (sem a chave: count), data.top_cut = o pedaço da folha que
##            virou a nota de cima, se ela saiu torta (Rect2 na textura da folha; vazio = reta)
##   "finger" um dedo que a guilhotina levou (a peça da luva do hands.glb); data.owner = de quem,
##            data.side = 0 direita / 1 esquerda, data.digit = qual (player.DIGITS)
##   "hand"   a mão inteira que a guilhotina levou: a luva com os dedos que ainda tinha;
##            data.owner, data.side e data.lost = os dedos que já tinham ido antes (bits)
##
## As texturas saem do art_source/paper_textures.py (assets/textures/).

const PAPER_SHADER := preload("res://shaders/paper.gdshader")
const Toon := preload("res://scripts/toon.gd")
const SHEET_FRONT := preload("res://assets/textures/sheet_front.png")
const SHEET_BACK := preload("res://assets/textures/sheet_back.png")
const PAPER_NORMAL := preload("res://assets/textures/paper_normal.png")
const REAM_WRAPPER := preload("res://assets/textures/ream_wrapper.png")
const BILL_FRONT := preload("res://assets/textures/bill_front.png")
const BILL_FRONT_SMUDGED := preload("res://assets/textures/bill_front_smudged.png")
const BILL_BACK := preload("res://assets/textures/bill_back.png")
const HANDS_MODEL := preload("res://assets/models/hands.glb")
const DIGITS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
## Pedaços de luva: o tamanho sai da malha.
const GLOVE_PIECES := ["finger", "hand"]
## Só dá para carregar com as duas mãos.
const TWO_HANDED := ["ream"]

const SIZES := {
	"ream": Vector3(0.3, 0.052, 0.21),
	"sheet": Vector3(0.297, 0.003, 0.21),
	"bills": Vector3(0.139, 0.002, 0.063),
}
## Espessura de cada nota no montinho (bem mais que o papel de verdade, para o monte aparecer).
const BILL_THICKNESS := 0.0004
## Uma resma de 500 folhas pesa uns 2,5 kg; uma folha A4 de 75 g/m², 5 g.
const MASS := {"ream": 2.5, "sheet": 0.005, "bills": 0.001, "finger": 0.02, "hand": 0.35}
## Atrito, quique e amortecimento do giro de cada tipo.
const PHYSICS := {
	"ream": {"friction": 0.8, "bounce": 0.12, "angular_damp": 0.6},
	"sheet": {"friction": 0.9, "bounce": 0.0, "angular_damp": 1.0},
	"bills": {"friction": 0.85, "bounce": 0.02, "angular_damp": 0.8},
	"finger": {"friction": 0.7, "bounce": 0.3, "angular_damp": 0.3},
	"hand": {"friction": 0.75, "bounce": 0.25, "angular_damp": 0.4},
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
		"bills":
			var count: int = item.data.get("count", 0)
			var smudged: int = item.data.get("smudged", 0)
			var crooked: int = item.data.get("crooked", 0)
			var text := "%d bill%s" % [count, "" if count == 1 else "s"]
			var notes: Array[String] = []
			if smudged >= count and count > 0:
				notes.append("smudged")
			elif smudged > 0:
				notes.append("%d smudged" % smudged)
			if crooked >= count and count > 0:
				notes.append("crooked")
			elif crooked > 0:
				notes.append("%d crooked" % crooked)
			return text + (" (%s)" % ", ".join(notes) if not notes.is_empty() else "")
		"finger":
			return "%s's %s" % [item.data.get("owner", "Someone"), String(item.data.get("digit", "finger")).to_lower()]
		"hand":
			return "%s's %s hand" % [item.data.get("owner", "Someone"), "right" if item.data.get("side", 0) == 0 else "left"]
	return item.kind


## Como o item fica na mão, em relação ao ponto Hold: a folha inclinada para quem segura ver as
## notas (a borda de perto embaixo, nas mãos), a resma um pouco virada para mostrar a tampa.
static func hold_offset(kind: String) -> Transform3D:
	match kind:
		"sheet":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.06, 0.0))
		"ream":
			return Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, -0.05, -0.06))
		"bills":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.05, 0.0))
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
		"bills":
			return Transform3D(basis, Vector3(side * 0.112, -0.025, 0.075))
	return Transform3D(basis, Vector3(side * 0.15, 0.0, 0.1))


## Monta a malha e a colisão do item (filhos do RigidBody3D).
static func build(item: RigidBody3D) -> void:
	var size: Vector3 = SIZES.get(item.kind, Vector3(0.2, 0.2, 0.2))
	var piece: Node3D = null
	if item.kind in GLOVE_PIECES:
		piece = _glove_piece(item)
		size = piece.get_meta("size")
		item.continuous_cd = true
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
	if piece != null:
		item.add_child(piece)
		return
	var mesh: MeshInstance3D
	if item.kind == "sheet":
		item.continuous_cd = true
		mesh = sheet_mesh_instance(item.data.get("wet", false))
	elif item.kind == "bills":
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
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
	if item.kind == "bills":
		refresh(item)


## Um dedo ou a mão inteira que a guilhotina levou: as peças da luva (hands.glb) do lado certo,
## centradas no meio delas (o item gira em volta dele). O tamanho vai no meta "size".
static func _glove_piece(item: RigidBody3D) -> Node3D:
	var prefix := "Hand_R_" if item.data.get("side", 0) == 0 else "Hand_L_"
	var names: Array[String] = []
	if item.kind == "finger":
		names.append(prefix + String(item.data.get("digit", "Index")))
	else:
		names.append(prefix + "Glove")
		var lost: int = item.data.get("lost", 0)
		for d in DIGITS.size():
			if lost & (1 << d) == 0:
				names.append(prefix + DIGITS[d])
	var model := HANDS_MODEL.instantiate()
	var root := Node3D.new()
	root.name = "Pieces"
	var box := AABB()
	for i in names.size():
		var part: MeshInstance3D = model.find_child(names[i], true, false)
		var copy := MeshInstance3D.new()
		copy.mesh = part.mesh
		root.add_child(copy)
		box = part.mesh.get_aabb() if i == 0 else box.merge(part.mesh.get_aabb())
	model.free()
	for copy: Node3D in root.get_children():
		copy.position = -box.get_center()
	root.set_meta("size", box.size)
	return root


## Atualiza a aparência quando o estado muda (folha secou, o montinho cresceu).
static func refresh(item: RigidBody3D) -> void:
	var mesh: MeshInstance3D = item.get_node_or_null("Mesh")
	if item.kind == "sheet" and mesh:
		mesh.set_instance_shader_parameter("wet", 1.0 if item.data.get("wet", false) else 0.0)
	elif item.kind == "bills" and mesh:
		# Uma malha de 1 de altura, esticada até a altura do monte; a colisão acompanha.
		var count: int = maxi(item.data.get("count", 1), 1)
		var height := maxf(count * BILL_THICKNESS, 0.0015)
		mesh.mesh = _bills_mesh(item.data.get("top_smudged", false), item.data.get("top_cut", Rect2()))
		Toon.apply_one(mesh)
		mesh.scale = Vector3(1.0, height, 1.0)
		var col: CollisionShape3D = item.get_child(0)
		(col.shape as BoxShape3D).size = Vector3(SIZES["bills"].x, height, SIZES["bills"].z)
		item.mass = MASS["bills"] * count


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


## Montinho de notas: caixa de 1 de altura (o item estica), com a nota na tampa (borrada ou não),
## o verso embaixo e as bordas de papel nos lados. Três superfícies, uma para cada material. Se a
## nota de cima saiu torta da guilhotina (`top_cut` não vazio), a tampa mostra o pedaço da folha
## que ela é de verdade: sobra de margem ou da nota vizinha, ou a nota comida pelo corte.
static func _bills_mesh(top_smudged: bool, top_cut := Rect2()) -> Mesh:
	var cut := top_cut.has_area()
	var key := "bills_mesh_cut_%s" % top_cut if cut else ("bills_mesh_smudged" if top_smudged else "bills_mesh")
	if _cache.has(key):
		return _cache[key]
	var h: Vector3 = Vector3(SIZES["bills"].x, 1.0, SIZES["bills"].z) / 2.0
	var full := Rect2(0, 0, 1, 1)
	var mesh := ArrayMesh.new()
	var top_tex: Texture2D = SHEET_FRONT if cut else (BILL_FRONT_SMUDGED if top_smudged else BILL_FRONT)
	var faces := [
		[top_tex, [[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]]]],
		[BILL_BACK, [[Vector3.DOWN, [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z)]]]],
		[null, [
			[Vector3.BACK, [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]],
			[Vector3.FORWARD, [Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)]],
			[Vector3.RIGHT, [Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)]],
			[Vector3.LEFT, [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)]],
		]],
	]
	for surface in faces:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in surface[1]:
			_face(st, face[0], face[1], top_cut if cut and surface == faces[0] else full)
		var mat := StandardMaterial3D.new()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if surface[0] != null:
			mat.albedo_texture = surface[0]
			mat.roughness = 0.75
		else:
			# Bordas: papel claro com um tom de verde das notas empilhadas.
			mat.albedo_color = Color(0.8, 0.86, 0.76)
			mat.roughness = 0.9
		st.set_material(mat)
		st.commit(mesh)
	_cache[key] = mesh
	return mesh


static func _face(st: SurfaceTool, normal: Vector3, corners: Array, region: Rect2) -> void:
	var uvs := [region.position, region.position + Vector2(region.size.x, 0), region.end,
			region.position + Vector2(0, region.size.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
