shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

// Clear glass for goggles, visors and canopies: almost invisible face-on, brighter towards the
// edge, with one soft streak of reflected sky across the top.
uniform vec3 tint : source_color = vec3(0.75, 0.92, 1.0);
uniform float clarity : hint_range(0.0, 1.0) = 0.12;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float streak = smoothstep(0.55, 0.8, world_normal.y) * (1.0 - smoothstep(0.86, 0.97, world_normal.y));
	ALBEDO = mix(tint, vec3(1.0), fresnel * 0.6 + streak * 0.5);
	EMISSION = ALBEDO * 0.35;
	ROUGHNESS = 0.1;
	ALPHA = clamp(clarity + fresnel * 0.6 + streak * 0.35, 0.0, 0.9);
}
