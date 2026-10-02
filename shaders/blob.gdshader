shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// Soft round patch drawn flat on the road: a contact shadow under the vehicle and pickups
// (`ring` = 0), or a glowing ring of colour (`ring` = 1).
uniform vec4 shade : source_color = vec4(0.0, 0.0, 0.0, 0.38);
uniform float ring = 0.0;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float disc = 1.0 - smoothstep(0.15, 1.0, r);
	float halo = smoothstep(0.35, 0.72, r) * (1.0 - smoothstep(0.72, 1.0, r));
	ALBEDO = shade.rgb;
	ALPHA = shade.a * mix(disc * disc, halo, ring);
}
