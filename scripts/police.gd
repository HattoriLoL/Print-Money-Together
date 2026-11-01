extends Node
## A polícia (nó "Police" do mapa): o vizinho do 303 ligou (neighbor.gd, call_cops) e a viatura
## chega RAID_DELAY segundos depois. A sirene vai chegando (SIREN_AT antes) e as luzes vermelha e
## azul piscam pela janela e pelo corredor.
##
## A batida (o host manda):
##   1. Dois policiais (cop.gd) sobem a escada, atravessam o corredor e entram pela 301 (abrem à
##      força, trancada ou não).
##   2. Cada um tem uma metade da kitnet para revistar (search_points): os móveis com dinheiro
##      escondido (stash.gd) e os esconderijos de gente (hideout.gd). Cada móvel tem uma chance de
##      ser revistado de verdade (`chance`; os óbvios mais). Achou: leva o dinheiro escondido (saco
##      de lixo fechado passa por lixo) e quem estiver escondido ali sai pego.
##   3. Prova à vista (folha, notas, maço, saco aberto com dinheiro) eles pegam no caminho.
##   4. Quem eles veem leva cacetada, é algemado e sai arrastado até a escada (jail): fica preso
##      até a batida acabar. Um amigo com a frigideira derruba o policial e solta o preso.
##   5. Terminaram (ou passou RAID_MAX): levam o que sobrou à vista e o que estiver nas máquinas
##      (`confiscate()` de cada uma), o caixa paga a multa (FINE se acharam prova, mais BAIL por
##      preso, ou o que tiver) e vão embora. Os presos voltam no corredor. A partida continua.
##
## O host conta o tempo e repassa; todo mundo ouve a sirene e lê o aviso no HUD.

const Cop := preload("res://scripts/cop.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const RAID_DELAY := 30.0
## A sirene começa a chegar a isso do fim (s), e as luzes piscam nos últimos LIGHTS_AT, durante a
## batida e depois dela (LIGHTS_AFTER).
const SIREN_AT := 18.0
const LIGHTS_AT := 6.0
const LIGHTS_AFTER := 8.0
const FINE := 100
const BAIL := 50
## A batida mais longa (s): passou disso, eles levam o que viram e vão embora.
const RAID_MAX := 150.0
## Tipos de item que a polícia leva.
const EVIDENCE := ["sheet", "bills", "bundle"]
## Luzes da viatura: lá fora, na frente da janela principal, e no corredor (Godot).
const LIGHT_SPOTS := [Vector3(2.5, 2.0, -6.5), Vector3(4.1, 2.0, 0.85)]
## Patamar da escada (fim oeste do corredor, logo depois da porta corta-fogo): por onde eles chegam
## e saem, e onde o preso fica esperando.
const STAIRS := Vector3(-1.0, 0.0, 0.8)
const JAIL := Vector3(-1.2, 0.05, 0.8)
## Onde os presos voltam (na frente da 301, no corredor).
const RELEASE := Vector3(4.1, 0.05, 1.05)

## Segundos até a batida (negativo = ninguém vindo).
var time_left := -1.0
## A batida está acontecendo (os policiais dentro).
var raiding := false
## O que levaram na última batida (para o teste): {"sheets", "bills", "bundles", "arrests", "fine"}.
var last_raid := {}
## Para o teste: se >= 0, toda revista usa esta chance.
var search_chance := -1.0
var cops: Array = []
## Ids presos agora (esperando na escada).
var jailed: Array = []

var _kitnet: Node
var _siren: AudioStreamPlayer
var _lights: Array[OmniLight3D] = []
var _flash_left := 0.0
var _time := 0.0
var _raid_time := 0.0
var _leaving := false
var _taken := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Police"
	add_to_group("station")
	_kitnet = get_parent()
	_rng.randomize()
	_siren = AudioStreamPlayer.new()
	_siren.name = "Siren"
	_siren.stream = _siren_sound()
	_siren.volume_db = -40.0
	add_child(_siren)
	for spot: Vector3 in LIGHT_SPOTS:
		var light := OmniLight3D.new()
		light.omni_range = 4.5
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.position = spot
		add_child(light)
		_lights.append(light)
	for i in 2:
		var cop := Cop.new()
		cop.setup(i, self)
		add_child(cop)
		cops.append(cop)


## A polícia vem vindo ou já está dentro (o vizinho não se irrita nesse meio tempo).
func coming() -> bool:
	return time_left >= 0.0 or raiding


## Texto do HUD ("" = nada acontecendo).
func alert_text() -> String:
	if time_left >= 0.0:
		return "POLICE ON THE WAY: %ds  ·  Hide everything!" % ceili(time_left)
	if raiding:
		return "POLICE RAID!  ·  Hide or run!"
	return ""


## Host: o vizinho ligou.
func call_cops() -> void:
	if coming():
		return
	_set_time(RAID_DELAY, "called")
	_kitnet.rpc_roster(self, &"_set_time", [RAID_DELAY, "called"])


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if time_left >= 0.0:
		time_left -= delta
		if time_left <= 0.0:
			_start_raid()
		return
	if not raiding:
		return
	_raid_time += delta
	if not _leaving:
		if cops.all(func(c): return c.done() or not c.active()) or _raid_time > RAID_MAX:
			_wrap_up()
	elif cops.all(func(c): return not c.active()):
		_finish()


# --- Host: a batida ------------------------------------------------------------------------------

func _start_raid() -> void:
	raiding = true
	_leaving = false
	_raid_time = 0.0
	_taken = {"sheets": 0, "bills": 0, "bundles": 0, "arrests": 0}
	_open_door("Stairs")
	var lists := _split_tasks()
	for i in cops.size():
		cops[i].begin(STAIRS + Vector3(-0.3 * i, 0.0, 0.35 * i - 0.15), lists[i])
	_set_time(-1.0, "arrive")
	_kitnet.rpc_roster(self, &"_set_time", [-1.0, "arrive"])


## Terminaram: levam o resto à vista e o das máquinas, cobram e vão embora.
func _wrap_up() -> void:
	_leaving = true
	var visible := seize_visible()
	for key in visible:
		_taken[key] = _taken.get(key, 0) + visible[key]
	for cop in cops:
		cop.leave(STAIRS)


func _finish() -> void:
	raiding = false
	var found: bool = _taken["sheets"] + _taken["bills"] + _taken["bundles"] > 0
	var bill: int = (FINE if found else 0) + BAIL * int(_taken["arrests"])
	var fine := mini(bill, _kitnet.wallet.cash)
	if fine > 0:
		_kitnet.wallet.spend(fine)
	_taken["fine"] = fine
	last_raid = _taken.duplicate()
	for i in jailed.size():
		var player: Node = _kitnet.players.get(jailed[i])
		if player != null:
			player.set_arrest("", null, RELEASE + Vector3(0.45 * (i - (jailed.size() - 1) / 2.0), 0.0, 0.0))
	jailed.clear()
	var stairs: Node = _kitnet.doors.get("Stairs")
	if stairs != null:
		stairs.set_open(false)
	_set_time(-1.0, "raid", last_raid)
	_kitnet.rpc_roster(self, &"_set_time", [-1.0, "raid", last_raid])


func _open_door(key: String) -> void:
	var door: Node = _kitnet.doors.get(key)
	if door != null:
		door.set_locked(false)
		door.set_open(true)


## As duas listas de tarefas: a parte da sala (oeste) e a parte da cozinha, banheiro e serviço
## (leste), cada uma meio embaralhada.
func _split_tasks() -> Array:
	var west := []
	var east := []
	for point in search_points():
		if point["side"] == "west":
			west.append(point)
		else:
			east.append(point)
	for list in [west, east]:
		# Embaralha sem levar o último (o corredor fica para a saída).
		var last: Variant = list.pop_back() if list.size() > 0 and list[-1]["key"] == "hall" else null
		for i in range(list.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var tmp: Variant = list[i]
			list[i] = list[j]
			list[j] = tmp
		if last != null:
			list.append(last)
	return [west, east]


## Os lugares que eles revistam: onde ficar, para onde olhar, a chance de revistar de verdade, o
## esconderijo de dinheiro (stash) e o de gente (hideout) que tem ali, e de que lado da kitnet fica.
## Os sem esconderijo são só para dar uma olhada no cômodo (chance 0).
func search_points() -> Array:
	var points := []
	var stash_of := {}
	for stash in _kitnet.stashes:
		stash_of[String(stash.get_parent().name)] = stash
	var hide: Dictionary = _kitnet.hideouts
	var wardrobe: Node3D = stash_of.get("HIDE_Wardrobe")
	if wardrobe != null:
		var n: Node3D = wardrobe.get_parent()
		points.append(_point("wardrobe", "the wardrobe", n.global_transform * Vector3(0, 0, 1.0), n.global_position + Vector3.UP, 0.7, wardrobe, hide.get("wardrobe"), "west"))
	var sofa: Node3D = stash_of.get("HIDE_SofaBed")
	if sofa != null:
		var n: Node3D = sofa.get_parent()
		points.append(_point("sofa", "the sofa bed", n.global_transform * Vector3(0.3, 0, 1.15), n.global_position + Vector3.UP * 0.3, 0.45, sofa, hide.get("sofa"), "west"))
	points.append(_point("window", "the window", Vector3(2.5, 0.0, -3.75), Vector3(2.5, 1.5, -5.0), 0.3, null, hide.get("window"), "west"))
	points.append(_point("room", "the room", Vector3(2.4, 0.0, -2.9), Vector3(1.0, 1.0, -2.0), 0.0, null, null, "west"))
	var fridge: Node3D = stash_of.get("HIDE_Fridge")
	if fridge != null:
		var n: Node3D = fridge.get_parent()
		points.append(_point("fridge", "the fridge", n.global_transform * Vector3(0, 0, 1.0), n.global_position + Vector3.UP, 0.6, fridge, null, "east"))
	points.append(_point("shower", "the shower", Vector3(6.45, 0.0, -1.5), Vector3(6.5, 1.0, -0.5), 0.6, null, hide.get("shower"), "east"))
	var hatch: Node3D = stash_of.get("KEEP_BathHatch")
	if hatch != null:
		var n: Node3D = hatch.get_parent()
		points.append(_point("hatch", "the ceiling", Vector3(n.global_position.x, 0.0, n.global_position.z + 0.45), n.global_position, 0.2, hatch, null, "east"))
	points.append(_point("service", "the laundry", Vector3(6.0, 0.0, -3.6), Vector3(6.3, 1.0, -4.4), 0.0, null, null, "east"))
	points.append(_point("hall", "the hallway", Vector3(8.4, 0.0, 0.85), Vector3(9.6, 0.5, 0.6), 0.35, null, hide.get("hall"), "east"))
	return points


func _point(key: String, label: String, stand: Vector3, look: Vector3, chance: float, stash: Node, hideout: Node, side: String) -> Dictionary:
	return {"kind": "search", "key": key, "label": label, "stand": stand, "look": look, "chance": chance,
			"stash": stash, "hideout": hideout, "side": side}


## A tarefa de revistar o esconderijo `spot` com esta chance (viram alguém entrar).
func task_for_hideout(spot: Node, chance: float) -> Dictionary:
	for point in search_points():
		if point["hideout"] == spot:
			point["chance"] = chance
			point["force"] = chance >= 1.0
			return point
	return _point(spot.key, spot.spot_name, spot.exit_point(), spot.center(), chance, null, spot, "west")


## Host: o policial terminou de revistar `task`. Rola a chance; achando, leva o dinheiro escondido
## e tira quem estava escondido. Devolve os ids pegos.
func search_hit(task: Dictionary) -> Array:
	var chance: float = task.get("chance", 0.0)
	if search_chance >= 0.0 and not task.get("force", false):
		chance = search_chance
	if chance <= 0.0 or _rng.randf() >= chance:
		return []
	var stash: Node = task.get("stash")
	if stash != null:
		var got: Dictionary = stash.seize()
		var any := false
		for key in got:
			_taken[key] = _taken.get(key, 0) + got[key]
			any = any or got[key] > 0
		task["money"] = any
	var hideout: Node = task.get("hideout")
	return hideout.flush() if hideout != null else []


## Prova à vista agora: itens soltos (ninguém segurando) do tipo que eles levam, e sacos de lixo
## abertos com dinheiro dentro.
func visible_evidence() -> Array:
	var out := []
	for item in _kitnet.items.items.values():
		if item.holder != 0:
			continue
		if item.kind in EVIDENCE:
			out.append(item)
		elif item.kind == "trashbag" and item.data.get("open", false) and not item.data.get("contents", []).is_empty():
			out.append(item)
	return out


## O jogador `peer` já é de outro policial (perseguindo ou, com `only_holding`, algemando e
## arrastando).
func claimed(peer: int, me: Node, only_holding := false) -> bool:
	for cop in cops:
		if cop == me or not cop.active():
			continue
		if cop.dragging == peer:
			return true
		if cop.target == peer and (not only_holding or cop.state in [Cop.State.CUFF, Cop.State.DRAG]):
			return true
	return false


## A prova `item` já está na lista (ou nas mãos) de outro policial.
func claimed_item(item: Node, me: Node) -> bool:
	for cop in cops:
		if cop != me and cop.has_task_item(item):
			return true
	return false


## Host: o policial pegou a prova `item`.
func seize_item(item: Node) -> void:
	var got := _count(item.kind, item.data)
	for key in got:
		_taken[key] = _taken.get(key, 0) + got[key]
	if item.kind == "trashbag":
		_kitnet.items.set_data(item, "contents", [])
	else:
		_kitnet.items.consume(item)


## Quanto vale como prova um item (ou o que está dentro de um saco aberto).
static func _count(kind: String, data: Dictionary) -> Dictionary:
	var got := {"sheets": 0, "bills": 0, "bundles": 0}
	match kind:
		"sheet":
			got["sheets"] = 1
		"bills":
			got["bills"] = int(data.get("count", 1))
		"bundle":
			got["bundles"] = 1
		"trashbag":
			if data.get("open", false):
				for entry: Array in data.get("contents", []):
					var inner := _count(entry[0], entry[1])
					for key in inner:
						got[key] += inner[key]
	return got


## Host: leva toda prova à vista (até na mão de quem não está escondido) e o que estiver na
## guilhotina, na máquina de lavar e na contadora. Devolve o que levou.
func seize_visible() -> Dictionary:
	var taken := {"sheets": 0, "bills": 0, "bundles": 0}
	for item in _kitnet.items.items.values().duplicate():
		if item.holder != 0:
			var holder: Node = _kitnet.players.get(item.holder)
			if holder != null and holder.get("hiding_spot") != null:
				continue
		var counts_as: bool = item.kind in EVIDENCE or (item.kind == "trashbag" and item.data.get("open", false))
		if not counts_as:
			continue
		var got := _count(item.kind, item.data)
		for key in got:
			taken[key] += got[key]
		if item.kind == "trashbag":
			_kitnet.items.set_data(item, "contents", [])
		else:
			_kitnet.items.consume(item)
	for station in [_kitnet.guillotine, _kitnet.washer, _kitnet.cash_counter]:
		if station != null and station.has_method("confiscate"):
			var got: Dictionary = station.confiscate()
			for key in got:
				taken[key] = taken.get(key, 0) + got[key]
	return taken


## Host: o policial chegou na escada arrastando `peer`: preso até a batida acabar.
func jail(peer: int) -> void:
	var player: Node = _kitnet.players.get(peer)
	if player == null:
		return
	if peer not in jailed:
		jailed.append(peer)
		_taken["arrests"] = _taken.get("arrests", 0) + 1
	player.set_arrest("jailed", null, JAIL)


## Para o teste: acaba com tudo na hora (sem batida, sem multa).
func cancel() -> void:
	time_left = -1.0
	_kitnet.rpc_roster(self, &"_set_time", [-1.0, ""])
	if raiding:
		for cop in cops:
			cop.leave(STAIRS)
			cop._gone()
		_leaving = true


func drop_peer(peer: int) -> void:
	jailed.erase(peer)


func send_state_to(peer: int) -> void:
	_set_time.rpc_id(peer, time_left, "", {}, raiding)


@rpc("authority", "call_remote", "reliable")
func _set_time(left: float, event: String, result := {}, is_raiding := false) -> void:
	time_left = left
	var me: Node = _kitnet.local_player()
	match event:
		"":
			raiding = is_raiding
		"called":
			if me != null:
				me.hud.show_message("The neighbor called the cops!\nYou have %d seconds. Hide the money!" % int(RAID_DELAY), 5.0)
		"arrive":
			raiding = true
			_flash_left = RAID_MAX
			if me != null:
				me.kick_camera(0.5)
				me.hud.show_message("POLICE! OPEN UP!\nHide (wardrobe, shower, sofa bed, window ledge) or run!", 5.0)
		"raid":
			raiding = false
			last_raid = result
			_flash_left = LIGHTS_AFTER
			if me != null:
				me.kick_camera(0.4)
				me.hud.show_message(_raid_text(result), 7.0)


static func _raid_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	if result.get("sheets", 0) > 0:
		parts.append("%d sheet%s" % [result["sheets"], "" if result["sheets"] == 1 else "s"])
	if result.get("bills", 0) > 0:
		parts.append("%d bill%s" % [result["bills"], "" if result["bills"] == 1 else "s"])
	if result.get("bundles", 0) > 0:
		parts.append("%d bundle%s" % [result["bundles"], "" if result["bundles"] == 1 else "s"])
	var arrests: int = result.get("arrests", 0)
	var lines: Array[String] = ["The police left."]
	if parts.is_empty():
		lines.append("They found no money. \"Sorry for the trouble, sir.\"")
	else:
		lines.append("They took %s." % ", ".join(parts))
	if arrests > 0:
		lines.append("%d arrested (bail $%d each)." % [arrests, BAIL])
	if result.get("fine", 0) > 0:
		lines.append("Total paid: $%d." % result["fine"])
	return "\n".join(lines)


func _process(delta: float) -> void:
	_time += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	if raiding:
		_flash_left = maxf(_flash_left, 1.0)
	# A sirene vai chegando (mais alta perto do fim), toca durante a batida e some depois.
	var siren := 0.0
	if time_left >= 0.0 and time_left < SIREN_AT:
		siren = 1.0 - time_left / SIREN_AT
	elif raiding:
		siren = 0.35
	elif _flash_left > 0.0:
		siren = _flash_left / LIGHTS_AFTER
	if siren > 0.0:
		_siren.volume_db = linear_to_db(0.08 + 0.6 * siren)
		if not _siren.playing:
			_siren.play()
	elif _siren.playing:
		_siren.stop()
	var flashing := _flash_left > 0.0 or (time_left >= 0.0 and time_left < LIGHTS_AT)
	for i in _lights.size():
		var light := _lights[i]
		if not flashing:
			light.light_energy = 0.0
			continue
		var red := fmod(_time * 3.0 + i * 0.5, 1.0) < 0.5
		light.light_color = Color(1.0, 0.1, 0.1) if red else Color(0.15, 0.3, 1.0)
		light.light_energy = 1.1


## A sirene "uóóó-iii" (sobe e desce), em loop.
static func _siren_sound() -> AudioStreamWAV:
	const RATE := 22050
	const LENGTH := 2.0
	var n := int(RATE * LENGTH)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var freq := 650.0 + 350.0 * (0.5 - 0.5 * cos(TAU * t / LENGTH))
		phase += TAU * freq / RATE
		var s := sin(phase) * 0.5 + sin(phase * 2.0) * 0.15 + sin(phase * 3.0) * 0.08
		data.encode_s16(i * 2, int(s * 14000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav
