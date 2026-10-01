shader_type spatial;

// The surface used by everything solid in the world: scenery, obstacles, vehicles and drivers.
// Vertex colours are the paint. Lighting is deliberately simple and soft:
// - sunlight falls off over a short, smooth step instead of a long gradient (`ramp`), so shapes
//   read as a lit side and a shaded side;
// - faces that point down receive less ambient light (`under`), which gives form in the shade;
// - a rim of light around the silhouette (`rim`) lifts shapes off the background, which is what
//   dark outlines used to be for;
// - `gloss` adds one crisp highlight for painted or wet-looking surfaces; `glow` self-lights.
uniform vec3 tint : source_color = vec3(1.0);
uniform float ramp : hint_range(0.0, 1.0) = 0.6;
uniform float under : hint_range(0.0, 1.0) = 0.55;
uniform vec3 rim_color : source_color = vec3(1.0);
uniform float rim : hint_range(0.0, 2.0) = 0.22;
uniform float gloss : hint_range(0.0, 2.0) = 0.0;
uniform float glow : hint_range(0.0, 4.0) = 0.0;

void fragment() {
	vec3 base = COLOR.rgb * tint;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float up = world_normal.y * 0.5 + 0.5;
	AO = mix(under, 1.0, up);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = mix(base, rim_color, 0.5) * fresnel * rim * (0.3 + 0.7 * up) + base * glow;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lambert = clamp(ndl, 0.0, 1.0);
	float stepped = smoothstep(0.0, 0.3, ndl) * (0.72 + 0.28 * lambert);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * mix(lambert, stepped, ramp) / PI;
	if (gloss > 0.0) {
		float highlight = pow(clamp(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0, 1.0), 90.0);
		SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * smoothstep(0.3, 0.8, highlight) * gloss * 0.14;
	}
}
