shader_type spatial;
render_mode unshaded;

// Animated hazard surface for hurdles: molten lava or a pulsing laser. Colours run from `cool`
// to `hot` with flowing noise; values above 1 feed the glow so it reads as dangerous.
uniform vec3 cool : source_color = vec3(0.9, 0.2, 0.02);
uniform vec3 hot : source_color = vec3(1.0, 0.85, 0.3);
uniform float brightness = 1.8;
uniform float flow_speed = 0.6;
uniform float scale = 3.0;
uniform float pulse = 0.0;

varying vec3 local_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 p = local_pos.xz * scale + vec2(local_pos.y * scale, 0.0);
	float t = TIME * flow_speed;
	float n = noise(p + vec2(t, t * 0.4)) * 0.6 + noise(p * 2.3 - vec2(t * 1.3, 0.0)) * 0.4;
	float heat = smoothstep(0.25, 0.85, n);
	float beat = 1.0 + pulse * 0.35 * sin(TIME * 12.0 + local_pos.x * 4.0);
	ALBEDO = mix(cool, hot, heat) * brightness * beat;
}
