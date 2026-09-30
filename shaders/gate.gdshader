shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Colour gate: an energy membrane hanging from the row's arch. A bright rim in the gate colour,
// a softly animated fill, and the colour's symbol (circle / triangle / square) in the middle so
// the gate never relies on hue alone. `burst` plays when the player passes through; `fade`
// dissolves the panel.
instance uniform vec4 color : source_color = vec4(0.9, 0.12, 0.2, 1.0);
instance uniform float symbol = 0.0;
instance uniform float burst = 0.0;
instance uniform float fade = 1.0;
uniform float show_symbols = 1.0;
uniform vec2 size = vec2(2.1, 2.7);
uniform float corner_radius = 0.28;
uniform float rim_width = 0.13;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float symbol_sdf(vec2 p, float kind) {
	if (kind < 0.5) {
		return length(p) - 0.42;
	} else if (kind < 1.5) {
		// Equilateral triangle pointing up.
		p.y += 0.08;
		const float k = 1.7320508;
		float r = 0.46;
		p.x = abs(p.x) - r;
		p.y = p.y + r / k;
		if (p.x + k * p.y > 0.0) {
			p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
		}
		p.x -= clamp(p.x, -2.0 * r, 0.0);
		return -length(p) * sign(p.y);
	}
	return rounded_box(p, vec2(0.36), 0.06);
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	p.y = -p.y;
	float d = rounded_box(p, size * 0.5, corner_radius);
	float aa = fwidth(d) * 1.5;
	if (d > aa) {
		discard;
	}
	float inside = 1.0 - smoothstep(-aa, aa, d);
	vec3 base = color.rgb;
	vec3 light = mix(base, vec3(1.0), 0.55);
	vec3 deep = base * 0.45;

	// Rim: a dark outer edge, the bright colour band, and a light inner bevel.
	float rim = 1.0 - smoothstep(rim_width - aa, rim_width + aa, -d);
	float outer = 1.0 - smoothstep(0.035 - aa, 0.035 + aa, -d);
	float bevel = 1.0 - smoothstep(0.018, 0.018 + aa, abs(-d - rim_width));
	float pulse = 0.5 + 0.5 * sin(TIME * 5.0);

	// Fill: translucent colour with slow scan bands and a brighter core.
	float bands = smoothstep(0.55, 0.9, sin(p.y * 7.0 - TIME * 3.5)) * 0.14;
	float core = 1.0 - smoothstep(0.0, 1.3, length(p));
	vec3 fill = mix(base, light, bands + core * 0.12);
	float fill_alpha = 0.6 + bands + core * 0.1;

	vec3 col = fill;
	float alpha = fill_alpha;
	col = mix(col, mix(base, light, 0.15 + pulse * 0.12), rim);
	alpha = mix(alpha, 0.96, rim);
	col = mix(col, light, bevel * 0.8);
	col = mix(col, deep, outer);
	alpha = mix(alpha, 1.0, outer);

	// Symbol: white shape with a coloured outline.
	if (show_symbols > 0.5) {
		float s = symbol_sdf(p - vec2(0.0, 0.05), symbol);
		float sa = fwidth(s) * 1.5;
		float shape = 1.0 - smoothstep(-sa, sa, s);
		float edge = 1.0 - smoothstep(0.06 - sa, 0.06 + sa, abs(s));
		col = mix(col, vec3(1.0), shape * 0.92);
		alpha = mix(alpha, 0.95, shape);
		col = mix(col, deep, edge);
		alpha = mix(alpha, 1.0, edge * 0.9);
	}

	// Pass-through burst: a white flash, then a ring expanding outwards as the panel dissolves.
	float ring_r = burst * 2.2;
	float ring = (1.0 - smoothstep(0.0, 0.18, abs(length(p) - ring_r))) * (1.0 - burst);
	col = mix(col, vec3(1.0), clamp((1.0 - burst * 3.0), 0.0, 1.0) * step(0.001, burst));
	col = mix(col, light, ring);
	float dissolve = 1.0 - smoothstep(ring_r - 0.25, ring_r, length(p)) * step(0.001, burst);

	ALBEDO = col;
	ALPHA = clamp(alpha * inside * fade * max(dissolve, ring), 0.0, 1.0);
}
