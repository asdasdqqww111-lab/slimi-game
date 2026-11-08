shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// Seam-free coral-pink rosy cheek blush with 3 crisp white "///" anime slash marks
uniform vec4 blush_color : source_color = vec4(1.0, 0.38, 0.56, 0.78);
uniform float blush_intensity : hint_range(0.1, 1.3) = 0.82;
uniform vec2 mesh_half_extents = vec2(0.095, 0.095);

varying vec2 v_cheek_uv;

float segment_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void vertex() {
	v_cheek_uv = vec2(VERTEX.x / max(mesh_half_extents.x, 0.001), -VERTEX.y / max(mesh_half_extents.y, 0.001));
}

void fragment() {
	vec2 uv = v_cheek_uv;
	float ellip = length(uv * vec2(0.95, 1.12));
	float soft_glow = pow(clamp(1.0 - ellip, 0.0, 1.0), 1.65);

	// Three cute diagonal white blush lines "///"
	float s1 = 1.0 - smoothstep(0.042, 0.068, segment_dist(uv, vec2(-0.36, -0.02), vec2(-0.20, -0.36)));
	float s2 = 1.0 - smoothstep(0.042, 0.068, segment_dist(uv, vec2(-0.08, -0.01), vec2(0.08, -0.35)));
	float s3 = 1.0 - smoothstep(0.042, 0.068, segment_dist(uv, vec2(0.20, -0.02), vec2(0.36, -0.36)));
	float slashes = clamp(s1 + s2 + s3, 0.0, 1.0) * smoothstep(0.05, 0.30, soft_glow);

	vec3 col = mix(blush_color.rgb, vec3(1.0, 0.99, 1.0), slashes * 0.96);
	float alpha = clamp(soft_glow * blush_color.a * blush_intensity + slashes * 0.88, 0.0, 0.96);

	ALBEDO = col;
	ALPHA = alpha;
}
