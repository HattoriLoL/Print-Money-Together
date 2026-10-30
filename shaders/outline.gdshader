// Contorno preto de desenho por cima da imagem: um quadrado que cobre a tela, filho da câmera
// (player.gd). Marca linha onde a profundidade dá um degrau ou faz quina e onde a direção da
// superfície muda de repente. Pega tudo de uma vez: mapa, itens, luvas e outros jogadores.
// O que é transparente (vidro, a própria linha) não entra.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D normal_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec4 line_color : source_color = vec4(0.07, 0.05, 0.08, 1.0);
// Grossura em pixels inteiros numa tela de 720 de altura (acompanha a resolução). As amostras
// caem sempre no meio de um pixel: entre dois, a linha saía tracejada.
uniform float thickness = 2.0;
// Degrau de profundidade (relativo) e quina (1 - cosseno entre as normais) que viram linha. A
// quina pega o bevel de 45° no meio: as quinas arredondadas dos móveis caem entre os pixels e,
// sem isso, a linha delas saía tracejada.
uniform float depth_threshold = 0.035;
uniform float normal_threshold = 0.2;
// Metros em que a linha começa a sumir e some de vez (lá fora, a cidade não tem contorno).
uniform float fade_start = 9.0;
uniform float fade_end = 25.0;
// As linhas de quina somem mais perto: de longe, um sulco ou quina arredondada fica menor que um
// pixel, aparece e some de um pixel para o outro, e a linha saía tracejada. Fica a silhueta.
uniform float crease_fade_start = 2.0;
uniform float crease_fade_end = 4.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// 1 / distância: num plano ela varia em linha reta na tela, então só quinas e degraus somam.
float inv_depth(ivec2 p, ivec2 size, mat4 inv_proj) {
	p = clamp(p, ivec2(0), size - 1);
	float d = texelFetch(depth_tex, p, 0).r;
	vec2 uv = (vec2(p) + 0.5) / vec2(size);
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, d, 1.0);
	return max(v.w / -v.z, 1e-5);
}

vec3 normal_at(ivec2 p, ivec2 size) {
	return normalize(texelFetch(normal_tex, clamp(p, ivec2(0), size - 1), 0).xyz * 2.0 - 1.0);
}

void fragment() {
	ivec2 size = textureSize(depth_tex, 0);
	ivec2 p = ivec2(FRAGCOORD.xy);
	int t = max(1, int(round(thickness * float(size.y) / 720.0)));
	ivec2 dx = ivec2(t, 0);
	ivec2 dy = ivec2(0, t);
	float c = inv_depth(p, size, INV_PROJECTION_MATRIX);
	float around = inv_depth(p - dx, size, INV_PROJECTION_MATRIX) + inv_depth(p + dx, size, INV_PROJECTION_MATRIX)
			+ inv_depth(p - dy, size, INV_PROJECTION_MATRIX) + inv_depth(p + dy, size, INV_PROJECTION_MATRIX);
	float depth_edge = smoothstep(depth_threshold, depth_threshold * 1.5, abs(around - 4.0 * c) / c);

	// A quina olha os 8 vizinhos: uma quina arredondada com 1 pixel de largura escapava ora de
	// um, ora de outro, e a linha saía pontilhada.
	vec3 n = normal_at(p, size);
	float bend = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			bend = max(bend, 1.0 - dot(n, normal_at(p + ivec2(i, j) * t, size)));
		}
	}
	float normal_edge = smoothstep(normal_threshold, normal_threshold * 1.3, bend);

	float dist = 1.0 / c;
	normal_edge *= 1.0 - smoothstep(crease_fade_start, crease_fade_end, dist);
	float edge = max(depth_edge, normal_edge) * (1.0 - smoothstep(fade_start, fade_end, dist));
	ALBEDO = line_color.rgb;
	ALPHA = edge * line_color.a;
}
