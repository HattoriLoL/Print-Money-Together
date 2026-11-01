extends Node3D
## Impressora de escritório velha (filha do MACHINE_Printer do kitnet.glb; o referencial é o do
## modelo, com a frente para +Z). Os números vêm de um PrinterStats
## (data/machines/printer_*.tres).
##
##   Botão de liga/desliga  [E]: liga ou desliga. Ligada, esquenta `warmup_seconds` e depois
##                          imprime sozinha: uma folha A4 molhada a cada `seconds_per_sheet`,
##                          que sai pela fenda da frente e cai na bandeja de saída.
##   Alimentador de trás    [E] com uma resma na mão: carrega `sheets_per_ream` folhas.
##   Tampa (em cima)        [E] com um cartucho na mão: troca o cartucho (o velho vem para a
##                          mão); de mão vazia, tira o cartucho.
## Para (e acende o LED âmbar) quando falta papel ou tinta, ou quando a bandeja de saída enche.
##
## A tinta é de jato de tinta: por isso a folha sai molhada. O cartucho original imprime a cor
## certa; o genérico (compatível, mais barato) imprime com a cor errada (`offcolor` na folha), e as
## notas dele valem menos. Cartuchos novos vêm pela internet (scripts/machines/computer.gd).
##
## O host manda no estado e repassa para todos (10 vezes por segundo enquanto muda, e na hora
## nos eventos). Quem entra depois recebe tudo em send_state_to.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")
const DEFAULT_STATS := preload("res://data/machines/printer_office.tres")

## Folha parada na bandeja de saída (a primeira; as outras empilham).
const OUTPUT_BASE := Vector3(0.0, 0.0595, 0.3)
const OUTPUT_STEP := 0.0035
## A folha saindo: da fenda até cair na bandeja, no fim de cada impressão.
const FEED_FROM := Vector3(0.0, 0.117, 0.17)
const FEED_PART := 0.4
const SYNC_RATE := 10.0
## O cartucho que já vem na impressora velha: o original, pela metade.
const START_INK := 0.5
## Ligada à toa, ela gasta essa fração do consumo de quando imprime (stats.power_watts).
const IDLE_POWER := 0.15

var stats: Resource = DEFAULT_STATS
var powered := false
## Segundos ligada (esquentando até warmup_seconds).
var warm := 0.0
var paper := 0
## Cartucho instalado: se tem, quanto de tinta ainda tem (0 a 1) e a marca.
var has_cartridge := true
var ink := START_INK
var brand := "original"
var progress := 0.0
## Ids das folhas paradas na bandeja de saída, por posição (0 = vaga livre).
var output_slots: Array[int] = []

var feeder_zone: Area3D
var power_zone: Area3D
var cartridge_zone: Area3D

var _kitnet: Node
var _button: Node3D
var _button_rest := 0.0
var _press_time := -10.0
var _led_ready: MeshInstance3D
var _led_attention: MeshInstance3D
var _led_off: StandardMaterial3D
var _paper_stack: Node3D
var _screen: Label3D
var _feeding: Node3D
var _sync_timer := 0.0
var _dirty := false


func _ready() -> void:
	name = "Printer"
	add_to_group("station")
	add_to_group("noise_source")
	add_to_group("powered")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	var model := get_parent()
	_button = model.find_child("MACHINE_Printer_Button", false, false)
	_led_ready = model.find_child("MACHINE_Printer_LedReady", false, false)
	_led_attention = model.find_child("MACHINE_Printer_LedAttention", false, false)
	_paper_stack = model.find_child("MACHINE_Printer_Paper", false, false)
	if _button:
		_button_rest = _button.position.y
	_led_off = StandardMaterial3D.new()
	_led_off.albedo_color = Color(0.12, 0.12, 0.1)
	_led_off.roughness = 0.3
	output_slots.resize(stats.output_capacity)
	output_slots.fill(0)

	feeder_zone = InteractZone.new()
	feeder_zone.setup(self, "Zone_Feeder", Vector3(0, 0.33, -0.16), Vector3(0.3, 0.3, 0.2))
	feeder_zone.prompt_fn = _feeder_prompt
	feeder_zone.press_fn = _load_paper
	power_zone = InteractZone.new()
	power_zone.setup(self, "Zone_Power", Vector3(0.19, 0.212, 0.072), Vector3(0.06, 0.04, 0.06))
	power_zone.prompt_fn = _power_prompt
	power_zone.press_fn = _toggle_power
	cartridge_zone = InteractZone.new()
	cartridge_zone.setup(self, "Zone_Cartridge", Vector3(-0.1, 0.21, 0.05), Vector3(0.22, 0.06, 0.16))
	cartridge_zone.prompt_fn = _cartridge_prompt
	cartridge_zone.press_fn = _swap_cartridge

	# Texto do visor, deitado em cima dele e lido de quem está na frente.
	_screen = Label3D.new()
	_screen.position = Vector3(0.0825, 0.2068, 0.1)
	_screen.rotation.x = -PI / 2
	_screen.pixel_size = 0.0004
	_screen.font_size = 32
	_screen.outline_size = 0
	_screen.modulate = Color(0.02, 0.08, 0.04)
	add_child(_screen)

	# A folha que desliza para fora enquanto termina de imprimir (só aparência).
	_feeding = Node3D.new()
	_feeding.rotation.y = PI / 2
	_feeding.visible = false
	_feeding.add_child(ItemKinds.sheet_mesh_instance(true))
	add_child(_feeding)

	if multiplayer.is_server():
		_kitnet.items.picked.connect(_on_item_picked)


func is_ready() -> bool:
	return powered and warm >= stats.warmup_seconds


func can_print() -> bool:
	return paper > 0 and has_ink() and output_slots.has(0)


func has_ink() -> bool:
	return has_cartridge and ink >= stats.ink_per_sheet - 0.0001


func printing() -> bool:
	return is_ready() and can_print()


## Barulho agora, de 0 a 1: o motor imprimindo, e um zumbido baixo ligada à toa.
func noise() -> float:
	if printing():
		return stats.noise
	return stats.noise * 0.15 if powered else 0.0


## Consumo agora (W), para o disjuntor (power.gd).
func power_draw() -> float:
	if not powered:
		return 0.0
	return stats.power_watts * (1.0 if printing() else IDLE_POWER)


## Host: a luz caiu. Desliga de vez: perde o aquecimento, e a folha pela metade volta.
func power_lost() -> void:
	if not powered:
		return
	powered = false
	warm = 0.0
	progress = 0.0
	_send_now()


# --- Host -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	_update_visuals()


func _server_tick(delta: float) -> void:
	if not powered:
		return
	if warm < stats.warmup_seconds:
		warm += delta
		_dirty = true
		if warm >= stats.warmup_seconds:
			_send_now()
	elif can_print():
		progress += delta / stats.seconds_per_sheet
		_dirty = true
		if progress >= 1.0:
			_finish_sheet()
	_sync_timer -= delta
	if _dirty and _sync_timer <= 0.0:
		_sync_timer = 1.0 / SYNC_RATE
		_dirty = false
		_kitnet.rpc_roster(self, &"_sync", [powered, warm, paper, ink, progress])


func _toggle_power(_peer: int) -> void:
	if not powered and not _kitnet.has_power():
		return
	powered = not powered
	warm = 0.0
	if not powered:
		progress = 0.0  # a folha pela metade volta para o alimentador
	_send_now(true)


func _finish_sheet() -> void:
	paper -= 1
	ink = maxf(0.0, ink - stats.ink_per_sheet)
	progress = 0.0
	var slot := output_slots.find(0)
	var local := Transform3D(Basis(Vector3.UP, PI / 2), OUTPUT_BASE + Vector3.UP * OUTPUT_STEP * slot)
	var data := {"wet": true, "resting": true}
	if brand == "generic":
		data["offcolor"] = true
	var sheet: Node = _kitnet.items.spawn("sheet", global_transform * local, data)
	output_slots[slot] = sheet.id
	_send_now()


func _load_paper(peer: int) -> void:
	var item: Node = _kitnet.items.held_by(peer)
	if item == null or item.kind != "ream" or paper + stats.sheets_per_ream > stats.paper_capacity:
		return
	_kitnet.items.consume(item)
	paper += stats.sheets_per_ream
	_send_now()


## Host: [E] na tampa. Com um cartucho na mão, ele entra e o que estava na impressora vai para a
## mão; de mão vazia, o cartucho sai.
func _swap_cartridge(peer: int) -> void:
	var held: Node = _kitnet.items.held_by(peer)
	if held != null and held.kind != "cartridge":
		return
	if held == null and not has_cartridge:
		return
	var old := {"ink": ink, "brand": brand}
	var had := has_cartridge
	if held != null:
		ink = held.data.get("ink", 0.0)
		brand = held.data.get("brand", "generic")
		has_cartridge = true
		_kitnet.items.consume(held)
	else:
		has_cartridge = false
	if had:
		_kitnet.items.give(peer, "cartridge", old)
	progress = 0.0  # a folha pela metade volta para o alimentador
	_send_now()


func _on_item_picked(item: Node) -> void:
	var slot := output_slots.find(item.id)
	if slot >= 0:
		output_slots[slot] = 0
		_send_now()


func _send_now(pressed := false) -> void:
	_kitnet.rpc_roster(self, &"_sync_full", [powered, warm, paper, ink, progress, output_slots, pressed, has_cartridge, brand])
	if pressed:
		_press_time = Time.get_ticks_msec() / 1000.0


func send_state_to(peer: int) -> void:
	_sync_full.rpc_id(peer, powered, warm, paper, ink, progress, output_slots, false, has_cartridge, brand)


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(on: bool, w: float, p: int, i: float, pr: float) -> void:
	powered = on
	warm = w
	paper = p
	ink = i
	progress = pr


@rpc("authority", "call_remote", "reliable")
func _sync_full(on: bool, w: float, p: int, i: float, pr: float, slots: Array, pressed: bool,
		cartridge: bool, cartridge_brand: String) -> void:
	_sync(on, w, p, i, pr)
	has_cartridge = cartridge
	brand = cartridge_brand
	output_slots.assign(slots)
	if pressed:
		_press_time = Time.get_ticks_msec() / 1000.0


# --- O que cada jogador vê --------------------------------------------------------------------

func _feeder_prompt(player: Node) -> String:
	var held: Node = player.held_item()
	if held != null and held.kind == "ream":
		if paper + stats.sheets_per_ream > stats.paper_capacity:
			return "Paper feeder is full (%d/%d)" % [paper, stats.paper_capacity]
		return "[E] Load paper (+%d sheets)" % stats.sheets_per_ream
	return "Paper: %d/%d" % [paper, stats.paper_capacity]


func _cartridge_prompt(player: Node) -> String:
	var held: Node = player.held_item()
	var current := "%s (%s)" % [ItemKinds.cartridge_name(brand), ItemKinds.ink_text(ink)] if has_cartridge else "no cartridge"
	if held != null and held.kind == "cartridge":
		return "[E] Swap ink cartridge (now: %s)" % current if has_cartridge else "[E] Put in the ink cartridge"
	if held == null and has_cartridge:
		return "[E] Take out the %s" % current
	return "Ink: %s" % current


func _power_prompt(_player: Node) -> String:
	if not powered and not _kitnet.has_power():
		return "No power: the printer won't turn on"
	return "[E] Turn printer off" if powered else "[E] Turn printer on"


func _update_visuals() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var blink := int(now * 2.5) % 2 == 0
	# Botão afunda um instante quando alguém aperta.
	if _button:
		_button.position.y = _button_rest - (0.003 if now - _press_time < 0.18 else 0.0)
	var working := powered and (not is_ready() or printing())
	_set_led(_led_ready, powered and (blink or not working))
	_set_led(_led_attention, powered and is_ready() and not can_print())
	if _paper_stack:
		_paper_stack.visible = paper > 0
	_screen.text = _screen_text()
	# A folha desliza pela fenda na última parte da impressão.
	var t := (progress - (1.0 - FEED_PART)) / FEED_PART
	_feeding.visible = printing() and t > 0.0
	if _feeding.visible:
		_feeding.get_child(0).set_instance_shader_parameter("offcolor", 1.0 if brand == "generic" else 0.0)
		var slot := maxi(output_slots.find(0), 0)
		var to := OUTPUT_BASE + Vector3.UP * (OUTPUT_STEP * slot + 0.002)
		_feeding.position = FEED_FROM.lerp(to, clampf(t, 0.0, 1.0))


func _set_led(led: MeshInstance3D, on: bool) -> void:
	if led:
		led.material_override = null if on else Toon.material(_led_off)


func _screen_text() -> String:
	if not powered:
		return ""
	if not is_ready():
		return "WARMING UP" + ".".repeat(int(warm * 2.0) % 4)
	if paper <= 0:
		return "PAPER OUT"
	if not has_cartridge:
		return "NO CARTRIDGE"
	if not has_ink():
		return "INK EMPTY"
	if not output_slots.has(0):
		return "TRAY FULL"
	return "PRINTING %d%%" % int(progress * 100.0) if printing() else "READY"
