extends RigidBody3D
## Objeto que os jogadores carregam, um por vez (resma, folha impressa...). Tipos em item_kinds.gd.
##
## Rede: o host manda. Ele simula a física dos que estão soltos e manda a posição para os outros,
## que só seguem. O que está na mão de alguém segue o ponto Hold desse jogador em todas as
## máquinas (sem física nem colisão), com um atraso suave: ao pegar ele voa até a mão, e ao
## virar a câmera ele vem um pouco atrás. "resting" = parado onde a máquina pôs (bandeja da
## impressora), congelado até alguém pegar.
##
## Física (só no host): a folha sente o ar (_paper_air: cai devagar, balança e plana), a resma
## é pesada e quica pouco. Itens soltos batem nos jogadores (uma resma arremessada acerta quem
## estiver no caminho, e andando dá para chutar folhas), menos em quem acabou de soltar.
##
## Camadas: 3 = itens. Batem no mundo, nos jogadores e em outros itens; os jogadores passam por
## eles (quem anda empurra o item, não o contrário).

const ItemKinds := preload("res://scripts/items/item_kinds.gd")
const BagContents := preload("res://scripts/items/bag_contents.gd")
const LAYER := 4  # camada 3
const MASK := 1 | 2 | 4
## Quem soltou ou arremessou não esbarra no próprio item por este tempo (s).
const DROP_GRACE := 0.5
## Abaixo disso o item caiu para fora do mapa (pela janela, atravessou o chão) e volta para dentro.
const FLOOR_LIMIT := -3.0
const RESCUE_POINT := Vector3(2.5, 0.4, -2.5)
const SEND_RATE := 20.0
## Quão rápido o item na mão alcança a pose (por segundo); menor = mais solto.
const HOLD_FOLLOW := 16.0

var id := 0
var kind := ""
var data := {}
## Peer segurando (0 = solto).
var holder := 0

var _kitnet: Node
var _target := Transform3D.IDENTITY
var _send_timer := 0.0
## Pose atual na mão, relativa ao ponto Hold de quem segura (anda até ItemKinds.hold_offset).
var _held_local := Transform3D.IDENTITY
var _holder_node: Node3D = null
var _last_hold_pos := Vector3.ZERO
var _hold_speed := 0.0
var _mesh: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _rustle: AudioStreamPlayer3D
static var _rustle_cache: AudioStreamWAV
## Saco de lixo: o pêndulo na mão (ângulos em x e z, e a velocidade deles), a velocidade do ponto
## Hold no quadro anterior, o amassado (força e tempo desde o tranco), a queda (altura e
## velocidade no quadro anterior), o tempo até derramar o próximo e o que acabou de sair dele
## (id -> até quando não pega de volta).
var _swing := Vector2.ZERO
var _swing_vel := Vector2.ZERO
var _hold_vel := Vector3.ZERO
var _squash := 0.0
var _squash_time := 0.0
var _last_y := 0.0
var _fall_speed := 0.0
var _spill_timer := 0.0
var _spilled := {}


func setup(item_id: int, item_kind: String, item_data: Dictionary, xform: Transform3D, held_by: int) -> void:
	id = item_id
	kind = item_kind
	data = item_data.duplicate()
	holder = held_by
	name = "Item_%d" % id
	transform = xform
	_target = xform


func _ready() -> void:
	_kitnet = get_tree().get_first_node_in_group("kitnet")
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Antes dos jogadores: as luvas deles leem a pose do item já atualizada no quadro.
	process_priority = -10
	ItemKinds.build(self)
	_mesh = get_node_or_null("Mesh")
	_last_y = global_position.y
	if kind == "trashbag":
		# O dinheiro com física lá dentro (aparece com o saco aberto).
		add_child(BagContents.new())
	sleeping_state_changed.connect(_on_sleeping_changed)
	apply_mode()


## Liga ou desliga a física e a colisão conforme está na mão, parado ou solto.
func apply_mode() -> void:
	var held := holder != 0
	collision_layer = 0 if held else LAYER
	collision_mask = 0 if held else MASK
	freeze = held or data.get("resting", false) or not multiplayer.is_server()
	_holder_node = _kitnet.players.get(holder) if held else null
	if _holder_node != null:
		# Começa de onde estava no mundo: o item voa até a mão.
		_held_local = _holder_node.hold_point.global_transform.affine_inverse() * global_transform
		_last_hold_pos = _holder_node.hold_point.global_position
	if kind == "sheet" and _mesh:
		_mesh.set_instance_shader_parameter("droop", ItemKinds.SHEET_DROOP if held else 0.0)
		_mesh.set_instance_shader_parameter("flutter", 0.0)


func get_prompt(player: Node) -> String:
	if kind == "parcel":
		return "" if holder != 0 else "[E] Open " + ItemKinds.label(self)
	if kind == "trashbag":
		return _bag_prompt(player)
	if holder != 0 or player.held_item() != null:
		return ""
	if kind in ItemKinds.TWO_HANDED and player.hands_left() < 2:
		return "Needs both hands to carry"
	return "[E] Pick up " + ItemKinds.label(self)


func interact(player: Node) -> void:
	if kind in ItemKinds.NOT_CARRIED:
		_kitnet.items.request_open(id)
	elif kind == "trashbag" and player.held_item() != null:
		_kitnet.items.request_bag_put(id)
	else:
		_kitnet.items.request_pickup(id)


## Host: o saco aberto engole o maço ou montinho solto que cai na boca dele (arremessado,
## largado em cima ou caindo da mão de alguém), esteja ele na mão de alguém ou no chão.
func _catch() -> void:
	if not data.get("open", false) or data.get("contents", []).size() >= ItemKinds.BAG_CAPACITY:
		return
	if global_basis.y.normalized().y < 0.5:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var mouth := ItemKinds.bag_mouth(self)
	var reach := ItemKinds.bag_mouth_radius(data) + ItemKinds.BAG_CATCH_MARGIN
	for other in _kitnet.items.items.values():
		if other == self or other.holder != 0 or other.kind not in ItemKinds.BAG_KINDS \
				or other.data.get("resting", false) or _spilled.get(other.id, 0.0) > now:
			continue
		var to: Vector3 = other.global_position - mouth
		if Vector2(to.x, to.z).length() < reach and to.y > -0.25 and to.y < 0.35:
			_kitnet.items.catch_into_bag(self, other)
			return


## Host: aberto e tombado (largado de lado, arremessado, caiu da mão de quem levou a frigideira),
## o que tem dentro sai pela boca, um de cada vez. Fechado, nada sai.
func _spill(delta: float) -> void:
	if holder != 0 or not data.get("open", false) or data.get("contents", []).is_empty() \
			or global_basis.y.normalized().y > ItemKinds.BAG_SPILL_TILT:
		_spill_timer = 0.0
		return
	_spill_timer -= delta
	if _spill_timer > 0.0:
		return
	_spill_timer = ItemKinds.BAG_SPILL_EVERY
	var out: Node = _kitnet.items.spill_from_bag(self)
	if out != null:
		_spilled[out.id] = Time.get_ticks_msec() / 1000.0 + 1.5


## Todos: o saco mudou (entrou ou saiu coisa, abriu ou fechou): o farfalhar do plástico, e
## entrando coisa ele dá uma achatadinha.
func data_changed(key: String) -> void:
	if kind != "trashbag" or (key != "contents" and key != "open"):
		return
	if key == "contents":
		_bump(0.45)
	if _rustle == null:
		_rustle = AudioStreamPlayer3D.new()
		_rustle.stream = _rustle_sound()
		_rustle.unit_size = 2.0
		add_child(_rustle)
	_rustle.pitch_scale = _rng.randf_range(0.85, 1.2)
	_rustle.play()


## Plástico amassando: ruído picado em estalinhos, que vem e vai.
static func _rustle_sound() -> AudioStreamWAV:
	if _rustle_cache != null:
		return _rustle_cache
	var rate := 22050
	var rng := RandomNumberGenerator.new()
	rng.seed = 301
	var bytes := PackedByteArray()
	var n := int(rate * 0.35)
	bytes.resize(n * 2)
	var low := 0.0
	for i in n:
		var t := float(i) / n
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.55)
		var crackle := 1.0 if rng.randf() < 0.08 else 0.35
		var v := low * crackle * sin(PI * t) * (0.6 + 0.4 * sin(t * 40.0))
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	_rustle_cache = wav
	return wav


## Clique no item de mão vazia: tira a última coisa que entrou no saco.
func click(player: Node) -> void:
	if kind == "trashbag" and holder == 0 and player.held_item() == null:
		_kitnet.items.request_bag_take(id)


## Saco de lixo no chão: com um maço (ou montinho) na mão, [E] põe dentro; de mão vazia, [E]
## pega o saco e o clique tira o último que entrou.
func _bag_prompt(player: Node) -> String:
	if holder != 0:
		return ""
	var contents: Array = data.get("contents", [])
	var held: Node = player.held_item()
	if held != null:
		if held.kind not in ItemKinds.BAG_KINDS:
			return ""
		if contents.size() >= ItemKinds.BAG_CAPACITY:
			return "The trash bag is full"
		return "[E] Put the %s in the trash bag (%d/%d)" % [ItemKinds.label(held), contents.size(), ItemKinds.BAG_CAPACITY]
	var text := "[E] Pick up the " + ItemKinds.label(self)
	if not contents.is_empty():
		var last: Array = contents[-1]
		text += "   Click: take out the " + ItemKinds.label_of(last[0], last[1])
	return text


## Na mão: segue o ponto Hold a cada quadro de tela (suave mesmo acima de 60 fps).
func _process(delta: float) -> void:
	if kind == "trashbag":
		_bag_squash(delta)
	if holder == 0 or _holder_node == null or not is_instance_valid(_holder_node):
		return
	var hold: Transform3D = _holder_node.hold_point.global_transform
	_held_local = _held_local.interpolate_with(ItemKinds.hold_offset(kind, data), clampf(HOLD_FOLLOW * delta, 0.0, 1.0))
	# Batendo com ele (a frigideira), a pose do golpe entra entre a mão e o item.
	global_transform = hold * _holder_node.swing_pose() * _held_local
	if kind == "trashbag" and delta > 0.0:
		global_transform = global_transform * _bag_swing(hold, delta)
	if kind == "sheet" and _mesh and delta > 0.0:
		# A folha tremula mais quanto mais rápido quem segura anda.
		var speed := hold.origin.distance_to(_last_hold_pos) / delta
		_hold_speed = lerpf(_hold_speed, speed, clampf(6.0 * delta, 0.0, 1.0))
		_mesh.set_instance_shader_parameter("flutter", clampf(_hold_speed / 5.0, 0.0, 1.0) * 0.008)
	_last_hold_pos = hold.origin


## Saco na mão: um pêndulo preso nas mãos (em cima). Quem segura acelera para um lado e o
## fundo fica para trás, passa do ponto e volta; virar a câmera também balança. Todo mundo vê
## (cada máquina calcula pelo ponto Hold de quem segura). Devolve o giro em volta das mãos.
func _bag_swing(hold: Transform3D, delta: float) -> Transform3D:
	var size := ItemKinds.bag_size(data)
	var contents: Array = data.get("contents", [])
	var gain := 1.0 if data.get("open", false) else ItemKinds.BAG_SWING_CLOSED
	if contents.is_empty() and not data.get("open", false):
		gain = 0.0
	# A mudança de velocidade das mãos vira um empurrão no pêndulo (o mesmo tranco com qualquer
	# taxa de quadros; o limite segura teleporte e quadro travado).
	var vel := ((hold.origin - _last_hold_pos) / delta).limit_length(ItemKinds.BAG_SWING_MAX_SPEED)
	var change := hold.basis.inverse() * (vel - _hold_vel)
	_hold_vel = vel
	# Acelerou para +x: o fundo fica para -x (giro negativo em z); para +z: giro positivo em x.
	_swing_vel += Vector2(change.z, -change.x) * ItemKinds.BAG_SWING_PUSH * gain
	_swing_vel -= (_swing * ItemKinds.BAG_SWING_SPRING + _swing_vel * ItemKinds.BAG_SWING_DAMP) * delta
	_swing += _swing_vel * delta
	_swing = _swing.limit_length(ItemKinds.BAG_SWING_MAX)
	var pivot := Vector3(0.0, size.y / 2.0, 0.0)
	var turn := Basis.from_euler(Vector3(_swing.x, 0.0, _swing.y))
	return Transform3D(Basis.IDENTITY, pivot) * Transform3D(turn) * Transform3D(Basis.IDENTITY, -pivot)


## Ângulo do pêndulo agora (o teste usa).
func bag_swing_angle() -> float:
	return _swing.length()


## Amassa o saco (de 0 a 1): achata e alarga, chacoalha e volta.
func _bump(strength: float) -> void:
	_squash = maxf(_squash * exp(-_squash_time * ItemKinds.BAG_SQUASH_DECAY), clampf(strength, 0.0, 1.0))
	_squash_time = 0.0


## Saco no chão: caiu (a altura parou de descer depressa) e amassa; o amassado chacoalha e some.
## O fundo fica no lugar (a malha desce o que achatou).
func _bag_squash(delta: float) -> void:
	if delta <= 0.0 or not _mesh:
		return
	var y := global_position.y
	var vy := (y - _last_y) / delta
	if holder == 0 and _fall_speed > ItemKinds.BAG_LAND_SPEED and vy > -0.3:
		_bump(_fall_speed / 4.0)
	_fall_speed = -vy if holder == 0 else 0.0
	_last_y = y
	_squash_time += delta
	var amount := _squash * exp(-_squash_time * ItemKinds.BAG_SQUASH_DECAY) * cos(_squash_time * ItemKinds.BAG_SQUASH_FREQ)
	var flat := ItemKinds.BAG_SQUASH * amount
	_mesh.scale = Vector3(1.0 + flat * 0.6, 1.0 - flat, 1.0 + flat * 0.6)
	_mesh.position.y = -ItemKinds.bag_size(data).y / 2.0 * flat


## Host: não esbarra em quem acabou de soltar (o item nasce colado nele).
func ignore_briefly(player: PhysicsBody3D) -> void:
	add_collision_exception_with(player)
	get_tree().create_timer(DROP_GRACE).timeout.connect(func():
		if is_instance_valid(player) and is_instance_valid(self):
			remove_collision_exception_with(player))


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if kind == "sheet" and holder == 0:
		_paper_air(state)


## Ar numa folha de papel: arrasto forte contra a face e fraco pela borda (deitada ela cai a ~1 m/s;
## inclinada, o arrasto da face empurra para o lado e ela plana), mais um torque que vira a face
## contra o vento. Ele passa do ponto e volta, e a folha desce balançando como folha de árvore.
func _paper_air(state: PhysicsDirectBodyState3D) -> void:
	var v := state.linear_velocity
	var speed := v.length()
	if speed < 0.05:
		return
	var n := state.transform.basis.y
	var vn := v.dot(n)
	var vt := v - n * vn
	state.apply_central_force(-n * vn * absf(vn) * ItemKinds.PAPER_FACE_DRAG
			- vt * vt.length() * ItemKinds.PAPER_EDGE_DRAG)
	var facing := n if vn < 0.0 else -n
	var torque := facing.cross(-v / speed) * speed * speed * ItemKinds.PAPER_ALIGN
	torque += Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) \
			* ItemKinds.PAPER_FLUTTER * speed
	state.apply_torque(torque)


func _physics_process(delta: float) -> void:
	if kind == "trashbag" and multiplayer.is_server():
		_catch()
		_spill(delta)
	if holder != 0:
		return
	if multiplayer.is_server() and global_position.y < FLOOR_LIMIT:
		_rescue()
	if not multiplayer.is_server():
		global_transform = global_transform.interpolate_with(_target, clampf(20.0 * delta, 0.0, 1.0))
		return
	if not freeze and not sleeping:
		_send_timer -= delta
		if _send_timer <= 0.0:
			_send_timer = 1.0 / SEND_RATE
			_kitnet.rpc_roster(self, &"_remote_xform", [global_transform])


## Quando para de rolar, manda a posição final (o envio contínuo para junto).
func _on_sleeping_changed() -> void:
	if multiplayer.is_server() and sleeping and holder == 0:
		_kitnet.rpc_roster(self, &"_remote_xform", [global_transform])


@rpc("authority", "call_remote", "unreliable_ordered")
func _remote_xform(xform: Transform3D) -> void:
	_target = xform


## Host: o item caiu para fora do mapa; volta para o meio da kitnet.
func _rescue() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	snap(Transform3D(Basis.IDENTITY, RESCUE_POINT))
	_kitnet.rpc_roster(self, &"_remote_xform", [global_transform])


## Coloca o item num lugar na hora (sem interpolar), em todas as máquinas.
func snap(xform: Transform3D) -> void:
	global_transform = xform
	_target = xform
