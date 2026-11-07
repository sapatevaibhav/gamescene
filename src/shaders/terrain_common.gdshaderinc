// Shared terrain shading: baked vertex colours (linear) + world-space detail
// noise + slope rock tint + soft path/sand grain. Variants set TOON / FLAT.

uniform vec4 rock_color : source_color = vec4(0.6, 0.62, 0.64, 1.0);
uniform float detail_amount = 0.12;
uniform float rock_mix = 0.65;

varying vec3 w_pos;
varying vec3 w_nrm;

float t_hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float t_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(t_hash(i), t_hash(i + vec2(1.0, 0.0)), u.x), mix(t_hash(i + vec2(0.0, 1.0)), t_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n = t_noise(w_pos.xz * 0.35) * 0.45 + t_noise(w_pos.xz * 1.7) * 0.3 + t_noise(w_pos.xz * 7.3) * 0.15 + t_noise(w_pos.xz * 29.0) * 0.1;
	c *= mix(1.0 - detail_amount, 1.0 + detail_amount, n);
	float slope = 1.0 - clamp(w_nrm.y, 0.0, 1.0);
	float rk = smoothstep(0.22, 0.42, slope + (n - 0.5) * 0.12) * rock_mix;
	vec3 rock = rock_color.rgb * mix(0.82, 1.12, t_noise(w_pos.xz * 3.1 + w_pos.y));
	c = mix(c, rock, rk);
#ifdef ANIME
	float big = t_noise(w_pos.xz * 0.05) * 0.7 + t_noise(w_pos.xz * 0.13) * 0.3;
	c *= mix(vec3(0.8, 0.94, 0.86), vec3(1.14, 1.1, 0.84), smoothstep(0.3, 0.75, big));
#endif
	ALBEDO = c;
#ifdef TOON
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
#else
	ROUGHNESS = mix(0.92, 0.8, rk);
	SPECULAR = 0.2;
#endif
#ifdef FLAT
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
#endif
}
