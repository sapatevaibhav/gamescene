// Fast stylised grass clumps (BotW-style cel look). Each instance is a pair of
// crossed cards with a painted blade texture: alpha cut-out, colour from a
// base-to-tip gradient tinted per clump, wind sway and rolling gusts, a hard
// cel band that picks up tree shadows, and a distance shrink so far clumps
// cost nothing (chunks beyond fade_end are culled on the CPU side too).
shader_type spatial;
render_mode cull_disabled;
// The scene clock (set by the studio), so every render of a moment matches.
global uniform float scene_time;

uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 base_color : source_color = vec3(0.16, 0.42, 0.17);
uniform vec3 tip_color : source_color = vec3(0.66, 0.88, 0.36);
uniform vec3 shadow_color : source_color = vec3(0.3, 0.48, 0.5);
uniform float tint_strength = 1.0;
uniform float wind_strength = 1.0;
uniform float fade_start = 22.0;
uniform float fade_end = 42.0;

varying float v_gust;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	float h = 1.0 - UV.y;
	float wave = sin(scene_time * 1.1 - (ip.x * 0.9 + ip.z * 0.55) * 0.14);
	v_gust = smoothstep(0.25, 1.0, wave);
	float sway = sin(scene_time * 2.1 + ip.x * 0.7 + ip.z * 0.45) * 0.1 + v_gust * 0.35;
	VERTEX.x += sway * h * h * wind_strength * 0.5;
	VERTEX.z += sway * h * h * wind_strength * 0.3;
	// Shrink with distance: hides the fade-out and saves fill rate.
	float d = distance(ip, INV_VIEW_MATRIX[3].xyz);
	float k = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX.y *= k;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 t = texture(grass_tex, UV);
	if (t.a < 0.5) {
		discard;
	}
	float h = 1.0 - UV.y;
	vec3 grass = mix(base_color, tip_color, smoothstep(0.0, 0.9, h)) * COLOR.rgb;
	vec3 c = mix(t.rgb * COLOR.rgb, grass * mix(0.85, 1.0, t.r), tint_strength);
	c += vec3(0.08, 0.1, 0.02) * v_gust * h * tint_strength;
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(0.3, 0.5, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_color, vec3(1.0), lit) * fall;
}
