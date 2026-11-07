// Anime cel shading (open-world fantasy look): a soft two-tone light ramp,
// tinted (not black) shadows, cast shadows folded into the ramp, a rim light
// on the lit side and an optional anime hair highlight band.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 shadow_tint : source_color = vec3(0.72, 0.7, 0.86);
uniform float ramp_edge = 0.46;
uniform float ramp_soft = 0.02;
uniform float rim_amount = 0.28;
uniform float hair_spec = 0.0;
uniform float spec_amount = 0.0;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(ramp_edge - ramp_soft, ramp_edge + ramp_soft, ndl) * smoothstep(0.25, 0.55, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	vec3 tone = mix(shadow_tint * 0.82, vec3(1.0), lit);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * tone * fall;
	// Rim light on the lit side.
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.62, 0.72, fres) * lit * rim_amount;
	SPECULAR_LIGHT += LIGHT_COLOR / PI * rim * fall * ALBEDO;
	// Anime hair ring / soft specular.
	vec3 hv = normalize(VIEW + LIGHT);
	float ndh = max(dot(NORMAL, hv), 0.0);
	if (hair_spec > 0.0) {
		float band = smoothstep(0.86, 0.9, ndh) * (1.0 - smoothstep(0.96, 0.99, ndh));
		SPECULAR_LIGHT += LIGHT_COLOR / PI * band * hair_spec * lit * fall;
	}
	if (spec_amount > 0.0) {
		SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.95, 0.97, ndh) * spec_amount * lit * fall;
	}
}
