shader_type canvas_item;

uniform float threshold = 0.5;
uniform vec2 view_size = vec2(1280.0, 720.0);
uniform float zoom = 0.8;
uniform vec2 cam_pos = vec2(0.0);
uniform vec2 origin = vec2(0.0);
uniform float energy = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float f = texture(TEXTURE, UV).r;
	float a = smoothstep(threshold - 0.02, threshold + 0.02, f);

	float s = 2.0;
	float fx = texture(TEXTURE, UV + vec2(px.x * s, 0.0)).r - texture(TEXTURE, UV - vec2(px.x * s, 0.0)).r;
	float fy = texture(TEXTURE, UV + vec2(0.0, px.y * s)).r - texture(TEXTURE, UV - vec2(0.0, px.y * s)).r;
	vec3 n = normalize(vec3(-fx * 9.0, -fy * 9.0, 0.35));

	vec3 L = normalize(vec3(-0.55, -0.65, 0.55));
	float diff = clamp(dot(n, L) * 0.5 + 0.5, 0.0, 1.0);
	vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
	float spec = pow(clamp(dot(n, H), 0.0, 1.0), 40.0);

	vec2 wp = (UV - 0.5) * view_size / zoom + cam_pos - origin;
	float v = vnoise(wp * 0.055 + vec2(TIME * 0.15, 0.0));
	float vein = smoothstep(0.47, 0.5, v) * smoothstep(0.53, 0.5, v);
	float pulse = 0.5 + 0.5 * sin(TIME * 2.6 + vnoise(wp * 0.03) * 6.0);
	float mott = vnoise(wp * 0.12 + 7.0);

	vec3 dark = vec3(0.22, 0.015, 0.045);
	vec3 mid = vec3(0.60, 0.065, 0.105);
	vec3 light = vec3(0.95, 0.30, 0.26);

	vec3 col = mix(dark, mid, diff);
	col = mix(col, light, pow(diff, 3.0) * 0.55);
	col *= 0.85 + 0.3 * mott;
	col += vec3(0.40, 0.05, 0.13) * vein * 0.55;
	float depth = smoothstep(threshold, 0.95, f);
	col += light * 0.07 * pulse * depth;
	col += vec3(spec) * 0.6;
	col += vec3(0.7, 0.1, 0.1) * energy * 0.35;

	col *= mix(0.40, 1.0, smoothstep(threshold, threshold + 0.10, f));
	col *= mix(0.65, 1.05, depth);

	COLOR = vec4(col, a);
}
