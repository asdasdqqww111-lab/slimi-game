shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_top : source_color = vec4(1.0, 0.77, 0.87, 1.0);
uniform vec4 albedo_bottom : source_color = vec4(0.95, 0.55, 0.74, 1.0);
uniform vec4 subsurface_color : source_color = vec4(1.0, 0.46, 0.68, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.97, 1.0);
uniform vec4 mood_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float roughness_val : hint_range(0.02, 0.6) = 0.11;
uniform float specular_val : hint_range(0.0, 1.0) = 0.86;
uniform float subsurface_strength : hint_range(0.0, 1.0) = 0.34;
uniform float rim_strength : hint_range(0.0, 1.5) = 0.62;

uniform vec3 squash_stretch = vec3(1.0, 1.0, 1.0);
uniform vec3 jiggle_offset = vec3(0.0, 0.0, 0.0);
uniform vec3 poke_local_pos = vec3(0.0, 0.2, 0.5);
uniform float poke_strength : hint_range(0.0, 1.0) = 0.0;
uniform float poke_phase = 0.0;
uniform float breath_phase = 0.0;
uniform float flatten_bottom : hint_range(0.0, 0.45) = 0.18;
uniform int detail_level : hint_range(0, 2) = 1;

varying float v_height_factor;
varying float v_poke_mask;

vec3 deform_slime_point(vec3 p) {
	// Normalized vertical weight from bottom (-0.55) to top (+0.55)
	float h = clamp((p.y + 0.55) / 1.1, 0.0, 1.0);

	// Soft jelly bottom contact flattening & slight wider puddle base
	if (p.y < -0.22) {
		float bottom_t = clamp((-0.22 - p.y) / 0.35, 0.0, 1.0);
		p.y += bottom_t * bottom_t * flatten_bottom;
		float radial_spread = 1.0 + bottom_t * flatten_bottom * 0.42;
		p.x *= radial_spread;
		p.z *= radial_spread;
	}

	// Living organic breath expansion
	float breath = sin(breath_phase) * 0.022;
	p.y *= (1.0 + breath);
	p.xz *= (1.0 - breath * 0.48);

	// Volume-preserving squash & stretch
	p *= squash_stretch;

	// Upper-body elastic jiggle shear
	float jiggle_weight = h * h;
	p += jiggle_offset * jiggle_weight;

	// Localized touch poke dent & concentric elastic ripple
	if (poke_strength > 0.001) {
		float dist = distance(p, poke_local_pos);
		float falloff = exp(-dist * dist * 11.0);
		float ripple = 0.0;
		if (detail_level >= 1) {
			ripple = sin(dist * 16.0 - poke_phase) * exp(-dist * 4.5) * 0.38;
		}
		vec3 dir = normalize(p + vec3(0.0, 0.0001, 0.0));
		p -= dir * (falloff * 0.14 - ripple * 0.06) * poke_strength;
	}

	// Subtle secondary organic wobble on High quality
	if (detail_level >= 2) {
		float micro = sin(p.x * 7.0 + breath_phase * 1.7) * cos(p.z * 7.0 + breath_phase * 1.3);
		p += normalize(p + vec3(0.0, 0.001, 0.0)) * micro * 0.005;
	}

	return p;
}

void vertex() {
	vec3 orig = VERTEX;
	vec3 deformed = deform_slime_point(orig);
	v_height_factor = clamp((orig.y + 0.55) / 1.1, 0.0, 1.0);

	float p_dist = distance(orig, poke_local_pos);
	v_poke_mask = exp(-p_dist * p_dist * 9.0) * poke_strength;

	// Finite-difference tangent basis normal reconstruction so glossy highlights ripple accurately
	if (detail_level >= 1 && (poke_strength > 0.002 || length(jiggle_offset) > 0.002)) {
		vec3 up_ref = abs(NORMAL.y) < 0.92 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
		vec3 tangent = normalize(cross(up_ref, NORMAL));
		vec3 bitangent = normalize(cross(NORMAL, tangent));
		float eps = 0.025;
		vec3 p_t = deform_slime_point(orig + tangent * eps);
		vec3 p_b = deform_slime_point(orig + bitangent * eps);
		vec3 recomputed = cross(p_b - deformed, p_t - deformed);
		if (length(recomputed) > 0.00001) {
			NORMAL = normalize(recomputed);
		}
	} else {
		NORMAL = normalize(NORMAL / max(squash_stretch, vec3(0.25)));
	}

	VERTEX = deformed;
}

void fragment() {
	vec3 base_col = mix(albedo_bottom.rgb, albedo_top.rgb, smoothstep(0.08, 0.92, v_height_factor));
	base_col *= mood_tint.rgb;

	// Fresnel rim & translucent gummy inner glow
	float ndotv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.8);
	float center_thickness = pow(ndotv, 1.6);

	vec3 jelly_glow = subsurface_color.rgb * (center_thickness * subsurface_strength * 0.45);
	vec3 pearlescent_rim = rim_color.rgb * (fresnel * rim_strength);

	// Slight warm blush where poked
	base_col = mix(base_col, subsurface_color.rgb, v_poke_mask * 0.28);

	ALBEDO = clamp(base_col + pearlescent_rim * 0.28, vec3(0.0), vec3(1.0));
	EMISSION = jelly_glow + pearlescent_rim * 0.22;
	ROUGHNESS = roughness_val;
	SPECULAR = specular_val;
	METALLIC = 0.02;
}
