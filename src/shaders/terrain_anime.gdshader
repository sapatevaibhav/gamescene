// Painterly anime ground: large soft colour patches (sun-bleached meadow,
// deep mossy green), the baked path/sand colours, slope rock, and the same
// tinted cel ramp as everything else so cast shadows read as cool blue-green.
shader_type spatial;
#define TOON
#define ANIME
#include "res://src/shaders/terrain_common.gdshaderinc"

uniform vec3 shadow_tint : source_color = vec3(0.4, 0.55, 0.58);

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(0.4, 0.5, ndl) * smoothstep(0.25, 0.55, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint, vec3(1.0), lit) * fall;
}
