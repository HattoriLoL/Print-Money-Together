extends Node3D
## Boneco de desenho dos jogadores (assets/models/character.glb, montado por
## art_source/blender/character.py): um adulto desengonçado e cansado, de moletom. Todos usam o
## mesmo boneco: a vaga escolhe a cor do moletom e o acessório. As peças são rígidas, com
## cotovelo e joelho, e são animadas aqui, por código:
## - andando: pernas e braços balançam, o joelho dobra quando a perna vem para frente, o corpo
##   quica e rebola;
## - parado: respira, com os cotovelos meio dobrados;
## - no ar: joelhos encolhidos e braços para cima;
## - segurando um item: ombro e cotovelo se ajustam (IK de dois ossos) para a mão chegar nas
##   luvas que seguram o item (hands.glb, do player.gd), e as luvas do boneco somem.

const MODEL := preload("res://assets/models/character.glb")
## Acessório de cada vaga (0 a 3).
const ACCESSORIES: Array[String] = ["Acc_Cap", "Acc_Glasses", "Acc_Quiff", "Acc_Beanie"]
## Medidas das juntas, iguais às do character.py (UPPER_ARM, FOREARM).
const UPPER_ARM := 0.3
const FOREARM := 0.3
## Braços abertos para contornar a barriga, e o cotovelo meio dobrado parado (radianos).
const ARM_SPLAY := 0.22
const ELBOW_REST := 0.3
## Passos: ciclos por metro andado, e quanto as pernas, os joelhos e os braços balançam.
const STRIDE := 1.1
const LEG_SWING := 0.45
const KNEE_BEND := 0.75
const ARM_SWING := 0.35
const BOUNCE := 0.03
const WADDLE := 0.05
## Curvado para frente o tempo todo (radianos), mais um tanto andando.
const SLOUCH := 0.06
## Velocidade de andar normal (a balançada chega no máximo aí).
const WALK_SPEED := 2.8

var slot := 0
var model: Node3D
var body: Node3D
var head: Node3D
## Índice 0 = direita, 1 = esquerda (a mesma ordem das luvas do player.gd).
var arms: Array[Node3D] = []
var forearms: Array[Node3D] = []
var gloves: Array[Node3D] = []
var legs: Array[Node3D] = []
var shins: Array[Node3D] = []
var accessory: Node3D

var _phase := 0.0
var _time := 0.0
var _swing := 0.0
var _air := 0.0
var _body_rest := Vector3.ZERO


func setup(player_slot: int, color: Color) -> void:
	name = "Character"
	slot = player_slot
	model = MODEL.instantiate()
	# O boneco olha para +Z no modelo; o jogador olha para -Z.
	model.rotation.y = PI
	add_child(model)
	body = model.find_child("Char_Body", true, false)
	head = model.find_child("Char_Head", true, false)
	for side in ["R", "L"]:
		arms.append(model.find_child("Char_Arm_" + side, true, false))
		forearms.append(model.find_child("Char_Forearm_" + side, true, false))
		gloves.append(model.find_child("Char_Glove_" + side, true, false))
		legs.append(model.find_child("Char_Leg_" + side, true, false))
		shins.append(model.find_child("Char_Shin_" + side, true, false))
	_body_rest = body.position
	for i in ACCESSORIES.size():
		var acc: Node3D = model.find_child(ACCESSORIES[i], true, false)
		if acc != null:
			acc.visible = i == slot % ACCESSORIES.size()
			if acc.visible:
				accessory = acc
	_paint(color)
	_pose_arms(0.0, 0.0)


## Moletom na cor da vaga (a barra, o bolso, a gola e os punhos um tom mais escuro).
func _paint(color: Color) -> void:
	var hoodie := StandardMaterial3D.new()
	hoodie.albedo_color = color
	hoodie.roughness = 0.95
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color.darkened(0.3)
	dark.roughness = 0.95
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i)
			if mat == null:
				continue
			if mat.resource_name == "M_Hoodie":
				mesh.set_surface_override_material(i, hoodie)
			elif mat.resource_name == "M_HoodieDark":
				mesh.set_surface_override_material(i, dark)


## Um quadro de animação. `velocity` no mundo; `pitch` é o olhar (radianos, + para cima);
## `hold_targets` são os pulsos das luvas segurando um item ([direita, esquerda]) ou vazio.
func animate(delta: float, velocity: Vector3, airborne: bool, pitch: float, hold_targets: Array = []) -> void:
	_time += delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	# Andar para trás roda o ciclo ao contrário.
	var forward := -global_basis.z
	var dir := signf(flat.dot(forward)) if speed > 0.05 else 1.0
	_phase += speed * STRIDE * TAU * delta * 0.5 * dir
	var target_swing := clampf(speed / WALK_SPEED, 0.0, 1.4) if not airborne else 0.0
	_swing = lerpf(_swing, target_swing, clampf(10.0 * delta, 0.0, 1.0))
	_air = lerpf(_air, 1.0 if airborne else 0.0, clampf(12.0 * delta, 0.0, 1.0))

	var s := sin(_phase)
	var c := cos(_phase)
	# Pernas (girar + leva o pé para trás). O joelho dobra quando a perna vem para frente e
	# encolhe no ar.
	legs[0].rotation = Vector3(s * LEG_SWING * _swing - _air * 0.35, 0.0, 0.0)
	legs[1].rotation = Vector3(-s * LEG_SWING * _swing - _air * 0.75, 0.0, 0.0)
	shins[0].rotation = Vector3(KNEE_BEND * _swing * (0.15 + maxf(0.0, -c)) + _air * 0.9, 0.0, 0.0)
	shins[1].rotation = Vector3(KNEE_BEND * _swing * (0.15 + maxf(0.0, c)) + _air * 1.2, 0.0, 0.0)
	# Corpo: quica a cada passo, rebola e respira parado.
	var breathe := sin(_time * 2.2) * 0.018 * (1.0 - _swing)
	body.position = _body_rest + Vector3(0.0, absf(s) * BOUNCE * _swing + _air * 0.04, 0.0)
	body.rotation = Vector3(SLOUCH + 0.05 * _swing, 0.0, s * WADDLE * _swing)
	body.scale = Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0 - breathe * 0.5)
	# Cabeça: acompanha o olhar (metade) e chacoalha um pouco no passo.
	head.rotation = Vector3(-pitch * 0.5 + absf(s) * 0.05 * _swing, 0.0, -s * 0.06 * _swing)

	if hold_targets.size() == 2:
		for i in 2:
			_reach(i, hold_targets[i])
	else:
		_pose_arms(s * ARM_SWING * _swing, _air)


## Braços soltos: balançam ao contrário das pernas (o cotovelo dobra mais quando o braço vai para
## frente) e sobem no ar.
func _pose_arms(swing: float, air: float) -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var splay := (ARM_SPLAY + air * 1.4) * side
		var fwd := -swing if i == 0 else swing
		arms[i].basis = Basis.from_euler(Vector3(fwd, 0.0, splay))
		var elbow := ELBOW_REST + maxf(0.0, -fwd) * 0.8 + air * 0.3
		forearms[i].basis = Basis.from_euler(Vector3(-elbow, 0.0, 0.0))
		gloves[i].visible = true


## IK de dois ossos: a mão do braço `i` vai até `target` (no mundo), com o cotovelo apontando
## para baixo, para fora e um pouco para trás. Se não alcança, o braço estica reto na direção.
func _reach(i: int, target: Vector3) -> void:
	var arm := arms[i]
	var parent := arm.get_parent() as Node3D
	var shoulder := arm.position
	var to_target := parent.to_local(target) - shoulder
	var a := UPPER_ARM
	var b := FOREARM
	var dist := clampf(to_target.length(), 0.05, a + b - 0.001)
	var aim := to_target.normalized() if to_target.length() > 0.001 else Vector3.DOWN
	var side := -1.0 if i == 0 else 1.0
	var pole := Vector3(side * 0.6, -1.0, -0.4)
	var axis := aim.cross(pole)
	axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
	var at_shoulder := acos(clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0))
	var upper_dir := aim.rotated(axis, at_shoulder)
	arm.basis = Basis(Quaternion(Vector3.DOWN, upper_dir))
	var hand := shoulder + aim * dist
	var fore_dir := (hand - (shoulder + upper_dir * a)).normalized()
	forearms[i].basis = Basis(Quaternion(Vector3.DOWN, arm.basis.inverse() * fore_dir))
	gloves[i].visible = false
