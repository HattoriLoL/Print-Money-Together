extends Node
## A polícia (nó "Police" do mapa): o vizinho do 303 ligou (neighbor.gd, call_cops) e a viatura
## chega RAID_DELAY segundos depois. A sirene vai chegando (SIREN_AT antes) e as luzes vermelha e
## azul piscam pela janela e pelo corredor.
##
## Na batida, a 301 abre à força (trancada ou não) e eles levam tudo que é prova e está à vista:
## folhas, notas e maços (até na mão de alguém), o que estiver na guilhotina, na máquina de lavar e
## na contadora (`confiscate()` de cada uma). O que estiver num esconderijo (stash.gd) fica. E o
## caixa paga a multa (FINE, ou o que tiver). A partida continua.
##
## O host conta o tempo e repassa; todo mundo ouve a sirene e lê a contagem no HUD.

const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const RAID_DELAY := 30.0
## A sirene começa a chegar a isso do fim (s), e as luzes piscam nos últimos LIGHTS_AT e depois da
## batida (LIGHTS_AFTER).
const SIREN_AT := 18.0
const LIGHTS_AT := 6.0
const LIGHTS_AFTER := 8.0
const FINE := 100
## Tipos de item que a polícia leva.
const EVIDENCE := ["sheet", "bills", "bundle"]
## Luzes da viatura: lá fora, na frente da janela principal, e no corredor (Godot).
const LIGHT_SPOTS := [Vector3(2.5, 2.0, -6.5), Vector3(4.1, 2.0, 0.85)]

## Segundos até a batida (negativo = ninguém vindo).
var time_left := -1.0
## O que levaram na última batida (para o teste): {"sheets", "bills", "bundles", "fine"}.
var last_raid := {}

var _kitnet: Node
var _siren: AudioStreamPlayer
var _lights: Array[OmniLight3D] = []
var _flash_left := 0.0
var _time := 0.0


func _ready() -> void:
	name = "Police"
	add_to_group("station")
	_kitnet = get_parent()
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


func coming() -> bool:
	return time_left >= 0.0


## Texto do HUD ("" = nada acontecendo).
func alert_text() -> String:
	if coming():
		return "POLICE ON THE WAY: %ds  ·  Hide everything!" % ceili(time_left)
	return ""


## Host: o vizinho ligou.
func call_cops() -> void:
	if coming():
		return
	_set_time(RAID_DELAY, "called")
	_kitnet.rpc_roster(self, &"_set_time", [RAID_DELAY, "called"])


func _physics_process(delta: float) -> void:
	if not coming() or not multiplayer.is_server():
		return
	time_left -= delta
	if time_left <= 0.0:
		var result := raid()
		_set_time(-1.0, "raid", result)
		_kitnet.rpc_roster(self, &"_set_time", [-1.0, "raid", result])


## Host: a batida. Leva a prova à vista e cobra a multa; devolve o que levou.
func raid() -> Dictionary:
	var door: Node = _kitnet.doors.get("301")
	if door != null:
		door.set_locked(false)
		door.set_open(true)
	var taken := {"sheets": 0, "bills": 0, "bundles": 0}
	for item in _kitnet.items.items.values().duplicate():
		if item.kind not in EVIDENCE:
			continue
		match item.kind:
			"sheet":
				taken["sheets"] += 1
			"bills":
				taken["bills"] += int(item.data.get("count", 1))
			"bundle":
				taken["bundles"] += 1
		_kitnet.items.consume(item)
	for station in [_kitnet.guillotine, _kitnet.washer, _kitnet.cash_counter]:
		if station != null and station.has_method("confiscate"):
			var got: Dictionary = station.confiscate()
			for key in got:
				taken[key] = taken.get(key, 0) + got[key]
	var found: bool = taken["sheets"] + taken["bills"] + taken["bundles"] > 0
	var fine := mini(FINE, _kitnet.wallet.cash) if found else 0
	if fine > 0:
		_kitnet.wallet.spend(fine)
	taken["fine"] = fine
	last_raid = taken
	return taken


func send_state_to(peer: int) -> void:
	_set_time.rpc_id(peer, time_left, "")


@rpc("authority", "call_remote", "reliable")
func _set_time(left: float, event: String, result := {}) -> void:
	time_left = left
	var me: Node = _kitnet.local_player()
	match event:
		"called":
			if me != null:
				me.hud.show_message("The neighbor called the cops!\nYou have %d seconds. Hide the money!" % int(RAID_DELAY), 5.0)
		"raid":
			last_raid = result
			_flash_left = LIGHTS_AFTER
			if me != null:
				me.kick_camera(0.8)
				me.hud.show_message(_raid_text(result), 7.0)


static func _raid_text(result: Dictionary) -> String:
	var parts: Array[String] = []
	if result.get("sheets", 0) > 0:
		parts.append("%d sheet%s" % [result["sheets"], "" if result["sheets"] == 1 else "s"])
	if result.get("bills", 0) > 0:
		parts.append("%d bill%s" % [result["bills"], "" if result["bills"] == 1 else "s"])
	if result.get("bundles", 0) > 0:
		parts.append("%d bundle%s" % [result["bundles"], "" if result["bundles"] == 1 else "s"])
	if parts.is_empty():
		return "POLICE! OPEN UP!\n...They found nothing. \"Sorry for the trouble, sir.\""
	return "POLICE! OPEN UP!\nThey took %s.\nFine: $%d." % [", ".join(parts), result.get("fine", 0)]


func _process(delta: float) -> void:
	_time += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	# A sirene vai chegando (mais alta perto do fim) e some depois da batida.
	var siren := 0.0
	if coming() and time_left < SIREN_AT:
		siren = 1.0 - time_left / SIREN_AT
	elif _flash_left > 0.0:
		siren = _flash_left / LIGHTS_AFTER
	if siren > 0.0:
		_siren.volume_db = linear_to_db(0.08 + 0.6 * siren)
		if not _siren.playing:
			_siren.play()
	elif _siren.playing:
		_siren.stop()
	var flashing := _flash_left > 0.0 or (coming() and time_left < LIGHTS_AT)
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
