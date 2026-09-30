shader_type spatial;
render_mode cull_disabled;

// Plain path: one flat colour, a dark edge band, and lane lines in the player's colour.
// Lane lines get a thin dark border so they read in any colour on any path.
uniform vec3 base_color : source_color = vec3(0.88, 0.85, 0.8);
uniform vec3 edge_color : source_color = vec3(0.6, 0.4, 0.24);
uniform vec3 line_color : source_color = vec3(0.9, 0.12, 0.18);
uniform vec3 line_border : source_color = vec3(0.1, 0.08, 0.16);
uniform float lane_glow = 0.0;
uniform float roughness_value = 0.9;
uniform float metallic_value = 0.0;
uniform float lane_width = 2.4;
uniform float half_width = 3.9;

float line_mask(float dist, float width) {
	float aa = fwidth(dist) * 1.5 + 0.0001;
	return 1.0 - smoothstep(width, width + aa, dist);
}

void fragment() {
	// UV.x spans the road width.
	float x = (UV.x - 0.5) * 2.0 * half_width;
	float lane_dist = abs(fract(x / lane_width + 1.0) - 0.5) * lane_width;
	float core = line_mask(lane_dist, 0.055);
	float outline = line_mask(lane_dist, 0.085) - core;
	float edge = smoothstep(half_width - 0.32, half_width - 0.28, abs(x));

	vec3 col = mix(base_color, edge_color, edge);
	col = mix(col, line_border, outline * 0.75);
	col = mix(col, line_color, core);

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	EMISSION = line_color * core * lane_glow;
}
