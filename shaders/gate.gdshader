shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

// Colour gate: a pane of tinted glass hanging from the row's arch. The pane is clear in the
// middle and denser towards its edge, with a bright rim that glows, and it carries the colour's
// symbol (circle / triangle / square) so a gate never relies on hue alone. Nothing is outlined
// in a dark colour: the rim's glow and the symbol's soft shadow do that job.
// `burst` plays when the player passes through; `fade` dissolves the panel.
instance uniform vec4 color : source_color = vec4(0.9, 0.12, 0.2, 1.0);
instance uniform float symbol = 0.0;
instance uniform float burst = 0.0;
instance uniform float fade = 1.0;
uniform float show_symbols = 1.0;
uniform vec2 size = vec2(2.1, 2.7);
uniform float corner_radius = 0.34;
uniform float rim_width = 0.075;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float symbol_sdf(vec2 p, float kind) {
	if (kind < 0.5) {
		return length(p) - 0.42;
	} else if (kind < 1.5) {
		// Equilateral triangle pointing up, with slightly rounded corners.
		p.y += 0.08;
		const float k = 1.7320508;
		float r = 0.42;
		p.x = abs(p.x) - r;
		p.y = p.y + r / k;
		if (p.x + k * p.y > 0.0) {
			p = vec2(p.x - k * p.y, -k * p.x - p.y) / 2.0;
		}
		p.x -= clamp(p.x, -2.0 * r, 0.0);
		return -length(p) * sign(p.y) - 0.04;
	}
	return rounded_box(p, vec2(0.37), 0.1);
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
	vec3 light = mix(base, vec3(1.0), 0.5);

	// Glass: the colour is strongest near the edge and thins out towards the middle, with a
	// gentle top-to-bottom gradient and a slow diagonal sheen.
	float depth = clamp(-d / 0.9, 0.0, 1.0);
	float edge_density = 1.0 - smoothstep(0.0, 1.0, depth);
	float sheen = smoothstep(0.75, 1.0, sin((p.x + p.y) * 1.4 - TIME * 1.2)) * 0.1;
	vec3 col = mix(base, light, 0.04 + 0.14 * (p.y / size.y + 0.5) + sheen);
	float alpha = 0.74 + 0.2 * edge_density + sheen;

	// Rim: a bright band in a lighter tone of the gate colour, brighter than white can be on
	// screen so it blooms a little.
	float pulse = 0.5 + 0.5 * sin(TIME * 4.0);
	float rim = 1.0 - smoothstep(rim_width - aa, rim_width + aa, -d);
	col = mix(col, mix(light, vec3(1.0), 0.25) * (1.25 + 0.2 * pulse), rim);
	alpha = mix(alpha, 1.0, rim);

	// Symbol: a white shape over a soft shadow in the gate's own colour.
	if (show_symbols > 0.5) {
		float s = symbol_sdf(p - vec2(0.0, 0.05), symbol);
		float sa = fwidth(s) * 1.5;
		float shadow = 1.0 - smoothstep(0.0, 0.2, s);
		col = mix(col, base * 0.72, shadow * 0.55);
		alpha = mix(alpha, 0.92, shadow * 0.7);
		float shape = 1.0 - smoothstep(-sa, sa, s);
		col = mix(col, vec3(1.15), shape);
		alpha = mix(alpha, 1.0, shape);
	}

	// Pass-through burst: a white flash, then a ring expanding outwards as the panel dissolves.
	float ring_r = burst * 2.2;
	float ring = (1.0 - smoothstep(0.0, 0.18, abs(length(p) - ring_r))) * (1.0 - burst);
	col = mix(col, vec3(1.3), clamp((1.0 - burst * 3.0), 0.0, 1.0) * step(0.001, burst));
	col = mix(col, light * 1.3, ring);
	float dissolve = 1.0 - smoothstep(ring_r - 0.25, ring_r, length(p)) * step(0.001, burst);

	ALBEDO = col;
	ALPHA = clamp(alpha * inside * fade * max(dissolve, ring), 0.0, 1.0);
}
