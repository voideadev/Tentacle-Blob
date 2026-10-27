shader_type canvas_item;
varying vec2 wp;

void vertex() { wp = VERTEX; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 base = vec3(0.11, 0.11, 0.16);
	vec2 c = fract(wp / 128.0);
	float panel = clamp(step(c.x, 0.012) + step(c.y, 0.012), 0.0, 1.0);
	float grime = vnoise(wp * 0.01) * 0.7 + vnoise(wp * 0.08) * 0.3;
	float py = abs(fract(wp.y / 320.0) - 0.5);
	float pipe = smoothstep(0.03, 0.0, abs(py - 0.40)) * 0.5;
	vec3 col = base * (0.6 + 0.8 * grime);
	col += vec3(0.05, 0.06, 0.09) * panel;
	col += vec3(0.10, 0.11, 0.15) * pipe;
	COLOR = vec4(col, 1.0);
}
