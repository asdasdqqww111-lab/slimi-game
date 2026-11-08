shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Cozy Butter-Yellow Ribbed Knitted Beanie Shader matching the reference hat
uniform vec4 yarn_bright : source_color = vec4(1.0, 0.90, 0.56, 1.0);
uniform vec4 yarn_mid : source_color = vec4(0.98, 0.78, 0.36, 1.0);
uniform vec4 yarn_shadow : source_color = vec4(0.84, 0.58, 0.20, 1.0);
uniform float rib_columns : hint_range(8.0, 48.0) = 26.0;
uniform float stitch_rows : hint_range(8.0, 48.0) = 22.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);

	// Procedural braided V-knit stitch pattern
	float col_phase = UV.x * rib_columns;
	float col_frac = fract(col_phase) - 0.5;
	// Chevron V-shape per knit column
	float row_chevron = fract(UV.y * stitch_rows + abs(col_frac) * 0.85);
	float rib_ridge = cos(col_frac * 6.28318) * 0.5 + 0.5;
	float loop_bump = sin(row_chevron * 3.14159);
	float stitch_height = clamp(rib_ridge * 0.68 + loop_bump * 0.38, 0.0, 1.0);

	// Studio warm top-left sunlight + cozy velvet yarn fuzz rim
	float studio_lit = clamp(dot(n, normalize(vec3(-0.35, 0.72, 0.60))) * 0.5 + 0.55, 0.2, 1.0);
	float fuzz_rim = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 2.2);

	vec3 yarn_col = mix(yarn_shadow.rgb, yarn_mid.rgb, smoothstep(0.15, 0.65, stitch_height));
	yarn_col = mix(yarn_col, yarn_bright.rgb, smoothstep(0.62, 0.98, stitch_height) * studio_lit);
	yarn_col *= (0.76 + 0.28 * studio_lit);
	yarn_col += vec3(1.0, 0.96, 0.84) * fuzz_rim * 0.30;

	ALBEDO = clamp(yarn_col, vec3(0.0), vec3(1.0));
}
