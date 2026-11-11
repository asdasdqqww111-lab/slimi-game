class_name RoomEnvironment
extends Node3D
## إعداد العرض السينمائي ثلاثي النقاط للغرفة (Cinematic 3-Point Studio Lighting Rig):
## يضم Soft Key Light + Pastel Fill Light + Back Rim Light مع 4 خلفيات جوية قابلة للتبديل حياً.

const BACKDROP_THEMES: Dictionary = {
	"pastel_dream": {
		"ar": "حلم الباستيل الوردي",
		"en": "Pastel Dream",
		"swatch": Color(0.98, 0.84, 0.94),
		"top_sky": Color(0.91, 0.84, 0.99, 1.0),
		"mid_pastel": Color(0.99, 0.88, 0.95, 1.0),
		"horizon_cream": Color(1.0, 0.95, 0.91, 1.0),
		"wall": Color(0.98, 0.93, 0.97, 1.0),
		"floor": Color(0.95, 0.88, 0.94, 1.0),
		"sun": Color(1.0, 0.97, 0.95, 1.0),
	},
	"golden_sunset": {
		"ar": "شروق ذهبي دافئ",
		"en": "Golden Glow",
		"swatch": Color(1.0, 0.78, 0.56),
		"top_sky": Color(0.98, 0.76, 0.82, 1.0),
		"mid_pastel": Color(1.0, 0.86, 0.74, 1.0),
		"horizon_cream": Color(1.0, 0.95, 0.84, 1.0),
		"wall": Color(0.99, 0.93, 0.88, 1.0),
		"floor": Color(0.95, 0.87, 0.80, 1.0),
		"sun": Color(1.0, 0.93, 0.84, 1.0),
	},
	"starry_night": {
		"ar": "سماء النجوم الهادئة",
		"en": "Starlight Evening",
		"swatch": Color(0.42, 0.36, 0.68),
		"top_sky": Color(0.20, 0.16, 0.38, 1.0),
		"mid_pastel": Color(0.32, 0.25, 0.54, 1.0),
		"horizon_cream": Color(0.48, 0.36, 0.64, 1.0),
		"wall": Color(0.30, 0.25, 0.46, 1.0),
		"floor": Color(0.26, 0.22, 0.40, 1.0),
		"sun": Color(0.92, 0.90, 1.0, 1.0),
	},
	"mint_meadow": {
		"ar": "نسيم النعناع المنعش",
		"en": "Mint Breeze",
		"swatch": Color(0.68, 0.94, 0.84),
		"top_sky": Color(0.80, 0.95, 0.92, 1.0),
		"mid_pastel": Color(0.88, 0.98, 0.92, 1.0),
		"horizon_cream": Color(0.97, 0.99, 0.93, 1.0),
		"wall": Color(0.92, 0.98, 0.95, 1.0),
		"floor": Color(0.86, 0.94, 0.90, 1.0),
		"sun": Color(0.98, 1.0, 0.97, 1.0),
	},
}

var sun_light: DirectionalLight3D
var studio_fill_light: DirectionalLight3D
var studio_rim_light: DirectionalLight3D
var warm_accent_light: OmniLight3D
var treat_anchor: Marker3D
var poi_container: Node3D
var current_backdrop_id: String = "pastel_dream"

var _treat_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _wall_runtime_mat: StandardMaterial3D
var _floor_runtime_mat: StandardMaterial3D
var _sky_runtime_mat: ShaderMaterial


func _ready() -> void:
	sun_light = get_node_or_null("MainSunLight") as DirectionalLight3D
	warm_accent_light = get_node_or_null("WarmAccentLight") as OmniLight3D
	treat_anchor = get_node_or_null("Props/FoodBowl/TreatAnchor") as Marker3D
	poi_container = get_node_or_null("PointsOfInterest") as Node3D

	_setup_cinematic_fill_and_rim_lights()

	_treat_material = StandardMaterial3D.new()
	_treat_material.albedo_color = Color(1.0, 0.45, 0.68, 1.0)
	_treat_material.roughness = 0.18
	_treat_material.metallic_specular = 0.8
	_treat_material.emission_enabled = true
	_treat_material.emission = Color(1.0, 0.35, 0.62, 1.0)
	_treat_material.emission_energy_multiplier = 0.25

	_ring_material = StandardMaterial3D.new()
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.albedo_color = Color(1.0, 0.65, 0.84, 0.72)

	if QualityManager != null:
		QualityManager.quality_changed.connect(_on_quality_changed)
		_on_quality_changed(QualityManager.current_preset, QualityManager.get_current_profile())

	_bind_room_surface_materials()
	var saved_bg: String = str(SaveManager.get_section("ui_preferences").get("room_backdrop", "pastel_dream"))
	apply_room_backdrop_theme(saved_bg)


func _bind_room_surface_materials() -> void:
	var sky_mesh := get_node_or_null("MagicalSkyBackdrop") as MeshInstance3D
	if sky_mesh != null:
		var sm := sky_mesh.get_active_material(0)
		if sm is ShaderMaterial:
			_sky_runtime_mat = (sm as ShaderMaterial).duplicate() as ShaderMaterial
			sky_mesh.set_surface_override_material(0, _sky_runtime_mat)

	var back_wall := get_node_or_null("Walls/BackWall") as MeshInstance3D
	if back_wall != null:
		var wm := back_wall.get_active_material(0)
		if wm is StandardMaterial3D:
			_wall_runtime_mat = (wm as StandardMaterial3D).duplicate() as StandardMaterial3D
			var walls_root := get_node_or_null("Walls") as Node3D
			if walls_root != null:
				for w in walls_root.get_children():
					if w is MeshInstance3D:
						(w as MeshInstance3D).material_override = _wall_runtime_mat

	var floor_mesh := get_node_or_null("FloorBody/FloorMesh") as MeshInstance3D
	if floor_mesh != null:
		var fm := floor_mesh.get_active_material(0)
		if fm is StandardMaterial3D:
			_floor_runtime_mat = (fm as StandardMaterial3D).duplicate() as StandardMaterial3D
			floor_mesh.material_override = _floor_runtime_mat


func apply_room_backdrop_theme(theme_id: String) -> void:
	if not BACKDROP_THEMES.has(theme_id):
		theme_id = "pastel_dream"
	current_backdrop_id = theme_id
	var cfg: Dictionary = BACKDROP_THEMES[theme_id]

	if _sky_runtime_mat != null:
		_sky_runtime_mat.set_shader_parameter("top_sky", cfg["top_sky"])
		_sky_runtime_mat.set_shader_parameter("mid_pastel", cfg["mid_pastel"])
		_sky_runtime_mat.set_shader_parameter("horizon_cream", cfg["horizon_cream"])
	if _wall_runtime_mat != null:
		_wall_runtime_mat.albedo_color = cfg["wall"]
	if _floor_runtime_mat != null:
		_floor_runtime_mat.albedo_color = cfg["floor"]
	if sun_light != null:
		sun_light.light_color = cfg["sun"]


func _setup_cinematic_fill_and_rim_lights() -> void:
	if sun_light != null:
		sun_light.light_color = Color(1.0, 0.97, 0.95, 1.0)
		sun_light.light_energy = 0.82
		sun_light.shadow_opacity = 0.26

	studio_fill_light = DirectionalLight3D.new()
	studio_fill_light.name = "StudioFillLight"
	studio_fill_light.light_color = Color(0.95, 0.92, 1.0, 1.0)
	studio_fill_light.light_energy = 0.28
	studio_fill_light.shadow_enabled = false
	studio_fill_light.rotation_degrees = Vector3(-28.0, -42.0, 0.0)
	add_child(studio_fill_light)

	studio_rim_light = DirectionalLight3D.new()
	studio_rim_light.name = "CinematicRimLight"
	studio_rim_light.light_color = Color(1.0, 0.90, 0.98, 1.0)
	studio_rim_light.light_energy = 0.36
	studio_rim_light.shadow_enabled = false
	studio_rim_light.rotation_degrees = Vector3(-34.0, 162.0, 0.0)
	add_child(studio_rim_light)


func get_studio_light_directions() -> Dictionary:
	var key_dir := Vector3(-0.46, 0.68, 0.57).normalized()
	var fill_dir := Vector3(0.58, 0.44, 0.68).normalized()
	var rim_dir := Vector3(0.12, 0.54, -0.83).normalized()

	if sun_light != null:
		key_dir = sun_light.global_transform.basis.z.normalized()
	if studio_fill_light != null:
		fill_dir = studio_fill_light.global_transform.basis.z.normalized()
	if studio_rim_light != null:
		rim_dir = studio_rim_light.global_transform.basis.z.normalized()

	return {
		"key": key_dir,
		"fill": fill_dir,
		"rim": rim_dir,
	}


func get_points_of_interest() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if poi_container != null:
		for child in poi_container.get_children():
			if child is Node3D:
				result.append((child as Node3D).global_position)
	return result


func spawn_treat_berry() -> Vector3:
	var target_pos := Vector3(0.62, 0.14, 0.52)
	if treat_anchor != null:
		target_pos = treat_anchor.global_position

	var berry := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.radial_segments = 16
	sphere.rings = 10
	berry.mesh = sphere
	berry.material_override = _treat_material
	add_child(berry)
	berry.global_position = target_pos + Vector3(0.0, 0.65, 0.0)

	var tw: Tween = create_tween()
	tw.tween_property(berry, "global_position", target_pos, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(berry, "scale", Vector3(0.05, 0.05, 0.05), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(berry.queue_free)

	return Vector3(target_pos.x, 0.0, target_pos.z)


func spawn_floor_tap_ring(world_pos: Vector3) -> void:
	var ring_inst := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.10
	torus.outer_radius = 0.15
	torus.rings = 20
	torus.ring_segments = 8
	ring_inst.mesh = torus

	var mat_copy: StandardMaterial3D = _ring_material.duplicate() as StandardMaterial3D
	ring_inst.material_override = mat_copy
	add_child(ring_inst)
	ring_inst.global_position = Vector3(world_pos.x, 0.02, world_pos.z)
	ring_inst.scale = Vector3(0.5, 0.3, 0.5)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring_inst, "scale", Vector3(1.65, 0.3, 1.65), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat_copy, "albedo_color:a", 0.0, 0.38)
	tw.chain().tween_callback(ring_inst.queue_free)


func _on_quality_changed(_preset: int, profile: Dictionary) -> void:
	if sun_light != null:
		sun_light.shadow_enabled = bool(profile.get("shadows_enabled", true))
	if studio_fill_light != null:
		studio_fill_light.visible = bool(profile.get("fill_light", true))
	if studio_rim_light != null:
		studio_rim_light.visible = bool(profile.get("rim_light", true))
	if warm_accent_light != null:
		warm_accent_light.visible = bool(profile.get("accent_light", true))
