extends Node3D
## Boneco de desenho dos jogadores (assets/models/character.glb, montado por
## art_source/blender/character.py): um adulto desengonçado e cansado, de moletom. Todos usam o
## mesmo boneco: a vaga escolhe a cor do moletom e o acessório. O corpo é uma malha só com
## esqueleto (a cabeça, as luvas, os tênis e os detalhes do moletom vão presos nos ossos), e a
## animação é feita aqui, por código, girando os ossos:
## - andando: pernas e braços balançam, o joelho dobra quando a perna vem para frente, o corpo
##   quica e rebola; os pés ficam sempre retos no chão. As pernas dão o passo para o lado em que
##   o corpo está indo de verdade: empurrado de lado ou de costas, ele tropeça para lá;
## - parado: respira, com os cotovelos meio dobrados;
## - no ar: joelhos encolhidos e braços para cima;
## - empurrado (push): o tronco inclina para o lado do empurrão e volta balançando numa mola,
##   como gelatina, e o resto vem atrasado, cada parte com a sua mola: o peito, a cabeça e os
##   braços, que chicoteiam para fora;
## - trombada (impact): além disso o corpo achata e volta (squash e stretch);
## - caído (start_ragdoll / end_ragdoll): ragdoll parcial, ossos de física (PhysicalBone3D) que
##   tombam e rolam com o tranco; ao levantar, a animação sai da pose de pano aos poucos;
## - segurando um item: ombro e cotovelo se ajustam (IK de dois ossos) para a mão chegar nas
##   luvas que seguram o item (hands.glb, do player.gd), e as luvas do boneco somem.
##
## Os ossos olham para +Y local; o modelo olha para +Z (o setup gira para a frente do jogador).
## Os giros são dados no espaço do esqueleto, em cima da pose de descanso.

const MODEL := preload("res://assets/models/character.glb")
## Acessório de cada vaga (0 a 3).
const ACCESSORIES: Array[String] = ["Acc_Cap", "Acc_Glasses", "Acc_Quiff", "Acc_Beanie"]
## Braço aberto além do descanso (contornando a barriga) e o cotovelo meio dobrado parado.
const ARM_SPLAY := 0.1
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
## Mola do balanço do tronco quando é empurrado: dureza, amortecimento e a inclinação máxima.
const WOBBLE_STIFFNESS := 70.0
const WOBBLE_DAMPING := 7.0
const WOBBLE_MAX := 0.45
## O peito e a cabeça vêm atrasados no empurrão (giram ao contrário do tronco no começo e depois
## passam do ponto): quanto do empurrão eles levam ao contrário, e a mola de cada um (dureza e
## amortecimento). Molas mais moles que a do tronco: o balanço desce o corpo como uma onda.
const CHEST_LAG := 0.55
const CHEST_SPRING := Vector2(50.0, 5.0)
const HEAD_LAG := 0.7
const HEAD_SPRING := Vector2(38.0, 4.0)
## Braços: quanto ficam para trás (contra o balanço do tronco) e quanto abrem para fora.
const ARM_FLAIL := 0.14
const ARM_FLAIL_OUT := 0.25
## Achatar na trombada: quanto achata por m/s de choque, a mola e o máximo.
const SQUASH_PER_SPEED := 0.6
const SQUASH_SPRING := Vector2(140.0, 9.0)
const SQUASH_MAX := 0.18

var slot := 0
var model: Node3D
var skeleton: Skeleton3D
## Índice 0 = direita, 1 = esquerda (a mesma ordem das luvas do player.gd).
var gloves: Array[Node3D] = []
## A mão que o boneco perdeu na guilhotina (a luva dela não aparece mais).
var glove_lost: Array[bool] = [false, false]
var accessory: Node3D
## Último giro de cada coxa e joelho (radianos; para o teste e para quem quiser ler).
var leg_angles := [0.0, 0.0]
var knee_angles := [0.0, 0.0]

var _bones := {}
var _rest := {}
var _rest_pos := {}
var _phase := 0.0
var _time := 0.0
var _swing := 0.0
var _air := 0.0
## Inclinação do tronco pelo empurrão (no espaço do esqueleto: x e z são a direção para onde o
## alto do tronco vai, o tamanho é o ângulo) e a velocidade dela.
var lean := Vector3.ZERO
var _lean_vel := Vector3.ZERO
## O mesmo para o peito e a cabeça (atrasados) e o quanto o corpo está achatado.
var chest_lean := Vector3.ZERO
var head_lean := Vector3.ZERO
var squash := 0.0
var _chest_vel := Vector3.ZERO
var _head_vel := Vector3.ZERO
var _squash_vel := 0.0
## Para onde as pernas dão o passo (no espaço do esqueleto; a frente é +Z).
var _step_dir := Vector3(0, 0, 1)


func setup(player_slot: int, color: Color) -> void:
	name = "Character"
	slot = player_slot
	model = MODEL.instantiate()
	# O boneco olha para +Z no modelo; o jogador olha para -Z.
	model.rotation.y = PI
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	for i in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(i)
		_bones[bone_name] = i
		_rest[i] = skeleton.get_bone_global_rest(i).basis.orthonormalized()
		_rest_pos[i] = skeleton.get_bone_rest(i).origin
	for side in ["R", "L"]:
		gloves.append(model.find_child("Char_Glove_" + side, true, false))
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


## Empurrão no tronco: `dir` (no mundo) é para onde o empurrão leva, `amount` o quanto (rad/s). O
## peito e a cabeça ficam para trás (vêm atrasados).
func push(dir: Vector3, amount: float) -> void:
	var local := _to_skeleton(dir)
	if local == Vector3.ZERO:
		return
	_lean_vel += local * amount
	_chest_vel -= local * amount * CHEST_LAG
	_head_vel -= local * amount * HEAD_LAG


## Trombada: um empurrão de uma vez (`speed` = quão rápido eles se chocaram, m/s) e o corpo achata.
func impact(dir: Vector3, speed: float) -> void:
	push(dir, speed * 1.1)
	_squash_vel += speed * SQUASH_PER_SPEED * 10.0


## Direção do mundo no espaço do esqueleto, na horizontal e com tamanho 1 (ou zero).
func _to_skeleton(dir: Vector3) -> Vector3:
	var local := skeleton.global_basis.orthonormalized().inverse() * dir
	local.y = 0.0
	return local.normalized() if local.length() > 0.001 else Vector3.ZERO


## Mola amortecida: devolve o novo valor e a nova velocidade.
static func _spring(value, vel, spring: Vector2, delta: float) -> Array:
	vel += (-spring.x * value - spring.y * vel) * delta
	return [value + vel * delta, vel]


## Giro que leva o alto (+Y) para o lado de `lean` (tamanho = ângulo).
static func _tilt(lean_vec: Vector3) -> Basis:
	if lean_vec.length() < 0.0001:
		return Basis.IDENTITY
	return Basis(Vector3.UP.cross(lean_vec).normalized(), lean_vec.length())


## Onde está o pulso da mão `i` (0 = direita), no mundo.
func hand_position(i: int) -> Vector3:
	var hand: int = _bones["Hand.R" if i == 0 else "Hand.L"]
	return skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)


## Um quadro de animação. `velocity` no mundo; `pitch` é o olhar (radianos, + para cima);
## `hold_targets` são os pulsos das luvas segurando um item ([direita, esquerda]) ou vazio.
func animate(delta: float, velocity: Vector3, airborne: bool, pitch: float, hold_targets: Array = []) -> void:
	_time += delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	# O passo vai para onde o corpo está indo (de lado e de costas também: empurrado, tropeça).
	var moving := _to_skeleton(flat)
	if speed > 0.2 and moving != Vector3.ZERO:
		_step_dir = _step_dir.slerp(moving, clampf(10.0 * delta, 0.0, 1.0)).normalized()
	_phase += speed * STRIDE * TAU * delta * 0.5
	var target_swing := clampf(speed / WALK_SPEED, 0.0, 1.4) if not airborne else 0.0
	_swing = lerpf(_swing, target_swing, clampf(10.0 * delta, 0.0, 1.0))
	_air = lerpf(_air, 1.0 if airborne else 0.0, clampf(12.0 * delta, 0.0, 1.0))
	var s := sin(_phase)
	var c := cos(_phase)

	# Balanço do empurrão: cada parte volta para o lugar na sua mola (o tronco, o peito e a
	# cabeça) e o corpo desachata.
	var r := _spring(lean, _lean_vel, Vector2(WOBBLE_STIFFNESS, WOBBLE_DAMPING), delta)
	lean = (r[0] as Vector3).limit_length(WOBBLE_MAX)
	_lean_vel = r[1]
	r = _spring(chest_lean, _chest_vel, CHEST_SPRING, delta)
	chest_lean = (r[0] as Vector3).limit_length(WOBBLE_MAX)
	_chest_vel = r[1]
	r = _spring(head_lean, _head_vel, HEAD_SPRING, delta)
	head_lean = (r[0] as Vector3).limit_length(WOBBLE_MAX)
	_head_vel = r[1]
	r = _spring(squash, _squash_vel, SQUASH_SPRING, delta)
	squash = clampf(r[0], -SQUASH_MAX, SQUASH_MAX)
	_squash_vel = r[1]
	var tilt := _tilt(lean)

	# Tronco: quica a cada passo, curva para frente e rebola; o peito respira parado.
	var spine: int = _bones["Spine"]
	skeleton.set_bone_pose_position(spine, _rest_pos[spine] + Vector3(0.0, absf(s) * BOUNCE * _swing + _air * 0.03, 0.0))
	_turn(spine, tilt * Basis.from_euler(Vector3(SLOUCH + 0.05 * _swing, 0.0, s * WADDLE * _swing)))
	# Achatado na trombada: mais baixo e mais largo (o volume fica parecido).
	skeleton.set_bone_pose_scale(spine, Vector3(1.0 + squash * 0.5, 1.0 - squash, 1.0 + squash * 0.5))
	var chest: int = _bones["Chest"]
	_turn(chest, _tilt(chest_lean))
	var breathe := sin(_time * 2.2) * 0.018 * (1.0 - _swing)
	skeleton.set_bone_pose_scale(chest, Vector3(1.0 - breathe * 0.5, 1.0 + breathe, 1.0 - breathe * 0.5))
	# Cabeça: acompanha metade do olhar, chacoalha um pouco no passo e balança atrasada.
	_turn(_bones["Head"], _tilt(head_lean) * Basis.from_euler(Vector3(-pitch * 0.5 + absf(s) * 0.05 * _swing, 0.0, -s * 0.06 * _swing)))

	# Pernas (girar + leva o pé para trás). O joelho dobra quando a perna vem para frente e
	# encolhe no ar; o pé fica reto.
	leg_angles = [s * LEG_SWING * _swing - _air * 0.35, -s * LEG_SWING * _swing - _air * 0.75]
	knee_angles = [KNEE_BEND * _swing * (0.15 + maxf(0.0, -c)) + _air * 0.9,
			KNEE_BEND * _swing * (0.15 + maxf(0.0, c)) + _air * 1.2]
	var step_axis := Vector3.UP.cross(_step_dir).normalized()
	for i in 2:
		var side := "R" if i == 0 else "L"
		_turn(_bones["Thigh." + side], Basis(step_axis, leg_angles[i]))
		_turn(_bones["Shin." + side], Basis(Vector3.RIGHT, knee_angles[i]))
		_set_global(_bones["Foot." + side], _rest[_bones["Foot." + side]])

	if hold_targets.size() == 2:
		for i in 2:
			_reach(i, hold_targets[i])
	else:
		_pose_arms(s * ARM_SWING * _swing, _air)
	_blend_getup(delta)


## Braços soltos: balançam ao contrário das pernas (o cotovelo dobra mais quando o braço vai para
## frente) e sobem no ar.
func _pose_arms(swing: float, air: float) -> void:
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var tag := "R" if i == 0 else "L"
		var fwd := -swing if i == 0 else swing
		# Os braços ficam para trás do balanço do tronco e abrem para fora (chicote).
		var whip := _lean_vel * ARM_FLAIL
		var flail := _tilt(whip) if whip.length() > 0.001 else Basis.IDENTITY
		var out := minf(_lean_vel.length() * ARM_FLAIL_OUT, 1.0)
		_turn(_bones["UpperArm." + tag], flail * Basis.from_euler(Vector3(fwd, 0.0, (ARM_SPLAY + air * 1.4 + out) * side)))
		var elbow := ELBOW_REST + maxf(0.0, -fwd) * 0.8 + air * 0.3
		_turn(_bones["Forearm." + tag], Basis(Vector3.RIGHT, -elbow))
		gloves[i].visible = not glove_lost[i]


## IK de dois ossos: a mão do braço `i` vai até `target` (no mundo), com o cotovelo apontando
## para baixo, para fora e um pouco para trás. Se não alcança, o braço estica reto na direção.
func _reach(i: int, target: Vector3) -> void:
	var tag := "R" if i == 0 else "L"
	var upper: int = _bones["UpperArm." + tag]
	var fore: int = _bones["Forearm." + tag]
	var hand: int = _bones["Hand." + tag]
	var shoulder := skeleton.get_bone_global_pose(upper).origin
	var a := (skeleton.get_bone_global_rest(fore).origin - skeleton.get_bone_global_rest(upper).origin).length()
	var b := (skeleton.get_bone_global_rest(hand).origin - skeleton.get_bone_global_rest(fore).origin).length()
	var to_target := skeleton.to_local(target) - shoulder
	var dist := clampf(to_target.length(), 0.05, a + b - 0.001)
	var aim := to_target.normalized() if to_target.length() > 0.001 else Vector3.DOWN
	var side := -1.0 if i == 0 else 1.0
	var pole := Vector3(side * 0.6, -1.0, -0.4)
	var axis := aim.cross(pole)
	axis = axis.normalized() if axis.length() > 0.001 else Vector3.RIGHT
	var at_shoulder := acos(clampf((a * a + dist * dist - b * b) / (2.0 * a * dist), -1.0, 1.0))
	var upper_dir := aim.rotated(axis, at_shoulder)
	var hand_at := shoulder + aim * dist
	var fore_dir := (hand_at - (shoulder + upper_dir * a)).normalized()
	_aim(upper, upper_dir)
	_aim(fore, fore_dir)
	gloves[i].visible = false



# --- Ragdoll -------------------------------------------------------------------------------------

## Ossos de física do ragdoll: nome -> (comprimento, raio, massa, abertura da junta em graus).
## A junta fica no começo do osso (onde ele gira); mãos, pés e pescoço vão junto com o pai.
const RAGDOLL_BONES := {
	"Hips": [0.12, 0.15, 10.0, 0.0],
	"Spine": [0.2, 0.16, 10.0, 25.0],
	"Chest": [0.18, 0.14, 8.0, 25.0],
	"Head": [0.22, 0.13, 4.0, 40.0],
	"UpperArm.L": [0.3, 0.05, 2.0, 80.0],
	"UpperArm.R": [0.3, 0.05, 2.0, 80.0],
	"Forearm.L": [0.3, 0.045, 1.5, 70.0],
	"Forearm.R": [0.3, 0.045, 1.5, 70.0],
	"Thigh.L": [0.35, 0.07, 5.0, 60.0],
	"Thigh.R": [0.35, 0.07, 5.0, 60.0],
	"Shin.L": [0.32, 0.06, 3.5, 60.0],
	"Shin.R": [0.32, 0.06, 3.5, 60.0],
}
## Quanto dura levantar (a pose de pano vira a pose em pé), em segundos.
const GETUP_TIME := 0.7

## Caído, com a física mandando nos ossos.
var ragdolling := false
## De 0 (acabou de levantar) a 1 (de pé de novo, a animação manda sozinha).
var getup := 1.0
var _sim: PhysicalBoneSimulator3D
var _pbones := {}
## Pose de cada osso no fim do ragdoll (local, em relação ao pai), para levantar daí.
var _snapshot := {}
## Onde os quadris estavam no mundo no fim do ragdoll (a cápsula do jogador pode ter ido para lá).
var _hips_world := Transform3D.IDENTITY


func _build_ragdoll() -> void:
	_sim = PhysicalBoneSimulator3D.new()
	_sim.name = "Ragdoll"
	skeleton.add_child(_sim)
	for bone_name: String in RAGDOLL_BONES:
		var spec: Array = RAGDOLL_BONES[bone_name]
		var length: float = spec[0]
		var radius: float = spec[1]
		var pb := PhysicalBone3D.new()
		pb.name = "PB_" + bone_name.replace(".", "_")
		pb.bone_name = bone_name
		pb.mass = spec[2]
		pb.friction = 0.9
		pb.linear_damp = 0.4
		pb.angular_damp = 3.0
		# Só bate no mundo: não empurra os jogadores, os itens nem os próprios ossos.
		pb.collision_layer = 0
		pb.collision_mask = 1
		var shape := CollisionShape3D.new()
		if bone_name == "Head":
			var ball := SphereShape3D.new()
			ball.radius = radius
			shape.shape = ball
		else:
			var cap := CapsuleShape3D.new()
			cap.radius = radius
			cap.height = maxf(length, radius * 2.0 + 0.01)
			shape.shape = cap
		pb.add_child(shape)
		# O corpo fica no meio do osso; a junta, no começo dele.
		pb.body_offset = Transform3D(Basis.IDENTITY, Vector3(0, length / 2.0, 0))
		pb.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0, -length / 2.0, 0))
		if bone_name == "Hips":
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		else:
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			pb.set("joint_constraints/swing_span", spec[3])
			pb.set("joint_constraints/twist_span", 20.0)
		_sim.add_child(pb)
		_pbones[_bones[bone_name]] = pb


## Cai: a física passa a mandar nos ossos, a partir da pose de agora, com o tranco `speed` (m/s)
## para o lado `dir` (no mundo) e um pulinho para cima.
func start_ragdoll(dir: Vector3, speed: float) -> void:
	if ragdolling:
		return
	if _sim == null:
		_build_ragdoll()
	ragdolling = true
	getup = 0.0
	_snapshot.clear()
	var to_world := skeleton.global_transform
	for bone: int in _pbones:
		var pb: PhysicalBone3D = _pbones[bone]
		pb.global_transform = to_world * skeleton.get_bone_global_pose(bone) * pb.body_offset
	_sim.physical_bones_start_simulation()
	var flat := Vector3(dir.x, 0.0, dir.z).normalized()
	for bone: int in _pbones:
		var pb: PhysicalBone3D = _pbones[bone]
		# O alto do corpo vai mais (tomba), os pés quase ficam (tropeça neles).
		var height := clampf((pb.global_position.y - global_position.y) / 1.6, 0.0, 1.0)
		pb.linear_velocity = flat * speed * (0.35 + 0.65 * height) + Vector3.UP * 1.0
		pb.angular_velocity = flat.cross(Vector3.UP) * -speed * 1.5


## Onde os quadris do ragdoll estão agora, no mundo.
func ragdoll_hips() -> Vector3:
	var pb: PhysicalBone3D = _pbones.get(_bones["Hips"])
	return pb.global_position if pb != null and ragdolling else skeleton.to_global(skeleton.get_bone_global_pose(_bones["Hips"]).origin)


## Posição da cabeça do ragdoll no mundo (para a câmera de quem caiu ir junto).
func ragdoll_head() -> Vector3:
	var pb: PhysicalBone3D = _pbones.get(_bones["Head"])
	return pb.global_position if pb != null else global_position + Vector3.UP * 1.6


## Levanta: guarda a pose de pano (para a animação sair dela aos poucos) e desliga a física.
func end_ragdoll() -> void:
	if not ragdolling:
		return
	var from_world := skeleton.global_transform.affine_inverse()
	var globals := {}
	for bone in skeleton.get_bone_count():
		var parent := skeleton.get_bone_parent(bone)
		var g: Transform3D
		if _pbones.has(bone):
			var pb: PhysicalBone3D = _pbones[bone]
			g = from_world * pb.global_transform * pb.body_offset.affine_inverse()
		elif parent >= 0:
			g = globals[parent] * skeleton.get_bone_pose(bone)
		else:
			g = skeleton.get_bone_global_pose(bone)
		globals[bone] = g
		var local := g if parent < 0 else (globals[parent] as Transform3D).affine_inverse() * g
		_snapshot[bone] = local.orthonormalized()
	_hips_world = skeleton.global_transform * globals[_bones["Hips"]]
	_sim.physical_bones_stop_simulation()
	ragdolling = false
	getup = 0.0


## Depois de levantar: a pose da animação vai saindo da pose de pano (os quadris, que são a raiz,
## saem de onde ficaram no mundo, mesmo que a cápsula tenha ido para lá).
func _blend_getup(delta: float) -> void:
	if getup >= 1.0 or _snapshot.is_empty():
		return
	getup = minf(1.0, getup + delta / GETUP_TIME)
	var t := smoothstep(0.0, 1.0, getup)
	var hips: int = _bones["Hips"]
	_snapshot[hips] = skeleton.global_transform.affine_inverse() * _hips_world
	for bone: int in _snapshot:
		var snap: Transform3D = _snapshot[bone]
		var rot := snap.basis.get_rotation_quaternion().slerp(skeleton.get_bone_pose_rotation(bone), t)
		skeleton.set_bone_pose_rotation(bone, rot)
		if bone == hips:
			skeleton.set_bone_pose_position(bone, snap.origin.lerp(skeleton.get_bone_pose_position(bone), t))

# --- Ossos ---------------------------------------------------------------------------------------

## Põe o osso com esta orientação no espaço do esqueleto (o pai já posado).
func _set_global(bone: int, global_rot: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var parent_rot := skeleton.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis.IDENTITY
	skeleton.set_bone_pose_rotation(bone, (parent_rot.inverse() * global_rot).get_rotation_quaternion())


## Gira o osso por `turn` (no espaço do esqueleto) em cima do descanso, levando junto o quanto o
## pai já girou.
func _turn(bone: int, turn: Basis) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var carried := Basis.IDENTITY
	if parent >= 0:
		carried = skeleton.get_bone_global_pose(parent).basis.orthonormalized() * (_rest[parent] as Basis).inverse()
	_set_global(bone, carried * turn * _rest[bone])


## Aponta o osso (o +Y dele) para `dir`, no espaço do esqueleto.
func _aim(bone: int, dir: Vector3) -> void:
	var rest: Basis = _rest[bone]
	_set_global(bone, Basis(Quaternion(rest.y.normalized(), dir.normalized())) * rest)
