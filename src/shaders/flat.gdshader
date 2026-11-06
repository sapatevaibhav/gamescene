// Faceted low-poly shading: one normal per triangle from screen derivatives.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0);

void fragment() {
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.95;
}
