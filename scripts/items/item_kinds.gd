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
##   "trashbag" saco de lixo preto do rolo da cozinha (scripts/machines/bag_roll.gd): leva vários
##            maços (e montinhos) de uma vez; data.contents = [[kind, data], ...] o que está dentro,
##            na ordem em que entrou. Estufa conforme enche (bag_size). data.open = aberto (o
##            clique de quem segura abre e dá o nó): maço ou montinho que cai na boca entra sozinho
##            (item.gd, _catch). Fechado parece lixo: o vizinho não vê o dinheiro dentro; aberto e
##            com dinheiro, vê
##   "parcel" caixa de papelão da entrega (scripts/shop/deliveries.gd); não dá para carregar,
##            [E] abre ali mesmo; data.from = a loja, data.order = o número do pedido,
##            data.contents = [[kind, data], ...] o que vem dentro
##   "phone"  o telefone sem fio do vizinho, que voa da mão dele na trombada (scripts/neighbor.gd);
##            data.calling = ainda chamando a polícia (pegar desliga)
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
## Saco de lixo: o que entra nele e quantos cabem (cada maço ou montinho conta um).
const BAG_KINDS := ["bundle", "bills"]
const BAG_CAPACITY := 10
## Plástico preto brilhante do saco (cinza-carvão: preto puro vira uma mancha sem volume no toon)
## e a lisura dele (abaixo de 0,5 o toon desenha o brilho duro).
const BAG_COLOR := Color(0.14, 0.14, 0.16)
const BAG_ROUGHNESS := 0.18
## Saco aberto: o menor enchimento da forma (vazio, ele fica de boca aberta como se tivesse ar) e
## a folga em volta da boca para pegar o que cai (m; a boca em si é bag_mouth_radius).
const BAG_OPEN_MIN_FILL := 0.45
const BAG_CATCH_MARGIN := 0.08
## Largura da boca aberta perto da barriga (a borda dobra um pouco para fora).
const BAG_RIM := 0.78
## Balanço na mão (item.gd, _bag_swing): o saco é um pêndulo preso nas mãos. Mola, amortecimento,
## quanto cada m/s que as mãos mudam de velocidade empurra (rad/s), a maior velocidade das mãos
## que conta (m/s), o maior ângulo, e quanto vale fechado (abraçado, balança menos; aberto, 1).
const BAG_SWING_SPRING := 55.0
const BAG_SWING_DAMP := 4.5
const BAG_SWING_PUSH := 0.9
const BAG_SWING_MAX_SPEED := 8.0
const BAG_SWING_MAX := 0.6
const BAG_SWING_CLOSED := 0.35
## Amassado (item.gd, _bag_squash): quanto achata no tranco mais forte, a frequência do
## chacoalhar (rad/s) e o quanto ele morre por segundo; a queda a partir de que velocidade conta.
const BAG_SQUASH := 0.22
const BAG_SQUASH_FREQ := 24.0
const BAG_SQUASH_DECAY := 6.0
const BAG_LAND_SPEED := 1.0
## Derramar: aberto e tombado (a boca abaixo disso, no cosseno com o "para cima"), o que tem
## dentro sai pela boca, um de cada vez (s), com este empurrão (m/s).
const BAG_SPILL_TILT := 0.25
const BAG_SPILL_EVERY := 0.12
const BAG_SPILL_PUSH := 1.1
## Quanto vale uma nota com a cor errada (cartucho genérico), perto de uma certa.
const OFFCOLOR_WORTH := 0.6
## Nota que nunca foi lavada é nova demais (lisinha, sem dobra): vale isso perto de uma usada.
const CRISP_WORTH := 0.7
## Cinta de papel do maço, na cor da nota de qualidade: dá para ver de longe se o maço é bom
## (dourada A, verde B, azul C, vermelha D).
const BAND_COLORS := {"A": Color(0.92, 0.74, 0.18), "B": Color(0.3, 0.66, 0.32), "C": Color(0.28, 0.48, 0.82),
		"D": Color(0.8, 0.24, 0.2)}
## Forma do maço (_bundle_mesh): a altura nas pontas (estufadas), quanto a cinta aperta o meio
## (fração da altura), a largura da cinta e quanto as pontas abrem para os lados.
const BUNDLE_HEIGHT := 0.016
const BUNDLE_PINCH := 0.38
const BUNDLE_BAND_WIDTH := 0.03
const BUNDLE_FLARE := 0.0025
## Nota de qualidade do maço pelo quanto cada nota vale, em média (value / count): a partir de
## cada limite, a letra.
const GRADES := [[0.9, "A"], [0.75, "B"], [0.55, "C"], [0.0, "D"]]
## Faixa do rótulo do cartucho de cada marca.
const CARTRIDGE_COLORS := {"original": Color(0.15, 0.7, 0.3), "generic": Color(0.85, 0.25, 0.65)}

const SIZES := {
	"ream": Vector3(0.3, 0.052, 0.21),
	"sheet": Vector3(0.297, 0.003, 0.21),
	"bills": Vector3(0.139, 0.002, 0.063),
	"bundle": Vector3(0.139, 0.016, 0.063),
	"pan": Vector3(0.27, 0.05, 0.47),
	"cartridge": Vector3(0.11, 0.075, 0.05),
	"parcel": Vector3(0.44, 0.26, 0.34),
	"trashbag": Vector3(0.2, 0.014, 0.28),
	"phone": Vector3(0.055, 0.03, 0.17),
}
## Espessura de cada nota no montinho (bem mais que o papel de verdade, para o monte aparecer).
const BILL_THICKNESS := 0.0004
## Uma resma de 500 folhas pesa uns 2,5 kg; uma folha A4 de 75 g/m², 5 g.
const MASS := {"ream": 2.5, "sheet": 0.005, "bills": 0.001, "bundle": 0.001, "pan": 1.2, "finger": 0.02, "hand": 0.35, "cartridge": 0.08,
		"parcel": 3.0, "trashbag": 0.05, "phone": 0.15}
## Quanto cada coisa dentro do saco pesa a mais (kg; um maço de verdade não pesa isso, mas o saco
## cheio tem que parecer pesado quando cai).
const BAG_ITEM_MASS := 0.25
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
	"trashbag": {"friction": 0.95, "bounce": 0.0, "angular_damp": 3.0},
	"phone": {"friction": 0.55, "bounce": 0.35, "angular_damp": 0.4},
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
		"phone":
			return "the neighbor's phone (CALLING THE POLICE!)" if data.get("calling", false) else "the neighbor's phone"
		"trashbag":
			var contents: Array = data.get("contents", [])
			var open := "open " if data.get("open", false) else ""
			if contents.is_empty():
				return "empty %strash bag" % open
			var bundles := 0
			var loose := 0
			for entry: Array in contents:
				if entry[0] == "bundle":
					bundles += 1
				else:
					loose += int(entry[1].get("count", 0))
			var parts: Array[String] = []
			if bundles > 0:
				parts.append("%d bundle%s" % [bundles, "" if bundles == 1 else "s"])
			if loose > 0:
				parts.append("%d loose bill%s" % [loose, "" if loose == 1 else "s"])
			return "%strash bag (%s)" % [open, ", ".join(parts)]
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
static func hold_offset(kind: String, data := {}) -> Transform3D:
	match kind:
		"trashbag":
			var size := bag_size(data)
			if data.get("open", false):
				# Aberto pela borda, na frente e embaixo, com a boca virada um pouco para quem segura
				# (dá para ver o que cai dentro).
				return Transform3D(Basis(Vector3.RIGHT, 0.55), Vector3(0.0, -0.08 - size.y * 0.3, -0.14))
			if data.get("contents", []).is_empty():
				return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.05, 0.0))
			# Abraçado na frente, um pouco abaixo (pelo nó, embaixo dos braços, ele sumia): cheio,
			# tampa um bom pedaço da vista, como um saco pesado de verdade.
			return Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.0, -0.1 - size.y * 0.15, -0.06))
		"sheet":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.06, 0.0))
		"ream":
			return Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3(0.0, -0.05, -0.06))
		"bills", "bundle":
			return Transform3D(Basis(Vector3.RIGHT, 0.95), Vector3(0.0, 0.05, 0.0))
		"cartridge":
			return Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0.0, 0.1, -0.06))
		"phone":
			# Em pé na mão, com o visor virado para quem segura.
			return Transform3D(Basis(Vector3.RIGHT, 1.1), Vector3(0.0, 0.08, -0.04))
		"pan":
			# Em pé do lado direito, de perfil como uma raquete (a face virada para a esquerda, para
			# o golpe de lado acertar com ela), e o cabo nas mãos.
			return Transform3D(Basis(Vector3.RIGHT, 1.15) * Basis(Vector3.BACK, 1.2), Vector3(0.27, -0.04, 0.02))
	return Transform3D.IDENTITY


## Onde fica o pulso de cada luva (side 1 = direita, -1 = esquerda), no referencial do item. A
## palma vira para o centro e o polegar para cima: a folha fica presa entre o polegar e o
## indicador nos cantos de perto; a resma, apertada pelos lados.
static func hand_offset(kind: String, side: int, data := {}) -> Transform3D:
	var basis := Basis(Vector3.BACK, -side * PI / 2)
	match kind:
		"trashbag":
			var size := bag_size(data)
			if data.get("open", false):
				# Uma de cada lado da boca, abrindo.
				return Transform3D(basis, Vector3(side * (bag_mouth_radius(data) + 0.01), size.y / 2.0 - 0.01, 0.0))
			if data.get("contents", []).is_empty():
				return Transform3D(basis, Vector3(side * 0.11, -0.02, 0.12))
			# Uma de cada lado, na barriga do saco (a parte mais larga), um pouco para o lado de quem
			# carrega.
			return Transform3D(basis, Vector3(side * (size.x / 2.0 - 0.01), -size.y / 2.0 + size.y * 0.3, 0.05))
		"sheet":
			return Transform3D(basis, Vector3(side * 0.135, -0.03, 0.17))
		"ream":
			return Transform3D(basis, Vector3(side * 0.176, -0.02, 0.11))
		"bills", "bundle":
			return Transform3D(basis, Vector3(side * 0.112, -0.025, 0.075))
		"cartridge":
			return Transform3D(basis, Vector3(side * 0.07, -0.01, 0.03))
		"phone":
			return Transform3D(basis, Vector3(side * 0.045, -0.005, 0.05))
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
	elif item.kind in STACKS or item.kind == "trashbag":
		mesh = MeshInstance3D.new()
		mesh.name = "Mesh"
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
		elif item.kind == "phone":
			# Pequeno e voando da mão do vizinho: sem isso atravessava o chão.
			item.continuous_cd = true
			_phone(mesh)
		else:
			var box := BoxMesh.new()
			box.size = size
			mesh.mesh = box
	item.add_child(mesh)
	if item.kind in STACKS or item.kind == "trashbag":
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
	elif item.kind == "trashbag" and mesh:
		# Estufa conforme enche: a malha e a colisão do tamanho de agora, e pesa o que tem dentro.
		var contents: Array = item.data.get("contents", [])
		mesh.mesh = _bag_mesh(contents.size(), item.data.get("open", false))
		Toon.apply_one(mesh)
		var col: CollisionShape3D = item.get_child(0)
		(col.shape as BoxShape3D).size = bag_size(item.data) * Vector3(0.9, 1.0, 0.9)
		item.mass = MASS["trashbag"] + BAG_ITEM_MASS * contents.size()
	elif item.kind == "bundle" and mesh:
		# Malha própria, do tamanho certo (o maço tem sempre as mesmas notas), com a cinta na cor
		# da nota de qualidade (na malha: o toon refaz os materiais a partir dela).
		mesh.mesh = _bundle_mesh(item.data.get("top_offcolor", false), item.data.get("top_worn", false),
				grade(item.data))
		mesh.scale = Vector3.ONE
		Toon.apply_one(mesh)
		var col: CollisionShape3D = item.get_child(0)
		(col.shape as BoxShape3D).size = SIZES["bundle"]
		item.mass = MASS["bundle"] * maxi(item.data.get("count", 1), 1)
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


## Telefone sem fio de casa, dos antigos: corpo bege, teclado cinza, o visorzinho verde aceso e a
## antena na ponta de cima (-Z).
static func _phone(mesh: MeshInstance3D) -> void:
	var size: Vector3 = SIZES["phone"]
	var body := BoxMesh.new()
	body.size = size
	body.material = _flat_material(Color(0.78, 0.74, 0.62), 0.5)
	mesh.mesh = body
	var keypad := MeshInstance3D.new()
	var keys := BoxMesh.new()
	keys.size = Vector3(size.x * 0.75, 0.004, size.z * 0.45)
	keys.material = _flat_material(Color(0.32, 0.32, 0.34), 0.6)
	keypad.mesh = keys
	keypad.position = Vector3(0.0, size.y / 2.0, size.z * 0.15)
	mesh.add_child(keypad)
	var screen := MeshInstance3D.new()
	var glass := BoxMesh.new()
	glass.size = Vector3(size.x * 0.7, 0.004, size.z * 0.2)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(0.45, 0.85, 0.45)
	lit.emission_enabled = true
	lit.emission = Color(0.35, 0.9, 0.4)
	lit.emission_energy_multiplier = 1.2
	glass.material = lit
	screen.mesh = glass
	screen.position = Vector3(0.0, size.y / 2.0, -size.z * 0.25)
	mesh.add_child(screen)
	var antenna := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.006
	rod.bottom_radius = 0.008
	rod.height = 0.06
	rod.radial_segments = 8
	rod.material = _flat_material(Color(0.12, 0.12, 0.13), 0.4)
	antenna.mesh = rod
	antenna.rotation.x = PI / 2.0
	antenna.position = Vector3(size.x * 0.3, 0.0, -size.z / 2.0 - 0.025)
	mesh.add_child(antenna)


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


## Maço cintado: as notas bem alinhadas, apertadas no meio pela cinta de papel e estufadas nas
## pontas (abrem um pouco para os lados), com a tampa levemente abaulada. A nota de cima na
## tampa, o verso embaixo, as bordas listradas (uma linha por nota) e a cinta na cor da nota de
## qualidade (`grade`). O meio do maço fica na origem, como a colisão.
static func _bundle_mesh(offcolor: bool, worn: bool, grade_letter: String) -> Mesh:
	var key := "bundle_mesh_%s_%s_%s" % [offcolor, worn, grade_letter]
	if _cache.has(key):
		return _cache[key]
	var top_tex: Texture2D = BILL_FRONT_OFFCOLOR if offcolor else BILL_FRONT
	var back_tex: Texture2D = BILL_BACK_OFFCOLOR if offcolor else BILL_BACK
	if worn:
		top_tex = BILL_FRONT_OFFCOLOR_WORN if offcolor else BILL_FRONT_WORN
		back_tex = BILL_BACK_OFFCOLOR_WORN if offcolor else BILL_BACK_WORN
	var length: float = SIZES["bundle"].x
	var band := BUNDLE_BAND_WIDTH / 2.0
	var lift := 0.0007
	# Meia altura e meia largura em cada x; `dome` baixa a tampa perto das bordas compridas.
	var half_h := func(x: float) -> float:
		return BUNDLE_HEIGHT / 2.0 * (1.0 - BUNDLE_PINCH * exp(-pow(x / 0.028, 2.0)))
	var half_w := func(x: float) -> float:
		return SIZES["bundle"].z / 2.0 + BUNDLE_FLARE * pow(absf(x) / (length / 2.0), 2.0)
	var dome := func(v: float) -> float:
		return 1.0 - 0.2 * pow(absf(2.0 * v - 1.0), 3.0)
	var at_x := func(u: float) -> float:
		return (u - 0.5) * length
	var mesh := ArrayMesh.new()

	# Tampa e fundo: u ao longo do comprimento, v da borda de trás para a da frente.
	var top := func(u: float, v: float, s: float, x0: float, x1: float, e: float) -> Vector3:
		var x: float = lerpf(x0, x1, u)
		return Vector3(x, s * (half_h.call(x) * dome.call(v) + e), (v - 0.5) * 2.0 * (half_w.call(x) + e))
	var st := _surface()
	_grid(st, 24, 6, func(u, v): return top.call(u, v, 1.0, -length / 2.0, length / 2.0, 0.0),
			func(u, v): return Vector2(u, v), Vector3.UP)
	_commit(st, mesh, _textured(top_tex, 0.75))
	st = _surface()
	_grid(st, 24, 6, func(u, v): return top.call(u, v, -1.0, -length / 2.0, length / 2.0, 0.0),
			func(u, v): return Vector2(1.0 - u, v), Vector3.DOWN)
	_commit(st, mesh, _textured(back_tex, 0.75))

	# Bordas: os dois lados compridos e as duas pontas, de cima para baixo (v), com uma listra
	# por nota.
	st = _surface()
	for side: float in [-1.0, 1.0]:
		var edge_v: float = 0.5 + side * 0.5
		var long_side := func(u: float, v: float) -> Vector3:
			var x: float = at_x.call(u)
			var y: float = lerpf(1.0, -1.0, v) * half_h.call(x) * dome.call(edge_v)
			return Vector3(x, y, side * half_w.call(x))
		_grid(st, 24, 2, long_side, func(u, v): return Vector2(u * 3.0, v), Vector3(0, 0, side))
		var x_end: float = side * length / 2.0
		var tip := func(u: float, v: float) -> Vector3:
			var y: float = lerpf(1.0, -1.0, v) * half_h.call(x_end) * dome.call(u)
			return Vector3(x_end, y, (u - 0.5) * 2.0 * half_w.call(x_end))
		_grid(st, 6, 2, tip, func(u, v): return Vector2(u, v), Vector3(side, 0, 0))
	var edge_mat := _textured(_bundle_edge_texture(), 0.9)
	if worn:
		edge_mat.albedo_color = Color(0.92, 0.9, 0.8)
	_commit(st, mesh, edge_mat)

	# A cinta: em volta do meio apertado, um pouco por fora das notas.
	st = _surface()
	_grid(st, 4, 6, func(u, v): return top.call(u, v, 1.0, -band, band, lift),
			func(u, v): return Vector2(u, v * 0.5), Vector3.UP)
	_grid(st, 4, 6, func(u, v): return top.call(u, v, -1.0, -band, band, lift),
			func(u, v): return Vector2(u, 0.5 + v * 0.5), Vector3.DOWN)
	for side: float in [-1.0, 1.0]:
		var edge_v: float = 0.5 + side * 0.5
		var band_side := func(u: float, v: float) -> Vector3:
			var x: float = lerpf(-band, band, u)
			var y: float = lerpf(1.0, -1.0, v) * (half_h.call(x) * dome.call(edge_v) + lift)
			return Vector3(x, y, side * (half_w.call(x) + lift))
		_grid(st, 4, 2, band_side, func(u, v): return Vector2(u, 0.0), Vector3(0, 0, side))
	_commit(st, mesh, _band_material(BAND_COLORS.get(grade_letter, BAND_COLORS["D"])))
	_cache[key] = mesh
	return mesh


## Tamanho do saco de lixo agora (largura, altura com o nó, fundo): vazio, dobrado e chato; com
## coisa dentro, cada vez mais gordo e alto.
static func bag_size(data: Dictionary) -> Vector3:
	var count: int = data.get("contents", []).size()
	var open: bool = data.get("open", false)
	if count == 0 and not open:
		return SIZES["trashbag"]
	var fill := _bag_fill(count, open)
	var half := _bag_half_width(fill)
	return Vector3(half.x * 2.0, _bag_body_height(fill) + (0.02 if open else 0.07), half.y * 2.0)


## Raio da boca do saco aberto (na largura; no fundo é um pouco menos).
static func bag_mouth_radius(data: Dictionary) -> float:
	return _bag_half_width(_bag_fill(data.get("contents", []).size(), true)).x * BAG_RIM


## A boca do saco aberto no mundo (o meio da borda).
static func bag_mouth(item: Node3D) -> Vector3:
	return item.global_transform * Vector3(0.0, bag_size(item.data).y / 2.0, 0.0)


static func _bag_fill(count: int, open: bool) -> float:
	var fill := float(count) / BAG_CAPACITY
	return maxf(fill, BAG_OPEN_MIN_FILL) if open else fill


static func _bag_half_width(fill: float) -> Vector2:
	var w := 0.1 + 0.09 * sqrt(fill)
	return Vector2(w, w * 0.85)


static func _bag_body_height(fill: float) -> float:
	return 0.13 + 0.25 * fill


## Saco de lixo com `count` coisas dentro (de 0 a BAG_CAPACITY). Vazio: o saco dobrado, um
## travesseirinho chato. Com coisa dentro: o corpo em pera (fundo chato e largo, estreitando até
## o gargalo), com calombos dos maços e as pregas do plástico juntando no gargalo, e o nó em cima
## (o gargalo torcido, a bolinha e as duas orelhas). O meio fica na origem, como a colisão.
static func _bag_mesh(count: int, open := false) -> Mesh:
	var key := "bag_mesh_%d_%s" % [count, open]
	if _cache.has(key):
		return _cache[key]
	var st := _surface()
	if open:
		_open_bag(st, count)
		var open_mesh := ArrayMesh.new()
		_commit(st, open_mesh, _bag_open_material())
		_cache[key] = open_mesh
		return open_mesh
	if count == 0:
		var h: Vector3 = SIZES["trashbag"] / 2.0
		var pillow := func(u: float, v: float, s: float) -> Vector3:
			var x := (u - 0.5) * 2.0
			var z := (v - 0.5) * 2.0
			var puff := (1.0 - x * x) * (1.0 - z * z)
			var crease := 0.25 * sin(u * 23.0 + v * 7.0) * sin(v * 17.0)
			return Vector3(x * h.x, s * h.y * clampf(puff + crease * puff, 0.05, 1.2), z * h.z)
		_grid(st, 10, 12, func(u, v): return pillow.call(u, v, 1.0), func(u, v): return Vector2(u, v), Vector3.UP)
		_grid(st, 10, 12, func(u, v): return pillow.call(u, v, -1.0), func(u, v): return Vector2(u, v), Vector3.DOWN)
	else:
		var fill := float(count) / BAG_CAPACITY
		var half := _bag_half_width(fill)
		var body := _bag_body_height(fill)
		var total := body + 0.07
		var bottom := -total / 2.0
		var neck := 0.016
		var seed := float(count) * 1.7
		# Corpo: u dá a volta (ângulo), v sobe do meio do fundo até o gargalo.
		var sack := func(u: float, v: float) -> Vector3:
			var ang := u * TAU
			var y: float
			var r: float
			if v < 0.15:
				y = bottom
				r = v / 0.15 * 0.93
			else:
				var s := (v - 0.15) / 0.85
				y = bottom + s * body
				r = maxf(pow(sin(PI * (0.35 + 0.65 * s)), 0.8), 0.0)
				# Calombos dos maços e pregas que juntam no gargalo.
				r *= 1.0 + 0.07 * sin(3.0 * ang + seed + 5.0 * s) * sin(2.0 * ang + 1.3 * seed)
				r *= 1.0 + 0.1 * pow(s, 3.0) * sin(9.0 * ang + seed)
			if v >= 0.999:
				r = 0.0
			var rx: float = maxf(r * half.x, neck if v >= 0.15 and v < 0.999 else 0.0)
			var rz: float = maxf(r * half.y, neck if v >= 0.15 and v < 0.999 else 0.0)
			return Vector3(cos(ang) * rx, y, sin(ang) * rz)
		_grid(st, 24, 16, sack, func(u, v): return Vector2(u, v), Vector3.ZERO, Vector3(0, bottom + body * 0.35, 0))
		# Gargalo torcido até o nó.
		var neck_base := bottom + body - 0.01
		var twist := func(u: float, v: float) -> Vector3:
			var ang := u * TAU + v * 2.5
			var r := neck * (1.0 + 0.25 * sin(5.0 * ang))
			return Vector3(cos(ang) * r, neck_base + v * 0.045, sin(ang) * r)
		_grid(st, 10, 3, twist, func(u, v): return Vector2(u, v), Vector3.ZERO, Vector3(0, neck_base + 0.02, 0))
		# A bolinha do nó e as duas orelhas do plástico.
		var top := neck_base + 0.045
		var knot := func(u: float, v: float) -> Vector3:
			var ang := u * TAU
			var phi := v * PI
			var r := 0.022 * (1.0 + 0.15 * sin(4.0 * ang))
			return Vector3(cos(ang) * sin(phi) * r, top - cos(phi) * r * 0.8, sin(ang) * sin(phi) * r)
		_grid(st, 10, 6, knot, func(u, v): return Vector2(u, v), Vector3.ZERO, Vector3(0, top, 0))
		for side: float in [-1.0, 1.0]:
			var ear := func(u: float, v: float) -> Vector3:
				var along := v * 0.05
				var width := 0.018 * sin(v * PI * 0.9 + 0.1) * (u - 0.5) * 2.0
				return Vector3(side * (0.012 + along * 0.8), top + 0.008 + along * 0.6 + width * 0.3, width)
			_grid(st, 2, 4, ear, func(u, v): return Vector2(u, v), Vector3.UP)
	var mat := _flat_material(BAG_COLOR, BAG_ROUGHNESS)
	var mesh := ArrayMesh.new()
	_commit(st, mesh, mat)
	_cache[key] = mesh
	return mesh


## Saco aberto: o mesmo corpo em pera, mas sem gargalo: sobe largo até a boca, que dobra um
## pouco para fora numa borda enrolada. Visto de dentro (o material não esconde as costas).
static func _open_bag(st: SurfaceTool, count: int) -> void:
	var fill := _bag_fill(count, true)
	var half := _bag_half_width(fill)
	var body := _bag_body_height(fill)
	var total := body + 0.02
	var bottom := -total / 2.0
	var seed := float(count) * 1.3 + 0.5
	var shape := func(s: float) -> float:
		var r := pow(sin(PI * (0.35 + 0.55 * s)), 0.8)
		return r * (1.0 + 0.45 * smoothstep(0.75, 1.0, s))
	var sack := func(u: float, v: float) -> Vector3:
		var ang := u * TAU
		var y: float
		var r: float
		if v < 0.15:
			y = bottom
			r = v / 0.15 * 0.93
		else:
			var s := (v - 0.15) / 0.85
			y = bottom + s * total
			r = shape.call(s)
			r *= 1.0 + 0.06 * sin(3.0 * ang + seed + 4.0 * s) * sin(2.0 * ang + 1.3 * seed)
			# A borda mole: ondula um pouco.
			r *= 1.0 + 0.05 * smoothstep(0.7, 1.0, s) * sin(7.0 * ang + seed)
		return Vector3(cos(ang) * r * half.x, y, sin(ang) * r * half.y)
	_grid(st, 28, 14, sack, func(u, v): return Vector2(u, v), Vector3.ZERO, Vector3(0, bottom + body * 0.35, 0))
	# A borda enrolada: um tubo fininho em volta da boca.
	var rim_r: float = shape.call(1.0)
	var rim := func(u: float, v: float) -> Vector3:
		var ang := u * TAU
		var tube := v * TAU
		var wobble := 1.0 + 0.05 * sin(7.0 * ang + seed)
		var ring := Vector2(cos(ang) * rim_r * half.x * wobble, sin(ang) * rim_r * half.y * wobble)
		var out := ring.normalized() * 0.007 * cos(tube)
		return Vector3(ring.x + out.x, -bottom + 0.007 * sin(tube), ring.y + out.y)
	_grid(st, 28, 4, rim, func(u, v): return Vector2(u, v), Vector3.ZERO, Vector3(0, -bottom, 0))


## A casca do saco aberto para a física do que está dentro (bag_contents.gd): a própria malha,
## batendo dos dois lados.
static func bag_shell_shape(count: int) -> ConcavePolygonShape3D:
	var key := "bag_shell_%d" % count
	if not _cache.has(key):
		var shape: ConcavePolygonShape3D = _bag_mesh(count, true).create_trimesh_shape()
		shape.backface_collision = true
		_cache[key] = shape
	return _cache[key]


## O plástico do saco aberto: o mesmo preto, mas sem esconder as costas (o lado de dentro).
static func _bag_open_material() -> StandardMaterial3D:
	if not _cache.has("bag_open_mat"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BAG_COLOR
		mat.roughness = BAG_ROUGHNESS
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache["bag_open_mat"] = mat
	return _cache["bag_open_mat"]


## A cinta de papel na cor da nota de qualidade: a textura (cinza) tem os filetes das bordas e a
## "letrinha" impressa no meio, e a cor multiplica.
static func _band_material(color: Color) -> StandardMaterial3D:
	var key := "band_%s" % color
	if not _cache.has(key):
		var mat := _textured(_bundle_band_texture(), 0.6)
		mat.albedo_color = color
		_cache[key] = mat
	return _cache[key]


static func _textured(texture: Texture2D, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## Bordas das notas empilhadas: listras de papel claro e esverdeado, uma por nota (v de cima
## para baixo), de grossura um pouco diferente cada uma.
static func _bundle_edge_texture() -> Texture2D:
	if _cache.has("bundle_edge_tex"):
		return _cache["bundle_edge_tex"]
	var rows := 80
	var img := Image.create(4, rows, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for y in rows:
		var shade := rng.randf_range(-0.03, 0.03)
		var light := Color(0.88 + shade, 0.91 + shade, 0.83 + shade)
		var dark := Color(0.62 + shade, 0.72 + shade, 0.6 + shade)
		img.fill_rect(Rect2i(0, y, 4, 1), dark if y % 4 == 3 else light)
	var tex := ImageTexture.create_from_image(img)
	_cache["bundle_edge_tex"] = tex
	return tex


## Cinta: branca (a cor vem do material), com um filete escuro perto de cada borda e uma fileira
## de tracinhos no meio da tampa e do fundo, como o carimbo impresso. u atravessa a cinta, v dá a
## volta (tampa de 0 a 0,5, fundo de 0,5 a 1).
static func _bundle_band_texture() -> Texture2D:
	if _cache.has("bundle_band_tex"):
		return _cache["bundle_band_tex"]
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(1, 1, 1))
	var line := Color(0.55, 0.55, 0.55)
	img.fill_rect(Rect2i(3, 0, 2, 64), line)
	img.fill_rect(Rect2i(27, 0, 2, 64), line)
	for half in 2:
		for i in 5:
			img.fill_rect(Rect2i(14, half * 32 + 9 + i * 3, 4, 2), Color(0.45, 0.45, 0.45))
	var tex := ImageTexture.create_from_image(img)
	_cache["bundle_band_tex"] = tex
	return tex


static func _surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _commit(st: SurfaceTool, mesh: ArrayMesh, mat: Material) -> void:
	st.set_material(mat)
	st.commit(mesh)


## Uma superfície em grade (nu x nv quadrados): `pos(u, v)` dá o ponto e `uv(u, v)` a textura,
## com u e v de 0 a 1. A normal sai da própria superfície, virada para o lado de `outward`.
## Com `outward` zero (superfície fechada), a normal aponta para longe de `center`.
static func _grid(st: SurfaceTool, nu: int, nv: int, pos: Callable, uv: Callable, outward: Vector3, center := Vector3.ZERO) -> void:
	var eps := 0.001
	var normal_at := func(u: float, v: float) -> Vector3:
		var du: Vector3 = pos.call(minf(u + eps, 1.0), v) - pos.call(maxf(u - eps, 0.0), v)
		var dv: Vector3 = pos.call(u, minf(v + eps, 1.0)) - pos.call(u, maxf(v - eps, 0.0))
		var n := du.cross(dv)
		if n.length_squared() < 1e-14:
			return outward
		n = n.normalized()
		var away: Vector3 = outward if outward != Vector3.ZERO else pos.call(u, v) - center
		return -n if n.dot(away) < 0.0 else n
	for i in nu:
		for j in nv:
			var quad := [Vector2(float(i) / nu, float(j) / nv), Vector2(float(i + 1) / nu, float(j) / nv),
					Vector2(float(i + 1) / nu, float(j + 1) / nv), Vector2(float(i) / nu, float(j + 1) / nv)]
			for k in [0, 1, 2, 0, 2, 3]:
				var p: Vector2 = quad[k]
				st.set_normal(normal_at.call(p.x, p.y))
				st.set_uv(uv.call(p.x, p.y))
				st.add_vertex(pos.call(p.x, p.y))


static func _face(st: SurfaceTool, normal: Vector3, corners: Array, region: Rect2) -> void:
	var uvs := [region.position, region.position + Vector2(region.size.x, 0), region.end,
			region.position + Vector2(0, region.size.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.add_vertex(corners[i])
