extends Node3D
## Contadora de cédulas na ponta da mesa do meio (filha do MACHINE_CashCounter do kitnet.glb; o
## referencial é o do modelo, com a frente para +Z). Junta os montinhos da guilhotina em maços
## cintados de BUNDLE_SIZE notas, com nota de qualidade (ItemKinds.grade).
##
##   Funil (em cima)    [E] com um montinho na mão: joga as notas dentro (até HOPPER_MAX); de
##                      mão vazia, pega de volta as que ainda não foram contadas.
##   Bandeja da frente  [E] com BUNDLE_SIZE notas: cinta o maço e ele vem para a mão; antes
##                      disso, de mão vazia, pega as contadas soltas.
##   Gabinete           Segurar [E] com a máquina emperrada: destrava (JAM_CLEAR segundos).
##
## Conta sozinha, BILLS_PER_SECOND notas por segundo, até a bandeja encher. Nota borrada (cortada
## molhada) tem a tinta grudenta e emperra a máquina: destravada, ela sai num montinho de
## rejeitadas do lado (REJECT_SPOT). O funil e a bandeja guardam só os totais (quantas, quanto
## valem, quantas tortas, de cor errada e usadas); cada nota que passa é sorteada dos totais.
##
## O host conta e repassa o estado para todos a cada nota (e no que muda). Quem entra depois
## recebe tudo em send_state_to.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")

const BUNDLE_SIZE := 20
const HOPPER_MAX := 120
const BILLS_PER_SECOND := 10.0
## Quanto tempo segurando para destravar (s).
const JAM_CLEAR := 1.2
const NOISE := 0.15
## Funil (art_source/blender/machines.py, COUNTER_HOPPER; y do Blender = -z): o centro da tampa
## dele e a inclinação (no X); as notas deitam em cima da tampa.
const HOPPER_CENTER := Vector3(0.0, 0.17, -0.06)
const HOPPER_SURFACE := Vector3(0.0, 0.005, 0.0)
const HOPPER_TILT := -0.6
## Em cima da bandeja da frente, e onde as notas aparecem saindo da fenda.
const TRAY_TOP := Vector3(0.0, 0.03, 0.16)
const SLOT := Vector3(0.0, 0.042, 0.12)
## Visor (na frente do painel).
const SCREEN_POS := Vector3(-0.035, 0.1, 0.1258)
## Onde as rejeitadas ficam, do lado da máquina (deitadas atravessadas).
const REJECT_SPOT := Vector3(0.22, 0.0, 0.0)

## As notas no funil (os totais; vazio = nada).
var hopper := {}
## As contadas na bandeja (os totais, mais top_worn / top_offcolor da última).
var tray := {}
var jammed := false
## Quanto já foi destravado (0 a JAM_CLEAR).
var jam_progress := 0.0

var hopper_zone: Area3D
var tray_zone: Area3D
var body_zone: Area3D

var _kitnet: Node
var _screen: Label3D
var _hopper_stack: MeshInstance3D
var _tray_stack: MeshInstance3D
var _flying: MeshInstance3D
var _fly_time := 10.0
var _timer := 0.0
## Só no host: a nota que emperrou e o montinho de rejeitadas que está do lado.
var _jam_bill := {}
var _reject_id := 0
var _rng := RandomNumberGenerator.new()
var _whirr: AudioStreamPlayer3D
var _clunk: AudioStreamPlayer3D
var _beep: AudioStreamPlayer3D


func _ready() -> void:
	name = "CashCounter"
	add_to_group("station")
	add_to_group("noise_source")
	_kitnet = get_tree().get_first_node_in_group("kitnet")

	hopper_zone = InteractZone.new()
	hopper_zone.setup(self, "Zone_Hopper", HOPPER_CENTER + Vector3(0.0, 0.02, 0.0), Vector3(0.24, 0.1, 0.18))
	hopper_zone.prompt_fn = _hopper_prompt
	hopper_zone.press_fn = _use_hopper
	tray_zone = InteractZone.new()
	tray_zone.setup(self, "Zone_Tray", Vector3(0.0, 0.05, 0.165), Vector3(0.22, 0.08, 0.1))
	tray_zone.prompt_fn = _tray_prompt
	tray_zone.press_fn = _use_tray
	body_zone = InteractZone.new()
	body_zone.setup(self, "Zone_Counter", Vector3(0.0, 0.065, -0.01), Vector3(0.28, 0.13, 0.22), true)
	body_zone.prompt_fn = _body_prompt

	_screen = Label3D.new()
	_screen.position = SCREEN_POS
	_screen.pixel_size = 0.0003
	_screen.font_size = 64
	_screen.outline_size = 0
	_screen.modulate = Color(0.35, 1.0, 0.5)
	add_child(_screen)

	# As notas no funil (deitadas na tampa inclinada), na bandeja e a que está passando.
	var hopper_base := Node3D.new()
	hopper_base.position = HOPPER_CENTER
	hopper_base.rotation.x = HOPPER_TILT
	add_child(hopper_base)
	_hopper_stack = _stack_mesh()
	hopper_base.add_child(_hopper_stack)
	_tray_stack = _stack_mesh()
	_tray_stack.position = TRAY_TOP
	add_child(_tray_stack)
	_flying = _stack_mesh()
	_flying.scale = Vector3(1.0, 0.0015, 1.0)
	add_child(_flying)

	_build_sounds()
	_render()


func counting() -> bool:
	return not jammed and hopper.get("count", 0) > 0 and tray.get("count", 0) < BUNDLE_SIZE


func noise() -> float:
	return NOISE if counting() else 0.0


# --- Host -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	if jammed:
		if not body_zone.holders.is_empty():
			jam_progress += delta
			if jam_progress >= JAM_CLEAR:
				_clear_jam()
			else:
				_send_now()
		return
	if not counting():
		_timer = 0.0
		return
	_timer += delta * BILLS_PER_SECOND
	while _timer >= 1.0 and counting():
		_timer -= 1.0
		_count_one()


## Passa uma nota do funil: a borrada emperra; as outras vão para a bandeja.
func _count_one() -> void:
	var bill := _take_bill()
	if bill["smudged"]:
		jammed = true
		jam_progress = 0.0
		_jam_bill = bill
		_send_now("jam")
		return
	_add(tray, bill)
	tray["top_worn"] = bill["worn"]
	tray["top_offcolor"] = bill["offcolor"]
	_send_now("full" if tray["count"] >= BUNDLE_SIZE else "bill")


## Tira uma nota do funil, sorteando das contas dele o que ela é (borrada, torta...), e devolve
## {"worth": quanto vale, e um bool para cada marca}.
func _take_bill() -> Dictionary:
	var n: int = hopper["count"]
	var bill := {"worth": hopper.get("worth", float(n)) / n}
	for key in ["smudged", "crooked", "offcolor", "worn"]:
		var k: int = hopper.get(key, 0)
		bill[key] = _rng.randi_range(1, n) <= k
		if bill[key]:
			hopper[key] = k - 1
	hopper["worth"] = hopper.get("worth", float(n)) - bill["worth"]
	hopper["count"] = n - 1
	if hopper["count"] <= 0:
		hopper = {}
	return bill


## Soma uma nota (de _take_bill) nos totais.
static func _add(into: Dictionary, bill: Dictionary) -> void:
	into["count"] = into.get("count", 0) + 1
	into["worth"] = into.get("worth", 0.0) + bill["worth"]
	for key in ["smudged", "crooked", "offcolor", "worn"]:
		if bill[key]:
			into[key] = into.get(key, 0) + 1


## Soma um montinho inteiro nos totais.
static func _merge(into: Dictionary, data: Dictionary) -> void:
	var count: int = data.get("count", 0)
	into["count"] = into.get("count", 0) + count
	into["worth"] = into.get("worth", 0.0) + data.get("worth", float(count))
	for key in ["smudged", "crooked", "offcolor", "worn"]:
		into[key] = into.get(key, 0) + data.get(key, 0)


## Destravou: a nota borrada vai para o montinho de rejeitadas do lado.
func _clear_jam() -> void:
	jammed = false
	jam_progress = 0.0
	var pile: Node = _kitnet.items.items.get(_reject_id)
	if pile != null and pile.holder == 0 and pile.data.get("resting", false):
		# Ainda parado do lado: soma nele.
		_kitnet.items.set_data(pile, "worth", pile.data.get("worth", float(pile.data["count"])) + _jam_bill["worth"])
		for key in ["smudged", "crooked", "offcolor", "worn"]:
			if _jam_bill.get(key, false):
				_kitnet.items.set_data(pile, key, pile.data.get(key, 0) + 1)
		_kitnet.items.set_data(pile, "count", pile.data["count"] + 1)
	else:
		var data := {"count": 1, "smudged": 1, "top_smudged": true, "worth": _jam_bill["worth"], "resting": true}
		for key in ["crooked", "offcolor", "worn"]:
			if _jam_bill.get(key, false):
				data[key] = 1
		data["top_offcolor"] = _jam_bill.get("offcolor", false)
		data["top_worn"] = _jam_bill.get("worn", false)
		var height := ItemKinds.BILL_THICKNESS
		var xform := Transform3D(Basis(Vector3.UP, PI / 2.0), REJECT_SPOT + Vector3.UP * (height / 2.0 + 0.001))
		pile = _kitnet.items.spawn("bills", global_transform * xform, data)
		_reject_id = pile.id
	_jam_bill = {}
	_send_now("clear")


## [E] no funil: joga o montinho da mão dentro, ou pega de volta as que não foram contadas.
func _use_hopper(peer: int) -> void:
	var held: Node = _kitnet.items.held_by(peer)
	if held != null:
		if held.kind != "bills" or hopper.get("count", 0) + held.data.get("count", 0) > HOPPER_MAX:
			return
		_merge(hopper, held.data)
		_kitnet.items.consume(held)
		_send_now("feed")
	elif not hopper.is_empty():
		_kitnet.items.give(peer, "bills", _pile_data(hopper))
		hopper = {}
		_send_now()


## Host: a polícia leva o que está no funil, na bandeja e a nota entalada. Devolve o que levou.
func confiscate() -> Dictionary:
	var bills: int = hopper.get("count", 0) + tray.get("count", 0) + (1 if jammed else 0)
	if bills == 0:
		return {}
	hopper = {}
	tray = {}
	jammed = false
	jam_progress = 0.0
	_jam_bill = {}
	_send_now()
	return {"bills": bills}


## [E] na bandeja: com ela cheia, cinta o maço; antes, pega as contadas soltas.
func _use_tray(peer: int) -> void:
	if _kitnet.items.held_by(peer) != null or tray.is_empty():
		return
	var full: bool = tray["count"] >= BUNDLE_SIZE
	_kitnet.items.give(peer, "bundle" if full else "bills", _pile_data(tray))
	tray = {}
	_send_now("strap" if full else "")


## Os dados de um item feito dos totais (só as chaves que têm alguma coisa).
static func _pile_data(totals: Dictionary) -> Dictionary:
	var data := {"count": totals["count"], "worth": totals.get("worth", float(totals["count"]))}
	for key in ["smudged", "crooked", "offcolor", "worn"]:
		if totals.get(key, 0) > 0:
			data[key] = totals[key]
	var count: int = totals["count"]
	data["top_smudged"] = totals.get("smudged", 0) * 2 > count
	data["top_offcolor"] = totals.get("top_offcolor", totals.get("offcolor", 0) * 2 > count)
	data["top_worn"] = totals.get("top_worn", totals.get("worn", 0) * 2 > count)
	return data


func _send_now(event := "") -> void:
	_kitnet.rpc_roster(self, &"_sync", [hopper, tray, jammed, jam_progress, event])
	_on_event(event)


func send_state_to(peer: int) -> void:
	_sync.rpc_id(peer, hopper, tray, jammed, jam_progress, "")


@rpc("authority", "call_remote", "reliable")
func _sync(h: Dictionary, t: Dictionary, jam: bool, progress: float, event: String) -> void:
	hopper = h
	tray = t
	jammed = jam
	jam_progress = progress
	_on_event(event)


# --- O que cada jogador vê e ouve -------------------------------------------------------------

func _on_event(event: String) -> void:
	_render()
	match event:
		"bill":
			_fly_time = 0.0
		"full":
			_fly_time = 0.0
			_beep.play()
		"jam", "feed", "strap", "clear":
			_clunk.pitch_scale = {"jam": 0.7, "feed": 1.3, "strap": 1.8, "clear": 1.0}[event]
			_clunk.play()


func _hopper_prompt(player: Node) -> String:
	var held: Node = player.held_item()
	var inside: int = hopper.get("count", 0)
	if held != null:
		if held.kind != "bills":
			return "Only loose bills go in the counter"
		if inside + held.data.get("count", 0) > HOPPER_MAX:
			return "The counter's hopper is full (%d/%d)" % [inside, HOPPER_MAX]
		return "[E] Feed %d bills into the counter" % held.data.get("count", 0)
	if inside > 0:
		return "[E] Take back the %d uncounted bills" % inside
	return "Cash counter: put bills in here"


func _tray_prompt(player: Node) -> String:
	var count: int = tray.get("count", 0)
	if count == 0:
		return ""
	if player.held_item() != null:
		return "%d counted bills" % count
	if count >= BUNDLE_SIZE:
		return "[E] Strap the bundle (%d bills, grade %s)" % [count, ItemKinds.grade(tray)]
	return "[E] Take the %d counted bills (a bundle is %d)" % [count, BUNDLE_SIZE]


func _body_prompt(_player: Node) -> String:
	if jammed:
		return "Hold [E] to clear the jam (smudged bill)"
	return ""


func _update_visuals(delta: float) -> void:
	# A nota que acabou de passar escorrega da fenda para a bandeja.
	_fly_time += delta
	var t := clampf(_fly_time / (0.8 / BILLS_PER_SECOND), 0.0, 1.0)
	var land: Vector3 = TRAY_TOP + Vector3.UP * (tray.get("count", 0) * ItemKinds.BILL_THICKNESS + 0.001)
	_flying.visible = t < 1.0
	_flying.position = SLOT.lerp(land, t)
	var now := Time.get_ticks_msec() / 1000.0
	_screen.text = _screen_text(now)
	if counting():
		if not _whirr.playing:
			_whirr.play()
	elif _whirr.playing:
		_whirr.stop()


func _screen_text(now: float) -> String:
	if jammed:
		return "JAM" if int(now * 3.0) % 2 == 0 else ""
	var count: int = tray.get("count", 0)
	if count >= BUNDLE_SIZE:
		return "%d %s" % [count, ItemKinds.grade(tray)]
	return "%03d" % count


## As pilhas do funil e da bandeja na altura certa, com a textura da nota de cima.
func _render() -> void:
	_show_stack(_hopper_stack, hopper, HOPPER_SURFACE)
	_show_stack(_tray_stack, tray, TRAY_TOP)
	_flying.mesh = ItemKinds._bills_mesh(false, Rect2(), tray.get("top_offcolor", false), tray.get("top_worn", false))
	Toon.apply_one(_flying)


func _show_stack(mesh: MeshInstance3D, totals: Dictionary, base: Vector3) -> void:
	var count: int = totals.get("count", 0)
	mesh.visible = count > 0
	if count == 0:
		return
	var data := _pile_data(totals)
	mesh.mesh = ItemKinds._bills_mesh(data["top_smudged"], Rect2(), data["top_offcolor"], data["top_worn"])
	Toon.apply_one(mesh)
	var height := maxf(count * ItemKinds.BILL_THICKNESS, 0.0015)
	mesh.scale = Vector3(1.0, height, 1.0)
	mesh.position = base + Vector3.UP * (height / 2.0 + 0.001)


static func _stack_mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.visible = false
	return mesh


# --- Sons -------------------------------------------------------------------------------------

func _build_sounds() -> void:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Contando (1 s em loop): o motor e um estalo de papel a cada nota.
	var whirr := PackedFloat32Array()
	var per_bill := int(RATE / BILLS_PER_SECOND)
	for i in RATE:
		var t := float(i) / RATE
		var k := float(i % per_bill) / RATE
		var flick := exp(-k * 160.0) * rng.randf_range(-1.0, 1.0)
		whirr.append(0.12 * sin(TAU * 120.0 * t) + 0.06 * sin(TAU * 360.0 * t) + 0.55 * flick
				+ 0.05 * rng.randf_range(-1.0, 1.0))
	# Tranco (emperrou, notas no funil, maço cintado).
	var clunk := PackedFloat32Array()
	for i in int(RATE * 0.2):
		var t := float(i) / RATE
		clunk.append(0.7 * exp(-t * 30.0) * sin(TAU * 140.0 * t) + 0.35 * exp(-t * 60.0) * rng.randf_range(-1.0, 1.0))
	# Maço completo: dois bipes.
	var beep := PackedFloat32Array()
	for i in int(RATE * 0.4):
		var t := float(i) / RATE
		beep.append(0.4 * sin(TAU * 1500.0 * t) if fmod(t, 0.2) < 0.11 else 0.0)
	_whirr = _player("Whirr", _wav(whirr, RATE, true))
	_clunk = _player("Clunk", _wav(clunk, RATE, false))
	_beep = _player("Beep", _wav(beep, RATE, false))


func _player(player_name: String, stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = player_name
	p.stream = stream
	p.unit_size = 3.0
	p.position = Vector3(0.0, 0.08, 0.0)
	add_child(p)
	return p


static func _wav(samples: PackedFloat32Array, rate: int, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 22000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
