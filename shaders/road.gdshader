shader_type spatial;
render_mode cull_disabled;

// The path: one calm surface with soft shoulders and light lane marks.
// - Lane dividers are short dashes a little lighter than the surface. They only mark the lanes;
//   as they slide past they also give a sense of speed.
// - A thin line along each edge carries the player's current colour, softened towards the
//   surface, so the road quietly shows which colour is selected.
uniform vec3 base_color : source_color = vec3(0.88, 0.85, 0.8);
uniform vec3 shoulder_color : source_color = vec3(0.6, 0.4, 0.24);
uniform vec3 mark_color : source_color = vec3(1.0);
uniform float mark_strength : hint_range(0.0, 1.0) = 0.5;
uniform vec3 line_color : source_color = vec3(0.9, 0.12, 0.18);
uniform float line_strength : hint_range(0.0, 1.0) = 0.4;
uniform float lane_glow = 0.0;
uniform float lane_width = 2.4;
uniform float half_width = 3.9;
uniform float dash_length = 2.2;
uniform float dash_period = 6.0;

float band(float dist, float half_thickness) {
	float aa = fwidth(dist) * 1.25 + 0.0001;
	return 1.0 - smoothstep(half_thickness - aa, half_thickness + aa, dist);
}

void fragment() {
	// UV.x spans the road width; UV.y is the distance along the road in metres.
	float x = (UV.x - 0.5) * 2.0 * half_width;
	float ax = abs(x);

	// Dashes on the two dividers between lanes. Far away, where a dash is smaller than a pixel,
	// they blend into an even faint line instead of shimmering.
	float along = fract(UV.y / dash_period) * dash_period;
	float soft = fwidth(UV.y) * 1.5 + 0.001;
	float dash = smoothstep(0.0, soft, along) * (1.0 - smoothstep(dash_length, dash_length + soft, along));
	dash = mix(dash, dash_length / dash_period, clamp(soft / dash_length, 0.0, 1.0));
	float divider = band(abs(ax - lane_width * 0.5), 0.06) * dash;

	// The outer edge of the outer lanes: a thin continuous line in the player's colour.
	float edge_line = band(abs(ax - lane_width * 1.5), 0.045);
	float shoulder = smoothstep(lane_width * 1.5, half_width, ax);

	vec3 col = mix(base_color, shoulder_color, shoulder * 0.55);
	col = mix(col, mark_color, divider * mark_strength);
	col = mix(col, line_color, edge_line * line_strength);

	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
	EMISSION = (mark_color * divider * mark_strength + line_color * edge_line * line_strength) * lane_glow;
}
