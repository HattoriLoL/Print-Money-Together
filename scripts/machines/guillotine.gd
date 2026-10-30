extends Node3D
## Guilhotina de mesa (filha do MACHINE_Guillotine do kitnet.glb; o referencial é o do modelo, com
## a frente, onde fica a lâmina, para +Z). Os números vêm de um GuillotineStats
## (data/machines/guillotine_*.tres).
##
##   [E] com uma folha impressa na mão: põe a folha, encostada no esquadro, com a primeira linha
##       de notas passando da linha de corte.
##   [E] de mão vazia: a alavanca desce e corta uma linha. As notas dela caem no montinho na
##       frente da guilhotina (item "bills") e o resto da folha anda até a lâmina. Folha molhada
##       corta, mas as notas saem borradas.
##
## O host manda no estado e repassa para todos; a alavanca anima em todas as máquinas.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")
const DEFAULT_STATS := preload("res://data/machines/guillotine_manual.tres")
const SHEET_FRONT := preload("res://assets/textures/sheet_front.png")

## Medidas do modelo (art_source/blender/machines.py, convertidas para o Godot: y do Blender = -z).
const CUT_Z := 0.1                       # linha da lâmina
const TOP_Y := 0.0315                    # tampo, logo acima do quadriculado
const SHEET_X := -0.0835                 # centro da folha (encostada no esquadro da esquerda)
const SHEET_SIZE := Vector2(0.297, 0.21)
const OPEN_ANGLE := deg_to_rad(50.0)     # alavanca levantada (gira no Z do Godot)
## Onde nasce o montinho de notas: na mesa, logo na frente da guilhotina.
const PILE_POS := Vector3(-0.0835, 0.0, 0.26)
const PILE_STEP := Vector3(0.16, 0.0, 0.0)

var stats: Resource = DEFAULT_STATS
## Linhas que ainda faltam cortar na folha posta (0 = vazia).
var rows_left := 0
var sheet_wet := false
var zone: Area3D

var _kitnet: Node
var _arm: Node3D
var _strips: Array[MeshInstance3D] = []
var _busy := false
var _pile_id := 0
var _noise_until := 0.0
var _tween: Tween


func _ready() -> void:
	name = "Guillotine"
	add_to_group("station")
	add_to_group("noise_source")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	_arm = get_parent().find_child("MACHINE_Guillotine_Arm", false, false)
	if _arm:
		_arm.rotation = Vector3(0, 0, OPEN_ANGLE)
	zone = InteractZone.new()
	zone.setup(self, "Zone_Cut", Vector3(0, 0.06, 0), Vector3(0.52, 0.1, 0.42))
	zone.prompt_fn = _prompt
	zone.press_fn = _press
	_build_strips()
	_update_strips(false)
	if multiplayer.is_server():
		_kitnet.items.picked.connect(_on_item_picked)


## Barulho agora: o golpe da lâmina, por um instante.
func noise() -> float:
	return stats.noise if Time.get_ticks_msec() / 1000.0 < _noise_until else 0.0


# --- Host -------------------------------------------------------------------------------------

func _press(peer: int) -> void:
	if _busy:
		return
	var held: Node = _kitnet.items.held_by(peer)
	if held != null:
		if held.kind == "sheet" and rows_left == 0:
			sheet_wet = held.data.get("wet", false)
			rows_left = stats.rows_per_sheet
			_kitnet.items.consume(held)
			_kitnet.rpc_roster(self, &"_sync", [rows_left, sheet_wet, false])
			_sync(rows_left, sheet_wet, false)
		return
	# Mão vazia: a alavanca desce (com ou sem folha, dá para bater a lâmina à toa).
	_busy = true
	_kitnet.rpc_roster(self, &"_swing", [])
	_swing()
	get_tree().create_timer(stats.swing_down).timeout.connect(_cut)
	get_tree().create_timer(stats.swing_down + stats.swing_up).timeout.connect(func(): _busy = false)


## A lâmina chegou embaixo: solta uma linha de notas no montinho.
func _cut() -> void:
	if rows_left <= 0:
		return
	rows_left -= 1
	var bills: int = stats.bills_per_row
	var smudged := bills if sheet_wet else 0
	var pile: Node = _kitnet.items.items.get(_pile_id)
	var pile_ok: bool = pile != null and pile.holder == 0 and pile.data.get("resting", false) \
			and pile.data.get("count", 0) + bills <= stats.pile_max
	if pile_ok:
		_kitnet.items.set_data(pile, "count", pile.data["count"] + bills)
		_kitnet.items.set_data(pile, "smudged", pile.data.get("smudged", 0) + smudged)
		_kitnet.items.set_data(pile, "top_smudged", sheet_wet)
	else:
		var spot := _free_pile_spot()
		var data := {"count": bills, "smudged": smudged, "top_smudged": sheet_wet, "resting": true}
		var height: float = maxf(bills * ItemKinds.BILL_THICKNESS, 0.0015)
		pile = _kitnet.items.spawn("bills", global_transform * Transform3D(Basis.IDENTITY, spot + Vector3.UP * height / 2.0), data)
		_pile_id = pile.id
	if rows_left == 0:
		sheet_wet = false
	_kitnet.rpc_roster(self, &"_sync", [rows_left, sheet_wet, true])
	_sync(rows_left, sheet_wet, true)


## O lugar do montinho na frente da guilhotina, ou um do lado se já tiver um parado lá.
func _free_pile_spot() -> Vector3:
	for i in 3:
		var spot := PILE_POS + PILE_STEP * i
		var taken := false
		for item in _kitnet.items.items.values():
			if item.kind == "bills" and item.holder == 0 and \
					(global_transform * spot).distance_to(item.global_position) < 0.08:
				taken = true
		if not taken:
			return spot
	return PILE_POS


func _on_item_picked(item: Node) -> void:
	if item.id == _pile_id:
		_pile_id = 0


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, rows_left, sheet_wet, false)


@rpc("authority", "call_remote", "reliable")
func _sync(rows: int, wet: bool, animate: bool) -> void:
	rows_left = rows
	sheet_wet = wet
	_update_strips(animate)


@rpc("authority", "call_remote", "reliable")
func _swing() -> void:
	_noise_until = Time.get_ticks_msec() / 1000.0 + stats.swing_down + 0.25
	if _arm == null:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_arm, "rotation:z", 0.0, stats.swing_down).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(_arm, "rotation:z", OPEN_ANGLE, stats.swing_up).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# --- O que cada jogador vê --------------------------------------------------------------------

func _prompt(player: Node) -> String:
	var held: Node = player.held_item()
	if held != null:
		if held.kind != "sheet":
			return "Needs a printed sheet"
		if rows_left > 0:
			return "There's already a sheet in the guillotine"
		if held.data.get("wet", false):
			return "[E] Place sheet (still wet: bills will smudge)"
		return "[E] Place sheet"
	if _busy:
		return ""
	if rows_left > 0:
		return "[E] Cut  (%d row%s left)" % [rows_left, "" if rows_left == 1 else "s"]
	return "[E] Pull the lever  (place a printed sheet to cut)"


## A folha posta é feita de faixas, uma por linha de notas: cada corte some com a da frente e as
## outras andam até a lâmina.
func _build_strips() -> void:
	var row_h: float = SHEET_SIZE.y / stats.rows_per_sheet
	for r in stats.rows_per_sheet:
		var quad := QuadMesh.new()
		quad.size = Vector2(SHEET_SIZE.x, row_h)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = SHEET_FRONT
		# A folha inteira mostraria a linha da frente embaixo na textura (v perto de 1).
		var band: int = stats.rows_per_sheet - 1 - r
		mat.uv1_scale = Vector3(1.0, 1.0 / stats.rows_per_sheet, 1.0)
		mat.uv1_offset = Vector3(0.0, float(band) / stats.rows_per_sheet, 0.0)
		quad.material = mat
		var strip := MeshInstance3D.new()
		strip.mesh = quad
		strip.rotation.x = -PI / 2
		strip.visible = false
		add_child(strip)
		_strips.append(strip)


func _update_strips(animate: bool) -> void:
	var row_h: float = SHEET_SIZE.y / stats.rows_per_sheet
	var cut: int = stats.rows_per_sheet - rows_left
	for r in _strips.size():
		var strip := _strips[r]
		strip.visible = r >= cut
		var mat := strip.mesh.material as StandardMaterial3D
		mat.albedo_color = Color(0.75, 0.84, 0.76) if sheet_wet else Color.WHITE
		mat.roughness = 0.15 if sheet_wet else 0.8
		Toon.sync(mat)
		# A linha da vez fica logo depois da lâmina; as outras atrás dela.
		var target := Vector3(SHEET_X, TOP_Y, CUT_Z + row_h / 2.0 - (r - cut) * row_h)
		if animate and strip.visible:
			create_tween().tween_property(strip, "position", target, 0.25).set_delay(0.05)
		else:
			strip.position = target
