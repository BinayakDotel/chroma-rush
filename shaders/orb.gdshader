shader_type spatial;

// Faceted gem that spins and bobs; colour comes from the instance.
instance uniform vec4 color : source_color = vec4(1.0);

void vertex() {
	float a = TIME * 2.5 + NODE_POSITION_WORLD.x;
	mat3 spin = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	VERTEX = spin * VERTEX;
	NORMAL = spin * NORMAL;
	VERTEX.y += sin(TIME * 4.0 + NODE_POSITION_WORLD.z) * 0.08;
}

void fragment() {
	ALBEDO = color.rgb;
	EMISSION = color.rgb * 0.35;
	ROUGHNESS = 0.25;
	SPECULAR = 0.8;
}
