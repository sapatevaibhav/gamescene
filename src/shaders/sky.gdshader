// Mood-driven sky: gradient, sun and moon discs, drifting clouds, stars.
shader_type sky;

uniform vec3 sky_top : source_color = vec3(0.32, 0.55, 0.92);
uniform vec3 sky_horizon : source_color = vec3(0.75, 0.86, 0.98);
uniform vec3 ground_color : source_color = vec3(0.32, 0.35, 0.33);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float sun_size = 0.9995;
uniform float stars = 0.0;
uniform float clouds = 0.55;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform float cloud_speed = 0.004;
uniform float horizon_haze = 1.0;
uniform float cloud_sharp = 0.35;
uniform float cloud_scale = 1.6;
uniform float cloud_toon = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col = mix(sky_horizon, sky_top, pow(clamp(h, 0.0, 1.0), 0.55));
	// Ground below the horizon fades to a muted tone so the skirt blends in.
	col = mix(col, mix(sky_horizon, ground_color, 0.6), smoothstep(0.0, -0.12, h));
	// Sun glow and disc.
	vec3 sd = LIGHT0_DIRECTION;
	float sdot = dot(d, sd);
	if (LIGHT0_ENABLED) {
		float glow = pow(max(sdot, 0.0), 8.0) * 0.35 + pow(max(sdot, 0.0), 64.0) * 0.5;
		col += sun_color * glow * LIGHT0_ENERGY * horizon_haze;
		if (sdot > sun_size && h > -0.02) {
			col = mix(col, sun_color * 4.0, smoothstep(sun_size, sun_size + 0.0002, sdot));
		}
	}
	// Stars (fixed to the sky dome).
	if (stars > 0.001 && h > 0.0) {
		vec2 sp = d.xz / (d.y + 0.25) * 140.0;
		float s = hash(floor(sp));
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + s * 40.0);
		col += vec3(step(0.9965, s) * stars * tw * smoothstep(0.0, 0.25, h));
	}
	// Clouds on a curved layer.
	{
		if (h > 0.0 && clouds > 0.01) {
			vec2 uv = d.xz / (d.y + 0.18) * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
			float n = fbm(uv);
			float c = smoothstep(1.0 - clouds, 1.0 - clouds + cloud_sharp, n);
			float f2 = fbm(uv * 2.0 + 3.0);
			float shade = mix(0.82 + 0.18 * f2, mix(0.8, 1.04, smoothstep(0.42, 0.5, n - f2 * 0.25)), cloud_toon);
			col = mix(col, cloud_color * shade, c * smoothstep(0.0, 0.18, h) * 0.92);
		}
	}
	COLOR = col;
}
