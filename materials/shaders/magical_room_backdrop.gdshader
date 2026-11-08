shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Magical Pastel Dream Sky & Cozy Studio Backdrop (100% unshaded -> 60 FPS & NEVER black!)
uniform vec4 top_sky : source_color = vec4(0.91, 0.84, 0.99, 1.0);
uniform vec4 mid_pastel : source_color = vec4(0.99, 0.88, 0.95, 1.0);
uniform vec4 horizon_cream : source_color = vec4(1.0, 0.95, 0.91, 1.0);

void fragment() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	vec3 col = mix(horizon_cream.rgb, mid_pastel.rgb, smoothstep(0.05, 0.52, h));
	col = mix(col, top_sky.rgb, smoothstep(0.48, 0.96, h));

	// Soft dreamy bokeh bubbles & twinkling pastel starlight
	vec2 p = UV * vec2(10.0, 6.0);
	vec2 id = floor(p);
	vec2 gv = fract(p) - 0.5;
	float seed = fract(sin(dot(id, vec2(27.1, 91.7))) * 43758.5453);
	if (seed > 0.58) {
		float drift = sin(TIME * (0.6 + seed) + seed * 6.28) * 0.14;
		float r = 0.12 + fract(seed * 13.7) * 0.18;
		float d = length(gv - vec2(drift, cos(TIME * 0.5 + seed * 9.0) * 0.12));
		float bokeh = smoothstep(r, r * 0.25, d) * 0.24;
		col += vec3(1.0, 0.97, 1.0) * bokeh;
	}

	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
}
