// Scene effects (SceneFx): billboard particles worked out entirely from the
// scene clock, so every render of a take (and a resumed export) matches.
// One MultiMesh instance per particle; INSTANCE_CUSTOM.x is its seed (0..1),
// .y its speed factor. Nothing is simulated or stored between frames.
global uniform float scene_time;
// 0 flame, 1 ember, 2 smoke, 3 sparkle, 4 dust.
uniform int kind = 0;
uniform float rate = 1.0;
uniform float height = 1.0;
uniform float spread = 0.3;
uniform float size = 0.3;
uniform float base_y = 0.0;
uniform vec4 col_a : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform vec4 col_b : source_color = vec4(1.0, 0.3, 0.05, 1.0);
uniform float strength = 1.0;
// 0 = 3D, 1 = 2D top view (rising runs north, up the screen), 2 = 2D side.
uniform int view = 0;
// Pixel 2D: snap to this many world units (one art pixel), 0 = smooth.
uniform float px = 0.0;
uniform vec2 wind = vec2(0.25, 0.08);

varying float v_life;
varying float v_seed;
varying float v_alpha;

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }

void vertex() {
	v_seed = INSTANCE_CUSTOM.x;
	float sp = INSTANCE_CUSTOM.y;
	float ph = fract(scene_time * rate * sp + v_seed * 7.13);
	v_life = ph;
	float a = h1(v_seed + 1.0) * 6.2832;
	float r = h1(v_seed + 2.0);
	vec3 c = vec3(0.0);
	float sz = size;
	float al = 1.0;
	if (kind == 0) {
		// Flames: rise from the logs, pulled in to a point as they go.
		float rr = spread * sqrt(r) * (1.0 - ph * 0.85);
		c = vec3(cos(a) * rr, base_y + ph * height * (0.55 + 0.45 * h1(v_seed + 3.0)), sin(a) * rr);
		c.x += sin(scene_time * 3.1 + v_seed * 40.0) * 0.05 * ph;
		sz = size * (1.0 - ph * 0.65) * (0.7 + 0.6 * h1(v_seed + 4.0));
		al = smoothstep(0.0, 0.08, ph) * pow(1.0 - ph, 0.9);
	} else if (kind == 1) {
		// Embers: fly up higher, weaving, and wink out.
		c = vec3(cos(a) * spread * r, base_y + ph * height, sin(a) * spread * r);
		c.xz += vec2(sin(ph * 6.0 + v_seed * 30.0), cos(ph * 5.0 + v_seed * 20.0)) * 0.22 * ph + wind * ph * 1.5;
		sz = size * (0.6 + 0.4 * h1(v_seed + 5.0));
		al = (1.0 - ph) * (0.55 + 0.45 * step(0.5, fract(scene_time * 7.0 + v_seed * 13.0)));
	} else if (kind == 2) {
		// Smoke: drifts up and downwind, growing and thinning out.
		c = vec3(cos(a) * spread * r * 0.6, base_y + ph * height, sin(a) * spread * r * 0.6);
		c.xz += wind * ph * height * 0.8 + vec2(sin(ph * 4.0 + v_seed * 9.0), 0.0) * 0.15;
		sz = size * (0.45 + ph * 1.4);
		al = sin(ph * 3.14159) * 0.9;
	} else if (kind == 3) {
		// Magic sparkles: spiral up round a column, twinkling.
		float an = a + ph * 6.2832 * 1.3;
		float rr = spread * (0.35 + 0.65 * r);
		c = vec3(cos(an) * rr, base_y + ph * height, sin(an) * rr);
		float tw = 0.5 + 0.5 * sin(scene_time * 9.0 + v_seed * 60.0);
		sz = size * (0.35 + 0.65 * tw * tw);
		al = sin(ph * 3.14159);
	} else {
		// Dust: motes drifting slowly in the air.
		float lift = fract(h1(v_seed + 6.0) + ph);
		c = vec3((h1(v_seed + 7.0) - 0.5) * 2.0 * spread, base_y + lift * height, (h1(v_seed + 8.0) - 0.5) * 2.0 * spread);
		c.x += sin(scene_time * 0.31 + v_seed * 11.0) * 0.35;
		c.z += cos(scene_time * 0.23 + v_seed * 17.0) * 0.35;
		sz = size * (0.5 + 0.5 * h1(v_seed + 9.0));
		al = sin(lift * 3.14159) * (0.6 + 0.4 * sin(scene_time * 2.0 + v_seed * 31.0));
	}
	if (view == 1) {
		// Top view: up the screen (north) instead of towards the camera.
		c = vec3(c.x, 0.001, c.z * 0.5 - c.y);
	} else if (view == 2) {
		// Side view: flat on the lane.
		c.z = 0.0;
	}
	vec3 wc = (MODEL_MATRIX * vec4(c, 1.0)).xyz;
	float k = length(MODEL_MATRIX[0].xyz);
	if (px > 0.0) {
		wc.x = floor(wc.x / px + 0.5) * px;
		if (view == 1) {
			wc.z = floor(wc.z / px + 0.5) * px;
		} else {
			wc.y = floor(wc.y / px + 0.5) * px;
		}
		sz = max(px * 2.0, floor(sz * k / px + 0.5) * px) / k;
	}
	v_alpha = al * strength;
	VERTEX = (VIEW_MATRIX * vec4(wc, 1.0)).xyz + vec3(VERTEX.xy * sz * k, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

vec4 fx_color(vec2 uv) {
	vec2 q = uv - 0.5;
	if (px > 0.0) {
		q = (floor(uv * 6.0) + 0.5) / 6.0 - 0.5;
	}
	float d = length(q) * 2.0;
	float m;
	if (kind == 3) {
		// A four-pointed star with a soft core.
		float cr = max(exp(-abs(q.x) * 28.0 - q.y * q.y * 30.0), exp(-abs(q.y) * 28.0 - q.x * q.x * 30.0));
		m = max(cr, exp(-d * d * 9.0));
	} else if (kind == 2) {
		m = smoothstep(1.0, 0.2, d);
	} else {
		m = exp(-d * d * 4.0) * smoothstep(1.0, 0.7, d);
	}
	vec3 col;
	if (kind == 0) {
		col = mix(col_a.rgb, col_b.rgb, smoothstep(0.05, 0.75, v_life));
	} else if (kind == 3) {
		col = mix(col_a.rgb, col_b.rgb, h1(v_seed + 10.0));
	} else {
		col = mix(col_a.rgb, col_b.rgb, v_life);
	}
	float a = m * v_alpha;
	if (px > 0.0) {
		a = step(0.3, a) * min(1.0, v_alpha * 1.4);
		col = floor(col * 6.0 + 0.5) / 6.0;
	}
	return vec4(col, clamp(a, 0.0, 1.0));
}
