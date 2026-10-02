shader_type spatial;

// Collectible gem: a glossy, softly glowing sweet that spins and bobs, with one material per
// colour. A light rim and its own glow separate it from any background, so it needs no
// outline.
uniform vec4 color : source_color = vec4(1.0);

void vertex() {
	float a = TIME * 2.2 + NODE_POSITION_WORLD.x + NODE_POSITION_WORLD.z * 0.35;
	mat3 spin = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
	VERTEX = spin * VERTEX;
	NORMAL = spin * NORMAL;
	VERTEX.y += sin(TIME * 3.0 + NODE_POSITION_WORLD.z * 0.6) * 0.07;
}

void fragment() {
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float top = world_normal.y * 0.5 + 0.5;
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = color.rgb * mix(0.8, 1.0, top);
	EMISSION = color.rgb * (0.4 + 0.3 * top) + mix(color.rgb, vec3(1.0), 0.75) * fresnel * 0.9;
	ROUGHNESS = 0.22;
	SPECULAR = 0.7;
}
