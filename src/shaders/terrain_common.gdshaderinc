// Shared terrain shading. Baked vertex colours carry the style palette and
// large colour patches; UV2 carries blend weights (x = path, y = sand) and
// slope picks rock. Ground textures (CC0, ambientCG) are sampled in world
// space with two scales to hide tiling:
//   tex_mode 0: no textures (low-poly), 1: palette colour x texture detail
//   (anime, keeps the painted look).
uniform vec4 rock_color : source_color = vec4(0.6, 0.62, 0.64, 1.0);
uniform float detail_amount = 0.12;
uniform float rock_mix = 0.65;
uniform int tex_mode = 0;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D floor_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_scale = 0.32;
uniform float normal_strength = 0.6;
// Phones: one texture sample per layer, no normal maps, two noise octaves.
uniform bool lite = false;

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

// Two scales blended by noise breaks up visible repetition.
vec4 tri_sample(sampler2D t, vec2 uv, float n) {
	if (lite) {
		return texture(t, uv);
	}
	return mix(texture(t, uv), texture(t, uv * 0.37 + vec2(0.31, 0.77)), 0.35 + 0.3 * n);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = COLOR.rgb;
	float n = t_noise(w_pos.xz * 0.35) * 0.45 + t_noise(w_pos.xz * 1.7) * 0.3;
	if (lite) {
		n += 0.125;
	} else {
		n += t_noise(w_pos.xz * 7.3) * 0.15 + t_noise(w_pos.xz * 29.0) * 0.1;
	}
	float slope = 1.0 - clamp(w_nrm.y, 0.0, 1.0);
	float rk = smoothstep(0.22, 0.42, slope + (n - 0.5) * 0.12) * rock_mix;
	float pw = smoothstep(0.15, 0.75, UV2.x + (n - 0.5) * 0.5);
	float sw = UV2.y;
	if (tex_mode > 0) {
		vec2 uv = w_pos.xz * tex_scale;
		float big = t_noise(w_pos.xz * 0.08);
		vec3 g = tri_sample(grass_tex, uv, big).rgb;
		vec3 d = tri_sample(dirt_tex, uv * 1.3, big).rgb;
		vec3 f = tri_sample(floor_tex, uv, big).rgb;
		vec3 r = tri_sample(rock_tex, vec2(w_pos.x + w_pos.z, w_pos.y) * tex_scale * 0.6, big).rgb;
		// Forest floor mixes into the grass in patches.
		float fw = smoothstep(0.55, 0.8, t_noise(w_pos.xz * 0.06 + 17.0)) * (1.0 - pw);
		vec3 tex = mix(mix(mix(g, f, fw), d, pw), f, sw * 0.6);
		tex = mix(tex, r, rk);
		if (!lite) {
			vec3 nt = mix(mix(tri_sample(grass_nrm, uv, big).rgb, tri_sample(dirt_nrm, uv * 1.3, big).rgb, pw), tri_sample(rock_nrm, vec2(w_pos.x + w_pos.z, w_pos.y) * tex_scale * 0.6, big).rgb, rk);
			NORMAL_MAP = nt;
			NORMAL_MAP_DEPTH = normal_strength;
		}
		// Keep the palette; use the texture's light and shade only.
		float lum = dot(tex, vec3(0.299, 0.587, 0.114));
		c *= mix(0.72, 1.32, smoothstep(0.08, 0.55, lum));
		c = mix(c, mix(rock_color.rgb, rock_color.rgb * 1.2, lum), rk);
	} else {
		c *= mix(1.0 - detail_amount, 1.0 + detail_amount, n);
		vec3 rock = rock_color.rgb * mix(0.82, 1.12, t_noise(w_pos.xz * 3.1 + w_pos.y));
		c = mix(c, rock, rk);
	}
#ifdef ANIME
	float bigp = t_noise(w_pos.xz * 0.05) * 0.7 + t_noise(w_pos.xz * 0.13) * 0.3;
	c *= mix(vec3(0.84, 0.95, 0.86), vec3(1.1, 1.08, 0.86), smoothstep(0.3, 0.75, bigp) * (1.0 - pw));
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
