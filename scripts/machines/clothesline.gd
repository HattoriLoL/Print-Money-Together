extends Node3D
## Varal de teto da área de serviço (filho do MACHINE_ClothesLine do kitnet.glb, que fica na origem:
## o referencial é o do mundo). A impressora é de jato de tinta e a folha sai molhada; cortada
## assim, as notas saem borradas. No varal ela seca.
##
##   [E] com uma folha na mão: pendura a folha na próxima vaga livre (5 cordas com 3 vagas).
##   [E] numa folha pendurada: pega de volta (como qualquer item).
##
## Pendurada, a folha seca em DRY_SECONDS; com o ventilador ligado (fan.gd), FAN_FACTOR vezes mais
## rápido, e ela tremula no vento. A umidade fica na folha (`data.wetness`, de 1 a 0): o brilho de
## molhada vai sumindo, e quem tira antes de secar leva ela ainda úmida (pendurar de novo continua
## de onde parou). Seca de vez, `data.wet` vira falso.
##
## O host conta a secagem e repassa a umidade a cada SYNC_STEP.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")

## Medidas do modelo (art_source/blender/machines.py, CLOTHES e CLOTHES_SLOTS_Y; y do Blender =
## -z): o x de cada corda, o z de cada vaga e a altura das cordas.
const LINES_X := [5.4, 5.5875, 5.775, 5.9625, 6.15]
const SLOTS_Z := [-2.95, -3.55, -4.15]
const LINE_Y := 2.22
## Segundos para uma folha encharcada secar no varal (sem ventilador).
const DRY_SECONDS := 40.0
## Com o ventilador ligado, seca tantas vezes mais rápido.
const FAN_FACTOR := 3.0
## A umidade vai para os outros a cada vez que baixa isso.
const SYNC_STEP := 0.05
## Tremor da ponta de baixo da folha: parada e no vento do ventilador (m).
const FLUTTER_CALM := 0.002
const FLUTTER_WIND := 0.012

## Só no host: id da folha em cada vaga (0 = livre).
var slots: Array[int] = []
var zone: Area3D
var _kitnet: Node
## Só no host: umidade de cada folha pendurada (id -> 0..1), mais fina que a que vai pela rede.
var _wetness := {}


func _ready() -> void:
	name = "ClothesLine"
	add_to_group("station")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	slots.resize(LINES_X.size() * SLOTS_Z.size())
	slots.fill(0)
	# Uma faixa fina em volta das cordas: embaixo dela a mira acerta as folhas penduradas.
	zone = InteractZone.new()
	var center := Vector3((LINES_X[0] + LINES_X[-1]) / 2.0, LINE_Y, (SLOTS_Z[0] + SLOTS_Z[-1]) / 2.0)
	zone.setup(self, "Zone_Hang", center, Vector3(LINES_X[-1] - LINES_X[0] + 0.15, 0.08, absf(SLOTS_Z[-1] - SLOTS_Z[0]) + 0.4))
	zone.prompt_fn = _prompt
	zone.press_fn = _hang
	if multiplayer.is_server():
		_kitnet.items.picked.connect(_on_item_picked)


## Onde fica a folha da vaga `slot`: em pé, o comprido ao longo da corda, presa pela borda de cima.
static func slot_transform(slot: int) -> Transform3D:
	var line: float = LINES_X[slot / SLOTS_Z.size()]
	var z: float = SLOTS_Z[slot % SLOTS_Z.size()]
	var half_height: float = ItemKinds.SIZES["sheet"].z / 2.0
	# O comprido da folha (x dela) vai ao longo da corda (z), a face (y dela) para o lado (x) e a
	# borda de perto (+z dela) para cima.
	var basis := Basis(Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0))
	return Transform3D(basis, Vector3(line, LINE_Y - 0.004 - half_height, z))


## Vagas livres, contando as folhas penduradas (vale em todas as máquinas).
func free_slots() -> int:
	var used := 0
	for item in _kitnet.items.items.values():
		if item.kind == "sheet" and item.holder == 0 and item.data.get("hanging", false):
			used += 1
	return slots.size() - used


func _fan() -> Node:
	return _kitnet.fan


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_dry(delta)


func _process(_delta: float) -> void:
	# As folhas penduradas tremulam no vento do ventilador (em todas as máquinas).
	var fan := _fan()
	var flutter := lerpf(FLUTTER_CALM, FLUTTER_WIND, fan.spin if fan else 0.0)
	for item in _kitnet.items.items.values():
		if item.kind == "sheet" and item.holder == 0 and item.data.get("hanging", false):
			var mesh: MeshInstance3D = item.get_node_or_null("Mesh")
			if mesh:
				mesh.set_instance_shader_parameter("flutter", flutter)


# --- Host -------------------------------------------------------------------------------------

func _hang(peer: int) -> void:
	var held: Node = _kitnet.items.held_by(peer)
	var slot := _free_slot()
	if held == null or held.kind != "sheet" or slot < 0:
		return
	var data := {"resting": true, "hanging": true, "wet": held.data.get("wet", false)}
	if held.data.get("offcolor", false):
		data["offcolor"] = true
	if data["wet"]:
		data["wetness"] = held.data.get("wetness", 1.0)
	_kitnet.items.consume(held)
	var sheet: Node = _kitnet.items.spawn("sheet", slot_transform(slot), data)
	slots[slot] = sheet.id
	if data["wet"]:
		_wetness[sheet.id] = data["wetness"]


func _dry(delta: float) -> void:
	if _wetness.is_empty():
		return
	var fan := _fan()
	var rate := delta / DRY_SECONDS * (FAN_FACTOR if fan and fan.blowing() else 1.0)
	for id in _wetness.keys():
		var item: Node = _kitnet.items.items.get(id)
		if item == null:
			_wetness.erase(id)
			continue
		var before: float = _wetness[id]
		var now := maxf(before - rate, 0.0)
		_wetness[id] = now
		if now <= 0.0:
			_kitnet.items.set_data(item, "wetness", 0.0)
			_kitnet.items.set_data(item, "wet", false)
			_wetness.erase(id)
		elif floorf(now / SYNC_STEP) != floorf(before / SYNC_STEP):
			_kitnet.items.set_data(item, "wetness", snappedf(now, 0.01))


## Host: a primeira vaga livre (a folha que estava nela pode ter sumido), ou -1.
func _free_slot() -> int:
	for i in slots.size():
		if slots[i] == 0 or not _kitnet.items.items.has(slots[i]):
			slots[i] = 0
			return i
	return -1


## Host: alguém pegou uma folha do varal: a vaga libera e ela para de secar.
func _on_item_picked(item: Node) -> void:
	var slot := slots.find(item.id)
	if slot < 0:
		return
	slots[slot] = 0
	if _wetness.has(item.id):
		_kitnet.items.set_data(item, "wetness", snappedf(_wetness[item.id], 0.01))
		_wetness.erase(item.id)
	_kitnet.items.set_data(item, "hanging", false)


func send_state_to(_peer: int) -> void:
	pass  # as folhas penduradas vão como itens; as vagas só o host precisa


func _prompt(player: Node) -> String:
	var held: Node = player.held_item()
	if held != null and held.kind == "sheet":
		if free_slots() <= 0:
			return "The clothesline is full"
		if not held.data.get("wet", false):
			return "[E] Hang the sheet (it's already dry)"
		var fan := _fan()
		return "[E] Hang the sheet to dry" + ("" if fan and fan.blowing() else " (turn on the fan to dry faster)")
	return ""
