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
	vec3 base = vec3(0.30, 0.33, 0.42);
	vec2 g = wp / 64.0;
	vec2 c = fract(g);
	float line = clamp(step(c.x, 0.03) + step(c.y, 0.03), 0.0, 1.0);
	float grime = vnoise(wp * 0.02) * 0.6 + vnoise(wp * 0.15) * 0.4;
	vec2 r = abs(c - 0.5);
	float rivet = step(length(c - vec2(0.12)), 0.035);
	vec3 col = base * (0.7 + 0.6 * grime);
	col *= 1.0 - line * 0.40;
	col += vec3(0.10) * rivet;
	COLOR = vec4(col, 1.0);
}
