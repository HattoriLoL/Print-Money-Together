// Folha A4 impressa (frente e verso) com a fibra do papel e um pouco de vida: a borda de longe
// cede quando alguém segura pela de perto, as pontas levantam um tico quando está apoiada, e
// ela tremula com o vento de quem anda. Tinta molhada fica mais escura e brilhando.
//
// Malha: PlaneMesh deitado (normal +Y), comprido em X; UV.x ao longo de X, UV.y ao longo de Z
// (UV.y = 1 é a borda +Z, a de perto de quem segura). Os parâmetros por folha são "instance
// uniform": cada item muda os seus sem duplicar o material.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D front_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D back_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D paper_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 sheet_size = vec2(0.297, 0.21);

// Metros que a borda de longe cai (segurando pela de perto).
instance uniform float droop = 0.0;
// Metros que as pontas levantam (papel apoiado nunca fica 100% liso).
instance uniform float curl = 0.002;
// Amplitude do tremor (vento de quem anda).
instance uniform float flutter = 0.0;
// 0 = seca, 1 = tinta fresca.
instance uniform float wet = 0.0;

float far_edge(vec2 uv) {
	return 1.0 - uv.y;
}

float height(vec2 uv, float t) {
	float far = far_edge(uv);
	vec2 c = uv * 2.0 - 1.0;
	float h = -droop * far * far;
	h += curl * (c.x * c.x * c.x * c.x + c.y * c.y * c.y * c.y);
	h += flutter * sin(t * 11.0 + uv.x * 7.0 + uv.y * 3.0) * far;
	return h;
}

void vertex() {
	float t = TIME;
	VERTEX.y += height(UV, t);
	// Normal da superfície curvada (diferença finita), para a luz acompanhar a dobra.
	float e = 0.02;
	float dx = (height(UV + vec2(e, 0.0), t) - height(UV - vec2(e, 0.0), t)) / (2.0 * e * sheet_size.x);
	float dz = (height(UV + vec2(0.0, e), t) - height(UV - vec2(0.0, e), t)) / (2.0 * e * sheet_size.y);
	NORMAL = normalize(vec3(-dx, 1.0, -dz));
}

void fragment() {
	vec3 col = FRONT_FACING ? texture(front_tex, UV).rgb : texture(back_tex, vec2(1.0 - UV.x, UV.y)).rgb;
	ALBEDO = mix(col, col * vec3(0.78, 0.84, 0.78), wet);
	ROUGHNESS = mix(0.82, 0.16, wet);
	SPECULAR = mix(0.25, 0.75, wet);
	NORMAL_MAP = texture(paper_normal, UV * vec2(9.0, 6.4)).rgb;
	NORMAL_MAP_DEPTH = mix(0.6, 0.15, wet);
}
