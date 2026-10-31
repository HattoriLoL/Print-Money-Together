// Tela do monitor CRT do PC (scripts/machines/computer.gd): mostra o navegador (a textura de um
// SubViewport) com o vidro um pouco abaulado, as linhas de varredura e os cantos mais escuros.
// Sem luz: a tela brilha sozinha (e o glow do ambiente pega um pouco).
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen_tex : source_color, filter_linear, repeat_disable;
uniform float brightness = 1.1;
// Linhas de varredura na altura da imagem (pixels).
uniform float lines = 480.0;

void fragment() {
	vec2 c = UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 + 0.05 * dot(c, c));
	vec3 col = texture(screen_tex, uv).rgb;
	float scan = 0.9 + 0.1 * sin(uv.y * lines * 3.14159);
	float vignette = smoothstep(0.78, 0.38, length(c * vec2(1.0, 1.2)));
	col *= scan * mix(0.6, 1.0, vignette) * brightness;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		col = vec3(0.02);
	}
	ALBEDO = col;
}
