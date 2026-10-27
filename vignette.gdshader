shader_type canvas_item;
uniform float strength = 0.55;
uniform float damage = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	float v = smoothstep(0.30, 0.85, length(uv * vec2(1.0, 1.15)));
	float grain = fract(sin(dot(UV * vec2(1280.0, 720.0) + TIME * 60.0, vec2(12.9898, 78.233))) * 43758.5453);
	vec3 c = mix(vec3(0.0), vec3(0.55, 0.0, 0.04), clamp(damage, 0.0, 1.0));
	float al = v * strength + damage * (0.10 + v * 0.55) + grain * 0.035;
	COLOR = vec4(c, clamp(al, 0.0, 1.0));
}
