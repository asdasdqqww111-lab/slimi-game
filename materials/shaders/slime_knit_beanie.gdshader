shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
// Cozy High-Detail Multi-Ply Knitted Wool Beanie Shader (Compatibility-Renderer Optimized)

uniform vec4 yarn_bright : source_color = vec4(1.0, 0.91, 0.56, 1.0);
uniform vec4 yarn_mid : source_color = vec4(0.98, 0.78, 0.35, 1.0);
uniform vec4 yarn_shadow : source_color = vec4(0.80, 0.53, 0.17, 1.0);
uniform float rib_columns : hint_range(8.0, 56.0) = 28.0;
uniform float stitch_rows : hint_range(8.0, 56.0) = 24.0;
uniform vec3 key_light_dir_ws = vec3(-0.46, 0.68, 0.57);
uniform int detail_level : hint_range(0, 2) = 2;

varying vec3 v_world_normal;
varying vec3 v_world_view;

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_view = normalize(CAMERA_POSITION_WORLD - world_pos);
}

void fragment() {
	vec3 n = normalize(v_world_normal);
	vec3 v = normalize(v_world_view);

	// ضفائر الحياكة الصوفية المزدوجة (V-Chevron Knit + Purl Valleys + Twisted Yarn Plies)
	float col_phase = UV.x * rib_columns;
	float col_frac = fract(col_phase) - 0.5;
	float row_chevron = fract(UV.y * stitch_rows + abs(col_frac) * 0.92);
	float rib_ridge = cos(col_frac * 6.28318) * 0.5 + 0.5;
	float loop_arch = sin(row_chevron * 3.14159);

	float fine_ply = 0.0;
	if (detail_level >= 1) {
		fine_ply = sin((UV.x * rib_columns * 5.0 + UV.y * stitch_rows * 3.0) * 6.28318) * 0.08;
	}

	float stitch_height = clamp(rib_ridge * 0.64 + loop_arch * 0.38 + fine_ply, 0.0, 1.0);
	float valley_ao = smoothstep(0.05, 0.55, stitch_height);

	// إضاءة ناعمة دافئة مع وبر الصوف الجانبي (Velvet Wool Fuzz Rim)
	float key_lit = clamp(dot(n, normalize(key_light_dir_ws)) * 0.5 + 0.55, 0.22, 1.0);
	float fuzz_rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.1);

	vec3 yarn_col = mix(yarn_shadow.rgb, yarn_mid.rgb, smoothstep(0.12, 0.62, stitch_height));
	yarn_col = mix(yarn_col, yarn_bright.rgb, smoothstep(0.58, 0.96, stitch_height) * key_lit);
	yarn_col *= (0.72 + 0.28 * valley_ao) * (0.78 + 0.26 * key_lit);
	yarn_col += vec3(1.0, 0.96, 0.84) * fuzz_rim * 0.34;

	ALBEDO = clamp(yarn_col, vec3(0.0), vec3(1.0));
}
