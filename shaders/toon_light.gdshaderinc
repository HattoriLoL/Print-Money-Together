// Luz de desenho animado, usada pelo toon (scripts/toon.gd) e pela folha (paper.gdshader).
//
// Três tons com borda dura: sombra (só o ambiente), meia-luz e luz cheia. A conta é feita na
// luz que chega (ângulo x distância x sombra), então em volta da lâmpada a luz cai em anéis. Nas
// superfícies lisas (ROUGHNESS abaixo de 0,5) aparece um brilho duro, como uma mancha branca.

const float TOON_MID = 0.025;   // a partir daqui, meia-luz
const float TOON_FULL = 0.28;   // a partir daqui, luz cheia
const float TOON_EDGE = 0.04;   // largura da borda entre os tons (menos que isso, a sombra chia)
const float TOON_MID_LEVEL = 0.45;

void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = TOON_MID_LEVEL * smoothstep(TOON_MID, TOON_MID + TOON_EDGE, lit)
			+ (1.0 - TOON_MID_LEVEL) * smoothstep(TOON_FULL, TOON_FULL + TOON_EDGE, lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	if (ROUGHNESS < 0.5) {
		vec3 half_dir = normalize(VIEW + LIGHT);
		float shine = pow(clamp(dot(NORMAL, half_dir), 0.0, 1.0), mix(160.0, 24.0, ROUGHNESS * 2.0));
		float spot = smoothstep(0.55, 0.6, shine) * step(TOON_FULL, lit);
		SPECULAR_LIGHT += LIGHT_COLOR / PI * spot * (1.0 - ROUGHNESS * 2.0) * 0.35;
	}
}
