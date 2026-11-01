extends Node
## A luz da kitnet 301: o quadro de luz ao lado da porta (KEEP_Breaker do modelo), com o disjuntor
## geral.
##
## Consumo agora: `BASE_WATTS` (geladeira, luzes e TV) mais o `power_draw()` de cada nó do grupo
## "powered" (impressora, ventilador, máquina de lavar, contadora e PC). Passou de `LIMIT_WATTS`,
## o disjuntor esquenta: as luzes tremem e o quadro zumbe. Com `TRIP_SECONDS` de sobrecarga, ele
## cai. Sem luz:
##   - as luzes da kitnet apagam (as do corredor são do prédio e ficam), e a TV e o PC também;
##   - a impressora desliga de vez (perde o aquecimento) e quem está no PC sai;
##   - a máquina de lavar e a contadora param onde estavam e voltam sozinhas com a luz;
##   - o ventilador para, mas o botão continua ligado.
## Cada nó "powered" pode ter `power_lost()`, chamado no host quando a luz cai.
##
##   Quadro de luz   [E] religa o disjuntor (com a sobrecarga ainda lá, ele cai de novo) ou desliga
##                   a luz de propósito.
##
## O host decide e repassa para todos.

const InteractZone := preload("res://scripts/interact_zone.gd")

## Até quanto o disjuntor aguenta (W).
const LIMIT_WATTS := 2000.0
## O que fica ligado sempre: geladeira 150, as quatro luzes 150 e a TV 100.
const BASE_WATTS := 400.0
## Segundos de sobrecarga até cair.
const TRIP_SECONDS := 3.0
## Abaixo do limite, a sobrecarga esfria nesse ritmo (por segundo).
const COOL_RATE := 0.5
const SYNC_RATE := 10.0
## A alavanca vermelha do disjuntor geral: quanto ela sobe ou desce (m) e o tamanho.
const LEVER_TRAVEL := 0.012
const LEVER_SIZE := Vector3(0.035, 0.05, 0.025)

## O disjuntor está desligado (caiu ou alguém desligou).
var tripped := false
## Consumo agora (W). O host calcula e repassa.
var load_watts := 0.0
## Sobrecarga acumulada, de 0 a TRIP_SECONDS.
var heat := 0.0
var zone: Area3D

var _kitnet: Node
var _lever: MeshInstance3D
var _lever_rest := Vector3.ZERO
var _sync_timer := 0.0
var _clack: AudioStreamPlayer3D
var _buzz: AudioStreamPlayer3D


func _ready() -> void:
	name = "Power"
	add_to_group("station")
	_kitnet = get_parent()


## Monta a zona de [E], a alavanca e os sons no quadro de luz do modelo.
func attach(model: Node3D) -> void:
	var panel: MeshInstance3D = model.find_child("KEEP_Breaker", true, false)
	if panel == null:
		return
	var box: AABB = panel.global_transform * panel.mesh.get_aabb()
	var center := box.get_center()
	# A frente do quadro é o lado de dentro da kitnet (-Z): a parede da porta fica em z 0.
	var front := box.position.z
	zone = InteractZone.new()
	zone.setup(_kitnet, "Zone_Breaker", Vector3(center.x, center.y, front + 0.02), box.size + Vector3(0.1, 0.1, 0.1))
	zone.prompt_fn = _prompt
	zone.press_fn = _press
	_lever = MeshInstance3D.new()
	_lever.name = "Breaker_Main"
	var mesh := BoxMesh.new()
	mesh.size = LEVER_SIZE
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.12, 0.1)
	red.roughness = 0.5
	mesh.material = red
	_lever.mesh = mesh
	_lever_rest = Vector3(center.x, box.position.y + 0.08, front - LEVER_SIZE.z / 2.0)
	_kitnet.add_child(_lever)
	_lever.global_position = _lever_rest
	_build_sounds()


## Tem luz na kitnet agora.
func has_power() -> bool:
	return not tripped


## Quanto as luzes da kitnet brilham agora (1 = normal): tremem com a sobrecarga e apagam sem luz.
func light_level() -> float:
	if not has_power():
		return 0.0
	var strain := heat / TRIP_SECONDS
	if strain <= 0.0:
		return 1.0
	var t := Time.get_ticks_msec() / 1000.0
	var dip := clampf(0.5 + 0.5 * sin(t * 31.0) * sin(t * 7.3 + 1.0) + 0.3 * sin(t * 53.0), 0.0, 1.0)
	# Já treme bem no começo (para dar tempo de reagir) e piora até cair.
	return 1.0 - (0.35 + 0.55 * strain) * dip


## Consumo agora (W) se a luz estiver ligada: a base mais cada aparelho.
func measure() -> float:
	var total := BASE_WATTS
	for node in get_tree().get_nodes_in_group("powered"):
		total += node.power_draw()
	return total


# --- Host -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_visuals()
	if not multiplayer.is_server():
		return
	var was_strained := heat > 0.0
	load_watts = measure() if has_power() else 0.0
	if load_watts > LIMIT_WATTS:
		heat += delta
		if not was_strained:
			_send_state("strain")
		if heat >= TRIP_SECONDS:
			_switch_off("trip")
			return
	elif heat > 0.0:
		heat = maxf(0.0, heat - delta * COOL_RATE)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 1.0 / SYNC_RATE
		_kitnet.rpc_roster(self, &"_meter", [load_watts, heat])


## Host: o disjuntor cai ("trip") ou alguém desliga no quadro ("off").
func _switch_off(event: String) -> void:
	if tripped:
		return
	tripped = true
	heat = 0.0
	_lose_power()
	_send_state(event)


func _lose_power() -> void:
	load_watts = 0.0
	for node in get_tree().get_nodes_in_group("powered"):
		if node.has_method("power_lost"):
			node.power_lost()


## [E] no quadro: religa o disjuntor ou desliga a luz.
func _press(_peer: int) -> void:
	if tripped:
		tripped = false
		heat = 0.0
		_send_state("reset")
	else:
		_switch_off("off")


func _send_state(event := "") -> void:
	_kitnet.rpc_roster(self, &"_state", [tripped, load_watts, heat, event])
	_on_event(event)


func send_state_to(peer: int) -> void:
	_state.rpc_id(peer, tripped, load_watts, heat, "")


@rpc("authority", "call_remote", "unreliable_ordered")
func _meter(watts: float, h: float) -> void:
	load_watts = watts
	heat = h


@rpc("authority", "call_remote", "reliable")
func _state(off: bool, watts: float, h: float, event: String) -> void:
	tripped = off
	_meter(watts, h)
	_on_event(event)


# --- O que cada jogador vê e ouve -------------------------------------------------------------

func _on_event(event: String) -> void:
	if event in ["trip", "off", "reset"] and _clack != null:
		_clack.pitch_scale = 0.8 if event == "trip" else 1.0
		_clack.play()
	var me: Node = _kitnet.local_player()
	if me == null:
		return
	match event:
		"strain":
			me.hud.show_hint("The lights are flickering: too much is running at once!", 4.0)
		"trip":
			me.hud.show_message("The breaker tripped! Too much running at once.\nFlip it back on at the panel by the door.", 5.0)
		"off":
			me.hud.show_message("Someone switched the power off.", 3.0)
		"reset":
			me.hud.show_message("Power's back.", 2.0)


func _prompt(_player: Node) -> String:
	if tripped:
		return "[E] Flip the breaker back on"
	return "[E] Switch the power off (%.1f of %.1f kW in use)" % [load_watts / 1000.0, LIMIT_WATTS / 1000.0]


func _update_visuals() -> void:
	if _lever != null:
		var up := not tripped
		var shake := Vector3.ZERO
		if heat > 0.0:
			var t := Time.get_ticks_msec() / 1000.0
			shake = Vector3(sin(t * 90.0), 0.0, 0.0) * 0.0015 * heat / TRIP_SECONDS
		_lever.global_position = _lever_rest + Vector3.UP * (LEVER_TRAVEL if up else -LEVER_TRAVEL) + shake
	if _buzz != null:
		var strain := heat / TRIP_SECONDS
		if strain > 0.0 and has_power():
			_buzz.volume_db = linear_to_db(clampf(0.25 + strain, 0.0, 1.0))
			if not _buzz.playing:
				_buzz.play()
		elif _buzz.playing:
			_buzz.stop()


func _build_sounds() -> void:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 1450
	# Clique seco da alavanca: um estalo de ruído e uma pancada grave no quadro.
	var clack := PackedFloat32Array()
	for i in int(RATE * 0.25):
		var t := float(i) / RATE
		clack.append(0.8 * exp(-t * 90.0) * rng.randf_range(-1.0, 1.0) + 0.6 * exp(-t * 25.0) * sin(TAU * 140.0 * t))
	# Zumbido do quadro sobrecarregado (loop de 1 s): 60 Hz com harmônicos e um chiado.
	var buzz := PackedFloat32Array()
	for i in RATE:
		var t := float(i) / RATE
		buzz.append(0.3 * sin(TAU * 120.0 * t) + 0.18 * signf(sin(TAU * 60.0 * t)) + 0.08 * rng.randf_range(-1.0, 1.0))
	_clack = _player("Clack", _wav(clack, RATE, false))
	_buzz = _player("Buzz", _wav(buzz, RATE, true))


func _player(player_name: String, stream: AudioStream) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = player_name
	p.stream = stream
	p.unit_size = 3.0
	_kitnet.add_child(p)
	p.global_position = _lever_rest
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
