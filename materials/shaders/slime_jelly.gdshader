shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;
// SLIMI High-End Hydrogel Shader (Compatibility-Renderer Safe Optical Approximations):
// ملاحظة هندسية صريحة: جميع تأثيرات SSS والانكسار وتشتت الضوء الداخلي هنا هي تقريبات بصرية فورية
// (Real-time Analytical Shader Approximations) مصممة لتعمل بثبات 60 FPS على محرك gl_compatibility للأندرويد.

uniform vec4 core_milk_color : source_color = vec4(1.0, 0.75, 0.88, 1.0);
uniform vec4 mid_jelly_color : source_color = vec4(0.99, 0.49, 0.76, 1.0);
uniform vec4 edge_glass_color : source_color = vec4(0.95, 0.33, 0.67, 1.0);
uniform vec4 rim_pearl_color : source_color = vec4(1.0, 0.95, 0.99, 1.0);
uniform vec4 albedo_top : source_color = vec4(1.0, 0.79, 0.90, 1.0);
uniform vec4 albedo_bottom : source_color = vec4(0.97, 0.47, 0.74, 1.0);
uniform vec4 subsurface_color : source_color = vec4(1.0, 0.38, 0.68, 1.0);
uniform vec4 mood_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float roughness_val : hint_range(0.02, 0.5) = 0.05;
uniform float subsurface_strength : hint_range(0.0, 1.2) = 0.68;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.88;
uniform float ior_ratio : hint_range(0.65, 0.90) = 0.743; // ~ 1.0 / 1.345 (Hydrogel)

// اتجاهات الإضاءة السينمائية الديناميكية في فضاء العالم (تتفاعل حياً مع دوران الكاميرا والشخصية)
uniform vec3 key_light_dir_ws = vec3(-0.46, 0.68, 0.57);
uniform vec3 fill_light_dir_ws = vec3(0.58, 0.44, 0.68);
uniform vec3 rim_light_dir_ws = vec3(0.12, 0.54, -0.83);

// معطيات التشوه الهلامي المرن وحقل الموجات الموضعية متعدد النقاط (4 نقاط لمس متزامنة)
uniform bool is_prebaked_mochi = true;
uniform vec3 squash_stretch = vec3(1.0, 1.0, 1.0);
uniform vec3 jiggle_offset = vec3(0.0, 0.0, 0.0);
uniform float breath_phase = 0.0;
uniform float flatten_bottom : hint_range(0.0, 0.45) = 0.24;
uniform int detail_level : hint_range(0, 2) = 2;

// توافق خلفي مع اللمسة المفردة + مصفوفة 4 موجات لمس موجهة
uniform vec3 poke_local_pos = vec3(0.0, 0.2, 0.5);
uniform float poke_strength : hint_range(0.0, 1.0) = 0.0;
uniform float poke_phase = 0.0;

uniform vec4 poke_slot_pos_0 = vec4(0.0, 0.2, 0.5, 0.0); // xyz=local_pos, w=strength
uniform vec4 poke_slot_dir_0 = vec4(0.0, 0.0, -1.0, 0.0); // xyz=inward_dir, w=phase
uniform vec4 poke_slot_pos_1 = vec4(0.0, 0.2, 0.5, 0.0);
uniform vec4 poke_slot_dir_1 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 poke_slot_pos_2 = vec4(0.0, 0.2, 0.5, 0.0);
uniform vec4 poke_slot_dir_2 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 poke_slot_pos_3 = vec4(0.0, 0.2, 0.5, 0.0);
uniform vec4 poke_slot_dir_3 = vec4(0.0, 0.0, -1.0, 0.0);

varying vec3 v_local_orig;
varying vec3 v_world_normal;
varying vec3 v_world_view;
varying float v_height_factor;
varying float v_total_compression;

void eval_wave_slot(
	vec3 orig_p,
	vec4 slot_pos,
	vec4 slot_dir,
	inout vec3 disp_sum,
	inout vec3 norm_tilt_sum,
	inout float comp_mask_sum
) {
	float strength = slot_pos.w;
	if (strength <= 0.001) {
		return;
	}
	vec3 diff = orig_p - slot_pos.xyz;
	float dist = length(diff);
	float phase = slot_dir.w;

	// انضغاط موضعي في نقطة التلامس + انتقال تدريجي للموجة المرنة إلى المناطق المجاورة
	float primary_dent = exp(-dist * dist * 11.5);
	float wave_front_r = clamp(phase * 0.055, 0.0, 0.85);
	float neighbor_ring = exp(-pow((dist - wave_front_r) * 4.8, 2.0)) * exp(-phase * 0.14);
	float ripple = 0.0;
	if (detail_level >= 1) {
		ripple = sin(dist * 17.0 - phase) * exp(-dist * 3.8) * 0.36;
	}

	vec3 press_dir = normalize(slot_dir.xyz + vec3(0.0, 0.0001, 0.0));
	float signed_amp = (primary_dent * 0.145 - neighbor_ring * 0.048 - ripple * 0.045) * strength;
	disp_sum += press_dir * signed_amp;
	norm_tilt_sum += diff * (primary_dent * 2.1 * strength);
	comp_mask_sum += primary_dent * strength;
}

void vertex() {
	vec3 orig = VERTEX;
	v_local_orig = orig;
	float h = clamp((orig.y + 0.53) / 1.06, 0.0, 1.0);
	v_height_factor = h;

	vec3 p = orig;
	// إذا كان المجسم SphereMesh احتياطياً غير مسبق النحت، نطبق منحنى الكمثرى المرجعي
	if (!is_prebaked_mochi) {
		float pear_profile = mix(1.19, 0.89, smoothstep(0.14, 0.94, h));
		float cheek_plump = 1.0 + 0.055 * exp(-pow((h - 0.34) * 3.4, 2.0));
		p.x *= pear_profile * cheek_plump;
		p.z *= mix(1.14, 0.88, smoothstep(0.14, 0.94, h)) * cheek_plump;
		if (p.y < -0.18) {
			float bottom_t = clamp((-0.18 - p.y) / 0.36, 0.0, 1.0);
			p.y += bottom_t * bottom_t * flatten_bottom;
			float spread = 1.0 + bottom_t * flatten_bottom * 0.36;
			p.x *= spread;
			p.z *= spread;
		}
	}

	// تنفس عضوي وحفظ حجم هلامي مرن
	float breath = sin(breath_phase) * 0.020;
	p.y *= (1.0 + breath);
	p.xz *= (1.0 - breath * 0.46);
	p *= squash_stretch;

	// قص الاهتزاز الثانوي العلوي بوزن ناعم
	float jiggle_w = h * h * (1.35 - 0.35 * h);
	p += jiggle_offset * jiggle_w;

	// تجميع حقل موجات اللمس الموجهة (الأربع فتحات + التوافق الخلفي)
	vec3 wave_disp = vec3(0.0);
	vec3 wave_norm = vec3(0.0);
	float comp_mask = 0.0;

	eval_wave_slot(orig, poke_slot_pos_0, poke_slot_dir_0, wave_disp, wave_norm, comp_mask);
	eval_wave_slot(orig, poke_slot_pos_1, poke_slot_dir_1, wave_disp, wave_norm, comp_mask);
	eval_wave_slot(orig, poke_slot_pos_2, poke_slot_dir_2, wave_disp, wave_norm, comp_mask);
	eval_wave_slot(orig, poke_slot_pos_3, poke_slot_dir_3, wave_disp, wave_norm, comp_mask);

	if (poke_strength > 0.001 && poke_slot_pos_0.w <= 0.001) {
		vec3 fallback_inward = -normalize(orig + vec3(0.0, 0.01, 0.0));
		eval_wave_slot(orig, vec4(poke_local_pos, poke_strength), vec4(fallback_inward, poke_phase), wave_disp, wave_norm, comp_mask);
	}

	p += wave_disp;
	v_total_compression = clamp(comp_mask, 0.0, 1.2);

	// تعديل تحليلي آمن للناظم (fp16-safe على Android بدون مشتقات متناهية الصغر)
	vec3 safe_scale = max(squash_stretch, vec3(0.35));
	vec3 n_local = NORMAL / safe_scale;
	n_local.xz -= jiggle_offset.xz * h * 0.52;
	n_local += wave_norm;
	n_local = normalize(n_local);

	NORMAL = n_local;
	VERTEX = p;

	v_world_normal = normalize((MODEL_MATRIX * vec4(n_local, 0.0)).xyz);
	vec3 world_pos = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	v_world_view = normalize(CAMERA_POSITION_WORLD - world_pos);
}

float ggx_lobe(float ndoth, float alpha) {
	float a2 = alpha * alpha;
	float denom = ndoth * ndoth * (a2 - 1.0) + 1.0;
	return a2 / max(3.14159265 * denom * denom, 0.0008);
}

void fragment() {
	vec3 n_ws = normalize(v_world_normal);
	vec3 v_ws = normalize(v_world_view);

	// 8. Fine surface irregularities (تفاصيل مجهرية ناعمة لسطح الهلام الرطب على المستوى العالي فقط)
	if (detail_level >= 2) {
		vec3 micro_wave = vec3(
			sin(v_local_orig.y * 46.0 + v_local_orig.z * 38.0),
			cos(v_local_orig.z * 44.0 + v_local_orig.x * 40.0),
			sin(v_local_orig.x * 42.0 - v_local_orig.y * 36.0)
		);
		n_ws = normalize(n_ws + micro_wave * 0.016);
	}

	float ndotv = clamp(dot(n_ws, v_ws), 0.0, 1.0);

	// 1. Thickness-based translucency (حساب السماكة الضوئية التقريبية عبر مركز الجسم والحواف والانضغاط)
	float dome_thinness = smoothstep(0.52, 0.98, v_height_factor) * 0.28;
	float optical_thickness = clamp(smoothstep(0.08, 0.88, ndotv) * (1.0 - dome_thinness) - v_total_compression * 0.18, 0.06, 1.0);
	float edge_thinness = 1.0 - optical_thickness;

	// 3. Schlick Fresnel reflections (IOR ~ 1.345 -> F0 = 0.042)
	float f0 = 0.042;
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndotv, 4.2);

	// 4 & 7. Controlled Refraction & Internal Light Scattering Approximation
	vec3 refr_ray = refract(-v_ws, n_ws, ior_ratio);
	float interior_depth_grad = clamp(refr_ray.y * 0.5 + 0.5, 0.0, 1.0);
	vec3 deep_core_rgb = mix(mid_jelly_color.rgb, core_milk_color.rgb, smoothstep(0.15, 0.85, optical_thickness));
	vec3 vert_rgb = mix(albedo_bottom.rgb, albedo_top.rgb, smoothstep(0.06, 0.94, v_height_factor));
	vec3 base_gel = mix(edge_glass_color.rgb, deep_core_rgb, 0.35 + 0.65 * optical_thickness);
	base_gel = mix(base_gel, vert_rgb, 0.26);

	// تشتت داخلي كوستيكي ناعم وفقاعات دقيقة معلقة داخل الهلام عبر الشعاع المنكسر
	if (detail_level >= 1) {
		vec3 sample_interior = v_local_orig * 26.0 + refr_ray * 2.4;
		float caustic = 0.5 + 0.5 * sin(sample_interior.x + breath_phase * 0.4) * cos(sample_interior.y * 1.1) * sin(sample_interior.z);
		base_gel += vec3(1.0, 0.72, 0.88) * smoothstep(0.76, 0.98, caustic) * (0.14 * (0.4 + 0.6 * edge_thinness));
		base_gel += vec3(1.0, 0.88, 0.96) * interior_depth_grad * edge_thinness * 0.12;
	}

	// 2. Subsurface Scattering (SSS) Approximation المتفاعلة مع اتجاه الإضاءة وزاوية الكاميرا
	vec3 l_key = normalize(key_light_dir_ws);
	vec3 l_fill = normalize(fill_light_dir_ws);
	vec3 l_rim = normalize(rim_light_dir_ws);

	float wrap_key = clamp((dot(n_ws, l_key) + 0.55) / 1.55, 0.0, 1.0);
	float wrap_fill = clamp((dot(n_ws, l_fill) + 0.65) / 1.65, 0.0, 1.0);
	float back_trans_key = pow(clamp(dot(v_ws, normalize(-(l_key + n_ws * 0.38))), 0.0, 1.0), 3.0);
	float back_trans_rim = pow(clamp(dot(v_ws, normalize(-(l_rim + n_ws * 0.35))), 0.0, 1.0), 2.6);
	float sss_energy = (back_trans_key * 0.65 + back_trans_rim * 0.55) * (0.35 + 0.65 * edge_thinness) * subsurface_strength;

	vec3 lit_gel = base_gel * (0.74 + 0.22 * wrap_key + 0.10 * wrap_fill);
	lit_gel += subsurface_color.rgb * sss_energy * 0.48;
	lit_gel = mix(lit_gel, subsurface_color.rgb, clamp(v_total_compression * 0.32, 0.0, 0.38));

	// ارتداد ضوء الطاولة/الأرضية الدافئ أسفل القاعدة الهلامية
	float floor_bounce = smoothstep(0.40, 0.02, v_height_factor) * optical_thickness;
	lit_gel += vec3(1.0, 0.56, 0.80) * floor_bounce * 0.15;

	// 6. Environment Reflections (انعكاس بيئة الاستوديو السماوية والأرضية الدافئة)
	vec3 refl_ws = reflect(-v_ws, n_ws);
	vec3 env_sky = vec3(1.0, 0.94, 0.99);
	vec3 env_horizon = vec3(0.96, 0.80, 0.94);
	vec3 env_ground = vec3(0.92, 0.66, 0.82);
	vec3 env_col = mix(env_horizon, env_sky, smoothstep(0.0, 0.75, refl_ws.y));
	env_col = mix(env_col, env_ground, smoothstep(0.0, -0.65, refl_ws.y));

	// 5 & 9. Glossy Dual-Lobe Specular & Wet Jelly Highlights
	vec3 h_key = normalize(l_key + v_ws);
	vec3 h_fill = normalize(l_fill + v_ws);
	vec3 h_rim = normalize(l_rim + v_ws);

	float coat_alpha = clamp(roughness_val, 0.035, 0.25);
	float wet_coat_key = min(ggx_lobe(max(dot(n_ws, h_key), 0.0), coat_alpha) * 0.032, 1.15);
	float soft_gel_key = pow(max(dot(n_ws, h_key), 0.0), 22.0) * 0.28;
	float wet_coat_fill = (detail_level >= 1) ? min(ggx_lobe(max(dot(n_ws, h_fill), 0.0), coat_alpha * 1.25) * 0.022, 0.80) : 0.0;
	float wet_rim_glint = pow(max(dot(n_ws, h_rim), 0.0), 16.0) * fresnel * 0.65;

	vec3 pearl_rim = rim_pearl_color.rgb * (fresnel * rim_strength * 0.82 + edge_thinness * 0.14);
	vec3 env_contrib = env_col * fresnel * 0.42;
	vec3 wet_specular = vec3(1.0, 0.99, 1.0) * (wet_coat_key + soft_gel_key + wet_coat_fill + wet_rim_glint);

	vec3 final_rgb = lit_gel * mood_tint.rgb + pearl_rim + env_contrib + wet_specular;
	ALBEDO = clamp(final_rgb, vec3(0.0), vec3(1.0));
}
