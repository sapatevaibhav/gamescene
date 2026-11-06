// Water for the blocky world: gentle waves on surface vertices (flagged by
// vertex colour alpha), shimmering normals, depth-tinted colour and fresnel.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.23, 0.58, 0.80);
uniform vec3 deep : source_color = vec3(0.04, 0.20, 0.36);
uniform float wave_height = 0.03;
uniform float surface_drop = 0.12;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 wpos;
varying float top_face;

float h(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 1.4) * 0.5 + cos(p.y * 1.1 + t * 1.1) * 0.5
		+ sin((p.x + p.y) * 3.1 + t * 2.3) * 0.18 + cos((p.x - p.y) * 4.3 - t * 2.9) * 0.12;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	top_face = NORMAL.y > 0.5 ? 1.0 : 0.0;
	if (COLOR.a > 0.5) {
		VERTEX.y += -surface_drop + h(wpos.xz, TIME) * wave_height;
	}
}

void fragment() {
	if (top_face > 0.5) {
		float e = 0.08;
		float t = TIME;
		vec2 p = wpos.xz * 2.2;
		float dx = h(p + vec2(e, 0.0), t) - h(p - vec2(e, 0.0), t);
		float dz = h(p + vec2(0.0, e), t) - h(p - vec2(0.0, e), t);
		vec3 n = normalize(vec3(-dx * 0.35, 1.0, -dz * 0.35));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	v.xyz /= v.w;
	float thick = clamp(VERTEX.z - v.z, 0.0, 12.0);
	float k = smoothstep(0.0, 3.0, thick);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(shallow, deep, k);
	ALPHA = clamp(mix(0.5, 0.9, smoothstep(0.0, 2.5, thick)) + fres * 0.3, 0.0, 0.97);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
