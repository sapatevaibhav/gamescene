// Cel shading for the anime style: hard light bands plus a soft rim.
shader_type spatial;
render_mode diffuse_toon, specular_toon, cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float rim_amount = 0.28;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
	RIM = rim_amount;
	RIM_TINT = 0.35;
}
