shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, skip_vertex_transform;
#include "res://src/shaders/fx_common.gdshaderinc"

void fragment() {
	vec4 c = fx_color(UV);
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
