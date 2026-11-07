// Painterly cel-shaded surfaces for nature and ruins: rock, bark, stone,
// with world-space colour breakup, optional bark grooves and moss that grows
// on upward-facing areas. Same tinted-shadow ramp as the character shader.
shader_type spatial;

uniform vec4 albedo : source_color = vec4(0.62, 0.63, 0.66, 1.0);
uniform vec4 albedo2 : source_color = vec4(0.48, 0.5, 0.56, 1.0);
uniform vec4 moss_color : source_color = vec4(0.36, 0.58, 0.24, 1.0);
uniform vec3 shadow_tint : source_color = vec3(0.62, 0.64, 0.82);
uniform float moss = 0.0;
uniform float grooves = 0.0;
uniform float detail_scale = 1.5;
uniform float rim_amount = 0.18;

varying vec3 w_pos;
varying vec3 w_nrm;
varying vec3 l_pos;

float h3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float n3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	l_pos = VERTEX;
}

void fragment() {
	vec3 p = w_pos * detail_scale;
	float n = n3(p) * 0.55 + n3(p * 2.3) * 0.3 + n3(p * 6.1) * 0.15;
	vec3 c = mix(albedo2.rgb, albedo.rgb, smoothstep(0.3, 0.7, n));
	if (grooves > 0.0) {
		float ang = atan(l_pos.z, l_pos.x);
		float g = sin(ang * 14.0 + n3(vec3(l_pos.y * 3.0, 0.0, 0.0)) * 3.0 + l_pos.y * 0.6);
		c *= mix(1.0, smoothstep(-0.6, 0.6, g) * 0.35 + 0.7, grooves);
	}
	if (moss > 0.0) {
		float m = smoothstep(0.35, 0.75, w_nrm.y + (n - 0.5) * 0.6) * moss;
		c = mix(c, moss_color.rgb * (0.85 + 0.3 * n3(p * 3.0)), m);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * 0.5 + 0.5;
	float sh = LIGHT_IS_DIRECTIONAL ? ATTENUATION : 1.0;
	float lit = smoothstep(0.42, 0.52, ndl) * smoothstep(0.25, 0.55, sh);
	float fall = LIGHT_IS_DIRECTIONAL ? 1.0 : ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * mix(shadow_tint * 0.85, vec3(1.0), lit) * fall;
	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.65, 0.75, fres) * lit * rim_amount * ALBEDO * fall;
}
