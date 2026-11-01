extends AnimatableBody3D
## Porta de dobradiça vinda do kitnet.glb (KEEP_Door_<n>). A folha já vem com a origem na
## dobradiça, a folha para +X local e o lado de fora para +Z local (o -Y do Blender). Abre
## sempre para dentro (-Z local: a 301 para dentro da kitnet, a do banheiro para dentro do
## banheiro), girando no Y local, e o estado vai para todos os jogadores.
##
## A 301 tranca por dentro: a tranca de barra no meio da folha ([E] na zona dela, `lockable`).
## Trancada, ninguém abre por fora (o vizinho bate e vai embora); de dentro, [E] na porta também
## destranca. O host abre e fecha qualquer porta com `set_open` (o vizinho sai pela 303, a polícia
## entra pela 301 trancada ou não).

const InteractZone := preload("res://scripts/interact_zone.gd")
const OPEN_ANGLE := 100.0
const SWING_TIME := 0.45
## Grossura da colisão da folha (m), sem os puxadores.
const LEAF_THICKNESS := 0.05
## Tranca de barra da 301 (art_source/blender/structure.py, _door_locks): no meio da folha, do
## lado de dentro (-Z local).
const LOCK_ZONE := Vector3(0.38, 1.32, -0.07)
const LOCK_ZONE_SIZE := Vector3(0.55, 0.16, 0.08)

var key := ""
var is_open := false
var locked := false
## Tranca por dentro (só a 301).
var lockable := false
var lock_zone: Area3D

var _closed: Basis
var _angle := 0.0
var _swing := 0.0:
	set(value):
		_swing = value
		basis = _closed * Basis(Vector3.UP, value)
var _tween: Tween


## Troca a folha `leaf` por esta porta no mesmo lugar, com uma caixa de colisão do tamanho dela.
func adopt(leaf: MeshInstance3D) -> void:
	key = String(leaf.name).trim_prefix("KEEP_Door_")
	name = "Door_" + key
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0
	leaf.get_parent().add_child(self)
	transform = leaf.transform
	_closed = basis
	leaf.reparent(self, false)
	leaf.transform = Transform3D.IDENTITY
	var box := leaf.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = box.size
	# Só a grossura da folha: a caixa com os puxadores dos dois lados ficava com ~18 cm e, aberta,
	# comia o vão da porta do banheiro (o jogador não passava).
	shape.size.z = minf(box.size.z, LEAF_THICKNESS)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = box.get_center()
	add_child(col)


## Põe a tranca por dentro (a 301): a zona da tranca de barra.
func make_lockable() -> void:
	lockable = true
	lock_zone = InteractZone.new()
	lock_zone.setup(self, "Zone_Lock", LOCK_ZONE, LOCK_ZONE_SIZE)
	lock_zone.prompt_fn = _lock_prompt
	lock_zone.press_fn = _toggle_lock


func _lock_prompt(_player: Node) -> String:
	if is_open:
		return ""
	return "[E] Unlock" if locked else "[E] Lock the door"


func _toggle_lock(_peer: int) -> void:
	if not is_open:
		set_locked(not locked)


func get_prompt(player: Node) -> String:
	if locked:
		return "[E] Unlock" if lockable and inside(player) else "Locked"
	return "[E] Close" if is_open else "[E] Open"


## De que lado da porta está o jogador: dentro é o -Z local.
func inside(node: Node3D) -> bool:
	return to_local(node.global_position).z < 0.0


func interact(player: Node3D) -> void:
	if locked:
		if lockable and inside(player):
			_request_lock(false)
		return
	_request_open(not is_open)


func _request_open(open: bool) -> void:
	if multiplayer.is_server():
		set_open(open)
	else:
		_rpc_open.rpc_id(1, open)


func _request_lock(lock: bool) -> void:
	if multiplayer.is_server():
		set_locked(lock)
	else:
		_rpc_lock.rpc_id(1, lock)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_open(open: bool) -> void:
	if multiplayer.is_server() and not locked:
		set_open(open)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_lock(lock: bool) -> void:
	if multiplayer.is_server() and lockable:
		set_locked(lock)


## Host: abre ou fecha para todos (mesmo trancada: quem chama decide).
func set_open(open: bool) -> void:
	if open == is_open:
		return
	# Girar +Y leva a folha (+X) para -Z: para dentro.
	var angle := deg_to_rad(OPEN_ANGLE) if open else 0.0
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	kitnet.rpc_roster(self, &"_set_state", [open, angle, false])
	_set_state(open, angle, false)


## Host: tranca ou destranca para todos (a tranca solta quando a porta abre à força).
func set_locked(lock: bool) -> void:
	if lock == locked:
		return
	var kitnet := get_tree().get_first_node_in_group("kitnet")
	kitnet.rpc_roster(self, &"_set_locked", [lock])
	_set_locked(lock)


## Manda o estado atual para quem acabou de entrar.
func send_state_to(peer: int) -> void:
	_set_state.rpc_id(peer, is_open, _angle, true)
	_set_locked.rpc_id(peer, locked)


@rpc("authority", "call_remote", "reliable")
func _set_locked(lock: bool) -> void:
	if lock != locked and lockable:
		_play_click(lock)
	locked = lock


@rpc("any_peer", "call_remote", "reliable")
func _set_state(open: bool, angle: float, instant: bool) -> void:
	is_open = open
	_angle = angle if open else 0.0
	if _tween:
		_tween.kill()
	if instant:
		_swing = _angle
		return
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "_swing", _angle, SWING_TIME)


## Clique da tranca (feito aqui: dois estalos de metal).
func _play_click(lock: bool) -> void:
	const RATE := 22050
	var count := int(RATE * 0.25)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var s := 0.0
		for hit in [0.0, 0.09 if lock else 0.06]:
			var u: float = t - hit
			if u >= 0.0:
				s += exp(-u * 90.0) * (sin(TAU * 2300.0 * u) * 0.5 + randf_range(-0.5, 0.5))
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 20000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	var player := AudioStreamPlayer3D.new()
	player.stream = wav
	player.unit_size = 3.0
	player.position = LOCK_ZONE
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
