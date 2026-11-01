extends CharacterBody3D
## Policial da batida (police.gd cria dois). O mesmo boneco dos jogadores (character_rig.gd), de
## farda azul, quepe (Acc_Police ou Acc_PoliceShades) e cacetete na mão direita.
##
## O host manda (police.gd entrega as tarefas):
##   1. Entra pela escada, atravessa o corredor e entra pela 301 (abre portas no caminho).
##   2. Faz as tarefas, uma de cada vez:
##      - "search": vai até a frente de um móvel e revista (SEARCH_TIME). A chance de achar vem
##        do police.gd; achando, leva o dinheiro escondido e quem estiver escondido ali sai pego.
##      - "grab": prova à vista (folha, notas, maço, saco aberto com dinheiro): vai lá e leva.
##   3. Viu alguém (na frente dele, sem parede no meio, e não escondido): "FREEZE!" e corre atrás
##      (CHASE). Perto, dá a cacetada (STRIKE): o jogador cai com as estrelinhas (take_bonk, o
##      mesmo da frigideira). Algema (CUFF) e sai arrastando pela gola até a escada (DRAG), onde
##      ele fica preso até a batida acabar (police.jail). Perdeu de vista por LOSE_TIME: volta.
##      Viu entrar num esconderijo: vai lá e abre (revista com chance 1).
##   4. Sem tarefa: espera os outros (DONE). O police.gd manda todos embora pela escada.
##
## Dá para bater nele com a frigideira (take_bonk): desmaia por KO_TIME e larga quem arrastava
## (a algema solta). Caído, o nó fica parado (mexer levaria os ossos de física junto): a cápsula
## vai até os quadris.
##
## Anda pela malha de navegação da kitnet (kitnet.gd, _bake_navigation; só o host tem). Os outros
## só seguem a posição (_sync) e ouvem os eventos (_event: falas, golpe, desmaio).

const CharacterRig := preload("res://scripts/character_rig.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const Bonk := preload("res://scripts/bonk.gd")

enum State {GONE, WALK, SEARCH, PAUSE, CHASE, STRIKE, CUFF, DRAG, KO, DONE}

const UNIFORM := Color(0.2, 0.27, 0.45)
const SKIN := Color(0.96, 0.72, 0.56)
const BATON := Color(0.08, 0.08, 0.09)
## Velocidades (m/s): andando o jogador faz 2,8 e correndo 4,8, então correndo dá para fugir.
const WALK_SPEED := 1.7
const RUN_SPEED := 3.7
const DRAG_SPEED := 1.4
const TURN_SPEED := 9.0
## Vista: alcance (m), meia abertura (rad) e, mais perto que isso, percebe até de costas.
const SIGHT := 9.0
const SIGHT_HALF_ANGLE := 1.1
const NOTICE_RANGE := 1.3
## Revistando um móvel (s).
const SEARCH_TIME := 2.2
## Cacetada: a que distância bate, quanto dura o golpe e quando pega.
const STRIKE_RANGE := 1.1
const STRIKE_TIME := 0.6
const STRIKE_HIT := 0.32
## Algemando (s), quanto tempo sem ver o fugitivo até desistir (s) e desmaiado (s).
const CUFF_TIME := 1.6
const LOSE_TIME := 4.0
const KO_TIME := 8.0
## Arrastando: onde os quadris e o peito de quem vai preso ficam (atrás dele: distância e altura).
const DRAG_HIPS := Vector2(1.0, 0.3)
const DRAG_CHEST := Vector2(0.62, 0.75)
const DRAG_PULL := 9.0
const SEND_RATE := 15.0
## Travou no caminho por isso (s): passa para o próximo ponto.
const STUCK_TIME := 2.5

var state := State.GONE
## 0 ou 1 (qual quepe, qual metade da kitnet).
var index := 0
var pose := ""
## Jogador sendo arrastado (0 = ninguém) e jogador perseguido.
var dragging := 0
var target := 0
var character: Node3D

var _police: Node
var _kitnet: Node
var _agent: NavigationAgent3D
var _collision: CollisionShape3D
var _tasks: Array = []
var _task := {}
var _speed := WALK_SPEED
var _then := Callable()
var _timer := 0.0
var _lost := 0.0
var _last_seen := Vector3.ZERO
var _strike_time := -1.0
var _struck := false
var _ko_left := 0.0
var _stuck := 0.0
var _send_timer := 0.0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _last_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _anim_time := 0.0
var _baton: MeshInstance3D
var _bubble: Label3D
var _bubble_tween: Tween
var _stars: Node3D
var _stars_left := 0.0
var _rng := RandomNumberGenerator.new()


func setup(cop_index: int, police: Node) -> void:
	index = cop_index
	_police = police
	name = "Cop_%d" % cop_index


func _ready() -> void:
	add_to_group("cop")
	add_to_group("station")
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	_rng.seed = 911 + index
	collision_layer = 2
	collision_mask = 1
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	_collision = CollisionShape3D.new()
	_collision.shape = capsule
	_collision.position.y = 0.9
	add_child(_collision)
	character = CharacterRig.new()
	character.setup(0, UNIFORM, "Acc_PoliceShades" if index == 1 else "Acc_Police")
	character.keep_gloves = true
	add_child(character)
	_dress()
	_agent = NavigationAgent3D.new()
	_agent.radius = 0.3
	_agent.height = 1.8
	_agent.path_desired_distance = 0.3
	_agent.target_desired_distance = 0.25
	add_child(_agent)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 32
	_bubble.pixel_size = 0.0022
	_bubble.outline_size = 10
	_bubble.modulate = Color(0.85, 0.92, 1.0)
	_bubble.width = 620.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.position.y = 2.35
	_bubble.visible = false
	add_child(_bubble)
	_stars = Bonk.make_stars()
	add_child(_stars)
	_show(false)


## Farda: mãos de pele, sem o capuz nem o bolso canguru do moletom, e o cacetete.
func _dress() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = SKIN
	skin.roughness = 0.6
	for mesh: MeshInstance3D in character.model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i)
			if mat != null and String(mat.resource_name).begins_with("M_Glove"):
				mesh.set_surface_override_material(i, skin)
	for part in ["Char_Hood", "Char_Pocket"]:
		var node: Node3D = character.model.find_child(part, true, false)
		if node != null:
			node.visible = false
	_baton = MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.018
	stick.bottom_radius = 0.021
	stick.height = 0.55
	stick.radial_segments = 10
	var black := StandardMaterial3D.new()
	black.albedo_color = BATON
	black.roughness = 0.35
	stick.material = black
	_baton.mesh = stick
	_baton.top_level = true
	add_child(_baton)


# --- Estado (todas as máquinas) ------------------------------------------------------------------

func active() -> bool:
	return state != State.GONE


func knocked_out() -> bool:
	return state == State.KO


## Terminou as tarefas e espera os outros.
func done() -> bool:
	return state == State.DONE


## Onde a pancada pega (a cabeça) e onde as estrelinhas giram.
func bonk_point() -> Vector3:
	if character.ragdolling:
		return character.ragdoll_head()
	return global_position + Vector3.UP * 1.75


## Onde o corpo está (caído, os quadris do ragdoll).
func body_position() -> Vector3:
	if character.ragdolling:
		var hips: Vector3 = character.ragdoll_hips()
		return Vector3(hips.x, global_position.y, hips.z)
	return global_position


## Onde os quadris e o peito de quem ele arrasta vão (atrás dele).
func drag_targets() -> Array:
	var back := global_basis.z
	back.y = 0.0
	back = back.normalized()
	var base := global_position
	return [base + back * DRAG_HIPS.x + Vector3.UP * DRAG_HIPS.y, base + back * DRAG_CHEST.x + Vector3.UP * DRAG_CHEST.y]


func _show(on: bool) -> void:
	visible = on
	_collision.disabled = not on
	_baton.visible = on


# --- Host: tarefas ------------------------------------------------------------------------------

## Host: entra em `at` (o patamar da escada) com estas tarefas.
func begin(at: Vector3, tasks: Array) -> void:
	_tasks = tasks.duplicate()
	target = 0
	dragging = 0
	global_position = at
	_last_pos = at
	_broadcast_event("show", [true, at])
	_say(["POLICE! NOBODY MOVE!", "Police! We're coming in!"][index % 2])
	_next_task()


## Host: vai embora pela escada (police.gd chama quando todos terminaram).
func leave(at: Vector3) -> void:
	if state == State.GONE:
		return
	if state == State.KO:
		_wake()
	_release_drag()
	target = 0
	_tasks.clear()
	_go(at, WALK_SPEED, _gone)


func _gone() -> void:
	state = State.GONE
	_broadcast_event("show", [false, global_position])


## Host: o próximo da lista (ou espera os outros).
func _next_task() -> void:
	_set_pose("")
	if _tasks.is_empty():
		state = State.DONE
		return
	_task = _tasks.pop_front()
	match _task["kind"]:
		"grab":
			# Sem tipo: o outro policial pode ter levado (o item some).
			var item = _task["item"]
			if not is_instance_valid(item) or item.holder != 0:
				_next_task()
				return
			_go(item.global_position, WALK_SPEED, _grab)
		"search":
			_go(_task["stand"], WALK_SPEED, _begin_search)


func _grab() -> void:
	var item = _task.get("item")
	if is_instance_valid(item) and item.holder == 0 and item.global_position.distance_to(global_position) < 1.6:
		_set_pose("search")
		_say(["Evidence!", "Bag it.", "What do we have here..."][_rng.randi() % 3])
		_police.seize_item(item)
	_wait_then(0.6, _next_task)


func _begin_search() -> void:
	state = State.SEARCH
	_timer = SEARCH_TIME
	_set_pose("search")
	_say(["Let's see in here...", "Check %s!" % _task.get("label", "this"), "Hmm..."][_rng.randi() % 3])


func _finish_search() -> void:
	var found: Array = _police.search_hit(_task)
	if not found.is_empty():
		_say("GOTCHA!")
		_chase(found[0])
		return
	if _task.get("money", false):
		_say("Ha! Look at this!")
	else:
		_say(["Clear.", "Nothing here.", "Clean."][_rng.randi() % 3])
	_wait_then(0.5, _next_task)


## Já vai buscar esta prova (é a tarefa de agora ou está na lista).
func has_task_item(item: Node) -> bool:
	var current = _task.get("item")
	if is_instance_valid(current) and current == item:
		return true
	for t in _tasks:
		if t["kind"] == "grab" and is_instance_valid(t["item"]) and t["item"] == item:
			return true
	return false


## Põe uma tarefa na frente (prova à vista, esconderijo que viu alguém entrar).
func push_task(task: Dictionary) -> void:
	if state in [State.GONE, State.DONE] and task["kind"] == "grab":
		return
	# Some com as provas que já sumiram (o outro levou) e não repete a mesma.
	_tasks = _tasks.filter(func(t): return t["kind"] != "grab" or is_instance_valid(t["item"]))
	if task["kind"] == "grab":
		if not is_instance_valid(task["item"]):
			return
		for t in _tasks:
			if t["kind"] == "grab" and t["item"] == task["item"]:
				return
		if _police.claimed_item(task["item"], self):
			return
	_tasks.push_front(task)
	if state == State.DONE:
		_next_task()


# --- Host: andar --------------------------------------------------------------------------------

func _go(point: Vector3, speed: float, then: Callable, walk_state := State.WALK) -> void:
	state = walk_state
	_speed = speed
	_then = then
	_stuck = 0.0
	_agent.target_position = point


## Uma pausinha (falando, guardando a prova) e depois `then`.
func _wait_then(seconds: float, then: Callable) -> void:
	state = State.PAUSE
	_timer = seconds
	_then = then


func _move(delta: float, goal: Vector3, speed: float) -> bool:
	var next := _agent.get_next_path_position()
	var to := next - global_position
	to.y = 0.0
	var arrived := _agent.is_navigation_finished() or Vector2(goal.x - global_position.x, goal.z - global_position.z).length() < 0.3
	if arrived:
		velocity = Vector3.ZERO
		return true
	if to.length() < 0.01:
		to = goal - global_position
		to.y = 0.0
	_face(global_position + to, delta)
	var before := global_position
	velocity = to.normalized() * speed
	velocity.y = -1.0
	move_and_slide()
	if before.distance_to(global_position) < speed * delta * 0.3:
		_stuck += delta
		if _stuck > STUCK_TIME:
			# Preso de vez (móvel, porta, jogador na frente): pula para o próximo ponto do caminho.
			global_position = next if next.distance_to(global_position) > 0.05 else goal
			_stuck = 0.0
	else:
		_stuck = 0.0
	return false


## Abre as portas fechadas logo na frente (a do banheiro, a 301, a da escada).
func _open_doors() -> void:
	for door: Node in _kitnet.doors.values():
		if door.key in ["302", "303"] or door.is_open:
			continue
		var center: Vector3 = door.global_transform * Vector3(0.4, 1.0, 0.0)
		if Vector2(center.x - global_position.x, center.z - global_position.z).length() < 1.2:
			if door.locked:
				door.set_locked(false)
			door.set_open(true)
			if door.key == "301":
				_broadcast_event("kick", [center])


func _face(point: Vector3, delta: float) -> void:
	var dir := point - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	_target_yaw = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))


# --- Host: ver ---------------------------------------------------------------------------------

## Dá para ver este jogador daqui (na frente, sem parede no meio, e não escondido nem preso)?
func can_see(player: Node3D) -> bool:
	if player == null or player.get("hiding_spot") != null or player.get("arrest_stage") != "":
		return false
	var point := player.global_position + Vector3.UP * 1.0
	if player.get("fallen"):
		point = player.character.ragdoll_hips() + Vector3.UP * 0.2
	var eye := global_position + Vector3.UP * 1.6
	var to := point - eye
	var dist := to.length()
	if dist > SIGHT:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > NOTICE_RANGE and flat.normalized().dot(-global_basis.z) < cos(SIGHT_HALF_ANGLE):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Prova à vista (o police.gd diz o que conta): na frente dele, sem parede no meio.
func _sees(point: Vector3) -> bool:
	var eye := global_position + Vector3.UP * 1.6
	var to := point - eye
	if to.length() > SIGHT:
		return false
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > NOTICE_RANGE and flat.normalized().dot(-global_basis.z) < cos(SIGHT_HALF_ANGLE):
		return false
	var query := PhysicsRayQueryParameters3D.create(eye, point, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.position as Vector3).distance_to(point) < 0.2


func _look_around() -> void:
	for player: Node3D in _kitnet.players.values():
		# Quem o outro já está pegando fica com ele.
		if _police.claimed(player.name.to_int(), self):
			continue
		if can_see(player):
			_say(["FREEZE! POLICE!", "HEY! STOP RIGHT THERE!", "Don't move!"][_rng.randi() % 3])
			_interrupt()
			_chase(player.name.to_int())
			return
	# Prova à vista: vai buscar logo depois do que está fazendo.
	for item in _police.visible_evidence():
		var current = _task.get("item")
		if is_instance_valid(current) and current == item:
			continue
		if _sees(item.global_position + Vector3.UP * 0.05):
			push_task({"kind": "grab", "item": item})


## Largou a tarefa no meio (viu alguém): ela volta para a frente da lista, para depois.
func _interrupt() -> void:
	if _task.is_empty() or state not in [State.WALK, State.SEARCH, State.PAUSE]:
		return
	if _task["kind"] == "search" or (_task["kind"] == "grab" and is_instance_valid(_task["item"])):
		_tasks.push_front(_task)
	_task = {}


# --- Host: perseguir, bater, algemar, arrastar ------------------------------------------------------

func _chase(peer: int) -> void:
	target = peer
	_lost = 0.0
	var player: Node3D = _kitnet.players.get(peer)
	if player != null:
		_last_seen = player.global_position
	state = State.CHASE
	_set_pose("point")


func _tick_chase(delta: float) -> void:
	var player: Node3D = _kitnet.players.get(target)
	if player == null or player.get("arrest_stage") != "" or _police.claimed(target, self, true):
		target = 0
		_next_task()
		return
	var spot: Node = player.get("hiding_spot")
	if spot != null:
		# Viu entrar: vai lá e abre.
		_say("I saw you go in there!")
		target = 0
		push_task(_police.task_for_hideout(spot, 1.0))
		_next_task()
		return
	if can_see(player):
		_lost = 0.0
		_last_seen = player.character.ragdoll_hips() if player.get("fallen") else player.global_position
	else:
		_lost += delta
		if _lost > LOSE_TIME:
			_say(["Where'd he go?!", "Lost him...", "Tch."][_rng.randi() % 3])
			target = 0
			_next_task()
			return
	_agent.target_position = _last_seen
	var flat := Vector2(_last_seen.x - global_position.x, _last_seen.z - global_position.z).length()
	if flat < STRIKE_RANGE and _lost == 0.0 and player.get("fallen"):
		# Já está no chão: algema direto.
		velocity = Vector3.ZERO
		state = State.CUFF
		_timer = CUFF_TIME
		_set_pose("cuff")
		_say(["Stay down!", "You're under arrest!"][_rng.randi() % 2])
		return
	if flat < STRIKE_RANGE and _lost == 0.0:
		_face(_last_seen, 1.0)
		velocity = Vector3.ZERO
		state = State.STRIKE
		_strike_time = 0.0
		_struck = false
		_set_pose("strike")
		_broadcast_event("strike", [])
		return
	_move(delta, _last_seen, RUN_SPEED)


func _tick_strike(delta: float) -> void:
	_strike_time += delta
	var player: Node3D = _kitnet.players.get(target)
	if player != null:
		_face(player.global_position, delta)
	if not _struck and _strike_time >= STRIKE_HIT:
		_struck = true
		if player != null and player.get("hiding_spot") == null and player.get("arrest_stage") == "" \
				and player.global_position.distance_to(global_position) < STRIKE_RANGE + 0.45:
			var dir := player.global_position - global_position
			dir.y = 0.0
			var at: Vector3 = player.bonk_point()
			_broadcast_event("bonk", [at])
			player.take_bonk(dir.normalized() if dir.length() > 0.01 else -global_basis.z)
	if _strike_time >= STRIKE_TIME:
		_set_pose("point")
		if player != null and player.get("fallen") and player.global_position.distance_to(global_position) < 2.5:
			# Caiu: algema.
			state = State.CUFF
			_timer = CUFF_TIME
			_set_pose("cuff")
			_say(["You're under arrest!", "Hands behind your back!", "Gotcha, punk."][_rng.randi() % 3])
		else:
			state = State.CHASE


func _tick_cuff(delta: float) -> void:
	var player: Node3D = _kitnet.players.get(target)
	if player == null:
		target = 0
		_next_task()
		return
	var hips: Vector3 = player.character.ragdoll_hips() if player.get("fallen") else player.global_position
	_face(hips, delta)
	if not player.get("fallen"):
		# Levantou antes (a frigideira de um amigo no meio): volta a correr atrás.
		state = State.CHASE
		_set_pose("point")
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _police.claimed(target, self, true):
		# O outro chegou antes e já está levando.
		target = 0
		_next_task()
		return
	dragging = target
	target = 0
	player.set_arrest("cuffed", self)
	_set_pose("drag")
	_go(_police.STAIRS, DRAG_SPEED, _jail, State.DRAG)


func _jail() -> void:
	var peer := dragging
	dragging = 0
	_police.jail(peer)
	_say(["One down.", "Into the car with you.", "Next!"][_rng.randi() % 3])
	_next_task()


## Larga quem estava arrastando (desmaiou, foi embora): a algema solta e ele levanta.
func _release_drag() -> void:
	if dragging == 0:
		return
	var player: Node = _kitnet.players.get(dragging)
	dragging = 0
	if player != null and player.get("arrest_stage") == "cuffed":
		player.set_arrest("", null)


# --- Host: frigideira ----------------------------------------------------------------------------

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
	if state == State.GONE:
		return
	_ko_left = KO_TIME
	if state == State.KO:
		_broadcast_event("stars", [])
		return
	_release_drag()
	target = 0
	if not _task.is_empty() and state in [State.WALK, State.SEARCH, State.PAUSE]:
		_tasks.push_front(_task)
	_task = {}
	_then = Callable()
	state = State.KO
	_set_pose("")
	_broadcast_event("ko", [dir])


func _tick_ko(delta: float) -> void:
	_ko_left -= delta
	if _ko_left <= 0.0:
		_wake()


func _wake() -> void:
	var at := body_position()
	_broadcast_event("wake", [at])
	_say(["Ugh... who did that?!", "Assaulting an officer?!", "My head..."][_rng.randi() % 3])
	_next_task()


# --- Host: o relógio --------------------------------------------------------------------------

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
	match state:
		State.GONE, State.DONE:
			return
		State.WALK, State.DRAG:
			_open_doors()
			if _move(delta, _agent.target_position, _speed):
				var next := _then
				_then = Callable()
				if next.is_valid():
					next.call()
		State.SEARCH:
			_face(_task.get("look", global_position), delta)
			_timer -= delta
			if _timer <= 0.0:
				_finish_search()
		State.PAUSE:
			_timer -= delta
			if _timer <= 0.0:
				var next := _then
				_then = Callable()
				if next.is_valid():
					next.call()
		State.CHASE:
			_open_doors()
			_tick_chase(delta)
		State.STRIKE:
			_tick_strike(delta)
		State.CUFF:
			_tick_cuff(delta)
		State.KO:
			_tick_ko(delta)
	if state in [State.WALK, State.SEARCH, State.PAUSE]:
		_look_around()


# --- Rede ---------------------------------------------------------------------------------------

func _set_pose(new_pose: String) -> void:
	pose = new_pose


func _send_state(delta: float) -> void:
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = 1.0 / SEND_RATE
	_kitnet.rpc_roster(self, &"_sync", _sync_args())


func _sync_args() -> Array:
	return [global_position, rotation.y, state, pose, dragging, target]


func send_state_to(peer: int) -> void:
	_event.rpc_id(peer, "show", [active(), global_position])
	if state == State.KO:
		_event.rpc_id(peer, "ko", [Vector3.FORWARD])
	callv(&"rpc_id", [peer, &"_sync"] + _sync_args())


@rpc("authority", "call_remote", "unreliable_ordered")
func _sync(pos: Vector3, yaw: float, new_state: int, new_pose: String, drag: int, chase: int) -> void:
	_target_pos = pos
	_target_yaw = yaw
	if not (state == State.KO and new_state != State.KO and character.ragdolling):
		state = new_state as State
	pose = new_pose
	dragging = drag
	target = chase


func _follow(delta: float) -> void:
	if character.ragdolling:
		return
	var t := clampf(12.0 * delta, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)


func _say(text: String) -> void:
	_broadcast_event("say", [text])


func _broadcast_event(event: String, args: Array) -> void:
	_kitnet.rpc_roster(self, &"_event", [event, args])
	_event(event, args)


@rpc("authority", "call_remote", "reliable")
func _event(event: String, args: Array) -> void:
	match event:
		"show":
			if character.ragdolling:
				character.end_ragdoll()
			global_position = args[1]
			_target_pos = args[1]
			_last_pos = args[1]
			_show(args[0])
			if args[0]:
				state = State.WALK
		"say":
			_show_bubble(args[0])
		"strike":
			_strike_anim = 0.0
			Bonk.play(self, "swoosh", global_position + Vector3.UP * 1.5)
		"bonk":
			Bonk.play(self, "bonk", args[0])
			Bonk.popup(_kitnet, args[0], "WHACK!")
		"kick":
			Bonk.play(self, "clang", args[0])
			var me: Node = _kitnet.local_player()
			if me != null:
				me.kick_camera(0.6)
		"ko":
			state = State.KO
			character.start_ragdoll(args[0], 3.0)
			_stars_left = KO_TIME + 1.0
		"stars":
			_stars_left = maxf(_stars_left, KO_TIME + 1.0)
		"wake":
			character.end_ragdoll()
			state = State.WALK
			global_position = args[0]
			_target_pos = args[0]
			_last_pos = args[0]
			_stars_left = 2.0


func _show_bubble(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	if _bubble_tween:
		_bubble_tween.kill()
	_bubble_tween = create_tween()
	_bubble_tween.tween_interval(1.8 + text.length() * 0.03)
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.5)
	_bubble_tween.tween_callback(func(): _bubble.visible = false)


# --- O que todos veem -------------------------------------------------------------------------

## Tempo desde o começo da cacetada (para a pose; -1 = parado).
var _strike_anim := -1.0


func _process(delta: float) -> void:
	if not visible or delta <= 0.0:
		return
	_anim_time += delta
	if _strike_anim >= 0.0:
		_strike_anim += delta
		if _strike_anim > STRIKE_TIME:
			_strike_anim = -1.0
	character.animate(delta, _velocity, false, 0.0, _arm_targets())
	_place_baton()
	_stars_left = maxf(0.0, _stars_left - delta)
	_stars.visible = _stars_left > 0.0
	if _stars.visible:
		Bonk.place_stars(_stars, bonk_point(), _anim_time)
	# No chão, a cápsula (a frigideira acerta nela) vai para onde o corpo está.
	var down: bool = character.ragdolling
	(_collision.shape as CapsuleShape3D).height = 0.7 if down else 1.8
	if down:
		_collision.global_position = body_position() + Vector3.UP * 0.25
	else:
		_collision.position = Vector3(0.0, 0.9, 0.0)


## Onde vão as mãos (IK) em cada pose: [direita, esquerda]; vazio = braços soltos.
func _arm_targets() -> Array:
	if character.ragdolling or pose.is_empty():
		return []
	var b := global_basis
	var right := b.x
	var fwd := -b.z
	var base := global_position
	var hip_l := base - right * 0.24 + Vector3.UP * 0.95 + fwd * 0.04
	match pose:
		"search":
			# Mexendo nas coisas: as duas mãos na frente, revirando.
			var wob := sin(_anim_time * 9.0) * 0.06
			return [base + right * 0.18 + fwd * 0.5 + Vector3.UP * (1.05 + wob),
					base - right * 0.18 + fwd * 0.5 + Vector3.UP * (1.05 - wob)]
		"point":
			return [base + right * 0.15 + fwd * 0.6 + Vector3.UP * 1.45, hip_l]
		"strike":
			# Arma o cacetete por cima da cabeça e desce na frente.
			var t := clampf((_strike_anim if _strike_anim >= 0.0 else STRIKE_TIME) / STRIKE_HIT, 0.0, 1.0)
			var high := base + right * 0.12 + Vector3.UP * 2.05 - fwd * 0.05
			var low := base + right * 0.08 + Vector3.UP * 1.05 + fwd * 0.62
			return [high.lerp(low, smoothstep(0.55, 1.0, t)), hip_l]
		"cuff":
			return [base + right * 0.14 + fwd * 0.55 + Vector3.UP * 0.55,
					base - right * 0.14 + fwd * 0.55 + Vector3.UP * 0.55]
		"drag":
			# Puxa pela gola, a mão direita para trás e para baixo.
			var back := -fwd
			return [base + right * 0.22 + back * 0.3 + Vector3.UP * 0.8, hip_l]
	return []


## O cacetete na mão direita, na direção do antebraço (caindo do punho; no golpe, vira o
## prolongamento do braço).
func _place_baton() -> void:
	var skel: Skeleton3D = character.skeleton
	var hand := skel.find_bone("Hand.R")
	var fore := skel.find_bone("Forearm.R")
	if hand < 0 or fore < 0:
		return
	var hand_pos: Vector3 = skel.to_global(skel.get_bone_global_pose(hand).origin)
	var elbow: Vector3 = skel.to_global(skel.get_bone_global_pose(fore).origin)
	var along := (hand_pos - elbow).normalized() if hand_pos.distance_to(elbow) > 0.01 else Vector3.DOWN
	var side := along.cross(Vector3.UP)
	if side.length() < 0.01:
		side = global_basis.x
	side = side.normalized()
	var fwd := side.cross(along).normalized()
	_baton.global_transform = Transform3D(Basis(side, along, fwd), hand_pos + along * 0.24)
