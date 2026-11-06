// Instanced grass blades and flowers with wind sway. Vertex colour carries
// the base-to-tip gradient; the MultiMesh instance colour tints each blade.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform float wind_strength = 1.0;
uniform float toon = 0.0;

void vertex() {
	vec3 ip = MODEL_MATRIX[3].xyz;
	float ph = ip.x * 0.45 + ip.z * 0.3;
	float gust = 0.75 + 0.25 * sin(TIME * 0.4 + ip.x * 0.05);
	VERTEX.x += sin(TIME * 1.7 + ph) * VERTEX.y * 0.35 * wind_strength * gust;
	VERTEX.z += cos(TIME * 1.3 + ph) * VERTEX.y * 0.18 * wind_strength * gust;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.25, 0.3, 0.15);
	if (toon > 0.5) {
		SPECULAR = 0.0;
	}
}
