// Rounded-rectangle billboard used behind speech bubbles and name tags.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform vec4 border : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform vec2 size = vec2(1.0, 0.3);
uniform float radius = 0.08;
uniform float tail = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

float box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	// The quad is taller than the box by `tail` so a small pointer fits below.
	vec2 full = vec2(size.x, size.y + tail);
	vec2 p = (vec2(UV.x, 1.0 - UV.y) - 0.5) * full;
	p.y -= tail * 0.5;
	float d = box(p, size * 0.5, radius);
	if (tail > 0.0) {
		vec2 t = p - vec2(-size.x * 0.18, -size.y * 0.5);
		float tri = max(abs(t.x) * 1.2 + t.y, -t.y - tail);
		d = min(d, tri);
	}
	float aa = fwidth(d);
	float a = 1.0 - smoothstep(-aa, aa, d);
	float edge = smoothstep(-aa * 2.0, 0.0, d + 0.006);
	ALBEDO = mix(color.rgb, border.rgb, edge * border.a);
	ALPHA = a * color.a;
}
