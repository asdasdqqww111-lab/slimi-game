shader_type canvas_item;

// Lightweight Mobile Glassmorphism Shader (frosted pearl glass + diagonal specular sheen, zero GPU blur stall!)
uniform vec4 glass_tint : source_color = vec4(1.0, 0.96, 0.99, 0.78);
uniform vec4 border_glow : source_color = vec4(1.0, 1.0, 1.0, 0.65);
uniform float sheen_strength : hint_range(0.0, 0.5) = 0.16;

void fragment() {
	float diag = UV.x * 0.65 + UV.y * 0.35;
	float sheen = exp(-pow((diag - 0.34) * 4.5, 2.0)) * sheen_strength;
	float top_frost = smoothstep(0.65, 0.0, UV.y) * 0.10;
	vec3 col = clamp(glass_tint.rgb + vec3(sheen + top_frost), vec3(0.0), vec3(1.0));
	COLOR = vec4(col, glass_tint.a);
}
