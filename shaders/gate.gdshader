shader_type spatial;
render_mode unshaded, cull_disabled;

// Colour gate: tinted glass pane in a rounded frame of the same colour. The frame has a light
// bevel line on its inner edge and a slightly deeper line on its outer edge, so it reads as a
// glass edge without a dark outline. A soft diagonal sheen crosses the glass.
instance uniform vec4 color : source_color = vec4(0.9, 0.12, 0.18, 1.0);
instance uniform float flash = 0.0;
instance uniform float fade = 1.0;
uniform vec2 size = vec2(2.2, 2.6);
uniform float frame_width = 0.16;
uniform float corner_radius = 0.18;

void fragment() {
	// Signed distance to the rounded outer edge (positive inside, in metres).
	vec2 q = abs(UV - 0.5) * size - (size * 0.5 - corner_radius);
	float inside = -(length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner_radius);
	float aa = fwidth(inside) * 1.5;
	if (inside < 0.0) {
		discard;
	}
	float frame = 1.0 - smoothstep(frame_width, frame_width + aa, inside);
	float bevel = 1.0 - smoothstep(0.025, 0.025 + aa, abs(inside - frame_width + 0.02));
	float rim = 1.0 - smoothstep(0.025, 0.025 + aa, inside);

	vec3 frame_col = color.rgb * 0.78;
	frame_col = mix(frame_col, vec3(1.0), bevel * 0.45);
	frame_col = mix(frame_col, color.rgb * 0.55, rim);

	float diag = UV.x * 0.7 + UV.y;
	float sheen = (1.0 - smoothstep(0.0, 0.02, abs(diag - 0.55) - 0.06)) * 0.35
		+ (1.0 - smoothstep(0.0, 0.015, abs(diag - 0.8) - 0.02)) * 0.2;
	vec3 glass_col = mix(color.rgb, vec3(1.0), 0.12 + sheen);

	vec3 col = mix(glass_col, frame_col, frame);
	ALBEDO = mix(col, vec3(1.0), flash);
	float alpha = mix(0.5 + sheen * 0.4, 1.0, frame);
	ALPHA = mix(alpha, 1.0, flash) * fade;
}
