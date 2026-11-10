// Stylised anime foliage: alpha-cut leaf cards with "spherised" normals so a
// whole canopy shades like one soft cloud, cel ramp with tinted shadows,
// subsurface glow when back-lit, a colour gradient from inner to outer leaves
// and wind sway. Vertex COLOR.r = per-card random, COLOR.g = height in canopy.
shader_type spatial;
render_mode cull_disabled;
// The scene clock (set by the studio), so every render of a moment matches.
global uniform float scene_time;

uniform sampler2D leaf_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 top_color : source_color = vec3(0.55, 0.78, 0.3);
uniform vec3 bottom_color : source_color = vec3(0.16, 0.38, 0.2);
uniform vec3 shadow_tint : source_color = vec3(0.32, 0.5, 0.52);
uniform float alpha_cut = 0.45;
uniform float wind = 0.06;
uniform float translucency = 0.45;
uniform float ramp_edge = 0.5;

varying float v_rand;
varying float v_h;

void vertex() {
	v_rand = COLOR.r;
	v_h = COLOR.g;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 root = MODEL_MATRIX[3].xyz;
	float gust = 0.6 + 0.4 * sin(scene_time * 0.35 + root.x * 0.07 + root.z * 0.05);
	float w = sin(scene_time * 1.7 + wp.x * 0.45 + wp.z * 0.35 + v_rand * 6.0) * 0.6 + sin(scene_time * 3.1 + wp.y * 1.3 + v_rand * 12.0) * 0.4;
	VERTEX += vec3(w, w * 0.35, w * 0.7) * wind * gust * (0.35 + v_h);
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	vec3 c = mix(bottom_color, top_color, smoothstep(0.0, 1.0, v_h));
	c *= 0.86 + 0.28 * v_rand;
	ALBEDO = c * mix(0.82, 1.0, t.r);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	BACKLIGHT = vec3(translucency) * ALBEDO;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(ramp_edge - 0.08, ramp_edge + 0.08, ndl) * smoothstep(0.2, 0.6, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint, vec3(1.0), lit) * fall;
	// Back-lit leaves glow (light passing through).
	float through = pow(clamp(dot(VIEW, -LIGHT), 0.0, 1.0), 4.0) * sh;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * through * translucency * fall;
}
