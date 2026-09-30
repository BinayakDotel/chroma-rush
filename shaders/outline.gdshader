shader_type spatial;
render_mode unshaded, cull_front;

// Inverted-hull outline for small convex pickups. With `spin`, it follows the gem shader's motion.
uniform float grow = 1.12;
uniform float spin = 0.0;
uniform vec3 outline_color : source_color = vec3(0.08, 0.06, 0.16);

void vertex() {
	VERTEX *= grow;
	if (spin > 0.5) {
		float a = TIME * 2.5 + NODE_POSITION_WORLD.x;
		mat3 r = mat3(vec3(cos(a), 0.0, -sin(a)), vec3(0.0, 1.0, 0.0), vec3(sin(a), 0.0, cos(a)));
		VERTEX = r * VERTEX;
		VERTEX.y += sin(TIME * 4.0 + NODE_POSITION_WORLD.z) * 0.08;
	}
}

void fragment() {
	ALBEDO = outline_color;
}
