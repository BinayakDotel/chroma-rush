shader_type spatial;

// Big background planets: vertex-coloured, with self-illumination so the unlit side keeps its hue.
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.45;
	ROUGHNESS = 1.0;
}
