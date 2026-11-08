shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// Crystal Rose-Pink Jelly Palette inspired directly by the reference character
uniform vec4 core_milk_color : source_color = vec4(1.0, 0.75, 0.88, 1.0);
uniform vec4 mid_jelly_color : source_color = vec4(0.99, 0.50, 0.76, 1.0);
uniform vec4 edge_glass_color : source_color = vec4(0.95, 0.34, 0.67, 1.0);
uniform vec4 rim_pearl_color : source_color = vec4(1.0, 0.94, 0.98, 1.0);
uniform vec4 albedo_top : source_color = vec4(1.0, 0.78, 0.89, 1.0);
uniform vec4 albedo_bottom : source_color = vec4(0.97, 0.48, 0.74, 1.0);
uniform vec4 subsurface_color : source_color = vec4(1.0, 0.42, 0.70, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.94, 0.98, 1.0);
uniform vec4 mood_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float roughness_val : hint_range(0.02, 0.6) = 0.06;
uniform float specular_val : hint_range(0.0, 1.0) = 0.96;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.55;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.88;

uniform vec3 squash_stretch = vec3(1.0, 1.0, 1.0);
uniform vec3 jiggle_offset = vec3(0.0, 0.0, 0.0);
uniform vec3 poke_local_pos = vec3(0.0, 0.2, 0.5);
uniform float poke_strength : hint_range(0.0, 1.0) = 0.0;
uniform float poke_phase = 0.0;
uniform float breath_phase = 0.0;
uniform float flatten_bottom : hint_range(0.0, 0.45) = 0.24;
uniform int detail_level : hint_range(0, 2) = 2;

varying vec3 v_local_orig;
varying float v_height_factor;
varying float v_poke_mask;

vec3 deform_slime_point(vec3 p) {
	// Normalized vertical weight from bottom (-0.53) to top (+0.53)
	float h = clamp((p.y + 0.53) / 1.06, 0.0, 1.0);

	// 1. Plump Mochi-Pear Reference Silhouette:
	// Wider chubby lower cheeks/belly, gently tapered rounded dome top
	float pear_profile = mix(1.19, 0.89, smoothstep(0.14, 0.94, h));
	// Extra lower-cheek plushness like the reference image
	float cheek_plump = 1.0 + 0.055 * exp(-pow((h - 0.34) * 3.4, 2.0));
	p.x *= pear_profile * cheek_plump;
	p.z *= mix(1.14, 0.88, smoothstep(0.14, 0.94, h)) * cheek_plump;

	// 2. Soft settled jelly cushion base
	if (p.y < -0.18) {
		float bottom_t = clamp((-0.18 - p.y) / 0.36, 0.0, 1.0);
		p.y += bottom_t * bottom_t * flatten_bottom;
		float puddle_spread = 1.0 + bottom_t * flatten_bottom * 0.36;
		p.x *= puddle_spread;
		p.z *= puddle_spread;
	}

	// 3. Organic continuous breathing
	float breath = sin(breath_phase) * 0.024;
	p.y *= (1.0 + breath);
	p.xz *= (1.0 - breath * 0.46);

	// 4. Volume-preserving squash & stretch
	p *= squash_stretch;

	// 5. Elastic upper-body jiggle shear
	float jiggle_weight = h * h;
	p += jiggle_offset * jiggle_weight;

	// 6. Localized touch poke dent & elastic concentric jelly ripple
	if (poke_strength > 0.001) {
		float dist = distance(p, poke_local_pos);
		float falloff = exp(-dist * dist * 10.0);
		float ripple = 0.0;
		if (detail_level >= 1) {
			ripple = sin(dist * 16.0 - poke_phase) * exp(-dist * 4.2) * 0.40;
		}
		vec3 safe_dir = normalize(p + vec3(0.0, 0.01, 0.0));
		p -= safe_dir * (falloff * 0.15 - ripple * 0.065) * poke_strength;
	}

	return p;
}

void vertex() {
	vec3 orig = VERTEX;
	v_local_orig = orig;
	vec3 deformed = deform_slime_point(orig);
	v_height_factor = clamp((orig.y + 0.53) / 1.06, 0.0, 1.0);

	float p_dist = distance(orig, poke_local_pos);
	v_poke_mask = exp(-p_dist * p_dist * 9.0) * poke_strength;

	// Mobile-safe analytical normal adjustment (avoids mediump fp16 cross-product underflow!)
	vec3 safe_scale = max(squash_stretch, vec3(0.35));
	vec3 n = NORMAL / safe_scale;
	// Pear taper tilts side normals slightly upward like a mochi dome
	n.y += 0.20 * (1.0 - abs(NORMAL.y));
	n.xz -= jiggle_offset.xz * v_height_factor * 0.55;
	if (poke_strength > 0.005) {
		vec3 away_poke = orig - poke_local_pos;
		n += away_poke * (v_poke_mask * 2.2);
	}
	NORMAL = normalize(n);
	VERTEX = deformed;
}

void fragment() {
	// Studio self-illuminated crystal-jelly shading:
	// 100% immune to mobile OpenGL ES shadow/tonemap darkening -> ALWAYS glossy candy pink!
	vec3 n_view = normalize(NORMAL);
	vec3 v_dir = normalize(VIEW);
	float ndotv = clamp(dot(n_view, v_dir), 0.0, 1.0);

	// Radial thickness from creamy center (ndotv ~ 1) to translucent glassy rim (ndotv ~ 0)
	float center_core = smoothstep(0.18, 0.92, ndotv);
	float outer_fresnel = pow(1.0 - ndotv, 2.35);
	float thin_glass_rim = smoothstep(0.55, 0.96, 1.0 - ndotv);

	// Vertical pastel gradient blended with milky translucent core
	vec3 vert_tint = mix(albedo_bottom.rgb, albedo_top.rgb, smoothstep(0.06, 0.92, v_height_factor));
	vec3 jelly_col = mix(edge_glass_color.rgb, mid_jelly_color.rgb, smoothstep(0.08, 0.58, ndotv));
	jelly_col = mix(jelly_col, core_milk_color.rgb, center_core * 0.76);
	jelly_col = mix(jelly_col, vert_tint, 0.28);

	// Soft warm subsurface bottom bounce glow (pink table reflection inside jelly)
	float bottom_bounce = smoothstep(0.42, 0.02, v_height_factor) * (0.4 + 0.6 * center_core);
	jelly_col += vec3(1.0, 0.52, 0.78) * bottom_bounce * 0.16;

	// Warm blush response where finger pokes SLIMI
	jelly_col = mix(jelly_col, subsurface_color.rgb, v_poke_mask * 0.34);

	// Studio Key + Fill Softbox Glossy Crescent Reflections (matching reference photo!)
	vec3 key_light_vs = normalize(vec3(-0.46, 0.64, 0.61));
	vec3 fill_light_vs = normalize(vec3(0.52, 0.56, 0.64));
	vec3 bottom_rim_vs = normalize(vec3(0.0, -0.78, 0.62));

	vec3 half_key = normalize(key_light_vs + v_dir);
	vec3 half_fill = normalize(fill_light_vs + v_dir);
	vec3 half_bot = normalize(bottom_rim_vs + v_dir);

	float spec_key_sharp = smoothstep(0.955, 0.988, max(dot(n_view, half_key), 0.0));
	float spec_key_soft = pow(max(dot(n_view, half_key), 0.0), 26.0) * 0.36;
	float spec_fill_sharp = smoothstep(0.968, 0.993, max(dot(n_view, half_fill), 0.0)) * 0.85;
	float spec_bottom_lip = pow(max(dot(n_view, half_bot), 0.0), 18.0) * outer_fresnel * 0.55;

	// Pearlescent outer crystal contour + crisp studio highlights
	vec3 pearl_edge = rim_pearl_color.rgb * (outer_fresnel * rim_strength * 0.68 + thin_glass_rim * 0.26);
	vec3 gloss_highlights = vec3(1.0) * (spec_key_sharp * 0.92 + spec_key_soft + spec_fill_sharp + spec_bottom_lip);

	// Subtle suspended micro-sparkle droplets inside the jelly
	float sparkle_seed = sin(v_local_orig.x * 37.0 + breath_phase * 0.5) * cos(v_local_orig.y * 43.0) * sin(v_local_orig.z * 31.0);
	float inner_sparkle = smoothstep(0.93, 0.99, sparkle_seed) * (1.0 - center_core * 0.5) * 0.35;

	vec3 final_rgb = jelly_col * mood_tint.rgb + pearl_edge + gloss_highlights + vec3(inner_sparkle);
	ALBEDO = clamp(final_rgb, vec3(0.0), vec3(1.0));
}
