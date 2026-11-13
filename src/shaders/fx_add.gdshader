shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform, fog_disabled;
#include "res://src/shaders/fx_common.gdshaderinc"

void fragment() {
	vec4 c = fx_color(UV);
	// Pixel art keeps its colours; smooth flames glow past white at the core.
	ALBEDO = c.rgb * (px > 0.0 ? 1.0 : 1.4);
	ALPHA = c.a;
}
