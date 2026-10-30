extends CharacterBody3D
## Jogador em primeira pessoa. Só a máquina dona dele (a autoridade, o peer com o id do nome
## do nó) lê teclado e mouse e move o corpo; ela manda posição, giro, olhar e altura para os
## outros, que só seguem e desenham o boneco.
##
## Interação: o que a mira (InteractRay) acerta pode ter
##   get_prompt(player) -> String   texto na tela ("" = nada a fazer)
##   interact(player)               [E] apertado
##   is_hold + begin_hold/end_hold  segurar [E] (zonas das máquinas: manivela, portinhola)
## Carrega um item por vez no ponto Hold (na frente da câmera); [G] solta. Com algo na mão
## aparecem as luvas (hands.glb, manga na cor da vaga) segurando o item, para todos verem. No
## jogador local o ponto Hold balança atrasado quando a câmera vira e recua perto da parede.
##
## Camadas de colisão: 1 = mundo, 2 = jogadores (um esbarra no outro), 3 = itens,
## 4 = zonas de interação. A mira acerta mundo, itens e zonas.

const Hud := preload("res://scripts/hud.gd")
const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const HandsModel := preload("res://assets/models/hands.glb")
## Onde o item fica na frente da câmera, parado.
const HOLD_REST := Vector3(0.0, -0.25, -0.46)
## Quantas vezes por segundo o dono manda o estado para os outros.
const SEND_RATE := 30.0
## Quão rápido os bonecos dos outros alcançam a última posição recebida.
const FOLLOW_SPEED := 15.0

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
var _tag: Label3D
## Zona em que o [E] está sendo segurado agora (só no jogador local).
var _hold_zone: Node = null
## Luvas: [direita, esquerda].
var _hands: Array[MeshInstance3D] = []
## Balanço do item na mão com o mouse (só no jogador local).
var _sway := Vector2.ZERO

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
	if is_local():
		_setup_input()
		camera.make_current()
		hud = Hud.new()
		add_child(hud)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# O próprio boneco some para quem joga: com a lâmpada a meio metro da cabeça, até a
		# sombra dele cobria o cômodo. Os outros continuam vendo (e com sombra).
		_body.visible = false
		hud.show_message("KITNET 301\nPrint the money. Don't get caught.", 4.0)
		hud.show_hint("WASD move · Shift run · Ctrl/C crouch · Space jump · E interact · G drop · Esc menu")
	else:
		interact_ray.enabled = false


## Em _input (antes da interface): nenhum Control embaixo do cursor engole o olhar.
func _input(event: InputEvent) -> void:
	if not is_local():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _has_control():
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * mouse_sensitivity, -1.5, 1.5)
		_sway = (_sway + event.relative * 0.004).limit_length(1.0)


func _process(delta: float) -> void:
	if is_local():
		_update_hold_point(delta)
	_update_hands()


func _physics_process(delta: float) -> void:
	if not is_local():
		_follow_remote(delta)
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

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
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	_update_bob(delta, horizontal.length())
	_update_interaction()
	_send_state(delta)


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


func _update_interaction() -> void:
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
	if _has_control() and held != null and Input.is_action_just_pressed("drop"):
		_drop_held()
	hud.set_carry("" if held == null else "%s   [G] drop" % ItemKinds.label(held).capitalize())


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
		var hand := _hands[i]
		hand.visible = held != null
		if held != null:
			hand.global_transform = held.global_transform * ItemKinds.hand_offset(held.kind, 1 if i == 0 else -1)


func _build_hands() -> void:
	var model := HandsModel.instantiate()
	var sleeve := StandardMaterial3D.new()
	sleeve.albedo_color = Net.PLAYER_COLORS[slot].lightened(0.15)
	sleeve.roughness = 0.95
	var cuff := StandardMaterial3D.new()
	cuff.albedo_color = Net.PLAYER_COLORS[slot].darkened(0.25)
	cuff.roughness = 0.95
	for hand_name in ["Hand_R", "Hand_L"]:
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
		if is_local():
			hand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(hand)
		_hands.append(hand)
	model.free()


## Solta o item na frente do jogador, ou rente à parede se ela estiver no caminho.
func _drop_held() -> void:
	var xform := hold_point.global_transform
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, xform.origin, 1 | 4)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		xform.origin = hit.position + hit.normal * 0.12
	var throw := -camera.global_basis.z * 1.2 + Vector3(velocity.x, 0, velocity.z)
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	kitnet.items.request_drop(Transform3D(Basis(Vector3.UP, rotation.y), xform.origin), throw)


func _has_control() -> bool:
	return controls_enabled and not hud.is_blocking()


# --- Corpo --------------------------------------------------------------------

## Boneco provisório: cápsula na cor da vaga, viseira escura na frente (-Z) e o nome em cima.
func _build_body() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Net.PLAYER_COLORS[slot]
	mat.roughness = 0.7
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = stand_height
	capsule.material = mat
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.position.y = stand_height / 2.0
	_body.add_child(mesh)
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color(0.08, 0.1, 0.12)
	visor_mat.roughness = 0.15
	var visor := BoxMesh.new()
	visor.size = Vector3(0.36, 0.14, 0.12)
	visor.material = visor_mat
	var visor_mesh := MeshInstance3D.new()
	visor_mesh.mesh = visor
	visor_mesh.position = Vector3(0, stand_height - 0.2, -0.26)
	_body.add_child(visor_mesh)
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
