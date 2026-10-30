extends RefCounted
## Visual de desenho animado: troca os StandardMaterial3D (os do kitnet.glb e os criados no código)
## por um shader com a luz em faixas (shaders/toon_light.gdshaderinc). As texturas perdem parte
## do detalhe e ficam perto da cor média delas, como pintadas à mão. O contorno preto é outro
## passe (shaders/outline.gdshader, na câmera do jogador).
##
## O kitnet.gd chama apply_one() em toda malha que entra na cena. Quem troca um material depois
## (material_override) passa ele por material(); quem muda a cor de um já convertido chama sync().

## Quanto as texturas vão para a cor média (0 = como foram pintadas, 1 = cor lisa).
const FLATTEN := 0.15

const CODE := """shader_type spatial;
render_mode %s;
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_vertex_color = false;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float flatten = 0.55;
uniform float roughness = 1.0;
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 1.0;
uniform sampler2D emission_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float alpha_scissor = 0.5;

void vertex() {
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	// A média da textura (o último mipmap): o detalhe fino some e a cor fica chapada.
	vec3 avg = textureLod(albedo_tex, UV, 12.0).rgb;
	vec3 col = mix(tex.rgb, avg, flatten) * albedo.rgb;
	if (use_vertex_color) {
		col *= COLOR.rgb;
	}
	ALBEDO = col;
	ROUGHNESS = roughness;
	EMISSION = emission * emission_energy * texture(emission_tex, UV).rgb;
	%s
}
"""

static var _shaders := {}
static var _converted := {}
## Os materiais toon criados aqui (para saber que um override é nosso, e não de quem criou a malha).
static var _made := {}


## Converte os materiais de `root` e de tudo embaixo dele.
static func apply(root: Node) -> void:
	if root is GeometryInstance3D:
		apply_one(root)
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		apply_one(node)


## O material em versão toon (o mesmo objeto sempre que o original for o mesmo).
static func material(mat: Material) -> Material:
	if not (mat is BaseMaterial3D) or mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		return mat
	if _converted.has(mat):
		return _converted[mat]
	var toon := ShaderMaterial.new()
	toon.shader = _shader_for(mat)
	toon.render_priority = mat.render_priority
	_converted[mat] = toon
	_made[toon] = true
	sync(mat)
	return toon


## Copia de novo cor, textura e brilho do original para a versão toon (o original mudou).
static func sync(mat: BaseMaterial3D) -> void:
	var toon: ShaderMaterial = _converted.get(mat)
	if toon == null:
		return
	toon.set_shader_parameter("albedo", mat.albedo_color)
	toon.set_shader_parameter("albedo_tex", mat.albedo_texture)
	toon.set_shader_parameter("use_vertex_color", mat.vertex_color_use_as_albedo)
	toon.set_shader_parameter("uv1_scale", mat.uv1_scale)
	toon.set_shader_parameter("uv1_offset", mat.uv1_offset)
	toon.set_shader_parameter("flatten", FLATTEN)
	# Metal sem reflexo vira só uma superfície lisa: o brilho duro já diz "metal".
	toon.set_shader_parameter("roughness", mat.roughness * (1.0 - mat.metallic * 0.6))
	var lit := mat.emission_enabled
	toon.set_shader_parameter("emission", mat.emission if lit else Color.BLACK)
	toon.set_shader_parameter("emission_energy", mat.emission_energy_multiplier)
	toon.set_shader_parameter("emission_tex", mat.emission_texture if lit else null)
	toon.set_shader_parameter("alpha_scissor", mat.alpha_scissor_threshold)


static func apply_one(node: GeometryInstance3D) -> void:
	if node.material_override:
		node.material_override = material(node.material_override)
	var mesh_node := node as MeshInstance3D
	if mesh_node == null or mesh_node.mesh == null:
		return
	# Um override toon antigo é refeito a partir da malha (ela pode ter sido trocada).
	for i in mesh_node.mesh.get_surface_count():
		var mat := mesh_node.get_surface_override_material(i)
		if mat == null or _made.has(mat):
			mat = mesh_node.mesh.surface_get_material(i)
		var toon := material(mat)
		if toon != mat:
			mesh_node.set_surface_override_material(i, toon)


## Um shader por combinação de render_mode (transparência e lados da face).
static func _shader_for(mat: BaseMaterial3D) -> Shader:
	var modes: Array[String] = []
	var alpha := ""
	match mat.transparency:
		BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS:
			modes.append("blend_mix")
			modes.append("depth_draw_opaque")
			alpha = "ALPHA = albedo.a * tex.a;"
		BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR, BaseMaterial3D.TRANSPARENCY_ALPHA_HASH:
			alpha = "ALPHA = albedo.a * tex.a;\n\tALPHA_SCISSOR_THRESHOLD = alpha_scissor;"
	match mat.cull_mode:
		BaseMaterial3D.CULL_DISABLED:
			modes.append("cull_disabled")
		BaseMaterial3D.CULL_FRONT:
			modes.append("cull_front")
	if mat.no_depth_test:
		modes.append("depth_test_disabled")
	if modes.is_empty():
		modes.append("cull_back")
	var key := ",".join(modes) + "|" + alpha
	if not _shaders.has(key):
		var shader := Shader.new()
		shader.code = CODE % [", ".join(modes), alpha]
		_shaders[key] = shader
	return _shaders[key]
