// Shared body of toon_tex (single-sided) and toon_tex_ds (double-sided leaves).

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = false;
uniform float alpha_cut = 0.0;
uniform vec3 shadow_tint : source_color = vec3(0.68, 0.68, 0.86);
uniform float rim_amount = 0.22;
uniform float wind = 0.0;
uniform float model_height = 4.0;

void vertex() {
	if (wind > 0.0) {
		vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float h = clamp(VERTEX.y / max(model_height, 0.1), 0.0, 1.0);
		float w = sin(TIME * 1.7 + wp.x * 0.45 + wp.z * 0.35) * 0.6 + sin(TIME * 3.1 + wp.y * 1.3) * 0.4;
		VERTEX += vec3(w, w * 0.3, w * 0.7) * wind * h * h;
	}
}

void fragment() {
	vec4 c = albedo;
	if (use_tex) {
		c *= texture(albedo_tex, UV);
	}
	if (alpha_cut > 0.0 && c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(0.44, 0.48, ndl) * smoothstep(0.25, 0.55, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint * 0.85, vec3(1.0), lit) * fall;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.65, 0.72, fres) * lit * rim_amount * ALBEDO * fall;
}
