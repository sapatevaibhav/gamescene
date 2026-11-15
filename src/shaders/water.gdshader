// Animated water: layered waves, fresnel, depth tint and shoreline foam.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, diffuse_burley, specular_schlick_ggx;
// The scene clock (set by the studio), so every render of a moment matches.
global uniform float scene_time;

uniform vec4 water_color : source_color = vec4(0.35, 0.72, 0.88, 1.0);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.36, 1.0);
uniform float opacity = 0.8;
uniform float wave_strength = 0.035;
uniform float roughness_val = 0.06;
uniform float depth_fade = 2.2;
uniform float foam_width = 0.35;
uniform bool use_depth = true;
// Poured water (TerrainWater): the mesh's vertex alpha fades the edges out
// (deep water solid, the dry rim clear), so puddles have a soft shoreline.
uniform bool edge_fade = false;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 w_pos;
// Poured water's flow (from the vertex colour's red/green): ripples slide
// along it, a two-phase flow map so they don't stretch out.
varying vec2 v_flow;

float w_hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float w_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(w_hash(i), w_hash(i + vec2(1.0, 0.0)), u.x), mix(w_hash(i + vec2(0.0, 1.0)), w_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float wave_h(vec2 p, float t) {
	return sin(p.x * 0.9 + t * 1.1) * 0.5 + sin(p.y * 1.3 - t * 0.9) * 0.35 + sin((p.x + p.y) * 2.1 + t * 1.7) * 0.15
		+ w_noise(p * 1.6 + vec2(t * 0.35, t * 0.2)) * 0.6 + w_noise(p * 4.0 - vec2(t * 0.5, -t * 0.3)) * 0.25;
}

vec3 wave_normal(vec2 p, float t) {
	float e = 0.08;
	float h0 = wave_h(p, t);
	float hx = wave_h(p + vec2(e, 0.0), t);
	float hz = wave_h(p + vec2(0.0, e), t);
	return normalize(vec3(-(hx - h0) / e * wave_strength, 1.0, -(hz - h0) / e * wave_strength));
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_flow = edge_fade ? (COLOR.rg - 0.5) * 2.0 : vec2(0.0);
	VERTEX.y += (sin(w_pos.x * 0.6 + scene_time * 0.8) + cos(w_pos.z * 0.5 + scene_time * 0.6)) * 0.02;
}

void fragment() {
	float t = scene_time;
	vec2 p = w_pos.xz;
	vec3 wn;
	if (edge_fade && length(v_flow) > 0.03) {
		// Flowing: two copies of the ripples slide downstream half a cycle
		// apart, each fading out as it resets.
		float ph0 = fract(t * 0.35);
		float ph1 = fract(t * 0.35 + 0.5);
		float wgt = abs(1.0 - 2.0 * ph0);
		vec2 flow = v_flow * 3.0;
		wn = normalize(mix(wave_normal(p - flow * ph0, t * 0.5), wave_normal(p - flow * ph1 + 7.3, t * 0.5), 1.0 - wgt) * vec3(1.6, 1.0, 1.6));
	} else {
		wn = wave_normal(p, t);
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float depth_m = 4.0;
	if (use_depth) {
		float d = texture(depth_tex, SCREEN_UV).r;
		vec4 up = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
		up.xyz /= up.w;
		depth_m = max(0.0, VERTEX.z - up.z);
	}
	float k = clamp(depth_m / depth_fade, 0.0, 1.0);
	vec3 col = mix(water_color.rgb, deep_color.rgb, k * 0.85);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	float foam = 0.0;
	if (use_depth) {
		foam = (1.0 - smoothstep(0.0, foam_width, depth_m)) * smoothstep(0.35, 0.75, w_noise(p * 3.0 + t * 0.4) + 0.3);
	}
	ALBEDO = mix(col, vec3(0.95), foam * 0.8);
	ROUGHNESS = mix(roughness_val, 0.6, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = clamp(mix(opacity * 0.55, opacity, k) + fres * 0.25 + foam * 0.5, 0.0, 1.0);
	if (edge_fade) {
		ALPHA *= smoothstep(0.0, 1.0, COLOR.a);
	}
}
