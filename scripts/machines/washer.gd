extends Node3D
## Máquina de lavar do serviço, de abertura em cima (filha do MACHINE_Washer do kitnet.glb; o
## referencial é o do modelo, com a frente para +Z). Nota recém-impressa é lisinha demais e
## denuncia: lavada, ela sai desbotada e vincada, com cara de nota que já rodou
## (`data.worn`; ver ItemKinds.value).
##
##   Tampa                [E] abre ou fecha (trava enquanto lava).
##   Cesto (tampa aberta) [E] com um montinho na mão: põe dentro (até LOAD_MAX); de mão vazia,
##                        tira o último que entrou.
##   Botão do timer       [E] com a tampa fechada e notas dentro: lava (WASH_SECONDS) e
##                        centrifuga (SPIN_SECONDS). No fim apita, e as notas saem usadas.
##   Gabinete             Segurar [E]: centrifugando, segura a máquina parada; parada fora do
##                        lugar, empurra de volta.
##
## Centrifugando, a máquina treme e, se ninguém segura, sai andando pela área de serviço (mais
## rápido com a carga desequilibrada: número ímpar de montinhos), até onde a mangueira deixa
## (HOSE_LENGTH). Segurada, faz menos barulho. Os sons são feitos aqui mesmo.
##
## O host manda no estado e repassa para todos (10 vezes por segundo enquanto muda, e na hora
## nos eventos). Quem entra depois recebe tudo em send_state_to.

const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Toon := preload("res://scripts/toon.gd")

enum Phase { IDLE, WASH, SPIN }

const LOAD_MAX := 6
const WASH_SECONDS := 15.0
const SPIN_SECONDS := 10.0
## Cesto (art_source/blender/machines.py, WASHER_DRUM; y do Blender = -z): centro, altura do
## fundo e o raio onde os montinhos ficam deitados.
const DRUM_CENTER := Vector3(0.0, 0.51, 0.05)
const DRUM_PILE_RADIUS := 0.14
## Quanto a tampa gira para abrir (rad; quase em pé, sem bater no painel).
const LID_OPEN := 1.5
const LID_SPEED := 6.0
## Andando: velocidade com a carga desequilibrada (m/s), quanto anda com ela equilibrada (fração)
## e até onde a mangueira deixa.
const WALK_SPEED := 0.05
const BALANCED_WALK := 0.35
const HOSE_LENGTH := 0.45
## Empurrando de volta (m/s).
const PUSH_SPEED := 0.3
## Tremor (m): lavando, centrifugando solta e segurada.
const SHAKE_WASH := 0.0012
const SHAKE_SPIN := 0.004
const SHAKE_HELD := 0.0012
## Barulho de 0 a 1 (a suspeita dos vizinhos, depois).
const NOISE_WASH := 0.25
const NOISE_SPIN := 0.55
const NOISE_HELD := 0.3
## A cada quanto a máquina bate no chão andando (s).
const THUMP_EVERY := 0.42
const SYNC_RATE := 10.0

var phase := Phase.IDLE
## Segundos que faltam da fase.
var time_left := 0.0
var lid_open := false
## Os montinhos dentro, na ordem em que entraram (os dados de cada um).
var contents: Array = []
## Quanto a máquina andou desde o lugar dela (referencial do modelo, no chão).
var offset := Vector3.ZERO
## Alguém está segurando o gabinete.
var steadied := false

var lid_zone: Area3D
var drum_zone: Area3D
var panel_zone: Area3D
var body_zone: Area3D

var _kitnet: Node
var _body: Node3D
var _home: Transform3D
var _lid: Node3D
var _lid_angle := 0.0
var _knob: Node3D
var _led: MeshInstance3D
var _led_off: StandardMaterial3D
var _screen: Label3D
var _piles: Node3D
var _shown_offset := Vector3.ZERO
var _walk_time := 0.0
var _sync_timer := 0.0
var _dirty := false
var _done_time := -10.0
var _thump_timer := 0.0
var _hum: AudioStreamPlayer3D
var _thump: AudioStreamPlayer3D
var _beep: AudioStreamPlayer3D
var _wash_sound: AudioStreamWAV
var _spin_sound: AudioStreamWAV


func _ready() -> void:
	name = "Washer"
	add_to_group("station")
	add_to_group("noise_source")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	_body = get_parent()
	_home = _body.transform
	_lid = _body.find_child("MACHINE_Washer_Lid", false, false)
	_knob = _body.find_child("MACHINE_Washer_Knob", false, false)
	_led = _body.find_child("MACHINE_Washer_Led", false, false)
	_led_off = StandardMaterial3D.new()
	_led_off.albedo_color = Color(0.25, 0.08, 0.06)
	_led_off.roughness = 0.3

	# A zona da tampa vai junto com ela: fechada, cobre o cesto; aberta, fica em pé atrás.
	lid_zone = InteractZone.new()
	lid_zone.setup(_lid if _lid else self, "Zone_Lid", Vector3(0.0, 0.02, 0.25), Vector3(0.62, 0.07, 0.52))
	lid_zone.prompt_fn = _lid_prompt
	lid_zone.press_fn = _toggle_lid
	drum_zone = InteractZone.new()
	drum_zone.setup(self, "Zone_Drum", Vector3(0.0, 0.74, 0.05), Vector3(0.4, 0.26, 0.4))
	drum_zone.prompt_fn = _drum_prompt
	drum_zone.press_fn = _use_drum
	panel_zone = InteractZone.new()
	panel_zone.setup(self, "Zone_Panel", Vector3(0.0, 0.96, -0.25), Vector3(0.62, 0.17, 0.14))
	panel_zone.prompt_fn = _panel_prompt
	panel_zone.press_fn = _start
	body_zone = InteractZone.new()
	body_zone.setup(self, "Zone_Body", Vector3(0.0, 0.44, 0.0), Vector3(0.68, 0.8, 0.68), true)
	body_zone.prompt_fn = _body_prompt

	# Visor do painel, em pé e lido de frente.
	_screen = Label3D.new()
	_screen.position = Vector3(-0.13, 0.965, -0.177)
	_screen.pixel_size = 0.0004
	_screen.font_size = 40
	_screen.outline_size = 0
	_screen.modulate = Color(0.02, 0.1, 0.05)
	add_child(_screen)

	# Os montinhos lá dentro (só aparência), deitados em roda no fundo do cesto.
	_piles = Node3D.new()
	_piles.name = "Piles"
	_piles.position = DRUM_CENTER
	add_child(_piles)

	_build_sounds()


func running() -> bool:
	return phase != Phase.IDLE


## Barulho agora, de 0 a 1.
func noise() -> float:
	match phase:
		Phase.WASH:
			return NOISE_WASH
		Phase.SPIN:
			return NOISE_HELD if steadied else NOISE_SPIN
	return 0.0


## Desequilibrada: número ímpar de montinhos (anda bem mais rápido).
func unbalanced() -> bool:
	return contents.size() % 2 == 1


func walking() -> bool:
	return phase == Phase.SPIN and not steadied


# --- Host -------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
	_update_visuals(delta)


func _server_tick(delta: float) -> void:
	var held: bool = not body_zone.holders.is_empty()
	if held != steadied:
		steadied = held
		_dirty = true
	match phase:
		Phase.WASH:
			time_left -= delta
			_dirty = true
			if time_left <= 0.0:
				phase = Phase.SPIN
				time_left = SPIN_SECONDS
				_send_now()
		Phase.SPIN:
			time_left -= delta
			_dirty = true
			if not steadied:
				_walk(delta)
			if time_left <= 0.0:
				_finish()
		Phase.IDLE:
			if steadied and offset.length() > 0.0:
				offset = offset.move_toward(Vector3.ZERO, PUSH_SPEED * delta)
				_dirty = true
	_sync_timer -= delta
	if _dirty and _sync_timer <= 0.0:
		_sync_timer = 1.0 / SYNC_RATE
		_dirty = false
		_kitnet.rpc_roster(self, &"_sync", [time_left, offset, steadied])


## Anda para a frente (para longe da parede), costurando para os lados, até onde a mangueira deixa.
func _walk(delta: float) -> void:
	_walk_time += delta
	var front := _home.basis * Vector3.BACK
	var side := _home.basis * Vector3.RIGHT
	var dir := (front + side * sin(_walk_time * 1.7) * 0.9).normalized()
	var speed := WALK_SPEED * (1.0 if unbalanced() else BALANCED_WALK)
	offset = (offset + dir * speed * delta).limit_length(HOSE_LENGTH)
	offset.y = 0.0


func _toggle_lid(_peer: int) -> void:
	if running():
		return
	lid_open = not lid_open
	_send_now("lid")


## [E] no cesto: põe o montinho da mão ou tira o último que entrou.
func _use_drum(peer: int) -> void:
	if not lid_open or running():
		return
	var held: Node = _kitnet.items.held_by(peer)
	if held != null:
		if held.kind != "bills" or contents.size() >= LOAD_MAX:
			return
		var data: Dictionary = held.data.duplicate(true)
		data.erase("resting")
		_kitnet.items.consume(held)
		contents.append(data)
	elif not contents.is_empty():
		_kitnet.items.give(peer, "bills", contents.pop_back())
	else:
		return
	_send_now()


## [E] no botão: com a tampa fechada e notas dentro, começa a lavar.
func _start(_peer: int) -> void:
	if running() or lid_open or contents.is_empty():
		return
	phase = Phase.WASH
	time_left = WASH_SECONDS
	_walk_time = 0.0
	_send_now("press")


## Fim da centrifugação: as notas saem usadas.
func _finish() -> void:
	for data: Dictionary in contents:
		data["worn"] = data.get("count", 0)
		data["top_worn"] = true
	phase = Phase.IDLE
	time_left = 0.0
	_send_now("done")


func _send_now(event := "") -> void:
	_kitnet.rpc_roster(self, &"_sync_full", [phase, time_left, lid_open, contents, offset, steadied, event])
	_on_event(event)


func send_state_to(peer: int) -> void:
	_sync_full.rpc_id(peer, phase, time_left, lid_open, contents, offset, steadied, "")


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(t: float, off: Vector3, held: bool) -> void:
	time_left = t
	offset = off
	steadied = held


@rpc("authority", "call_remote", "reliable")
func _sync_full(ph: int, t: float, open: bool, inside: Array, off: Vector3, held: bool, event: String) -> void:
	phase = ph as Phase
	_sync(t, off, held)
	lid_open = open
	contents = inside
	_on_event(event)


# --- O que cada jogador vê e ouve -------------------------------------------------------------

func _on_event(event: String) -> void:
	_rebuild_piles()
	match event:
		"lid":
			_thump.pitch_scale = 1.9
			_thump.play()
		"press":
			_thump.pitch_scale = 2.6
			_thump.play()
		"done":
			_done_time = Time.get_ticks_msec() / 1000.0
			_beep.play()


func _lid_prompt(_player: Node) -> String:
	if running():
		return "The lid is locked until the wash ends"
	return "[E] Close the lid" if lid_open else "[E] Open the lid"


func _drum_prompt(player: Node) -> String:
	if not lid_open or running():
		return ""
	var held: Node = player.held_item()
	if held != null:
		if held.kind != "bills":
			return "Only bills go in the washer"
		if contents.size() >= LOAD_MAX:
			return "The washer is full (%d/%d)" % [contents.size(), LOAD_MAX]
		return "[E] Put the bills in (%d/%d inside)" % [contents.size(), LOAD_MAX]
	if contents.is_empty():
		return "Put bills in here to make them look used"
	return "[E] Take out the %s" % ItemKinds.label_of("bills", contents[-1])


func _panel_prompt(_player: Node) -> String:
	match phase:
		Phase.WASH:
			return "Washing... %s" % _clock(time_left + SPIN_SECONDS)
		Phase.SPIN:
			return "Spinning... %s" % _clock(time_left)
	if lid_open:
		return "Close the lid to start"
	if contents.is_empty():
		return "Put bills in to wash them"
	return "[E] Start the wash (%s)" % _clock(WASH_SECONDS + SPIN_SECONDS)


func _body_prompt(_player: Node) -> String:
	if phase == Phase.SPIN:
		return "Hold [E] to hold the washer still"
	if not running() and offset.length() > 0.02:
		return "Hold [E] to push the washer back"
	return ""


static func _clock(seconds: float) -> String:
	var s := ceili(maxf(seconds, 0.0))
	return "%d:%02d" % [s / 60, s % 60]


func _update_visuals(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# A máquina no lugar (mais o quanto andou) e tremendo.
	_shown_offset = _shown_offset.lerp(offset, clampf(delta * 12.0, 0.0, 1.0))
	var amp := 0.0
	match phase:
		Phase.WASH:
			amp = SHAKE_WASH
		Phase.SPIN:
			amp = SHAKE_HELD if steadied else SHAKE_SPIN
	var shake := Vector3(sin(now * 37.0), 0.0, sin(now * 43.0 + 1.0)) * amp
	var tilt := Basis.from_euler(Vector3(sin(now * 29.0) * amp * 3.0, 0.0, sin(now * 33.0 + 2.0) * amp * 3.0))
	_body.transform = Transform3D(_home.basis * tilt, _home.origin + _shown_offset + shake)

	# A tampa abre e fecha devagar.
	_lid_angle = move_toward(_lid_angle, LID_OPEN if lid_open else 0.0, delta * LID_SPEED)
	if _lid:
		_lid.rotation.x = -_lid_angle

	# O cesto: lavando, os montinhos vão e voltam; centrifugando, giram rápido.
	match phase:
		Phase.WASH:
			_piles.rotation.y = sin(now * 5.0) * 0.9
		Phase.SPIN:
			var spin_up := clampf((SPIN_SECONDS - time_left) / 2.0, 0.0, 1.0)
			_piles.rotation.y += delta * 25.0 * spin_up

	# Botão do timer: volta para o zero enquanto lava.
	if _knob:
		var total := WASH_SECONDS + SPIN_SECONDS
		var left := time_left + (SPIN_SECONDS if phase == Phase.WASH else 0.0)
		_knob.rotation.z = -TAU * 0.8 * (left / total if running() else 0.0)
	if _led:
		var lit := running() or (now - _done_time < 3.0 and int(now * 3.0) % 2 == 0)
		_led.material_override = null if lit else Toon.material(_led_off)
	_screen.text = _screen_text(now)
	_update_sounds(delta)


func _screen_text(now: float) -> String:
	match phase:
		Phase.WASH:
			return "WASH %s" % _clock(time_left + SPIN_SECONDS)
		Phase.SPIN:
			return "SPIN %s" % _clock(time_left)
	if now - _done_time < 4.0:
		return "END"
	if lid_open:
		return "OPEN"
	return "READY" if not contents.is_empty() else ""


## Um montinho deitado para cada um dentro do cesto, em roda (o comprido ao longo da parede).
func _rebuild_piles() -> void:
	for child in _piles.get_children():
		child.queue_free()
	for i in contents.size():
		var data: Dictionary = contents[i]
		var count: int = maxi(data.get("count", 1), 1)
		var height := maxf(count * ItemKinds.BILL_THICKNESS, 0.0015)
		var mesh := MeshInstance3D.new()
		mesh.mesh = ItemKinds._bills_mesh(data.get("top_smudged", false), data.get("top_cut", Rect2()),
				data.get("top_offcolor", false), data.get("top_worn", false))
		# O primeiro no fundo do cesto, de lado do agitador: é o que quem está na frente enxerga.
		var a := -PI / 3.0 + i * TAU / LOAD_MAX
		mesh.position = Vector3(cos(a), 0.0, sin(a)) * DRUM_PILE_RADIUS + Vector3.UP * (height / 2.0 + 0.004 * (i % 2))
		mesh.rotation.y = -(a + PI / 2.0)
		mesh.scale = Vector3(1.0, height, 1.0)
		_piles.add_child(mesh)


# --- Sons -------------------------------------------------------------------------------------

func _update_sounds(delta: float) -> void:
	var want: AudioStreamWAV = null
	match phase:
		Phase.WASH:
			want = _wash_sound
		Phase.SPIN:
			want = _spin_sound
	if want == null:
		if _hum.playing:
			_hum.stop()
	elif _hum.stream != want or not _hum.playing:
		_hum.stream = want
		_hum.play()
	if phase == Phase.SPIN:
		# O motor acelera no começo da centrifugação.
		_hum.pitch_scale = lerpf(0.55, 1.0, clampf((SPIN_SECONDS - time_left) / 2.0, 0.0, 1.0))
		_hum.volume_db = -4.0 if steadied else 0.0
	else:
		_hum.pitch_scale = 1.0
		_hum.volume_db = -6.0
	# Andando, a máquina bate no chão.
	if walking():
		_thump_timer -= delta
		if _thump_timer <= 0.0:
			_thump_timer = THUMP_EVERY * (1.0 if unbalanced() else 1.6)
			_thump.pitch_scale = randf_range(0.85, 1.1)
			_thump.play()
	else:
		_thump_timer = 0.0


func _build_sounds() -> void:
	const RATE := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	# Lavando (2 s em loop): o motor baixinho e a água indo e voltando duas vezes.
	var wash := PackedFloat32Array()
	var low := 0.0
	for i in RATE * 2:
		var t := float(i) / RATE
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.06)
		var slosh := pow(sin(PI * t), 2.0)
		wash.append(0.16 * sin(TAU * 50.0 * t) + 0.06 * sin(TAU * 100.0 * t) + low * (0.5 + 1.4 * slosh))
	_wash_sound = _wav(wash, RATE, true)
	# Centrifugando (1 s em loop): o zumbido agudo do motor, o ronco do cesto e o vento.
	var spin := PackedFloat32Array()
	low = 0.0
	for i in RATE:
		var t := float(i) / RATE
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.25)
		spin.append(0.22 * sin(TAU * 140.0 * t) + 0.1 * sin(TAU * 280.0 * t) + 0.25 * sin(TAU * 23.0 * t)
				* (0.6 + 0.4 * sin(TAU * 4.0 * t)) + 0.25 * low)
	_spin_sound = _wav(spin, RATE, true)
	# Pancada no chão (e o clique da tampa e do botão, mais agudos).
	var thump := PackedFloat32Array()
	for i in int(RATE * 0.3):
		var t := float(i) / RATE
		thump.append(0.9 * exp(-t * 16.0) * sin(TAU * 55.0 * t) + 0.4 * exp(-t * 45.0) * rng.randf_range(-1.0, 1.0))
	# Fim: três bipes.
	var beep := PackedFloat32Array()
	for i in int(RATE * 0.95):
		var t := float(i) / RATE
		var k := fmod(t, 0.32)
		beep.append(0.5 * sin(TAU * 1100.0 * t) if k < 0.18 else 0.0)
	_hum = _player("Hum", null, 4.0)
	_thump = _player("Thump", _wav(thump, RATE, false), 5.0)
	_beep = _player("Beep", _wav(beep, RATE, false), 4.0)


func _player(player_name: String, stream: AudioStream, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = player_name
	p.stream = stream
	p.unit_size = unit_size
	p.position = Vector3(0.0, 0.6, 0.0)
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
