shader_type spatial;
// Pixel 2D water: see-through tiles with a slow shimmer on the surface row.
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec4 c = texture(tex, UV);
	float shimmer = step(0.92, fract(UV.x * 40.0 + TIME * 0.4 + floor(UV.y * 64.0) * 0.37)) * 0.12;
	ALBEDO = (c.rgb + shimmer) * tint.rgb;
	ALPHA = 0.62;
}
