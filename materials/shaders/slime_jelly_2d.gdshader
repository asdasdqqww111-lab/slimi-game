shader_type canvas_item;

// Reusable 2D CanvasItem Glossy Crystal-Jelly Shader (used for HUD emblem & 2D jelly sprites)
uniform vec4 core_color : source_color = vec4(1.0, 0.76, 0.88, 0.96);
uniform vec4 mid_color : source_color = vec4(0.99, 0.48, 0.75, 0.94);
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.97, 1.0);
uniform float jelly_alpha : hint_range(0.4, 1.0) = 0.95;
uniform float breath_speed : hint_range(0.5, 6.0) = 2.4;
uniform float wobble_amount : hint_range(0.0, 0.08) = 0.022;

void fragment() {
	vec2 centered = (UV - vec2(0.5, 0.54)) * vec2(1.0, 1.12);
	// Continuous organic breathing squash & stretch
	float breath = sin(TIME * breath_speed) * wobble_amount;
	centered.x /= (1.0 - breath * 0.6);
	centered.y /= (1.0 + breath);

	// Plump mochi-slime silhouette SDF
	float pear_widen = mix(1.14, 0.86, clamp((0.5 - UV.y) + 0.5, 0.0, 1.0));
	vec2 p = vec2(centered.x / pear_widen, centered.y);
	float dist = length(p);
	float radius = 0.43;
	float edge_alpha = 1.0 - smoothstep(radius - 0.02, radius + 0.01, dist);

	// Pseudo-3D spherical normal for Fresnel & glossy studio highlight
	float nr = clamp(dist / radius, 0.0, 1.0);
	float nz = sqrt(max(0.0, 1.0 - nr * nr));
	vec3 normal_3d = normalize(vec3(p.x / radius, -p.y / radius, nz));

	float fresnel = pow(1.0 - nz, 2.4);
	vec3 body = mix(mid_color.rgb, core_color.rgb, smoothstep(0.15, 0.9, nz));
	body = mix(body, rim_color.rgb, fresnel * 0.72);

	// Upper-left studio crescent specular highlight
	vec3 light_dir = normalize(vec3(-0.45, 0.58, 0.68));
	float spec = smoothstep(0.93, 0.985, max(dot(normal_3d, light_dir), 0.0));
	float soft_glow = pow(max(dot(normal_3d, light_dir), 0.0), 14.0) * 0.25;

	// Cute tiny internal bubble
	float bub = 1.0 - smoothstep(0.038, 0.048, length(p - vec2(0.22, 0.16)));
	vec3 final_col = clamp(body + vec3(spec * 0.9 + soft_glow + bub * 0.35), vec3(0.0), vec3(1.0));

	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(final_col * mix(vec3(1.0), tex.rgb, 0.15), edge_alpha * jelly_alpha);
}
