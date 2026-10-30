extends Node
## Vida no cenário, só visual (cada máquina anima a sua; nada passa pela rede):
## - o ventilador gira e o vento dele faz as folhas do varal tremularem; a cortina balança devagar
##   (vento no vértice, ver `wind` no toon.gd);
## - a lâmpada pelada pisca de vez em quando e balança no fio quando alguém passa perto (a luz
##   vai junto, então as sombras balançam);
## - a TV de tubo mostra chuvisco;
## - a panela de tinta solta vapor.

const Toon := preload("res://scripts/toon.gd")

## Voltas por segundo das pás do ventilador.
const FAN_SPEED := 4.0
## Vento no vértice: força (m), velocidade da onda e direção (no mundo do Godot).
const CLOTHES_WIND := [0.05, 5.0, Vector3(1, 0, 0)]
const CURTAIN_WIND := [0.025, 1.3, Vector3(0, 0, 1)]
## Altura (m) do varal no Godot: as folhas penduradas abaixo dela tremulam.
const CLOTHES_LINE_Y := 2.218
const CURTAIN_ROD_Y := 2.32

## Lâmpada: segundos entre uma piscada e outra, e o fio (pêndulo).
const FLICKER_GAP := Vector2(6.0, 15.0)
const BULB_NAME := "main_0"
const PENDULUM_LENGTH := 0.45
const PENDULUM_DAMPING := 0.8
const PENDULUM_MAX := 0.35
## Quem anda a menos disso (na horizontal) do fio empurra o ar e balança a lâmpada.
const PUSH_RADIUS := 1.1
const PUSH_STRENGTH := 1.2

## Vapor: onde fica a superfície da tinta na panela (local da MACHINE_InkPot no Godot).
const STEAM_OFFSET := Vector3(0, 0.135, 0)

var fan_blades: Node3D
var tv_material: ShaderMaterial
var steam: CPUParticles3D
## Quanto a lâmpada brilha agora (1 = normal), para o teste.
var bulb_level := 1.0
## Brilho da luz da lâmpada sem piscar.
var light_energy_full := 1.0
## Ângulo do fio (x e z, radianos).
var swing := Vector2.ZERO

var _model: Node3D
var _kitnet: Node
var _rng := RandomNumberGenerator.new()
var _light: Light3D
var _light_rest := Vector3.ZERO
var _bulb_parts: Array[Node3D] = []
var _bulb_rest: Array[Basis] = []
var _bulb_pivot := Vector3.ZERO
var _bulb_materials: Array[ShaderMaterial] = []
var _bulb_emission: Array[float] = []
var _swing_vel := Vector2.ZERO
var _flicker_wait := 0.0
## Piscada em andamento: pares [segundos, brilho].
var _flicker: Array = []
var _last_positions := {}


func setup(model: Node3D, kitnet: Node) -> void:
	name = "Ambience"
	_model = model
	_kitnet = kitnet
	_rng.randomize()
	_flicker_wait = _rng.randf_range(FLICKER_GAP.x, FLICKER_GAP.y)
	fan_blades = model.find_child("MACHINE_Fan_Blades", true, false)
	_setup_wind("MACHINE_ClothesLine", CLOTHES_WIND, CLOTHES_LINE_Y, 0.25)
	_setup_wind("Curtain_Main", CURTAIN_WIND, CURTAIN_ROD_Y, 1.4)
	_setup_bulb()
	_setup_tv()
	_setup_steam()


func _process(delta: float) -> void:
	if fan_blades != null:
		fan_blades.rotate_object_local(Vector3.FORWARD, FAN_SPEED * TAU * delta)
	_update_flicker(delta)
	_update_swing(delta)


# --- Vento --------------------------------------------------------------------

func _setup_wind(mesh_name: String, cfg: Array, top_y: float, length: float) -> void:
	var mesh: GeometryInstance3D = _model.find_child(mesh_name, true, false)
	if mesh == null:
		return
	mesh.set_instance_shader_parameter("wind", Vector4(cfg[0], top_y, length, cfg[1]))
	mesh.set_instance_shader_parameter("wind_dir", cfg[2])


# --- Lâmpada ------------------------------------------------------------------

func _setup_bulb() -> void:
	_light = _model.find_child("LIGHT_" + BULB_NAME, true, false)
	if _light != null:
		light_energy_full = _light.light_energy
		_light_rest = _light.global_position
	for part_name in ["LAMP_" + BULB_NAME, "Cord_Lamp_" + BULB_NAME]:
		var part: MeshInstance3D = _model.find_child(part_name, true, false)
		if part == null:
			continue
		_bulb_parts.append(part)
		_bulb_rest.append(part.transform.basis)
		_bulb_pivot = part.global_position
	var lamp: MeshInstance3D = _model.find_child("LAMP_" + BULB_NAME, true, false)
	if lamp == null:
		return
	# Já em versão toon (o kitnet só converte no quadro seguinte).
	Toon.apply_one(lamp)
	for i in lamp.mesh.get_surface_count():
		var mat := lamp.get_surface_override_material(i) as ShaderMaterial
		if mat != null:
			_bulb_materials.append(mat)
			_bulb_emission.append(mat.get_shader_parameter("emission_energy"))


## Começa uma piscada agora (o teste usa; no jogo vem sozinha).
func flicker_now() -> void:
	_flicker.clear()
	for i in _rng.randi_range(2, 5):
		_flicker.append([_rng.randf_range(0.04, 0.12), _rng.randf_range(0.1, 0.4)])
		_flicker.append([_rng.randf_range(0.03, 0.15), 1.0])
	_flicker_wait = _rng.randf_range(FLICKER_GAP.x, FLICKER_GAP.y)


func _update_flicker(delta: float) -> void:
	if _flicker.is_empty():
		_flicker_wait -= delta
		if _flicker_wait <= 0.0:
			flicker_now()
		_set_bulb(1.0)
		return
	_set_bulb(_flicker[0][1])
	_flicker[0][0] -= delta
	if _flicker[0][0] <= 0.0:
		_flicker.pop_front()


func _set_bulb(level: float) -> void:
	if is_equal_approx(level, bulb_level):
		return
	bulb_level = level
	if _light != null:
		_light.light_energy = light_energy_full * level
	for i in _bulb_materials.size():
		_bulb_materials[i].set_shader_parameter("emission_energy", _bulb_emission[i] * level)


## Pêndulo no fio: quem passa perto empurra o ar na direção em que anda.
func _update_swing(delta: float) -> void:
	if _bulb_parts.is_empty() or delta <= 0.0:
		return
	var players: Dictionary = _kitnet.get("players") if _kitnet != null else {}
	for id in players:
		var player: Node3D = players[id]
		if not is_instance_valid(player):
			continue
		var pos := player.global_position
		var last: Vector3 = _last_positions.get(id, pos)
		_last_positions[id] = pos
		var vel := (pos - last) / delta
		vel.y = 0.0
		var away := Vector2(pos.x - _bulb_pivot.x, pos.z - _bulb_pivot.z).length()
		if away < PUSH_RADIUS and vel.length() > 0.5:
			var push := PUSH_STRENGTH * (1.0 - away / PUSH_RADIUS) * delta
			# O bulbo fica embaixo do pivô: girar +Z leva ele para +X, girar +X leva para -Z.
			_swing_vel += Vector2(-vel.z, vel.x) * push
	var omega2 := 9.8 / PENDULUM_LENGTH
	_swing_vel += (-omega2 * swing - PENDULUM_DAMPING * _swing_vel) * delta
	swing += _swing_vel * delta
	swing = swing.limit_length(PENDULUM_MAX)
	var tilt := Basis.from_euler(Vector3(swing.x, 0.0, swing.y))
	for i in _bulb_parts.size():
		_bulb_parts[i].transform.basis = tilt * _bulb_rest[i]
	if _light != null:
		_light.global_position = _bulb_pivot + tilt * (_light_rest - _bulb_pivot)


# --- TV -----------------------------------------------------------------------

const TV_STATIC := """shader_type spatial;
render_mode unshaded;

uniform float brightness = 0.9;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	// Chuvisco em blocos grandes (cara de desenho), trocando 12 vezes por segundo, e uma faixa
	// mais escura rolando pela tela.
	vec2 cell = floor(UV * vec2(70.0, 70.0));
	float frame = floor(TIME * 12.0);
	float n = hash(cell + frame * vec2(13.17, 7.31));
	float band = smoothstep(0.0, 0.25, abs(fract(UV.y * 1.2 + UV.x * 1.2 - TIME * 0.35) - 0.5));
	vec3 col = mix(vec3(0.18, 0.22, 0.3), vec3(0.85, 0.9, 1.0), step(0.45, n) * (0.6 + 0.4 * n));
	ALBEDO = col * brightness * (0.7 + 0.3 * band);
}
"""


func _setup_tv() -> void:
	var tv: MeshInstance3D = _model.find_child("TV_Rack", true, false)
	if tv == null:
		return
	for i in tv.mesh.get_surface_count():
		var mat := tv.mesh.surface_get_material(i)
		if mat != null and mat.resource_name == "M_TVScreen":
			var shader := Shader.new()
			shader.code = TV_STATIC
			tv_material = ShaderMaterial.new()
			tv_material.shader = shader
			tv.set_surface_override_material(i, tv_material)


# --- Vapor --------------------------------------------------------------------

func _setup_steam() -> void:
	var pot: Node3D = _model.find_child("MACHINE_InkPot", true, false)
	if pot == null:
		return
	steam = CPUParticles3D.new()
	steam.name = "Steam"
	steam.position = STEAM_OFFSET
	steam.amount = 9
	steam.lifetime = 2.2
	steam.preprocess = 2.2
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.05
	steam.direction = Vector3.UP
	steam.spread = 15.0
	steam.initial_velocity_min = 0.12
	steam.initial_velocity_max = 0.18
	steam.gravity = Vector3(0, 0.02, 0)
	steam.damping_min = 0.02
	steam.damping_max = 0.05
	# Nuvenzinhas opacas (assim ganham o contorno preto): nascem pequenas, incham e somem
	# encolhendo, em vez de desbotar.
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.25))
	grow.add_point(Vector2(0.35, 1.0))
	grow.add_point(Vector2(0.8, 0.9))
	grow.add_point(Vector2(1.0, 0.0))
	steam.scale_amount_curve = grow
	steam.color = Color(0.86, 1.0, 0.88)
	var puff := SphereMesh.new()
	puff.radius = 0.04
	puff.height = 0.07
	puff.radial_segments = 12
	puff.rings = 6
	var mat := StandardMaterial3D.new()
	# Sem luz (o toon deixa como está): uma nuvenzinha chapada.
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	puff.material = mat
	steam.mesh = puff
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pot.add_child(steam)
