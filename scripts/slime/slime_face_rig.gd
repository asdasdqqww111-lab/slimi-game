class_name SlimeFaceRig
extends Node3D
## نظام تعبيرات وجه سلايمي المرجعي عالي الدقة مع مزامنة الكلام (Lip-Sync) و20 شعوراً:
## عيون مجرّية لامعة بنجمة ذهبية، حواجب تعبيرية ناعمة، خدود موردة بخطوط ///، وفم ناطق بلسان وردي.

enum FaceExpression {
	HAPPY = 0,
	PLAYFUL = 1,
	CURIOUS = 2,
	SLEEPY = 3,
	HUNGRY = 4,
	AFFECTIONATE = 5,
	DIZZY = 6,
	SURPRISED = 7,
}

var left_eye_pivot: Node3D
var right_eye_pivot: Node3D
var left_iris_group: Node3D
var right_iris_group: Node3D
var left_upper_lid: MeshInstance3D
var right_upper_lid: MeshInstance3D
var left_brow: MeshInstance3D
var right_brow: MeshInstance3D
var left_cheek: MeshInstance3D
var right_cheek: MeshInstance3D
var mouth_mesh_instance: MeshInstance3D
var tongue_mesh_instance: MeshInstance3D

var current_expression: int = FaceExpression.HAPPY
var gaze_local_offset := Vector2.ZERO

var _target_gaze := Vector2.ZERO
var _blink_countdown: float = 3.2
var _blink_progress: float = 0.0
var _is_blinking: bool = false
var _eye_openness: float = 1.0
var _emotion_eye_open_override: float = -1.0
var _emotion_blush_override: float = -1.0
var _brow_tilt_target_deg: float = 4.0
var _brow_lift_target: float = 0.0
var _blush_amount: float = 0.78
var _cheek_puff_amount: float = 0.0
var _tongue_blep_active: bool = false
var _dizzy_phase: float = 0.0

# متغيرات مزامنة النطق الحية (Lip-Sync)
var is_lip_syncing: bool = false
var lip_sync_open: float = 0.0
var lip_sync_wide: float = 1.0
var lip_sync_brow_pulse: float = 0.0

var _mouth_meshes: Dictionary = {}
var _left_eye_mat: ShaderMaterial
var _right_eye_mat: ShaderMaterial
var _blush_shader_mat: ShaderMaterial
var _mouth_cavity_mat: StandardMaterial3D
var _tongue_mat: StandardMaterial3D
var _brow_mat: StandardMaterial3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	left_eye_pivot = get_node_or_null("LeftEye") as Node3D
	right_eye_pivot = get_node_or_null("RightEye") as Node3D
	if left_eye_pivot != null:
		left_iris_group = left_eye_pivot.get_node_or_null("IrisGroup") as Node3D
		left_upper_lid = left_eye_pivot.get_node_or_null("UpperLid") as MeshInstance3D
	if right_eye_pivot != null:
		right_iris_group = right_eye_pivot.get_node_or_null("IrisGroup") as Node3D
		right_upper_lid = right_eye_pivot.get_node_or_null("UpperLid") as MeshInstance3D

	left_cheek = get_node_or_null("LeftCheek") as MeshInstance3D
	right_cheek = get_node_or_null("RightCheek") as MeshInstance3D
	mouth_mesh_instance = get_node_or_null("Mouth") as MeshInstance3D

	_setup_galaxy_eyes_and_cheeks()
	_setup_expressive_eyebrows()
	_prebuild_mouth_and_tongue()
	set_expression(FaceExpression.HAPPY)


func _setup_galaxy_eyes_and_cheeks() -> void:
	var eye_shader := load("res://materials/shaders/slime_galaxy_eye.gdshader") as Shader
	if eye_shader != null:
		_left_eye_mat = ShaderMaterial.new()
		_left_eye_mat.shader = eye_shader
		_left_eye_mat.set_shader_parameter("star_side", 1.0)

		_right_eye_mat = ShaderMaterial.new()
		_right_eye_mat.shader = eye_shader
		_right_eye_mat.set_shader_parameter("star_side", 1.0)

		if left_eye_pivot != null:
			var l_sclera := left_eye_pivot.get_node_or_null("Sclera") as MeshInstance3D
			if l_sclera != null:
				l_sclera.material_override = _left_eye_mat
			if left_iris_group != null:
				left_iris_group.visible = false
		if right_eye_pivot != null:
			var r_sclera := right_eye_pivot.get_node_or_null("Sclera") as MeshInstance3D
			if r_sclera != null:
				r_sclera.material_override = _right_eye_mat
			if right_iris_group != null:
				right_iris_group.visible = false

	var cheek_shader := load("res://materials/shaders/slime_cheek_blush.gdshader") as Shader
	if cheek_shader != null:
		_blush_shader_mat = ShaderMaterial.new()
		_blush_shader_mat.shader = cheek_shader
		_blush_shader_mat.render_priority = 3
		if left_cheek != null:
			left_cheek.material_override = _blush_shader_mat
		if right_cheek != null:
			right_cheek.material_override = _blush_shader_mat


func _setup_expressive_eyebrows() -> void:
	_brow_mat = StandardMaterial3D.new()
	_brow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_brow_mat.albedo_color = Color(0.68, 0.22, 0.44, 0.92)
	_brow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var brow_mesh: ArrayMesh = _build_soft_brow_arc(0.052, 0.012, 0.0085)

	left_brow = MeshInstance3D.new()
	left_brow.name = "LeftBrow"
	left_brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	left_brow.mesh = brow_mesh
	left_brow.position = Vector3(-0.185, 0.215, 0.032)
	left_brow.material_override = _brow_mat
	add_child(left_brow)

	right_brow = MeshInstance3D.new()
	right_brow.name = "RightBrow"
	right_brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	right_brow.mesh = brow_mesh
	right_brow.position = Vector3(0.185, 0.215, 0.032)
	right_brow.material_override = _brow_mat
	add_child(right_brow)


func _prebuild_mouth_and_tongue() -> void:
	_mouth_cavity_mat = StandardMaterial3D.new()
	_mouth_cavity_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mouth_cavity_mat.albedo_color = Color(0.58, 0.10, 0.28, 1.0)

	_tongue_mat = StandardMaterial3D.new()
	_tongue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tongue_mat.albedo_color = Color(1.0, 0.50, 0.72, 1.0)

	var open_cute_o := SphereMesh.new()
	open_cute_o.radius = 0.044
	open_cute_o.height = 0.094
	open_cute_o.radial_segments = 22
	open_cute_o.rings = 14

	var open_joy := SphereMesh.new()
	open_joy.radius = 0.056
	open_joy.height = 0.104
	open_joy.radial_segments = 22
	open_joy.rings = 14

	var open_surprised := SphereMesh.new()
	open_surprised.radius = 0.052
	open_surprised.height = 0.118
	open_surprised.radial_segments = 22
	open_surprised.rings = 14

	var sleepy_tiny_o := SphereMesh.new()
	sleepy_tiny_o.radius = 0.024
	sleepy_tiny_o.height = 0.046
	sleepy_tiny_o.radial_segments = 16
	sleepy_tiny_o.rings = 10

	_mouth_meshes[FaceExpression.HAPPY] = open_cute_o
	_mouth_meshes[FaceExpression.CURIOUS] = open_cute_o
	_mouth_meshes[FaceExpression.HUNGRY] = open_joy
	_mouth_meshes[FaceExpression.PLAYFUL] = open_joy
	_mouth_meshes[FaceExpression.SURPRISED] = open_surprised
	_mouth_meshes[FaceExpression.SLEEPY] = sleepy_tiny_o
	_mouth_meshes[FaceExpression.AFFECTIONATE] = _build_cat_mouth(0.072, -0.024, 0.012)
	_mouth_meshes[FaceExpression.DIZZY] = _build_wavy_mouth(0.070, 0.014, 0.011)

	if mouth_mesh_instance != null:
		mouth_mesh_instance.material_override = _mouth_cavity_mat
		mouth_mesh_instance.scale = Vector3(1.0, 1.05, 0.34)

		tongue_mesh_instance = MeshInstance3D.new()
		tongue_mesh_instance.name = "TongueMesh"
		tongue_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var t_sphere := SphereMesh.new()
		t_sphere.radius = 0.031
		t_sphere.height = 0.046
		t_sphere.radial_segments = 18
		t_sphere.rings = 10
		tongue_mesh_instance.mesh = t_sphere
		tongue_mesh_instance.position = Vector3(0.0, -0.018, 0.022)
		tongue_mesh_instance.scale = Vector3(1.05, 0.78, 0.55)
		tongue_mesh_instance.material_override = _tongue_mat
		mouth_mesh_instance.add_child(tongue_mesh_instance)


func set_expression(expr: int) -> void:
	current_expression = expr
	_emotion_eye_open_override = -1.0
	_emotion_blush_override = -1.0
	_refresh_mouth_mesh()


func apply_emotion_profile(profile: Dictionary) -> void:
	var face_id: int = int(profile.get("face", FaceExpression.HAPPY))
	current_expression = face_id
	_emotion_eye_open_override = float(profile.get("eye_open", -1.0))
	_emotion_blush_override = float(profile.get("blush", -1.0))
	_brow_tilt_target_deg = float(profile.get("brow_tilt", 4.0))
	_brow_lift_target = float(profile.get("brow_lift", 0.0))
	_refresh_mouth_mesh()


func set_lip_sync_frame(mouth_open: float, mouth_wide: float, brow_lift: float, speaking: bool) -> void:
	is_lip_syncing = speaking
	lip_sync_open = clampf(mouth_open, 0.0, 1.35)
	lip_sync_wide = clampf(mouth_wide, 0.75, 1.35)
	lip_sync_brow_pulse = clampf(brow_lift, -0.02, 0.04)
	_refresh_mouth_mesh()


func set_tongue_blep(enabled: bool) -> void:
	_tongue_blep_active = enabled
	_refresh_mouth_mesh()


func set_cheek_puff(amount: float) -> void:
	_cheek_puff_amount = clampf(amount, 0.0, 1.0)


func _refresh_mouth_mesh() -> void:
	if mouth_mesh_instance == null:
		return

	if is_lip_syncing and lip_sync_open > 0.08:
		mouth_mesh_instance.mesh = _mouth_meshes[FaceExpression.HAPPY]
		var sy: float = clampf(0.32 + lip_sync_open * 1.18, 0.28, 1.55)
		var sx: float = clampf(lip_sync_wide * (0.85 + lip_sync_open * 0.25), 0.75, 1.35)
		mouth_mesh_instance.scale = Vector3(sx, sy, 0.34)
		if tongue_mesh_instance != null:
			tongue_mesh_instance.visible = lip_sync_open > 0.24
			tongue_mesh_instance.position = Vector3(0.0, -0.018, 0.022)
			tongue_mesh_instance.scale = Vector3(1.05, 0.78, 0.55)
		return

	if _mouth_meshes.has(current_expression):
		mouth_mesh_instance.mesh = _mouth_meshes[current_expression]
		var is_cavity: bool = current_expression in [
			FaceExpression.HAPPY,
			FaceExpression.CURIOUS,
			FaceExpression.HUNGRY,
			FaceExpression.PLAYFUL,
			FaceExpression.SURPRISED,
			FaceExpression.SLEEPY,
		]
		mouth_mesh_instance.scale = Vector3(1.0, 1.05, 0.34) if is_cavity else Vector3.ONE
		if tongue_mesh_instance != null:
			if _tongue_blep_active:
				tongue_mesh_instance.visible = true
				tongue_mesh_instance.position = Vector3(0.0, -0.036, 0.048)
				tongue_mesh_instance.scale = Vector3(1.18, 1.35, 0.72)
			else:
				tongue_mesh_instance.visible = is_cavity and current_expression != FaceExpression.SLEEPY
				tongue_mesh_instance.position = Vector3(0.0, -0.018, 0.022)
				tongue_mesh_instance.scale = Vector3(1.05, 0.78, 0.55)


func set_look_direction_local(local_dir: Vector3) -> void:
	_target_gaze = Vector2(
		clampf(local_dir.x * 0.036, -0.028, 0.028),
		clampf(local_dir.y * 0.030, -0.022, 0.022)
	)


func trigger_blink() -> void:
	_is_blinking = true
	_blink_progress = 0.0


func _process(delta: float) -> void:
	if current_expression != FaceExpression.SLEEPY:
		_blink_countdown -= delta
		if _blink_countdown <= 0.0 and not _is_blinking:
			_is_blinking = true
			_blink_progress = 0.0
			_blink_countdown = _rng.randf_range(2.6, 5.4)

	var blink_factor: float = 0.0
	if _is_blinking:
		_blink_progress += delta / 0.14
		if _blink_progress >= 1.0:
			_is_blinking = false
			_blink_progress = 0.0
		else:
			blink_factor = sin(_blink_progress * PI)

	var target_open: float = 1.0
	var target_blush: float = 0.78
	var lid_tilt_deg: float = 0.0

	match current_expression:
		FaceExpression.SLEEPY:
			target_open = 0.12
			target_blush = 0.55
		FaceExpression.AFFECTIONATE:
			target_open = 0.45
			target_blush = 1.15
			lid_tilt_deg = -9.0
		FaceExpression.PLAYFUL:
			target_open = 1.06
			target_blush = 0.92
		FaceExpression.CURIOUS:
			target_open = 1.08
			target_blush = 0.80
			lid_tilt_deg = 6.0
		FaceExpression.SURPRISED:
			target_open = 1.14
			target_blush = 0.88
		FaceExpression.HUNGRY:
			target_open = 0.92
			target_blush = 0.65
			lid_tilt_deg = 10.0
		FaceExpression.DIZZY:
			target_open = 0.85
			target_blush = 0.95
			_dizzy_phase += delta * 9.5

	if _emotion_eye_open_override > 0.0:
		target_open = _emotion_eye_open_override
	if _emotion_blush_override > 0.0:
		target_blush = _emotion_blush_override

	var final_open: float = clampf(target_open * (1.0 - blink_factor * 0.92), 0.08, 1.18)
	_eye_openness = lerpf(_eye_openness, final_open, minf(1.0, delta * 16.0))
	_blush_amount = lerpf(_blush_amount, target_blush, minf(1.0, delta * 6.0))
	gaze_local_offset = gaze_local_offset.lerp(_target_gaze, minf(1.0, delta * 10.0))

	_apply_eye_and_brow_transforms(lid_tilt_deg, delta)
	_apply_blush()


func _apply_eye_and_brow_transforms(lid_tilt_deg: float, delta: float) -> void:
	var base_eye_scale := 1.42
	if left_eye_pivot != null:
		left_eye_pivot.scale = Vector3(base_eye_scale, base_eye_scale * _eye_openness, base_eye_scale)
	if right_eye_pivot != null:
		var right_open: float = _eye_openness * (0.94 if current_expression == FaceExpression.CURIOUS else 1.0)
		right_eye_pivot.scale = Vector3(base_eye_scale, base_eye_scale * right_open, base_eye_scale)

	var left_gaze: Vector2 = gaze_local_offset
	var right_gaze: Vector2 = gaze_local_offset
	if current_expression == FaceExpression.DIZZY:
		left_gaze = Vector2(cos(_dizzy_phase), sin(_dizzy_phase)) * 0.024
		right_gaze = Vector2(-cos(_dizzy_phase), sin(_dizzy_phase)) * 0.024

	if _left_eye_mat != null:
		_left_eye_mat.set_shader_parameter("gaze_uv", left_gaze)
	if _right_eye_mat != null:
		_right_eye_mat.set_shader_parameter("gaze_uv", right_gaze)

	var lid_y: float = lerpf(0.015, 0.085, clampf(_eye_openness, 0.0, 1.0))
	if left_upper_lid != null:
		left_upper_lid.visible = _eye_openness < 0.88
		left_upper_lid.position.y = lid_y
		left_upper_lid.rotation_degrees.z = lid_tilt_deg
	if right_upper_lid != null:
		right_upper_lid.visible = _eye_openness < 0.88
		right_upper_lid.position.y = lid_y
		right_upper_lid.rotation_degrees.z = -lid_tilt_deg

	var target_brow_y: float = 0.215 + _brow_lift_target + (lip_sync_brow_pulse if is_lip_syncing else 0.0)
	var blend: float = minf(1.0, delta * 12.0)
	if left_brow != null:
		left_brow.position.y = lerpf(left_brow.position.y, target_brow_y, blend)
		left_brow.rotation_degrees.z = lerpf(left_brow.rotation_degrees.z, _brow_tilt_target_deg, blend)
	if right_brow != null:
		right_brow.position.y = lerpf(right_brow.position.y, target_brow_y, blend)
		right_brow.rotation_degrees.z = lerpf(right_brow.rotation_degrees.z, -_brow_tilt_target_deg, blend)


func _apply_blush() -> void:
	if _blush_shader_mat != null:
		_blush_shader_mat.set_shader_parameter("blush_intensity", clampf(_blush_amount + _cheek_puff_amount * 0.25, 0.25, 1.35))
	var cheek_scale: float = 1.18 + _blush_amount * 0.16 + _cheek_puff_amount * 0.42
	if left_cheek != null:
		left_cheek.scale = Vector3(cheek_scale, cheek_scale * (0.68 + _cheek_puff_amount * 0.24), 0.32 + _cheek_puff_amount * 0.25)
	if right_cheek != null:
		right_cheek.scale = Vector3(cheek_scale, cheek_scale * (0.68 + _cheek_puff_amount * 0.24), 0.32 + _cheek_puff_amount * 0.25)


func _build_soft_brow_arc(half_width: float, arch_height: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 10
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var y: float = sin(u * PI) * arch_height
		pts.append(Vector3(x, y, 0.008))
	return _extrude_tube_along_points(pts, radius)


func _build_cat_mouth(half_width: float, depth: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var lobe: float = absf(sin(u * PI * 2.0))
		pts.append(Vector3(x, depth * lobe, 0.012))
	return _extrude_tube_along_points(pts, radius)


func _build_wavy_mouth(half_width: float, amp: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		pts.append(Vector3(x, sin(u * TAU * 1.5) * amp, 0.012))
	return _extrude_tube_along_points(pts, radius)


func _extrude_tube_along_points(points: PackedVector3Array, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring_sides: int = 6
	var count: int = points.size()
	if count < 2:
		return ArrayMesh.new()

	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	for i in range(count):
		var prev_idx: int = maxi(0, i - 1)
		var next_idx: int = mini(count - 1, i + 1)
		var tangent: Vector3 = (points[next_idx] - points[prev_idx]).normalized()
		if tangent.length_squared() < 0.001:
			tangent = Vector3.RIGHT
		var up_axis := Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD)) <= 0.92 else Vector3.UP
		var normal_a: Vector3 = tangent.cross(up_axis).normalized()
		var normal_b: Vector3 = tangent.cross(normal_a).normalized()
		var u: float = float(i) / float(count - 1)
		var taper: float = 0.45 + 0.55 * sin(u * PI)
		var r_verts := PackedVector3Array()
		var r_norms := PackedVector3Array()
		for s in range(ring_sides):
			var theta: float = TAU * float(s) / float(ring_sides)
			var dir: Vector3 = (normal_a * cos(theta) + normal_b * sin(theta)).normalized()
			r_verts.append(points[i] + dir * (radius * taper))
			r_norms.append(dir)
		rings.append(r_verts)
		ring_normals.append(r_norms)

	for i in range(count - 1):
		for s in range(ring_sides):
			var next_s: int = (s + 1) % ring_sides
			st.set_normal(ring_normals[i][s]); st.add_vertex(rings[i][s])
			st.set_normal(ring_normals[i + 1][s]); st.add_vertex(rings[i + 1][s])
			st.set_normal(ring_normals[i + 1][next_s]); st.add_vertex(rings[i + 1][next_s])
			st.set_normal(ring_normals[i][s]); st.add_vertex(rings[i][s])
			st.set_normal(ring_normals[i + 1][next_s]); st.add_vertex(rings[i + 1][next_s])
			st.set_normal(ring_normals[i][next_s]); st.add_vertex(rings[i][next_s])

	return st.commit()
