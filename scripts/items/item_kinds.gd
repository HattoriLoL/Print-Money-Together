extends RefCounted
## Tipos de objeto carregável: aparência, colisão, peso, nome na tela e como fica na mão.
##
##   "ream"   resma de papel embrulhada (vira folhas na impressora)
##   "sheet"  folha A4 impressa com 2 x 3 notas; data.wet = tinta ainda fresca (data.wetness = quanto,
##            de 1 a 0, secando no varal; data.hanging = pendurada nele), data.offcolor =
##            impressa com cartucho genérico (as cores saem erradas e as notas valem menos)
##   "bills"  montinho de notas cortadas; data.count = quantas, data.smudged = quantas
##            borradas (cortadas molhadas), data.top_smudged = se a de cima está borrada,
##            data.crooked = quantas saíram tortas da guilhotina, data.offcolor = quantas saíram
##            com a cor errada (cartucho genérico), data.top_offcolor = se a de cima saiu com a
##            cor errada (muda a textura), data.worth = quanto o monte
##            vale em notas perfeitas (sem a chave: count), data.top_cut = o pedaço da folha que
##            virou a nota de cima, se ela saiu torta (Rect2 na textura da folha; vazio = reta),
##            data.worn = quantas já passaram na máquina de lavar (parecem usadas),
##            data.top_worn = se a de cima passou (muda a textura); ver value()
##   "bundle" maço cintado que sai da contadora (scripts/machines/cash_counter.gd): as mesmas
##            chaves do montinho (count, worth, crooked, offcolor, worn, top_offcolor, top_worn),
##            sem notas borradas (a contadora separa); grade() dá a nota de qualidade
##   "pan"    frigideira de ferro da cozinha: arma de pastelão (clique para bater; player.gd)
##   "finger" um dedo que a guilhotina levou (a peça da luva do hands.glb); data.owner = de quem,
##            data.side = 0 direita / 1 esquerda, data.digit = qual (player.DIGITS)
##   "hand"   a mão inteira que a guilhotina levou: a luva com os dedos que ainda tinha;
##            data.owner, data.side e data.lost = os dedos que já tinham ido antes (bits)
##   "cartridge" cartucho de tinta da impressora; data.ink = quanto ainda tem (0 a 1),
##            data.brand = "original" ou "generic" (compatível: imprime com a cor errada)
##   "parcel" caixa de papelão da entrega (scripts/shop/deliveries.gd); não dá para carregar,
##            [E] abre ali mesmo; data.from = a loja, data.order = o número do pedido,
##            data.contents = [[kind, data], ...] o que vem dentro
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
## As mesmas com a cor errada do cartucho genérico (art_source/paper_textures.py, offcolor).
const BILL_FRONT_OFFCOLOR := preload("res://assets/textures/bill_front_offcolor.png")
const BILL_BACK_OFFCOLOR := preload("res://assets/textures/bill_back_offcolor.png")
const SHEET_FRONT_OFFCOLOR := preload("res://assets/textures/sheet_front_offcolor.png")
## As notas depois da máquina de lavar: desbotadas e vincadas (art_source/paper_textures.py, worn).
const BILL_FRONT_WORN := preload("res://assets/textures/bill_front_worn.png")
const BILL_BACK_WORN := preload("res://assets/textures/bill_back_worn.png")
const BILL_FRONT_SMUDGED_WORN := preload("res://assets/textures/bill_front_smudged_worn.png")
const BILL_FRONT_OFFCOLOR_WORN := preload("res://assets/textures/bill_front_offcolor_worn.png")
const BILL_BACK_OFFCOLOR_WORN := preload("res://assets/textures/bill_back_offcolor_worn.png")
## A nota de cima torta mostra um pedaço da folha: lavada, ela só fica com este tom.
const WORN_TINT := Color(0.86, 0.84, 0.72)
const HANDS_MODEL := preload("res://assets/models/hands.glb")
const DIGITS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
## Pedaços de luva: o tamanho sai da malha.
const GLOVE_PIECES := ["finger", "hand"]
## Dá para bater com eles (clique esquerdo na mão).
const WEAPONS := ["pan"]
## Frigideira: o centro do fundo dela e o comprimento do cabo, no referencial do item (o cabo
## vai para +Z, e o meio da caixa de colisão fica entre os dois).
const PAN_CENTER := Vector3(0.0, 0.0, -0.1)
const PAN_RADIUS := 0.135
## Pilhas de notas (o montinho e o maço): a mesma malha, esticada até a altura delas.
const STACKS := ["bills", "bundle"]
## Só dá para carregar com as duas mãos.
const TWO_HANDED := ["ream"]
## Não dá para pegar: [E] usa (a caixa da entrega abre).
const NOT_CARRIED := ["parcel"]
## Quanto vale uma nota com a cor errada (cartucho genérico), perto de uma certa.
const OFFCOLOR_WORTH := 0.6
## Nota que nunca foi lavada é nova demais (lisinha, sem dobra): vale isso perto de uma usada.
const CRISP_WORTH := 0.7
## Cinta de papel do maço.
const BUNDLE_BAND := Color(0.9, 0.75, 0.2)
## Nota de qualidade do maço pelo quanto cada nota vale, em média (value / count): a partir de
## cada limite, a letra.
const GRADES := [[0.9, "A"], [0.75, "B"], [0.55, "C"], [0.0, "D"]]
## Faixa do rótulo do cartucho de cada marca.
const CARTRIDGE_COLORS := {"original": Color(0.15, 0.7, 0.3), "generic": Color(0.85, 0.25, 0.65)}

const SIZES := {
	"ream": Vector3(0.3, 0.052, 0.21),
	"sheet": Vector3(0.297, 0.003, 0.21),
	"bills": Vector3(0.139, 0.002, 0.063),
	"bundle": Vector3(0.139, 0.008, 0.063),
	"pan": Vector3(0.27, 0.05, 0.47),
	"cartridge": Vector3(0.11, 0.075, 0.05),
	"parcel": Vector3(0.44, 0.26, 0.34),
}
## Espessura de cada nota no montinho (bem mais que o papel de verdade, para o monte aparecer).
const BILL_THICKNESS := 0.0004
## Uma resma de 500 folhas pesa uns 2,5 kg; uma folha A4 de 75 g/m², 5 g.
const MASS := {"ream": 2.5, "sheet": 0.005, "bills": 0.001, "bundle": 0.001, "pan": 1.2, "finger": 0.02, "hand": 0.35, "cartridge": 0.08,
		"parcel": 3.0}
## Atrito, quique e amortecimento do giro de cada tipo.
const PHYSICS := {
	"ream": {"friction": 0.8, "bounce": 0.12, "angular_damp": 0.6},
	"sheet": {"friction": 0.9, "bounce": 0.0, "angular_damp": 1.0},
	"bills": {"friction": 0.85, "bounce": 0.02, "angular_damp": 0.8},
	"bundle": {"friction": 0.85, "bounce": 0.05, "angular_damp": 0.8},
	"pan": {"friction": 0.6, "bounce": 0.3, "angular_damp": 0.4},
	"finger": {"friction": 0.7, "bounce": 0.3, "angular_damp": 0.3},
	"hand": {"friction": 0.75, "bounce": 0.25, "angular_damp": 0.4},
	"cartridge": {"friction": 0.6, "bounce": 0.2, "angular_damp": 0.4},
	"parcel": {"friction": 0.9, "bounce": 0.05, "angular_damp": 0.8},
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
	return label_of(item.kind, item.data)


## O nome de um item que não está no mundo (o montinho dentro da máquina de lavar).
static func label_of(kind: String, data: Dictionary) -> String:
	match kind:
		"ream":
			return "paper ream"
		"sheet":
			var sheet := "printed sheet"
			if data.get("wet", false):
				var wetness: float = data.get("wetness", 1.0)
				sheet = "wet sheet" if wetness >= 0.99 else "damp sheet (%d%% dry)" % roundi((1.0 - wetness) * 100.0)
			return sheet + (" (off-color)" if data.get("offcolor", false) else "")
		"bills":
			var count: int = data.get("count", 0)
			var smudged: int = data.get("smudged", 0)
			var crooked: int = data.get("crooked", 0)
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
			var offcolor: int = data.get("offcolor", 0)
			if offcolor >= count and count > 0:
				notes.append("off-color")
			elif offcolor > 0:
				notes.append("%d off-color" % offcolor)
			var worn: int = data.get("worn", 0)
			if worn >= count and count > 0:
				notes.append("worn")
			elif worn > 0:
				notes.append("%d worn" % worn)
			return text + (" (%s)" % ", ".join(notes) if not notes.is_empty() else "")
		"bundle":
			return "bundle of %d bills (grade %s)" % [data.get("count", 0), grade(data)]
		"pan":
			return "frying pan"
		"finger":
			return "%s's %s" % [data.get("owner", "Someone"), String(data.get("digit", "finger")).to_lower()]
		"hand":
			return "%s's %s hand" % [data.get("owner", "Someone"), "right" if data.get("side", 0) == 0 else "left"]
		"cartridge":
			return "%s (%s)" % [cartridge_name(data.get("brand", "generic")), ink_text(data.get("ink", 0.0))]
		"parcel":
			return "parcel from %s" % data.get("from", "somewhere")
	return kind


## Quanto um montinho de notas vale de verdade, em notas perfeitas: o `worth` da guilhotina (já
## com as tortas e as de cor errada), com as que nunca foram lavadas valendo CRISP_WORTH.
static func value(data: Dictionary) -> float:
	var count: int = data.get("count", 0)
	if count <= 0:
		return 0.0
	var worth: float = data.get("worth", float(count))
	var worn := clampi(data.get("worn", 0), 0, count)
	return worth * (worn + (count - worn) * CRISP_WORTH) / count


## A nota de qualidade (A a D) de um monte ou maço: quanto cada nota vale em média (value).
static func grade(data: Dictionary) -> String:
	var count: int = data.get("count", 0)
	var each := value(data) / count if count > 0 else 0.0
	for g in GRADES:
		if each >= g[0] - 0.0001:
			return g[1]
	return "D"


## Quanto a tinta da folha ainda está molhada, de 0 a 1 (o brilho do shader).
static func wet_amount(data: Dictionary) -> float:
	if not data.get("wet", false):
		return 0.0
	return clampf(data.get("wetness", 1.0), 0.0, 1.0)


static func cartridge_name(brand: String) -> String:
	return "original ink cartridge" if brand == "original" else "compatible ink cartridge"


static func ink_text(ink: float) -> String:
	return "empty" if ink < 0.01 else "%d%% ink" % roundi(ink * 100.0)


## Como o item fica na mão, em relação ao ponto Hold: a folha inclinada para quem segura ver as
## notas (a borda de perto embaixo, nas mãos), a resma um pouco virada para mostrar a tampa.
static func hold_offset(kind: String) -> Transform3D:
	match kind:
		"sheet":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.06, 0.0))
		"ream":
			return Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, -0.05, -0.06))
		"bills", "bundle":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.05, 0.0))
		"cartridge":
			return Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.0, 0.1, -0.06))
		"pan":
			# Em pé do lado direito, de perfil como uma raquete (a face virada para a esquerda, para
			# o golpe de lado acertar com ela), e o cabo nas mãos.
			return Transform3D(Basis(Vector3.RIGHT, 1.15) * Basis(Vector3.BACK, 1.2), Vector3(0.27, -0.04, 0.02))
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
		"bills", "bundle":
			return Transform3D(basis, Vector3(side * 0.112, -0.025, 0.075))
		"cartridge":
			return Transform3D(basis, Vector3(side * 0.07, -0.01, 0.03))
		"pan":
			# As duas no cabo, uma atrás da outra, como num taco.
			return Transform3D(basis, Vector3(side * 0.022, 0.0, 0.2 if side == 1 else 0.12))
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
		mesh = sheet_mesh_instance(item.data.get("wet", false), item.data.get("offcolor", false))
		mesh.set_instance_shader_parameter("wet", wet_amount(item.data))
	elif item.kind in STACKS:
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
		if item.kind == "bundle":
			# A cinta de papel em volta do meio (filha da malha: estica junto com o maço).
			var band := MeshInstance3D.new()
			band.name = "Band"
			var band_box := BoxMesh.new()
			band_box.size = Vector3(0.03, 1.12, SIZES["bundle"].z + 0.002)
			band_box.material = _flat_material(BUNDLE_BAND, 0.6)
			band.mesh = band_box
			mesh.add_child(band)
	else:
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
		if item.kind == "ream":
			mesh.mesh = _ream_mesh()
		elif item.kind == "cartridge":
			# Pequeno e rápido: sem isso ele atravessava o chão.
			item.continuous_cd = true
			_cartridge(mesh, item.data.get("brand", "generic"))
		elif item.kind == "parcel":
			_parcel(mesh, item.data.get("from", ""))
		elif item.kind == "pan":
			# Pesada e rápida no arremesso: sem isso atravessava a parede.
			item.continuous_cd = true
			_pan(mesh)
		else:
			var box := BoxMesh.new()
			box.size = size
			mesh.mesh = box
	item.add_child(mesh)
	if item.kind in STACKS:
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
		mesh.set_instance_shader_parameter("wet", wet_amount(item.data))
		mesh.set_instance_shader_parameter("offcolor", 1.0 if item.data.get("offcolor", false) else 0.0)
	elif item.kind in STACKS and mesh:
		# Uma malha de 1 de altura, esticada até a altura do monte; a colisão acompanha.
		var count: int = maxi(item.data.get("count", 1), 1)
		var height := maxf(count * BILL_THICKNESS, 0.0015)
		mesh.mesh = _bills_mesh(item.data.get("top_smudged", false), item.data.get("top_cut", Rect2()),
				item.data.get("top_offcolor", false), item.data.get("top_worn", false))
		Toon.apply_one(mesh)
		mesh.scale = Vector3(1.0, height, 1.0)
		var col: CollisionShape3D = item.get_child(0)
		(col.shape as BoxShape3D).size = Vector3(SIZES["bills"].x, height, SIZES["bills"].z)
		item.mass = MASS[item.kind] * count


## Uma folha (a do item e a que a impressora mostra saindo pela fenda).
static func sheet_mesh_instance(wet: bool, offcolor := false) -> MeshInstance3D:
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
	mesh.set_instance_shader_parameter("offcolor", 1.0 if offcolor else 0.0)
	return mesh


## Cartucho de tinta: plástico preto com a faixa do rótulo na cor da marca e o bico embaixo.
static func _cartridge(mesh: MeshInstance3D, brand: String) -> void:
	var size: Vector3 = SIZES["cartridge"]
	var body := BoxMesh.new()
	body.size = size
	body.material = _flat_material(Color(0.07, 0.07, 0.08), 0.35)
	mesh.mesh = body
	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(size.x + 0.002, size.y * 0.4, size.z + 0.002)
	band_box.material = _flat_material(CARTRIDGE_COLORS.get(brand, CARTRIDGE_COLORS["generic"]), 0.5)
	band.mesh = band_box
	band.position.y = size.y * 0.08
	mesh.add_child(band)
	var nozzle := MeshInstance3D.new()
	var nozzle_box := BoxMesh.new()
	nozzle_box.size = Vector3(size.x * 0.4, 0.008, size.z * 0.5)
	nozzle_box.material = _flat_material(Color(0.6, 0.55, 0.3), 0.3)
	nozzle.mesh = nozzle_box
	nozzle.position.y = -size.y / 2.0 - 0.004
	mesh.add_child(nozzle)


## Frigideira de ferro: o fundo (mais largo em cima), a face de dentro um pouco mais clara e o
## cabo com a ponta de madeira.
static func _pan(mesh: MeshInstance3D) -> void:
	var iron := _flat_material(Color(0.12, 0.12, 0.13), 0.45)
	var body := CylinderMesh.new()
	body.top_radius = PAN_RADIUS
	body.bottom_radius = PAN_RADIUS - 0.025
	body.height = 0.045
	body.radial_segments = 28
	body.material = iron
	mesh.mesh = body
	mesh.position = PAN_CENTER
	var face := MeshInstance3D.new()
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = PAN_RADIUS - 0.012
	face_mesh.bottom_radius = PAN_RADIUS - 0.012
	face_mesh.height = 0.002
	face_mesh.radial_segments = 28
	face_mesh.material = _flat_material(Color(0.22, 0.22, 0.24), 0.3)
	face.mesh = face_mesh
	face.position.y = 0.0235
	mesh.add_child(face)
	var handle := MeshInstance3D.new()
	var handle_box := BoxMesh.new()
	handle_box.size = Vector3(0.028, 0.02, 0.13)
	handle_box.material = iron
	handle.mesh = handle_box
	handle.position = Vector3(0.0, 0.012, PAN_RADIUS + 0.06)
	handle.rotation.x = -0.12
	mesh.add_child(handle)
	var grip := MeshInstance3D.new()
	var grip_box := BoxMesh.new()
	grip_box.size = Vector3(0.034, 0.026, 0.1)
	grip_box.material = _flat_material(Color(0.42, 0.25, 0.12), 0.8)
	grip.mesh = grip_box
	grip.position = Vector3(0.0, 0.025, PAN_RADIUS + 0.17)
	grip.rotation.x = -0.12
	mesh.add_child(grip)


## Caixa de papelão da entrega: a fita em cima e o nome da loja escrito dos dois lados.
static func _parcel(mesh: MeshInstance3D, store: String) -> void:
	var size: Vector3 = SIZES["parcel"]
	var box := BoxMesh.new()
	box.size = size
	box.material = _flat_material(Color(0.72, 0.52, 0.3), 0.9)
	mesh.mesh = box
	var tape := MeshInstance3D.new()
	var tape_box := BoxMesh.new()
	tape_box.size = Vector3(size.x + 0.004, size.y + 0.004, 0.06)
	tape_box.material = _flat_material(Color(0.82, 0.72, 0.5), 0.4)
	tape.mesh = tape_box
	mesh.add_child(tape)
	for side in [-1.0, 1.0]:
		var label := Label3D.new()
		label.text = store
		label.font_size = 64
		label.pixel_size = 0.0012
		label.outline_size = 0
		label.modulate = Color(0.15, 0.1, 0.08)
		label.position = Vector3(0.0, 0.03, side * (size.z / 2.0 + 0.002))
		label.rotation.y = 0.0 if side > 0 else PI
		mesh.add_child(label)


static func _flat_material(color: Color, roughness: float) -> StandardMaterial3D:
	var key := "flat_%s_%s" % [color, roughness]
	if not _cache.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		_cache[key] = mat
	return _cache[key]


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
## que ela é de verdade: sobra de margem ou da nota vizinha, ou a nota comida pelo corte. Lavado
## (`worn`), o monte usa as texturas desbotadas e vincadas.
static func _bills_mesh(top_smudged: bool, top_cut := Rect2(), offcolor := false, worn := false) -> Mesh:
	var cut := top_cut.has_area()
	var key := "bills_mesh_cut_%s" % top_cut if cut else ("bills_mesh_smudged" if top_smudged else "bills_mesh")
	if offcolor:
		key += "_offcolor"
	if worn:
		key += "_worn"
	if _cache.has(key):
		return _cache[key]
	var h: Vector3 = Vector3(SIZES["bills"].x, 1.0, SIZES["bills"].z) / 2.0
	var full := Rect2(0, 0, 1, 1)
	var mesh := ArrayMesh.new()
	var top_tex: Texture2D = SHEET_FRONT if cut else (BILL_FRONT_SMUDGED if top_smudged else BILL_FRONT)
	if offcolor:
		top_tex = SHEET_FRONT_OFFCOLOR if cut else (BILL_FRONT_SMUDGED if top_smudged else BILL_FRONT_OFFCOLOR)
	var back_tex: Texture2D = BILL_BACK_OFFCOLOR if offcolor else BILL_BACK
	if worn:
		back_tex = BILL_BACK_OFFCOLOR_WORN if offcolor else BILL_BACK_WORN
		if not cut:
			top_tex = BILL_FRONT_SMUDGED_WORN if top_smudged else (BILL_FRONT_OFFCOLOR_WORN if offcolor else BILL_FRONT_WORN)
	var faces := [
		[top_tex, [[Vector3.UP, [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]]]],
		[back_tex, [[Vector3.DOWN, [Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z)]]]],
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
			if worn and cut and surface == faces[0]:
				mat.albedo_color = WORN_TINT
		else:
			# Bordas: papel claro com um tom de verde das notas empilhadas (lavadas, mais apagado).
			mat.albedo_color = Color(0.76, 0.78, 0.68) if worn else Color(0.8, 0.86, 0.76)
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
