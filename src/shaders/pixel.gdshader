shader_type spatial;
// Pixel 2D style: flat, unlit pixel art with hard alpha edges. Used for
// tiles, parallax backdrops and sprite characters. `frames`/`frame` pick one
// cell of a sprite sheet; `flip` mirrors it; `tint` carries the time of day.
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform sampler2D tex : source_color, filter_nearest, repeat_disable;
uniform vec2 frames = vec2(1.0, 1.0);
uniform vec2 frame = vec2(0.0, 0.0);
uniform float flip = 0.0;
uniform vec4 tint : source_color = vec4(1.0);

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = (frame + uv) / frames;
	vec4 c = texture(tex, uv);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb * tint.rgb * COLOR.rgb;
}
