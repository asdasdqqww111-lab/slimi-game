shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
// Seam-free High-Detail Expressive Starry Eye Shader:
// Supports independent gaze, pupil focus dilation, squint shaping, and dynamic light-tracked catchlights.

uniform vec2 gaze_uv = vec2(0.0, 0.0);
uniform vec2 highlight_shift = vec2(0.0, 0.0);
uniform float pupil_scale : hint_range(0.70, 1.35) = 1.0;
uniform float star_side = 1.0;
uniform vec2 mesh_half_extents = vec2(0.095, 0.095);

varying vec2 v_eye_uv;

float sd_five_star(vec2 p, float r, float rf) {
	const vec2 k1 = vec2(0.809016994, -0.587785252);
	const vec2 k2 = vec2(-k1.x, k1.y);
	p.x = abs(p.x);
	p -= 2.0 * max(dot(k1, p), 0.0) * k1;
	p -= 2.0 * max(dot(k2, p), 0.0) * k2;
	p.x = abs(p.x);
	p.y -= r;
	vec2 ba = rf * vec2(-k1.y, k1.x) - vec2(0.0, 1.0);
	float h = clamp(dot(p, ba) / dot(ba, ba), 0.0, r);
	return length(p - ba * h) * sign(p.y * ba.x - p.x * ba.y);
}

float four_sparkle(vec2 p, float size) {
	p = abs(p);
	float d = (p.x + p.y) / size;
	float core = exp(-dot(p, p) / (size * size * 0.14));
	float rays = max(0.0, 1.0 - d) * exp(-min(p.x, p.y) / (size * 0.18));
	return clamp(core + rays * 0.95, 0.0, 1.0);
}

void vertex() {
	v_eye_uv = vec2(VERTEX.x / max(mesh_half_extents.x, 0.001), -VERTEX.y / max(mesh_half_extents.y, 0.001));
}

void fragment() {
	vec2 uv = v_eye_uv;
	float radial = length(uv);

	vec3 lash_col = vec3(0.16, 0.03, 0.11);
	vec3 sclera_col = vec3(1.0, 0.98, 0.99);

	vec2 iris_p = uv - vec2(gaze_uv.x, -gaze_uv.y) * 5.5;
	float iris_dist = length(iris_p * vec2(1.02, 0.98));

	// Deep obsidian-midnight top -> luminous orchid nebula bottom (retains signature dark large eyes!)
	float neb_t = smoothstep(-0.10, 0.74, iris_p.y);
	vec3 night_sky = vec3(0.04, 0.015, 0.07);
	vec3 mid_violet = vec3(0.24, 0.04, 0.31);
	vec3 lower_nebula = vec3(0.88, 0.19, 0.70);
	vec3 hot_pink_glow = vec3(1.0, 0.56, 0.90);

	vec3 iris_col = mix(night_sky, mid_violet, smoothstep(-0.48, 0.22, iris_p.y));
	iris_col = mix(iris_col, lower_nebula, neb_t * smoothstep(0.92, 0.18, iris_dist));

	float cloud = 0.5 + 0.5 * sin(iris_p.x * 7.2 + 1.1) * cos(iris_p.y * 6.0);
	iris_col += hot_pink_glow * neb_t * cloud * 0.34 * smoothstep(0.86, 0.26, iris_dist);

	// Dynamic focus/emotion pupil dilation
	float p_rad = 0.46 * pupil_scale;
	float pupil_mask = 1.0 - smoothstep(p_rad * 0.52, p_rad, length(iris_p - vec2(0.0, -0.05)));
	iris_col = mix(iris_col, vec3(0.02, 0.008, 0.04), pupil_mask * 0.86);

	// Starfield micro-specks
	vec2 grid = iris_p * 5.2;
	vec2 cid = floor(grid);
	vec2 cell = fract(grid) - 0.5;
	float h = fract(sin(dot(cid, vec2(12.9898, 78.233))) * 43758.5453);
	if (h > 0.70 && iris_dist < 0.78) {
		float tiny_star = smoothstep(0.16, 0.02, length(cell));
		iris_col += vec3(1.0, 0.90, 0.99) * tiny_star * (0.45 + 0.48 * neb_t);
	}

	// Signature golden 5-pointed star in lower iris
	vec2 gold_star_pos = vec2(0.18 * star_side, 0.30);
	float star_d = sd_five_star(iris_p - gold_star_pos, 0.19, 0.46);
	float gold_star_mask = 1.0 - smoothstep(-0.015, 0.022, star_d);
	iris_col = mix(iris_col, vec3(1.0, 0.91, 0.50), gold_star_mask);

	// 4-point sparkles
	float sp1 = four_sparkle(iris_p - vec2(-0.32, 0.12), 0.14);
	float sp2 = four_sparkle(iris_p - vec2(0.33, -0.02), 0.11);
	iris_col += vec3(1.0) * (sp1 + sp2 * 0.88);

	// Glossy corneal catchlights with subtle parallax shift
	vec2 catch_main = (iris_p - (vec2(-0.24, -0.30) + highlight_shift)) * vec2(0.88, 1.12);
	float hi_big = 1.0 - smoothstep(0.18, 0.215, length(catch_main));
	float hi_dot = 1.0 - smoothstep(0.07, 0.095, length(iris_p - (vec2(0.08, -0.42) + highlight_shift * 0.6)));
	iris_col = mix(iris_col, vec3(1.0), clamp(hi_big + hi_dot * 0.92, 0.0, 1.0));

	float iris_mask = 1.0 - smoothstep(0.82, 0.87, iris_dist);
	vec3 eye_col = mix(sclera_col, iris_col, iris_mask);

	float lash_arch = smoothstep(0.80, 0.93, radial) * smoothstep(0.32, -0.35, uv.y);
	eye_col = mix(eye_col, lash_col, lash_arch * 0.96);

	ALBEDO = clamp(eye_col, vec3(0.0), vec3(1.0));
}
