shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

// Shield bubble: nearly clear in the middle, glowing towards the rim, with a slow shimmer.
uniform vec4 tint : source_color = vec4(0.3, 0.92, 1.0, 1.0);

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float shimmer = 0.85 + 0.15 * sin(TIME * 5.0 + UV.y * 18.0);
	ALBEDO = tint.rgb;
	ALPHA = (0.05 + rim * 0.6) * shimmer;
}
