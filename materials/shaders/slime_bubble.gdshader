shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// Translucent glossy suspended jelly bubble shader (matches internal & rim bubbles in reference image)
uniform vec4 bubble_tint : source_color = vec4(1.0, 0.82, 0.93, 1.0);

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndotv = clamp(dot(n, v), 0.0, 1.0);

	float rim = pow(1.0 - ndotv, 2.1);
	vec3 key = normalize(vec3(-0.45, 0.65, 0.61));
	float spec = smoothstep(0.91, 0.985, max(dot(n, normalize(key + v)), 0.0));
	float bottom_glint = pow(max(dot(n, normalize(vec3(0.3, -0.7, 0.6) + v)), 0.0), 14.0) * 0.45;

	vec3 col = mix(bubble_tint.rgb, vec3(1.0), clamp(rim * 0.7 + spec + bottom_glint, 0.0, 1.0));
	float alpha = clamp(0.14 + rim * 0.58 + spec * 0.88 + bottom_glint * 0.4, 0.0, 0.95);

	ALBEDO = col;
	ALPHA = alpha;
}
