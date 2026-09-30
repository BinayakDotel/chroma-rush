shader_type sky;

// One sky for every theme: gradient, sun, cartoon clouds, stars and nebula / aurora.
uniform vec3 zenith_color : source_color = vec3(0.22, 0.52, 0.95);
uniform vec3 horizon_color : source_color = vec3(0.72, 0.88, 1.0);
uniform vec3 ground_color : source_color = vec3(0.78, 0.9, 0.98);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.85);
uniform vec3 sun_direction = vec3(0.4, 0.5, -0.7);
uniform float sun_size = 0.06;
uniform float sun_glow = 0.35;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.8, 0.86, 0.96);
uniform float cloud_amount = 0.0;
uniform float star_amount = 0.0;
uniform float star_everywhere = 0.0;
uniform vec3 nebula_a : source_color = vec3(0.7, 0.2, 0.9);
uniform vec3 nebula_b : source_color = vec3(0.1, 0.5, 1.0);
uniform float nebula_amount = 0.0;
// Below the horizon: a faceted low-poly sea (water, ice or lava) in ground_color.
uniform float sea_amount = 0.0;
uniform vec3 sea_glint : source_color = vec3(1.0);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), u.x),
		mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * noise2(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;
	vec3 col = mix(horizon_color, zenith_color, smoothstep(0.0, 0.6, h));
	col = mix(col, ground_color, 1.0 - smoothstep(-0.25, 0.0, h));
	if (sea_amount > 0.0 && h < 0.0) {
		// Project onto a flat plane below and break it into big flat facets.
		vec2 sp = dir.xz / max(-h, 0.015) * 0.35;
		vec2 cell = floor(sp + vec2(0.5 * floor(sp.y), 0.0));
		float facet = hash2(cell) - 0.5;
		float below = 1.0 - smoothstep(-0.04, 0.0, h);
		col *= 1.0 + facet * 0.14 * sea_amount * below;
		float glint = step(0.93, hash2(cell + 17.0)) * below * sea_amount;
		col = mix(col, sea_glint, glint * 0.35);
	}

	if (nebula_amount > 0.0) {
		vec2 np = vec2(atan(dir.x, -dir.z) * 1.2, h * 2.5);
		float n = fbm(np * 1.3 + vec2(3.0, 1.0));
		float m = fbm(np * 2.1 + vec2(11.0, 4.0));
		col += mix(nebula_a, nebula_b, m) * smoothstep(0.42, 0.8, n) * nebula_amount * smoothstep(-0.1, 0.25, h + star_everywhere);
	}

	if (star_amount > 0.0) {
		vec3 p = dir * 220.0;
		vec3 cell = floor(p);
		if (hash3(cell) > 0.99) {
			vec3 star = cell + 0.5 + (vec3(hash3(cell + 1.7), hash3(cell + 3.1), hash3(cell + 5.3)) - 0.5) * 0.5;
			float mask = mix(smoothstep(0.0, 0.25, h), 1.0, star_everywhere);
			col += vec3(1.0, 0.95, 0.9) * (1.0 - smoothstep(0.0, 0.3, length(p - star))) * star_amount * 1.6 * mask;
		}
	}

	vec3 sd = normalize(sun_direction);
	float ang = acos(clamp(dot(dir, sd), -1.0, 1.0));
	col += sun_color * sun_glow * exp(-ang * 5.0);
	col = mix(col, sun_color * 1.6, 1.0 - smoothstep(sun_size - 0.004, sun_size, ang));

	if (cloud_amount > 0.0 && h > 0.0) {
		vec2 cp = dir.xz / (h + 0.15);
		float threshold = mix(0.72, 0.45, cloud_amount);
		float n = fbm(cp * 0.9);
		float cover = smoothstep(threshold, threshold + 0.02, n);
		float lit = smoothstep(threshold, threshold + 0.2, fbm(cp * 0.9 + vec2(0.06, 0.1)));
		col = mix(col, mix(cloud_shade, cloud_color, lit), cover * smoothstep(0.0, 0.1, h));
	}

	COLOR = col;
}
