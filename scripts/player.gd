extends CharacterBody3D
## Jogador em primeira pessoa. Só a máquina dona dele (a autoridade, o peer com o id do nome
## do nó) lê teclado e mouse e move o corpo; ela manda posição, giro, olhar e altura para os
## outros, que só seguem e desenham o boneco.
##
## Interação: o que a mira (InteractRay) acerta pode ter
##   get_prompt(player) -> String   texto na tela ("" = nada a fazer)
##   interact(player)               [E] apertado
##   is_hold + begin_hold/end_hold  segurar [E] (zonas das máquinas: manivela, portinhola)
## Carrega um item por vez no ponto Hold (na frente da câmera). Tocar [G] solta na frente;
## segurar [G] carrega a força e soltar a tecla arremessa (THROW_*). Com algo na mão
## aparecem as luvas (hands.glb, manga na cor da vaga) segurando o item, para todos verem. No
## jogador local o ponto Hold balança atrasado quando a câmera vira e recua perto da parede.
##
## Empurra-empurra: os jogadores não travam um no outro como blocos (a colisão deles é só com o
## mundo). Encostados, uma mola afasta os dois (cada dono calcula o próprio empurrão pela posição
## dos outros, que já vem pela rede), e quem chega andando empurra junto (PUSH_*). O tronco de
## quem leva o empurrão balança (character_rig.push), e todo mundo vê.
##
## Quem leva uma trombada de alguém correndo cai (ragdoll parcial, RAGDOLL_*): solta o que
## segura, tomba e rola com o tranco, e depois levanta onde caiu. O dono decide e avisa os outros.
##
## Operando uma máquina de perto (`operating`: a guilhotina, o PC): o boneco fica parado na frente dela,
## as luvas vão para onde a máquina manda (todos veem), e no jogador local a câmera vai para a
## vista da máquina (outra câmera, que sai da de primeira pessoa e volta para ela), o mouse e o
## clique vão para a máquina e [E] sai. Com o botão direito segurado, o mouse mexe só as mãos
## (na guilhotina, elas andam livres pela mesa, sem levar a folha). Uma estação com
## `station_input(event)` (o PC) recebe o mouse e o clique do jeito dela, e `station_hint()` dá a dica.
##
## Mãos machucadas (`injury`, a guilhotina decide no host): cada mão pode perder dedos ou ela
## inteira, e as luvas mostram o curativo no lugar. Vale até sair da partida. Com dedo faltando o
## item na mão escorrega andando (SLIP_PER_FINGER), e sem uma das mãos não dá para pegar o que
## precisa das duas (ItemKinds.TWO_HANDED).
##
## Camadas de colisão: 1 = mundo, 2 = jogadores (os itens esbarram neles), 3 = itens,
## 4 = zonas de interação. A mira acerta mundo, itens e zonas.

const Hud := preload("res://scripts/hud.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const HandsModel := preload("res://assets/models/hands.glb")
const OutlineShader := preload("res://shaders/outline.gdshader")
const CharacterRig := preload("res://scripts/character_rig.gd")
## Onde o item fica na frente da câmera, parado.
const HOLD_REST := Vector3(0.0, -0.25, -0.46)
## Dedos de cada mão, da frente (o lado do polegar) para trás: os nomes das peças do hands.glb e
## os bits de `injury`. HAND_LOST é o bit da mão inteira.
const DIGITS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]
const HAND_LOST := 1 << 5
## Com dedo faltando, o item na mão escorrega: chance por segundo andando, por dedo a menos.
const SLIP_PER_FINGER := 0.015
## Segurando [G]: segundos até a força máxima, abaixo de quanto é só soltar, e a velocidade
## do arremesso (m/s) da mais fraca à mais forte.
const THROW_CHARGE_TIME := 0.8
const THROW_MIN_CHARGE := 0.15
const THROW_SPEED := Vector2(2.5, 7.5)
## Quantas vezes por segundo o dono manda o estado para os outros.
const SEND_RATE := 30.0
## Quão rápido os bonecos dos outros alcançam a última posição recebida.
const FOLLOW_SPEED := 15.0
## Primeira pessoa: quanto o próprio boneco fica atrás da câmera olhando para frente e olhando
## todo para baixo (metros), e a partir de que inclinação ele já recuou tudo (radianos).
const FIRST_PERSON_BACK := Vector2(0.08, 0.3)
const FIRST_PERSON_FULL_DOWN := 1.2
## Empurra-empurra. Distância entre dois jogadores em que começam a se empurrar (metros, entre
## os centros; um pouco menos que dois corpos, que são fofos), a mola que afasta quem está
## encostado (m/s por metro encostado; é refeita a cada quadro, não acumula), quanto da
## velocidade de quem chega passa para quem leva o empurrão, quão rápido esse empurrão some (por
## segundo) e o máximo de tudo junto (m/s).
const PUSH_DISTANCE := 0.62
const PUSH_SPRING := 25.0
const PUSH_TRANSFER := 0.95
const PUSH_DAMPING := 6.0
const PUSH_MAX := 4.0
## Trombada: a partir de que velocidade de choque (m/s) os dois sentem o tranco (o boneco achata
## e balança de uma vez, e a câmera de quem joga dá um tranco), e quanto a câmera gira por m/s.
const IMPACT_MIN_SPEED := 0.6
const CAMERA_KICK := 0.02
## Acima disso (m/s) o boneco não andou, foi teleportado.
const TELEPORT_SPEED := 9.0
## Quanto tempo (s) a câmera leva para ir até a vista da máquina operada e voltar.
const STATION_CAMERA_TIME := 0.35
## Balanço do tronco: quanto o boneco ganha de giro (rad/s, por segundo encostado) por unidade de
## empurrão.
const PUSH_WOBBLE := 10.0

@export_group("Movimento")
@export var walk_speed := 2.8
@export var sprint_speed := 4.8
@export var crouch_speed := 1.4
@export var acceleration := 12.0
@export_range(0.0, 1.0) var air_control := 0.3
@export var jump_velocity := 3.4
@export var mouse_sensitivity := 0.0022

@export_group("Agachar")
@export var stand_height := 1.75
@export var crouch_height := 1.05
@export var crouch_transition := 10.0

@export_group("Balanço")
@export var bob_frequency := 1.9
@export var bob_amount := 0.03

## Vaga (0 a 3): cor e ponto de spawn.
var slot := 0
var player_name := ""
## Só existe no jogador local.
var hud: CanvasLayer = null
var controls_enabled := true

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _crouching := false
var _current_height := stand_height
var _bob_time := 0.0
var _send_timer := 0.0
var _target_position := Vector3.ZERO
var _target_yaw := 0.0
var _target_pitch := 0.0
var _body: Node3D
## O boneco de desenho (character_rig.gd), dentro de _body.
var character: Node3D
## Velocidade do boneco no mundo (pelo quanto ele andou no passo de física): de todos, locais e
## remotos.
var body_velocity := Vector3.ZERO
var _last_physics_pos := Vector3.ZERO
## Empurrão que os outros jogadores estão dando neste (só no dono): a mola de quem está
## encostado mais o que sobrou do empurrão de quem chegou andando (_shove).
var push := Vector3.ZERO
var _shove := Vector3.ZERO
## Com quem este boneco está encostado agora (para a trombada valer só na hora do choque).
var _touching := {}
## Tranco da câmera de quem joga (rolar e inclinar, radianos) e a velocidade dele.
var camera_kick := Vector2.ZERO
var _camera_kick_vel := Vector2.ZERO
var _tag: Label3D
## Zona em que o [E] está sendo segurado agora (só no jogador local).
var _hold_zone: Node = null
## Luvas: [direita, esquerda]. As de segurar item e as abertas, apertando a folha na máquina que
## o jogador opera (com o curativo do que perdeu nas duas).
var _hands: Array[MeshInstance3D] = []
var _press_hands: Array[MeshInstance3D] = []
## Vermelho pulsando por cima dos dedos que o golpe da máquina levaria agora.
var _danger_mat: StandardMaterial3D
var _danger_lost := 0
## O que cada mão perdeu ([direita, esquerda]): um bit por dedo (DIGITS) e HAND_LOST.
var injury: Array[int] = [0, 0]
## Botão direito segurado operando uma máquina: o mouse mexe as mãos.
var _regripping := false
## Balanço do item na mão com o mouse (só no jogador local).
var _sway := Vector2.ZERO
## Força do arremesso sendo carregada, de 0 a 1 (-1 = não está segurando [G]).
var _throw_charge := -1.0
## Máquina que este jogador está operando de perto (todas as máquinas sabem; quem diz é a máquina).
var operating: Node3D = null:
	set(value):
		operating = value
		if value != null and is_local():
			_start_operating()
## Câmera da vista da máquina (só no jogador local) e de 0 (primeira pessoa) a 1 (na máquina).
var _station_cam: Camera3D
var _station_blend := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var hold_point: Node3D = $Head/Camera3D/Hold


## Chame antes de pôr na árvore.
func setup(peer_id: int, display_name: String, player_slot: int, spawn: Transform3D) -> void:
	name = str(peer_id)
	player_name = display_name
	slot = player_slot
	transform = spawn
	set_multiplayer_authority(peer_id)


func is_local() -> bool:
	return is_multiplayer_authority()


func _ready() -> void:
	collision.shape = collision.shape.duplicate()
	interact_ray.add_exception(self)
	_target_position = position
	_target_yaw = rotation.y
	_build_body()
	_build_hands()
	hold_point.position = HOLD_REST
	_fall_camera_ball.radius = FALL_CAMERA_RADIUS
	if is_local():
		_setup_input()
		camera.make_current()
		_add_outline(camera)
		hud = Hud.new()
		add_child(hud)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_setup_first_person_body()
		hud.show_message("KITNET 301\nPrint the money. Don't get caught.", 4.0)
		hud.show_hint("WASD move · Shift run · Ctrl/C crouch · Space jump · E interact · G drop (hold to throw) · Esc menu")
	else:
		interact_ray.enabled = false


## Em _input (antes da interface): nenhum Control embaixo do cursor engole o olhar.
func _input(event: InputEvent) -> void:
	if not is_local():
		return
	if operating != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hud.is_blocking():
		# Estação com o próprio jeito de usar o mouse (o PC): ela recebe tudo.
		if operating.has_method("station_input"):
			operating.station_input(event)
			return
		var fine := Input.is_action_pressed("sprint")
		if event is InputEventMouseMotion:
			if _regripping:
				operating.regrip(event.relative.y, fine)
			else:
				operating.slide(event.relative.y, fine)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
			_regripping = event.pressed
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			operating.request_cut()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _has_control():
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		_sway = (_sway + event.relative * 0.004).limit_length(1.0)


func _process(delta: float) -> void:
	if is_local():
		_update_hold_point(delta)
	_update_hands()
	_animate_character(delta)
	if is_local():
		_update_fall_camera()
		_update_station_camera(delta)


func _physics_process(delta: float) -> void:
	# Quanto andou no último passo de física (o quadro de desenho roda mais vezes que a física, e
	# medido lá dava zero em metade dos quadros).
	if delta > 0.0:
		body_velocity = (global_position - _last_physics_pos) / delta
		# Teleporte (nascer, voltar de fora do mapa) não é uma corrida: não derruba nem empurra.
		if body_velocity.length() > TELEPORT_SPEED:
			body_velocity = Vector3.ZERO
	_last_physics_pos = global_position
	if not is_local():
		_follow_remote(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	_update_fall(delta)
	if fallen or character.getup < 1.0:
		# Caído ou levantando: sem andar nem pular, só a gravidade (e larga a máquina que operava).
		if operating != null:
			operating.request_leave()
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		# Sem controle, só para a interface largar o aviso do item que caiu da mão.
		_update_interaction(delta)
		_send_state(delta)
		return

	if operating != null:
		# Operando: parado na frente da máquina; [E] sai.
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if not hud.is_blocking() and Input.is_action_just_pressed("interact"):
			operating.request_leave()
		_send_state(delta)
		return

	var input_dir := Vector2.ZERO
	if _has_control():
		input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	_update_crouch(delta)
	if _has_control() and Input.is_action_just_pressed("jump") and is_on_floor() and not _crouching:
		velocity.y = jump_velocity

	# Só corre para frente e em pé.
	var sprinting := _has_control() and Input.is_action_pressed("sprint") \
			and input_dir.y < 0.0 and not _crouching
	var target_speed := walk_speed
	if _crouching:
		target_speed = crouch_speed
	elif sprinting:
		target_speed = sprint_speed

	var control := 1.0 if is_on_floor() else air_control
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.lerp(direction * target_speed, clampf(acceleration * control * delta, 0.0, 1.0))
	# O empurrão entra só no movimento deste quadro: o passo do jogador continua o mesmo.
	_update_push(delta)
	velocity.x = horizontal.x + push.x
	velocity.z = horizontal.z + push.z
	move_and_slide()
	velocity.x -= push.x
	velocity.z -= push.z

	_update_bob(delta, horizontal.length())
	_maybe_slip(delta, horizontal.length())
	_update_interaction(delta)
	_send_state(delta)


## Mola entre os jogadores encostados e o empurrão de quem chega andando.
func _update_push(delta: float) -> void:
	_shove = _shove.lerp(Vector3.ZERO, clampf(PUSH_DAMPING * delta, 0.0, 1.0))
	var spring := Vector3.ZERO
	for other: Node3D in get_tree().get_nodes_in_group("player"):
		if other == self or other.get("fallen") or absf(other.global_position.y - global_position.y) > 1.2:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var dist := away.length()
		if dist >= PUSH_DISTANCE:
			continue
		# Bem no mesmo lugar (nasceram juntos), cada um vai para um lado.
		var dir := away / dist if dist > 0.01 else Vector3(1, 0, 0).rotated(Vector3.UP, float(name.hash() % 628) / 100.0)
		spring += dir * (PUSH_DISTANCE - dist) * PUSH_SPRING
		# Quem vem para cima empurra junto, na velocidade dele (quase).
		# `dir` vai do outro para este: quem vem para cima anda no sentido de `dir`.
		var coming: float = (other.get("body_velocity") as Vector3).dot(dir)
		var along := _shove.dot(dir)
		if coming * PUSH_TRANSFER > along:
			_shove += dir * (coming * PUSH_TRANSFER - along)
	push = (_shove + spring).limit_length(PUSH_MAX)



# --- Caído (ragdoll) ----------------------------------------------------------

## Quem chega correndo (mais rápido que isto, m/s, na direção deste boneco) derruba: andando é
## 2,8 e correndo 4,8. Caído dura RAGDOLL_TIME segundos; depois levanta e fica RAGDOLL_COOLDOWN
## sem poder cair de novo.
const RAGDOLL_SPEED := 3.5
const RAGDOLL_TIME := 1.6
const RAGDOLL_COOLDOWN := 1.5
## Raio (m) que a câmera de quem caiu guarda das paredes (o plano near está a 0,05 m).
const FALL_CAMERA_RADIUS := 0.12

## Caído (todas as máquinas sabem; quem decide é o dono).
var fallen := false
var _fallen_time := 0.0
var _fall_cooldown := 0.0
var _fall_camera_ball := SphereShape3D.new()


## Só o dono: alguém veio correndo para cima deste boneco.
func _maybe_fall(dir: Vector3, speed: float) -> void:
	if not is_local() or fallen or _fall_cooldown > 0.0 or speed < RAGDOLL_SPEED:
		return
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	if held_item() != null:
		_drop_held()
	_begin_fall(dir, speed)
	if kitnet != null:
		kitnet.rpc_roster(self, &"_remote_fall", [dir, speed])


@rpc("any_peer", "call_remote", "reliable")
func _remote_fall(dir: Vector3, speed: float) -> void:
	if multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		_begin_fall(dir, speed)


@rpc("any_peer", "call_remote", "reliable")
func _remote_stand() -> void:
	if multiplayer.get_remote_sender_id() == get_multiplayer_authority():
		_end_fall()


func _begin_fall(dir: Vector3, speed: float) -> void:
	fallen = true
	_fallen_time = RAGDOLL_TIME
	character.position = Vector3.ZERO
	character.start_ragdoll(dir, speed)


func _end_fall() -> void:
	fallen = false
	character.end_ragdoll()


## Só o dono: conta o tempo caído e levanta onde os quadris pararam (a cápsula desliza até lá,
## sem atravessar parede).
func _update_fall(delta: float) -> void:
	_fall_cooldown = maxf(0.0, _fall_cooldown - delta)
	if not fallen:
		return
	_fallen_time -= delta
	if _fallen_time > 0.0:
		return
	var hips: Vector3 = character.ragdoll_hips()
	var move := Vector3(hips.x - global_position.x, 0.0, hips.z - global_position.z)
	_end_fall()
	move_and_collide(move)
	_fall_cooldown = RAGDOLL_COOLDOWN
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	if kitnet != null:
		kitnet.rpc_roster(self, &"_remote_stand")


## Câmera de quem caiu: vai junto com a cabeça do ragdoll e volta enquanto levanta. Vai até lá
## como uma bolinha de FALL_CAMERA_RADIUS saindo da cabeça da cápsula, e para antes de entrar na
## parede (a cabeça do ragdoll pode parar encostada nela ou num batente).
func _update_fall_camera() -> void:
	var weight := 1.0 if fallen else 1.0 - smoothstep(0.0, 1.0, character.getup)
	if weight <= 0.0:
		return
	var target: Vector3 = character.ragdoll_head() + Vector3.UP * 0.08 if fallen else character.skeleton.to_global(
			character.skeleton.get_bone_global_pose(character.skeleton.find_bone("Head")).origin) + Vector3.UP * 0.2
	var from := head.global_position
	var move := (target - from) * weight
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _fall_camera_ball
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = move
	query.collision_mask = 1
	var safe: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
	camera.global_position = from + move * safe[0]


# --- Rede ---------------------------------------------------------------------

func _send_state(delta: float) -> void:
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = 1.0 / SEND_RATE
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	if kitnet != null:
		kitnet.rpc_roster(self, &"_remote_state", [position, rotation.y, head.rotation.x, _current_height])


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _remote_state(pos: Vector3, yaw: float, pitch: float, height: float) -> void:
	if multiplayer.get_remote_sender_id() != get_multiplayer_authority():
		return
	_target_position = pos
	_target_yaw = yaw
	_target_pitch = pitch
	_set_height(height)


func _follow_remote(delta: float) -> void:
	var t := clampf(FOLLOW_SPEED * delta, 0.0, 1.0)
	position = position.lerp(_target_position, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)
	head.rotation.x = lerp_angle(head.rotation.x, _target_pitch, t)


# --- Interação ----------------------------------------------------------------

## Item que este jogador está segurando, ou null.
func held_item() -> Node:
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	return kitnet.items.held_by(name.to_int()) if kitnet != null else null


func _update_interaction(delta: float) -> void:
	var target: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	var prompt := ""
	if _has_control() and target != null and target.has_method("get_prompt"):
		prompt = target.get_prompt(self)
	hud.set_prompt(prompt)

	# Segurar [E]: avisa a zona ao começar e ao parar (soltou a tecla ou tirou a mira).
	var hold_target: Object = target if target != null and target.get("is_hold") == true else null
	var pressing := _has_control() and Input.is_action_pressed("interact")
	if _hold_zone != null and (not pressing or hold_target != _hold_zone):
		_hold_zone.end_hold(self)
		_hold_zone = null
	if hold_target != null:
		if pressing and _hold_zone == null and not prompt.is_empty():
			_hold_zone = hold_target
			_hold_zone.begin_hold(self)
	elif not prompt.is_empty() and target.has_method("interact") and Input.is_action_just_pressed("interact"):
		target.interact(self)

	var held := held_item()
	if not _has_control() or held == null:
		_throw_charge = -1.0
	elif Input.is_action_just_pressed("drop"):
		_throw_charge = 0.0
	elif _throw_charge >= 0.0:
		if Input.is_action_pressed("drop"):
			_throw_charge = minf(_throw_charge + delta / THROW_CHARGE_TIME, 1.0)
		else:
			_drop_held(_throw_charge)
			_throw_charge = -1.0
	hud.set_throw(_throw_charge if _throw_charge >= THROW_MIN_CHARGE else -1.0)
	hud.set_carry("" if held == null else "%s   [G] drop · hold [G] to throw" % ItemKinds.label(held).capitalize())


## Ponto Hold do jogador local: vem atrasado quando a câmera vira (o item "pesa") e recua
## quando a parede está perto, para o item não atravessar.
func _update_hold_point(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, clampf(9.0 * delta, 0.0, 1.0))
	var reach := HOLD_REST.z
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 0.8, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		reach = -clampf(from.distance_to(hit.position) - 0.3, 0.2, -HOLD_REST.z)
	var t := clampf(12.0 * delta, 0.0, 1.0)
	var target := Vector3(HOLD_REST.x - _sway.x * 0.035, HOLD_REST.y + _sway.y * 0.03, reach)
	hold_point.position = hold_point.position.lerp(target, t)
	hold_point.rotation = hold_point.rotation.lerp(Vector3(_sway.y * 0.12, -_sway.x * 0.2, -_sway.x * 0.12), t)


## Luvas segurando o item: cada uma no lugar de ItemKinds.hand_offset, em cima da pose atual do
## item (os itens processam antes dos jogadores).
func _update_hands() -> void:
	var held := held_item()
	for i in _hands.size():
		var side := 1 if i == 0 else -1
		_hands[i].visible = held != null and operating == null
		_press_hands[i].visible = operating != null
		if operating != null:
			_press_hands[i].global_transform = operating.hand_transform(side)
			# A mão (as peças filhas da manga, com a origem no pulso) dobra no pulso.
			for piece: Node3D in _press_hands[i].get_children():
				piece.rotation.y = side * operating.hand_bend()
		elif held != null:
			_hands[i].global_transform = held.global_transform * ItemKinds.hand_offset(held.kind, side)
	if _danger_lost != 0:
		_danger_mat.albedo_color.a = 0.5 + 0.35 * absf(sin(Time.get_ticks_msec() / 110.0))


## As luvas que aparecem agora: as abertas operando uma máquina, senão as de segurar item.
func active_hands() -> Array[MeshInstance3D]:
	return _press_hands if operating != null else _hands


## A máquina operada avisa o que o golpe levaria das mãos agora (bits de DIGITS e HAND_LOST):
## essas peças das luvas abertas ficam vermelhas, pulsando, para todo mundo ver.
func show_danger(lost: int) -> void:
	if lost == _danger_lost:
		return
	_danger_lost = lost
	for hand in _press_hands:
		var whole := lost & HAND_LOST != 0
		hand.get_node(NodePath(hand.name + "_Glove")).material_overlay = _danger_mat if whole else null
		for d in DIGITS.size():
			var piece: GeometryInstance3D = hand.get_node(NodePath(hand.name + "_" + DIGITS[d]))
			piece.material_overlay = _danger_mat if whole or lost & (1 << d) else null


## O contorno preto do visual de desenho: um quadrado na frente da câmera que o shader estica
## até cobrir a tela.
func _add_outline(cam: Camera3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = OutlineShader
	quad.material = mat
	var outline := MeshInstance3D.new()
	outline.name = "Outline"
	outline.mesh = quad
	outline.position = Vector3(0.0, 0.0, -0.5)
	outline.extra_cull_margin = 16384.0
	outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(outline)


func _build_hands() -> void:
	var model := HandsModel.instantiate()
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Net.PLAYER_COLORS[slot].lightened(0.15)
	sleeve.roughness = 0.95
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = Net.PLAYER_COLORS[slot].darkened(0.25)
	cuff.roughness = 0.95
	for hand_name in ["Hand_R", "Hand_L", "HandFlat_R", "HandFlat_L"]:
		var hand: MeshInstance3D = model.find_child(hand_name, true, false)
		hand.get_parent().remove_child(hand)
		hand.owner = null
		hand.top_level = true
		hand.visible = false
		for i in hand.mesh.get_surface_count():
			var mat_name := String(hand.mesh.surface_get_material(i).resource_name)
			if mat_name == "M_Sleeve":
				hand.set_surface_override_material(i, sleeve)
			elif mat_name == "M_SleeveCuff":
				hand.set_surface_override_material(i, cuff)
		var pressing: bool = hand_name.begins_with("HandFlat")
		# As de segurar ficam na frente da câmera de quem joga: sem sombra. As abertas, na mesa da
		# máquina, fazem sombra no papel (dá a noção de altura).
		if is_local() and not pressing:
			for part in [hand] + hand.get_children():
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hand)
		(_press_hands if pressing else _hands).append(hand)
	model.free()
	_danger_mat = StandardMaterial3D.new()
	_danger_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_danger_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_danger_mat.albedo_color = Color(0.95, 0.02, 0.02, 0.7)
	_show_injury()


# --- Mãos machucadas ---------------------------------------------------------------

## Quantos dedos faltam, somando as duas mãos (uma mão perdida conta os 5).
func fingers_missing() -> int:
	var count := 0
	for lost in injury:
		for d in DIGITS.size():
			if lost & HAND_LOST or lost & (1 << d):
				count += 1
	return count


func hands_left() -> int:
	return injury.filter(func(lost): return lost & HAND_LOST == 0).size()


## Host: a mão `hand` (0 = direita, 1 = esquerda) perdeu as partes `lost` (bits de DIGITS e
## HAND_LOST), somadas ao que ela já tinha perdido. Todo mundo fica sabendo.
func injure(hand: int, lost: int) -> void:
	var now := injury[hand] | lost
	if now == injury[hand]:
		return
	get_tree().get_first_node_in_group("kitnet").rpc_roster(self, &"_set_injury", [hand, now])
	_set_injury(hand, now)


## Host: quem entrou depois vê as mãos como estão.
func send_injury_to(peer: int) -> void:
	for hand in injury.size():
		if injury[hand] != 0:
			_set_injury.rpc_id(peer, hand, injury[hand])


## As mãos de volta, inteiras (partida nova e testes).
func heal() -> void:
	injury = [0, 0]
	_show_injury()


@rpc("any_peer", "call_remote", "reliable")
func _set_injury(hand: int, lost: int) -> void:
	if multiplayer.get_remote_sender_id() not in [0, 1]:
		return
	injury[hand] = lost
	_show_injury()


## As luvas sem o que foi perdido, com o curativo no lugar; sem a mão, o boneco também perde a
## luva dele.
func _show_injury() -> void:
	for i in _hands.size() * 2:
		var hand := _hands[i] if i < _hands.size() else _press_hands[i - _hands.size()]
		var lost := injury[i % _hands.size()]
		var hand_gone := lost & HAND_LOST != 0
		hand.get_node(NodePath(hand.name + "_Glove")).visible = not hand_gone
		hand.get_node(NodePath(hand.name + "_StumpWrist")).visible = hand_gone
		for d in DIGITS.size():
			var gone := lost & (1 << d) != 0
			hand.get_node(NodePath(hand.name + "_" + DIGITS[d])).visible = not gone and not hand_gone
			hand.get_node(NodePath(hand.name + "_Stump" + DIGITS[d])).visible = gone and not hand_gone
	if character != null:
		character.glove_lost.assign([injury[0] & HAND_LOST != 0, injury[1] & HAND_LOST != 0])


## Com dedo faltando, andando com algo na mão, às vezes ele escorrega e cai.
func _maybe_slip(delta: float, speed: float) -> void:
	var missing := fingers_missing()
	if missing == 0 or speed < 0.5 or held_item() == null:
		return
	if randf() < SLIP_PER_FINGER * missing * delta:
		_drop_held()
		hud.show_message("It slipped out of your hand!", 1.6)


## Solta o item na frente do jogador (charge abaixo de THROW_MIN_CHARGE) ou arremessa com a força
## `charge` (0 a 1). Sai na pose em que estava na mão, girando um pouco (mais forte, mais gira),
## e rente à parede se ela estiver no caminho.
func _drop_held(charge := 0.0) -> void:
	var held := held_item()
	if held == null:
		return
	var origin: Vector3 = held.global_position
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, origin, 1 | 4)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		origin = hit.position + hit.normal * 0.12
	var forward := -camera.global_basis.z
	var throw := forward * 1.2
	if charge >= THROW_MIN_CHARGE:
		throw = forward * lerpf(THROW_SPEED.x, THROW_SPEED.y, charge) + Vector3.UP * 1.2 * charge
	throw += Vector3(velocity.x, 0, velocity.z)
	var spin := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * (0.8 + 6.0 * maxf(charge, 0.0))
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	kitnet.items.request_drop(Transform3D(held.global_basis.orthonormalized(), origin), throw, spin)


func _has_control() -> bool:
	return controls_enabled and not hud.is_blocking() and not fallen and operating == null


# --- Operando uma máquina -----------------------------------------------------

## Jogador local começou a operar: vai para a frente da máquina, olhando para ela, e a câmera da
## vista sai de onde está a de primeira pessoa.
func _start_operating() -> void:
	var to: Vector3 = operating.stand_point() - global_position
	move_and_collide(Vector3(to.x, 0.0, to.z))
	rotation.y = operating.stand_yaw()
	head.rotation.x = 0.0
	if _station_cam == null:
		_station_cam = Camera3D.new()
		_station_cam.name = "StationCamera"
		_station_cam.top_level = true
		_station_cam.fov = operating.VIEW_FOV
		_station_cam.near = 0.02
		add_child(_station_cam)
		_add_outline(_station_cam)
	hud.set_prompt("")
	hud.set_carry("")
	_regripping = false
	var hint := "Mouse: push the sheet (hands on it) · Right mouse: move only your hands · Shift: fine · Click: cut · E: leave"
	if operating.has_method("station_hint"):
		hint = operating.station_hint()
	hud.show_hint(hint, 6.0)


## A câmera da vista vai até a máquina operada e volta para a de primeira pessoa quando sai.
func _update_station_camera(delta: float) -> void:
	if _station_cam == null:
		return
	var goal := 1.0 if operating != null else 0.0
	_station_blend = move_toward(_station_blend, goal, delta / STATION_CAMERA_TIME)
	if _station_blend <= 0.0:
		if _station_cam.current:
			camera.make_current()
		return
	if operating != null:
		_station_cam.set_meta("view", operating.view_transform())
	var view: Transform3D = _station_cam.get_meta("view")
	var t := smoothstep(0.0, 1.0, _station_blend)
	_station_cam.global_transform = camera.global_transform.interpolate_with(view, t)
	# O tranco da câmera (golpe da máquina, trombada) também na vista dela.
	_station_cam.rotate_object_local(Vector3.RIGHT, camera_kick.y * t)
	_station_cam.rotate_object_local(Vector3.FORWARD, camera_kick.x * t)
	_station_cam.fov = lerpf(camera.fov, operating.VIEW_FOV if operating != null else _station_cam.fov, t)
	if not _station_cam.current:
		_station_cam.make_current()


# --- Corpo --------------------------------------------------------------------

## O boneco de desenho (moletom na cor da vaga e o acessório dela) e o nome em cima.
func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	character = CharacterRig.new()
	character.setup(slot, Net.PLAYER_COLORS[slot])
	_body.add_child(character)
	_last_physics_pos = global_position
	_tag = Label3D.new()
	_tag.text = player_name
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font_size = 40
	_tag.pixel_size = 0.004
	_tag.outline_size = 10
	_tag.modulate = Net.PLAYER_COLORS[slot].lightened(0.4)
	_tag.no_depth_test = false
	_tag.position.y = stand_height + 0.25
	_body.add_child(_tag)


## Quem joga vê o próprio corpo olhando para baixo (barriga, pernas e tênis) e os braços indo
## até o que segura. Somem só a cabeça (a câmera fica dentro dela) e o nome em cima, e o boneco
## não faz sombra: com a lâmpada a meio metro da cabeça, a sombra dele cobria o cômodo. Os outros
## continuam vendo o boneco inteiro, com sombra.
func _setup_first_person_body() -> void:
	_tag.visible = false
	# A cabeça (a câmera fica dentro dela) e a gola com o capuz, que ficam colados na câmera.
	for part in ["Char_Head", "Char_Hood"]:
		var node: Node3D = character.model.find_child(part, true, false)
		if node != null:
			node.visible = false
	for mesh: GeometryInstance3D in character.model.find_children("*", "GeometryInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Balanço do tronco quando encosta em alguém: inclina para o lado do empurrão, mais forte se o
## outro chegou correndo. Na hora do choque (os dois se aproximando rápido), uma trombada: o boneco
## achata e balança de uma vez, e a câmera de quem joga dá um tranco. Só visual, calculado em cada
## máquina para todos os bonecos.
func _wobble_from_others(delta: float) -> void:
	var touching := {}
	for other: Node3D in get_tree().get_nodes_in_group("player"):
		if other == self or absf(other.global_position.y - global_position.y) > 1.2:
			continue
		var away := global_position - other.global_position
		away.y = 0.0
		var dist := away.length()
		if dist >= PUSH_DISTANCE or dist < 0.001:
			continue
		var dir := away / dist
		var other_vel: Vector3 = other.get("body_velocity")
		touching[other] = true
		if fallen or other.get("fallen"):
			continue
		if not _touching.has(other):
			var closing := (other_vel - body_velocity).dot(dir)
			if closing > IMPACT_MIN_SPEED:
				character.impact(dir, closing)
				if is_local():
					_kick_camera(dir, closing)
			_maybe_fall(dir, other_vel.dot(dir))
		var coming := maxf(0.0, other_vel.dot(dir))
		var strength := (PUSH_DISTANCE - dist) * 6.0 + coming * 1.5
		character.push(dir, strength * PUSH_WOBBLE * delta)
	_touching = touching
	if is_local():
		_update_camera_kick(delta)


## Tranco da câmera na trombada: rola para o lado do empurrão e inclina para frente ou para trás.
func _kick_camera(dir: Vector3, speed: float) -> void:
	var side := dir.dot(global_basis.x)
	var back := dir.dot(global_basis.z)
	_camera_kick_vel += Vector2(-side, -back) * speed * CAMERA_KICK * 30.0


## Tranco de fora (o golpe da guilhotina): a câmera dá uma cabeçada para baixo, um pouco torta.
func kick_camera(strength: float) -> void:
	_camera_kick_vel += Vector2(randf_range(-0.4, 0.4), -1.0) * strength


func _update_camera_kick(delta: float) -> void:
	_camera_kick_vel += (-160.0 * camera_kick - 12.0 * _camera_kick_vel) * delta
	camera_kick = (camera_kick + _camera_kick_vel * delta).limit_length(0.12)
	camera.rotation = Vector3(camera_kick.y, 0.0, camera_kick.x)


## Anima o boneco pelo quanto ele andou (serve para o dono e para os bonecos dos outros).
func _animate_character(delta: float) -> void:
	if character == null or not _body.visible or delta <= 0.0:
		return
	var moved := body_velocity
	_wobble_from_others(delta)
	var airborne := absf(moved.y) > 0.6
	var targets := []
	if (held_item() != null or operating != null) and _hands.size() == 2:
		var hands := active_hands()
		targets = [hands[0].global_position, hands[1].global_position]
	character.animate(delta, moved, airborne, head.rotation.x, targets)
	if is_local() and not fallen:
		# Olhando para baixo, o corpo recua para trás da câmera: aparecem a barriga, as pernas e
		# os tênis, em vez do buraco da gola e dos ombros. Levantando, volta aos poucos.
		var down := clampf(-head.rotation.x / FIRST_PERSON_FULL_DOWN, 0.0, 1.0)
		character.position.z = lerpf(FIRST_PERSON_BACK.x, FIRST_PERSON_BACK.y, down) * character.getup


func _update_crouch(delta: float) -> void:
	var wants_crouch := _has_control() and Input.is_action_pressed("crouch")
	if wants_crouch:
		_crouching = true
	elif _crouching:
		# Só levanta se não houver nada acima da cabeça.
		var rise := Vector3.UP * (stand_height - _current_height)
		if not test_move(global_transform, rise):
			_crouching = false
	var target := crouch_height if _crouching else stand_height
	_set_height(lerpf(_current_height, target, clampf(crouch_transition * delta, 0.0, 1.0)))


func _set_height(height: float) -> void:
	_current_height = height
	var capsule := collision.shape as CapsuleShape3D
	capsule.height = height
	collision.position.y = height / 2.0
	head.position.y = height - 0.12
	if _body != null:
		_body.scale.y = height / stand_height


func _update_bob(delta: float, speed: float) -> void:
	if is_on_floor() and speed > 0.3:
		_bob_time += delta * bob_frequency * TAU * (speed / walk_speed) * 0.5
		camera.position.y = sin(_bob_time * 2.0) * bob_amount
		camera.position.x = cos(_bob_time) * bob_amount * 0.5
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, clampf(10.0 * delta, 0.0, 1.0))


func _setup_input() -> void:
	var bindings := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"crouch": [KEY_CTRL, KEY_C],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
		"drop": [KEY_G],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
