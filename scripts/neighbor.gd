extends CharacterBody3D
## O vizinho do 303 (nó "Neighbor" do mapa): um senhor de roupão e bobes que não aguenta barulho.
## Usa o mesmo boneco dos jogadores (character_rig.gd), com o acessório Acc_Neighbor.
##
## Paciência: o host soma o barulho das máquinas (grupo "noise_source", `noise()`); acima de
## QUIET, a irritação dele sobe (mais rápido a cada visita que já fez) e, em silêncio, desce
## devagar. No meio do caminho ele bate na parede (BANG_AT) e grita (YELL_AT); cheia, ele vem:
##   1. sai do 303 e bate na 301 (KNOCKS vezes). Alguém abre: reclama, e olha para dentro pela
##      porta aberta. Ninguém abre e a porta está trancada (door.gd): ameaça e volta para casa.
##      Destrancada: ele entra e olha em volta.
##   2. Viu prova (`_sees_evidence`: notas, folhas e maços à vista, a impressora imprimindo, a
##      contadora ou a guilhotina com dinheiro): grita e corre para o capacho dele ligando para a
##      polícia (CALL_TIME). Completou: police.gd vem dar a batida.
##   3. Para parar: a frigideira (take_bonk, como nos jogadores) derruba ele por KO_TIME, com as
##      estrelinhas, e a ligação cai. Desmaiado, [E] arrasta pela gola (só um por vez, devagar).
##      Acorda no capacho dele: acha que sonhou e vai dormir. Em qualquer outro lugar: lembra de
##      tudo e liga de novo. Ou o suborno: um maço na mão e [E] nele, e ele não viu nada.
##
## Rede: o host decide tudo e manda posição, giro, pose, quem arrasta, a ligação e o barulho
## (_sync, 15 vezes por segundo); as falas, as batidas e o desmaio vão como eventos (_event).

const CharacterRig := preload("res://scripts/character_rig.gd")
const InteractZone := preload("res://scripts/interact_zone.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Bonk := preload("res://scripts/bonk.gd")

enum State {HOME, WALK, LEAVE, WAIT, KNOCK, COMPLAIN, INSPECT, CALL, KO}

## Pontos do corredor e da entrada (Godot; ver art_source/blender/plan.py, o +Y do Blender vira
## -Z): no vão da porta do 303, no capacho dele, na frente da 301 e logo depois da entrada.
const DOORWAY := Vector3(3.4, 0.0, 1.35)
const DOORMAT := Vector3(3.4, 0.0, 0.95)
const KNOCK_SPOT := Vector3(4.1, 0.0, 0.62)
const INSIDE := Vector3(4.1, 0.0, -0.8)
## Acordar até essa distância do capacho dele (m) é acordar "em casa".
const HOME_RADIUS := 1.1
## Roupão (cor do moletom) e a pele das mãos (no lugar das luvas amarelas).
const ROBE := Color(0.55, 0.32, 0.42)
const SKIN := Color(0.96, 0.72, 0.56)
## Andando, bravo, e correndo para ligar (m/s).
const WALK_SPEED := 1.3
const RUN_SPEED := 2.4
const TURN_SPEED := 8.0

## Barulho: abaixo disso não incomoda; quanto a irritação sobe por unidade de barulho acima
## dele (por segundo), quanto cada visita já feita acelera, e quanto desce em silêncio.
const QUIET := 0.18
const ANNOY_RATE := 0.05
const VISIT_FACTOR := 0.4
const CALM_RATE := 0.003
## Avisos de longe: bate na parede e grita.
const BANG_AT := 0.55
const YELL_AT := 0.85
## Batidas na porta: quantas vezes e de quanto em quanto tempo (s).
const KNOCKS := 3
const KNOCK_EVERY := 2.6
## Reclamando na porta (s) e olhando em volta lá dentro (s).
const COMPLAIN_TIME := 3.5
const INSPECT_TIME := 4.5
## Até onde ele enxerga (m) e o meio ângulo da vista (rad).
const SIGHT := 7.0
const SIGHT_HALF_ANGLE := 1.2
## Tipos de item que entregam o esquema.
const EVIDENCE := ["sheet", "bills", "bundle"]
## Ligação para a polícia (s) e quanto tempo ele fica desmaiado (s).
const CALL_TIME := 12.0
const KO_TIME := 20.0
## Arrastando pela gola: onde vão os quadris e o peito, na frente de quem arrasta (m), e a força.
const DRAG_HIPS := Vector2(0.95, 0.3)
const DRAG_CHEST := Vector2(0.6, 0.85)
const DRAG_PULL := 9.0
## Longe assim de quem arrasta (m), ele escapa da mão.
const DRAG_BREAK := 2.5
const SEND_RATE := 15.0

var state := State.HOME
## Desligado, a irritação não sobe (o teste desliga para as máquinas não chamarem ele no meio).
var enabled := true
## Só no host: de 0 a 1; cheia, ele vem. E quantas visitas já fez.
var annoyance := 0.0
var visits := 0
## Barulho da kitnet agora (o host soma; vai para todos, o HUD mostra).
var noise := 0.0
## Peer arrastando ele desmaiado (0 = ninguém).
var dragger := 0
## Ligando para a polícia e quanto falta (s).
var calling := false
var call_left := 0.0
## Pose dos braços: "", "hips" (mãos na cintura), "knock", "phone", "fist" (todos animam).
var pose := ""
## Só no host: viu o esquema (desmaiado, acorda lembrando).
var alarmed := false
var character: Node3D
var zone: Area3D

var _kitnet: Node
var _collision: CollisionShape3D
var _zone_shape: CollisionShape3D
var _route: Array[Vector3] = []
var _speed := WALK_SPEED
var _then := Callable()
var _timer := 0.0
var _knocks := 0
var _look_yaw := 0.0
var _banged := false
var _yelled := false
var _ko_left := 0.0
var _stuck := 0.0
var _send_timer := 0.0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _last_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _anim_time := 0.0
var _bubble: Label3D
var _bubble_tween: Tween
var _call_label: Label3D
var _phone: MeshInstance3D
var _stars: Node3D
var _stars_left := 0.0
var _knock_sound: AudioStreamPlayer3D
var _bang_sound: AudioStreamPlayer3D
var _ring_sound: AudioStreamPlayer3D


func _ready() -> void:
	name = "Neighbor"
	add_to_group("station")
	_kitnet = get_parent()
	collision_layer = 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.75
	_collision = CollisionShape3D.new()
	_collision.shape = capsule
	_collision.position.y = 0.875
	add_child(_collision)
	character = CharacterRig.new()
	character.setup(0, ROBE, "Acc_Neighbor")
	character.keep_gloves = true
	add_child(character)
	_dress()
	zone = InteractZone.new()
	zone.setup(self, "Zone_Neighbor", Vector3(0, 1.0, 0), Vector3(0.7, 1.7, 0.7))
	zone.prompt_fn = _prompt
	zone.press_fn = _press
	_zone_shape = zone.get_child(0)
	_build_labels()
	_stars = Bonk.make_stars()
	add_child(_stars)
	_build_sounds()
	global_position = DOORWAY
	_target_pos = DOORWAY
	_last_pos = DOORWAY
	_show(false)


## Mãos de pele no lugar das luvas amarelas, e o celular (aparece ligando).
func _dress() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.roughness = 0.6
	for mesh: MeshInstance3D in character.model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i)
			if mat != null and String(mat.resource_name).begins_with("M_Glove"):
				mesh.set_surface_override_material(i, skin)
	_phone = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.055, 0.13, 0.026)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.22, 0.23, 0.26)
	box.material = black
	_phone.mesh = box
	_phone.top_level = true
	_phone.visible = false
	add_child(_phone)


func _build_labels() -> void:
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 32
	_bubble.pixel_size = 0.0022
	_bubble.outline_size = 10
	_bubble.modulate = Color(1.0, 0.95, 0.8)
	_bubble.width = 620.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position.y = 2.35
	_bubble.visible = false
	add_child(_bubble)
	_call_label = Label3D.new()
	_call_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_call_label.font_size = 30
	_call_label.pixel_size = 0.002
	_call_label.outline_size = 10
	_call_label.modulate = Color(1.0, 0.35, 0.3)
	_call_label.position.y = 2.0
	_call_label.visible = false
	add_child(_call_label)


# --- Estado (todas as máquinas) -------------------------------------------------------------------

func out() -> bool:
	return state != State.HOME


func knocked_out() -> bool:
	return state == State.KO


## O jogador `peer` está arrastando ele.
func dragged_by(peer: int) -> bool:
	return dragger != 0 and dragger == peer


## Onde a pancada pega (a cabeça) e onde as estrelinhas giram.
func bonk_point() -> Vector3:
	if character.ragdolling:
		return character.ragdoll_head()
	return global_position + Vector3.UP * 1.72


## Onde quem arrasta segura (a gola): os braços do boneco dele vão até lá.
func grip_point() -> Vector3:
	return character.ragdoll_head() + Vector3.DOWN * 0.25 if character.ragdolling else bonk_point()


## Dá para subornar: está aqui incomodando (não voltando para casa nem desmaiado).
func bribable() -> bool:
	return state in [State.WALK, State.WAIT, State.KNOCK, State.COMPLAIN, State.INSPECT, State.CALL]


## Fração da ligação já feita (0 a 1).
func call_fraction() -> float:
	return 1.0 - call_left / CALL_TIME if calling else 0.0


func _show(on: bool) -> void:
	visible = on
	_collision.disabled = not on
	_zone_shape.disabled = not on


# --- Host -----------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_server_tick(delta)
		_send_state(delta)
	else:
		_follow(delta)
	if delta > 0.0:
		_velocity = (global_position - _last_pos) / delta
		if _velocity.length() > 9.0:
			_velocity = Vector3.ZERO
	_last_pos = global_position


func _server_tick(delta: float) -> void:
	noise = _total_noise()
	if calling:
		call_left -= delta
		if call_left <= 0.0:
			_call_done()
	match state:
		State.HOME:
			_tick_home(delta)
		State.WALK, State.LEAVE:
			_tick_walk(delta)
		State.WAIT:
			_timer -= delta
			if _timer <= 0.0:
				_continue()
		State.KNOCK:
			_tick_knock(delta)
		State.COMPLAIN:
			_timer -= delta
			if _sees_evidence():
				_alarm()
			elif _timer <= 0.0:
				_say("...and turn that racket OFF!")
				_go_home(true)
		State.INSPECT:
			_timer -= delta
			_look_yaw += delta
			rotation.y = _target_yaw + sin(_look_yaw * 1.7) * 1.1
			if _sees_evidence():
				_alarm()
			elif _timer <= 0.0:
				_say("Hmph. Smells like paint in here.")
				_go_home(true)
		State.CALL:
			_face(KNOCK_SPOT, delta)
		State.KO:
			_tick_ko(delta)


func _tick_home(delta: float) -> void:
	var police: Node = _kitnet.get("police")
	if not enabled or (police != null and police.coming()):
		annoyance = 0.0
		return
	if noise > QUIET:
		annoyance += (noise - QUIET) * ANNOY_RATE * (1.0 + VISIT_FACTOR * visits) * delta
	else:
		annoyance = maxf(0.0, annoyance - CALM_RATE * delta)
	if annoyance >= BANG_AT and not _banged:
		_banged = true
		_broadcast_event("bang", [])
	elif annoyance < BANG_AT - 0.15:
		_banged = false
	if annoyance >= YELL_AT and not _yelled:
		_yelled = true
		_broadcast_event("yell", [])
	elif annoyance < YELL_AT - 0.15:
		_yelled = false
	if annoyance >= 1.0:
		visit()


## Host: sai do 303 e vem bater na 301 (o teste chama direto).
func visit() -> void:
	if out():
		return
	annoyance = 1.0
	global_position = DOORWAY
	rotation.y = 0.0
	_door("303").set_open(true)
	_show(true)
	_set_pose("")
	_broadcast_event("show", [true, global_position])
	_walk([DOORMAT, KNOCK_SPOT], WALK_SPEED, _at_door)


func _at_door() -> void:
	_door("303").set_open(false)
	if _door("301").is_open:
		_say("Hello? Your door is wide open...")
		_enter()
		return
	state = State.KNOCK
	_knocks = 0
	_timer = 0.3
	_target_yaw = 0.0


func _tick_knock(delta: float) -> void:
	_face(KNOCK_SPOT + Vector3.FORWARD, delta)
	if _door("301").is_open:
		_complain()
		return
	_timer -= delta
	if pose == "knock" and _timer < KNOCK_EVERY - 0.85:
		_set_pose("hips")
	if _timer > 0.0:
		return
	if _knocks < KNOCKS:
		_knocks += 1
		_set_pose("knock")
		_broadcast_event("knock", [])
		_say(["Hey! 301!", "I KNOW you're in there!", "Open up! It's 3 AM!"][_knocks - 1])
		_timer = KNOCK_EVERY
		return
	if _door("301").locked:
		_set_pose("fist")
		_say("FINE! Next time I'm calling the landlord!")
		_wait(2.0, _go_home.bind(true))
	else:
		_say("That's it, I'm coming in!")
		_door("301").set_open(true)
		_wait(0.6, _enter)


## Alguém abriu: ele reclama e espia pela porta.
func _complain() -> void:
	state = State.COMPLAIN
	_timer = COMPLAIN_TIME
	_set_pose("fist")
	_say("Do you know what time it is?! Keep it DOWN!")


func _enter() -> void:
	_set_pose("")
	_walk([INSIDE], WALK_SPEED, _start_inspect)


func _start_inspect() -> void:
	state = State.INSPECT
	_timer = INSPECT_TIME
	_look_yaw = 0.0
	_target_yaw = rotation.y


## Viu o esquema: grita e corre para o capacho dele ligando para a polícia.
func _alarm() -> void:
	alarmed = true
	calling = true
	call_left = CALL_TIME
	_say("COUNTERFEIT MONEY?! I'm calling the cops!")
	_broadcast_event("alarm", [])
	_set_pose("phone")
	var route: Array[Vector3] = []
	if global_position.z < 0.25:
		route.append(KNOCK_SPOT)
		_door("301").set_open(true)
	route.append(DOORMAT)
	_walk(route, RUN_SPEED, _start_call)


func _start_call() -> void:
	state = State.CALL


func _call_done() -> void:
	calling = false
	alarmed = false
	_say("Yes, officer. Apartment 301. HURRY!")
	var police: Node = _kitnet.get("police")
	if police != null:
		police.call_cops()
	if state != State.KO:
		_wait(1.5, _go_home.bind(false))


## Volta para o 303 e some lá dentro. `annoyed`: foi uma visita (a próxima vem mais cedo).
func _go_home(annoyed: bool) -> void:
	if annoyed:
		visits += 1
	annoyance = 0.0
	_banged = false
	_yelled = false
	var route: Array[Vector3] = []
	if global_position.z < 0.25:
		route.append(KNOCK_SPOT)
	route.append(DOORMAT)
	route.append(DOORWAY)
	_set_pose("")
	_door("303").set_open(true)
	_walk(route, WALK_SPEED, _arrive_home, State.LEAVE)


func _arrive_home() -> void:
	_door("303").set_open(false)
	state = State.HOME
	_set_pose("")
	_show(false)
	_broadcast_event("show", [false, global_position])


func _walk(route: Array[Vector3], speed: float, then: Callable, walk_state := State.WALK) -> void:
	state = walk_state
	_stuck = 0.0
	_route = route
	_speed = speed
	_then = then
	# Atravessando a porta de entrada fechada (ia sair de dentro), ele abre.
	if _route.size() > 0 and (global_position.z < 0.0) != (_route[-1].z < 0.0):
		_door("301").set_open(true)


func _tick_walk(delta: float) -> void:
	if _route.is_empty():
		_continue()
		return
	var to := _route[0] - global_position
	to.y = 0.0
	if to.length() < 0.12:
		_route.pop_front()
		return
	_face(_route[0], delta)
	var before := global_position
	velocity = to.normalized() * _speed
	velocity.y = -1.0
	move_and_slide()
	# Travou (alguém fechou a porta na cara dele, um móvel no caminho): abre a 301 se estiver
	# perto dela e, preso de vez, passa direto para o próximo ponto.
	if before.distance_to(global_position) < _speed * delta * 0.3:
		_stuck += delta
		if _stuck > 1.0 and global_position.distance_to(_door("301").global_position) < 1.6:
			_door("301").set_open(true)
		if _stuck > 3.0:
			global_position = _route.pop_front()
			_stuck = 0.0
	else:
		_stuck = 0.0


func _wait(seconds: float, then: Callable) -> void:
	state = State.WAIT
	_timer = seconds
	_then = then


func _continue() -> void:
	var next := _then
	_then = Callable()
	if next.is_valid():
		next.call()


func _face(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_target_yaw = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


func _door(key: String) -> Node:
	return _kitnet.doors[key]


## Barulho de todas as máquinas juntas.
func _total_noise() -> float:
	var total := 0.0
	for source in get_tree().get_nodes_in_group("noise_source"):
		total += source.noise()
	return total


## Ele vê prova do esquema daqui? Notas, folhas e maços (mesmo na mão de alguém), a impressora
## imprimindo, a contadora com notas e a guilhotina com folha, na frente dele e sem parede no meio.
func _sees_evidence() -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var forward := -global_basis.z
	var points: Array[Vector3] = []
	for item in _kitnet.items.items.values():
		if item.kind in EVIDENCE:
			points.append(item.global_position + Vector3.UP * 0.03)
		elif item.kind == "trashbag" and item.data.get("open", false) and not item.data.get("contents", []).is_empty():
			# Saco aberto com dinheiro: dá para ver os maços pela boca.
			points.append(ItemKinds.bag_mouth(item))
	if _kitnet.printer != null and _kitnet.printer.printing():
		points.append(_kitnet.printer.global_position + Vector3.UP * 0.25)
	if _kitnet.cash_counter != null and not (_kitnet.cash_counter.hopper.is_empty() and _kitnet.cash_counter.tray.is_empty()):
		points.append(_kitnet.cash_counter.global_position + Vector3.UP * 0.15)
	if _kitnet.guillotine != null and _kitnet.guillotine.has_sheet():
		points.append(_kitnet.guillotine.global_position + Vector3.UP * 0.1)
	var space := get_world_3d().direct_space_state
	for point in points:
		var to := point - eye
		var dist := to.length()
		if dist > SIGHT or dist < 0.01:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.3 and flat.normalized().dot(forward) < cos(SIGHT_HALF_ANGLE):
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty() or (hit.position as Vector3).distance_to(point) < 0.2:
			return true
	return false


# --- Frigideira, arrasto e suborno --------------------------------------------------------------

## A frigideira pegou (na máquina de quem bateu): quem decide é o host.
func take_bonk(dir: Vector3) -> void:
	if multiplayer.is_server():
		_get_bonked(dir)
	else:
		_rpc_bonked.rpc_id(1, dir)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_bonked(dir: Vector3) -> void:
	if multiplayer.is_server():
		_get_bonked(dir)


func _get_bonked(dir: Vector3) -> void:
	if not out():
		return
	_ko_left = KO_TIME
	if state == State.KO:
		_broadcast_event("stars", [])
		return
	var cut := calling
	calling = false
	state = State.KO
	_then = Callable()
	_route.clear()
	_set_pose("")
	_broadcast_event("ko", [dir, cut])


## Onde o corpo está agora (caído, os quadris do ragdoll; o nó fica parado enquanto ele está no
## chão: mexer nele levaria os ossos de física junto).
func body_position() -> Vector3:
	if character.ragdolling:
		var hips: Vector3 = character.ragdoll_hips()
		return Vector3(hips.x, global_position.y, hips.z)
	return global_position


func _tick_ko(delta: float) -> void:
	if dragger != 0:
		var player: Node3D = _kitnet.players.get(dragger)
		if player == null or player.global_position.distance_to(body_position()) > DRAG_BREAK or player.get("fallen"):
			_set_dragger(0)
	_ko_left -= delta
	if _ko_left <= 0.0:
		_wake()


## Acorda: no capacho dele, acha que sonhou; em qualquer outro lugar, liga para a polícia.
func _wake() -> void:
	_set_dragger(0)
	var at := body_position()
	var home := at.distance_to(DOORMAT) < HOME_RADIUS and at.z > 0.2
	state = State.WAIT
	_broadcast_event("wake", [at])
	if home:
		alarmed = false
		_say("Huh...? What a weird dream...")
		_wait(2.0, _go_home.bind(false))
	else:
		_say("Ow... my head. YOU!")
		_wait(1.2, _alarm)


func _prompt(player: Node) -> String:
	if state == State.KO:
		if dragged_by(player.name.to_int()):
			return "[E] Let go"
		if dragger != 0:
			return ""
		if player.held_item() != null:
			return "Knocked out (hands full)"
		return "[E] Drag him by the collar"
	if not bribable():
		return ""
	var held: Node = player.held_item()
	if held != null and held.kind == "bundle":
		return "[E] Bribe him with the bundle"
	return "Neighbor (a bundle might shut him up)"


## Host: [E] no vizinho.
func _press(peer: int) -> void:
	var player: Node3D = _kitnet.players.get(peer)
	if player == null:
		return
	if state == State.KO:
		if dragger == peer:
			_set_dragger(0)
		elif dragger == 0 and _kitnet.items.held_by(peer) == null:
			_set_dragger(peer)
		return
	var held: Node = _kitnet.items.held_by(peer)
	if held != null and held.kind == "bundle" and bribable():
		_kitnet.items.consume(held)
		var cut := calling
		calling = false
		alarmed = false
		visits = maxi(0, visits - 1)
		_broadcast_event("bribe", [cut])
		_say("...I didn't see anything. Goodnight.")
		_wait(1.2, _go_home.bind(false))


## Quem arrasta solta (o [G] do jogador também).
func request_let_go() -> void:
	if multiplayer.is_server():
		if dragger == multiplayer.get_unique_id():
			_set_dragger(0)
	else:
		_rpc_let_go.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_let_go() -> void:
	if multiplayer.is_server() and dragger == multiplayer.get_remote_sender_id():
		_set_dragger(0)


func _set_dragger(peer: int) -> void:
	dragger = peer
	_send_timer = 0.0


## Host: alguém saiu da sala.
func drop_peer(peer: int) -> void:
	if dragger == peer:
		_set_dragger(0)


# --- Rede -------------------------------------------------------------------------------------

func _send_state(delta: float) -> void:
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = 1.0 / SEND_RATE
	_kitnet.rpc_roster(self, &"_sync", _sync_args())


func _sync_args() -> Array:
	return [global_position, rotation.y, state, pose, dragger, call_fraction() if calling else -1.0, noise]


func send_state_to(peer: int) -> void:
	_event.rpc_id(peer, "show", [out(), global_position])
	if state == State.KO:
		_event.rpc_id(peer, "ko", [Vector3.FORWARD, false])
	callv(&"rpc_id", [peer, &"_sync"] + _sync_args())


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, yaw: float, new_state: int, new_pose: String, drag: int, call_frac: float, level: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	if not (state == State.KO and new_state != State.KO and character.ragdolling):
		state = new_state as State
	pose = new_pose
	dragger = drag
	calling = call_frac >= 0.0
	call_left = (1.0 - maxf(call_frac, 0.0)) * CALL_TIME
	noise = level


func _follow(delta: float) -> void:
	if character.ragdolling:
		return
	var t := clampf(12.0 * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)


func _set_pose(new_pose: String) -> void:
	pose = new_pose


func _say(text: String) -> void:
	_broadcast_event("say", [text])


func _broadcast_event(event: String, args: Array) -> void:
	_kitnet.rpc_roster(self, &"_event", [event, args])
	_event(event, args)


@rpc("authority", "call_remote", "reliable")
func _event(event: String, args: Array) -> void:
	var me: Node = _kitnet.local_player()
	match event:
		"show":
			global_position = args[1]
			_target_pos = args[1]
			_last_pos = args[1]
			_show(args[0])
		"say":
			_show_bubble(args[0])
		"knock":
			_knock_sound.global_position = _door("301").global_position + Vector3(0.4, 1.2, 0.1)
			_knock_sound.play()
			if me != null:
				me.hud.show_message("*KNOCK KNOCK KNOCK*\nThe neighbor from 303 is at the door.", 2.5)
		"bang":
			_bang_sound.global_position = _door("303").global_position + Vector3(0.0, 1.4, -0.2)
			_bang_sound.play()
			if me != null:
				me.hud.show_message("*BANG BANG BANG*\nThe neighbor is banging on the wall. Too much noise!", 3.5)
		"yell":
			if me != null:
				me.hud.show_message("\"KEEP IT DOWN OVER THERE!\"\n(from 303)", 3.5)
		"alarm":
			Bonk.popup(_kitnet, bonk_point() + Vector3.UP * 0.2, "!!")
			if me != null:
				me.hud.show_message("The neighbor saw everything!\nStop him before he calls the police!", 4.0)
		"ko":
			if not visible:
				_show(true)
			state = State.KO
			character.start_ragdoll(args[0], 3.0)
			_stars_left = KO_TIME + 1.0
			if args[1] and me != null:
				me.hud.show_message("The call got cut off!", 2.5)
		"stars":
			_stars_left = maxf(_stars_left, KO_TIME + 1.0)
		"wake":
			# Primeiro levanta (guarda a pose de pano no mundo), depois o nó vai até onde ele caiu.
			character.end_ragdoll()
			state = State.WAIT
			global_position = args[0]
			_target_pos = args[0]
			_last_pos = args[0]
			_stars_left = 2.0
		"bribe":
			if me != null:
				me.hud.show_message("Bribed. He didn't see a thing." + ("\n(He hung up.)" if args[0] else ""), 3.0)


func _show_bubble(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(2.4 + text.length() * 0.03)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.5)
	_bubble_tween.tween_callback(func(): _bubble.visible = false)


# --- O que todos veem -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not visible or delta <= 0.0:
		return
	_anim_time += delta
	if character.ragdolling and dragger != 0:
		_pull_ragdoll()
	character.animate(delta, _velocity, false, 0.0, _arm_targets())
	_place_phone()
	_stars_left = maxf(0.0, _stars_left - delta)
	_stars.visible = _stars_left > 0.0
	if _stars.visible:
		Bonk.place_stars(_stars, bonk_point(), _anim_time)
	# No chão, a zona de [E] e a cápsula da frigideira vão para onde o corpo está.
	var down: bool = character.ragdolling
	(_collision.shape as CapsuleShape3D).height = 0.7 if down else 1.75
	if down:
		var at := body_position() + Vector3.UP * 0.25
		zone.global_position = at
		_collision.global_position = at
	else:
		zone.position = Vector3(0.0, 1.0, 0.0)
		_collision.position = Vector3(0.0, 0.875, 0.0)
	_call_label.visible = calling and not down
	if _call_label.visible:
		var dots := ".".repeat(int(_anim_time * 3.0) % 4)
		_call_label.text = "Calling the police%s %d%%" % [dots, roundi(call_fraction() * 100.0)]
		if not _ring_sound.playing:
			_ring_sound.play()
	elif _ring_sound.playing:
		_ring_sound.stop()


## Arrastado: os quadris e o peito vão para a frente de quem arrasta; o resto vem pendurado.
func _pull_ragdoll() -> void:
	var player: Node3D = _kitnet.players.get(dragger)
	if player == null:
		return
	var fwd := -player.global_basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var base := player.global_position
	character.pull_bone("Hips", base + fwd * DRAG_HIPS.x + Vector3.UP * DRAG_HIPS.y, DRAG_PULL)
	character.pull_bone("Chest", base + fwd * DRAG_CHEST.x + Vector3.UP * DRAG_CHEST.y, DRAG_PULL)


## Onde vão as mãos (IK) em cada pose: [direita, esquerda]; vazio = braços soltos.
func _arm_targets() -> Array:
	if character.ragdolling or pose.is_empty():
		return []
	var b := global_basis
	var right := b.x
	var fwd := -b.z
	var base := global_position
	var hip_l := base - right * 0.24 + Vector3.UP * 0.95 + fwd * 0.04
	var hip_r := base + right * 0.24 + Vector3.UP * 0.95 + fwd * 0.04
	match pose:
		"knock":
			# Bate com o nó dos dedos na porta, a outra mão na cintura.
			var beat := absf(sin(_anim_time * 14.0))
			return [base + right * 0.12 + Vector3.UP * 1.38 + fwd * (0.38 + 0.1 * beat), hip_l]
		"phone":
			# O celular na orelha (a orelha fica a ~1,56 m, do lado da cabeça).
			return [base + right * 0.2 + Vector3.UP * 1.5 + fwd * 0.06, hip_l]
		"fist":
			var shake := sin(_anim_time * 22.0) * 0.05
			return [base + right * 0.2 + Vector3.UP * (1.95 + shake) + fwd * 0.18, hip_l]
	return [hip_r, hip_l]


func _place_phone() -> void:
	_phone.visible = pose == "phone" and not character.ragdolling
	if not _phone.visible:
		return
	var hand: Vector3 = character.hand_position(0)
	var head := global_position + Vector3.UP * 1.56
	var up := (head - hand).normalized() if head.distance_to(hand) > 0.01 else Vector3.UP
	var side := global_basis.x
	var fwd := side.cross(up).normalized()
	# Na frente da orelha, encostado na bochecha (entre a mão e a cabeça ele sumia).
	var face := -global_basis.z
	_phone.global_transform = Transform3D(Basis(side, up, -fwd).orthonormalized(), hand + up * 0.08 + face * 0.07 + side * 0.03)


# --- Sons -------------------------------------------------------------------------------------

func _build_sounds() -> void:
	_knock_sound = _player("Knock", _thuds(3, 0.17, 110.0, 0.9), 5.0)
	_bang_sound = _player("Bang", _thuds(3, 0.3, 70.0, 1.0), 10.0)
	_ring_sound = _player("Ring", _ringback(), 3.0)
	# O toque vai junto com ele.
	_ring_sound.top_level = false
	_ring_sound.position = Vector3(0.0, 1.6, 0.0)


## `count` pancadas surdas de madeira, de `gap` em `gap` segundos.
static func _thuds(count: int, gap: float, freq: float, gain: float) -> AudioStreamWAV:
	const RATE := 22050
	var length := gap * count + 0.3
	var n := int(RATE * length)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 303
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in count:
			var u := t - k * gap
			if u >= 0.0:
				s += exp(-u * 28.0) * (sin(TAU * freq * u) * 0.8 + sin(TAU * freq * 2.7 * u) * 0.25) \
						+ exp(-u * 160.0) * rng.randf_range(-0.6, 0.6)
		data.encode_s16(i * 2, int(clampf(s * gain, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav


## Tom de chamada do celular dele ("tuuu... tuuu..."), em loop.
static func _ringback() -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE * 3.0)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var on := t < 1.0
		var s := (sin(TAU * 425.0 * t) * 0.5 + sin(TAU * 480.0 * t) * 0.2) if on else 0.0
		data.encode_s16(i * 2, int(s * 9000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = n
	return wav


func _player(player_name: String, stream: AudioStream, unit_size: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = player_name
	p.stream = stream
	p.unit_size = unit_size
	p.top_level = true
	add_child(p)
	return p
