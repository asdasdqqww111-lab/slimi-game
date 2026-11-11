class_name SlimeFaceRig
extends Node3D
## نظام التحريك الدقيق لملامح وجه SLIMI (Facial Micro-Animation System):
## - تتبع مستقل للعينين اليمنى واليسرى مع تقارب بؤري طبيعي (Vergence) ورمش طبيعي ومزدوج وبطيء وتضييق جفون (Squint).
## - 8 أشكال فم نحتية ثلاثية الأبعاد (Resting, Smile, Open Smile, Speaking, Laughing, Sad, Surprised, Pouting).
## - خدود متناظرة مرتبطة بالمشاعر والابتسامة، مع حماية كاملة من التداخل أو الاختفاء أثناء تشوه الجسم.

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

enum BlinkMode {
	NATURAL = 0,
	DOUBLE = 1,
	SLOW = 2,
}

enum MouthShape {
	RESTING = 0,
	SMILE = 1,
	OPEN_SMILE = 2,
	SPEAKING_SMALL = 3,
	LAUGHING = 4,
	SAD = 5,
	SURPRISED = 6,
	POUTING = 7,
}

var left_eye_pivot: Node3D
var right_eye_pivot: Node3D
var left_iris_group: Node3D
var right_iris_group: Node3D
var left_upper_lid: MeshInstance3D
var right_upper_lid: MeshInstance3D
var left_lower_lid: MeshInstance3D
var right_lower_lid: MeshInstance3D
var left_brow: MeshInstance3D
var right_brow: MeshInstance3D
var left_cheek: MeshInstance3D
var right_cheek: MeshInstance3D
var mouth_mesh_instance: MeshInstance3D
var tongue_mesh_instance: MeshInstance3D

var current_expression: int = FaceExpression.HAPPY
var current_mouth_shape: int = MouthShape.OPEN_SMILE
var current_blink_mode: int = BlinkMode.NATURAL

# تتبع مستقل للعينين (Independent Left/Right Gaze)
var left_gaze_offset := Vector2.ZERO
var right_gaze_offset := Vector2.ZERO
var gaze_local_offset := Vector2.ZERO

var squint_amount: float = 0.0
var focus_intensity: float = 0.0
var pupil_scale: float = 1.0

var _target_left_gaze := Vector2.ZERO
var _target_right_gaze := Vector2.ZERO
var _micro_saccade := Vector2.ZERO
var _saccade_timer: float = 1.4

var _blink_countdown: float = 3.2
var _blink_progress: float = 0.0
var _blink_duration: float = 0.14
var _is_blinking: bool = false

var _eye_openness: float = 1.0
var _emotion_eye_open_override: float = -1.0
var _emotion_blush_override: float = -1.0
var _target_squint: float = 0.0
var _target_pupil_scale: float = 1.0
var _brow_tilt_target_deg: float = 4.0
var _brow_lift_target: float = 0.0
var _blush_amount: float = 0.78
var _cheek_puff_amount: float = 0.0
var _tongue_blep_active: bool = false
var _dizzy_phase: float = 0.0

# مزامنة النطق الحية (Lip-Sync)
var is_lip_syncing: bool = false
var lip_sync_open: float = 0.0
var lip_sync_wide: float = 1.0
var lip_sync_brow_pulse: float = 0.0

var _mouth_shape_meshes: Dictionary = {}
var _left_eye_mat: ShaderMaterial
var _right_eye_mat: ShaderMaterial
var _blush_shader_mat: ShaderMaterial
var _mouth_cavity_mat: StandardMaterial3D
var _tongue_mat: StandardMaterial3D
var _brow_mat: StandardMaterial3D
var _lid_mat: StandardMaterial3D
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
	_setup_lower_eyelids_for_squint()
	_setup_expressive_eyebrows()
	_prebuild_eight_mouth_shapes()
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


func _setup_lower_eyelids_for_squint() -> void:
	_lid_mat = StandardMaterial3D.new()
	_lid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lid_mat.albedo_color = Color(0.99, 0.66, 0.84, 1.0)

	var lid_sphere := SphereMesh.new()
	lid_sphere.radius = 0.095
	lid_sphere.height = 0.19
	lid_sphere.radial_segments = 22
	lid_sphere.rings = 14

	if left_eye_pivot != null:
		left_lower_lid = MeshInstance3D.new()
		left_lower_lid.name = "LowerLid"
		left_lower_lid.visible = false
		left_lower_lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		left_lower_lid.mesh = lid_sphere
		left_lower_lid.scale = Vector3(1.10, 0.44, 0.48)
		left_lower_lid.position = Vector3(0.0, -0.078, 0.025)
		left_lower_lid.material_override = _lid_mat
		left_eye_pivot.add_child(left_lower_lid)

	if right_eye_pivot != null:
		right_lower_lid = MeshInstance3D.new()
		right_lower_lid.name = "LowerLid"
		right_lower_lid.visible = false
		right_lower_lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		right_lower_lid.mesh = lid_sphere
		right_lower_lid.scale = Vector3(1.10, 0.44, 0.48)
		right_lower_lid.position = Vector3(0.0, -0.078, 0.025)
		right_lower_lid.material_override = _lid_mat
		right_eye_pivot.add_child(right_lower_lid)


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
	left_brow.position = Vector3(-0.185, 0.215, 0.035)
	left_brow.material_override = _brow_mat
	add_child(left_brow)

	right_brow = MeshInstance3D.new()
	right_brow.name = "RightBrow"
	right_brow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	right_brow.mesh = brow_mesh
	right_brow.position = Vector3(0.185, 0.215, 0.035)
	right_brow.material_override = _brow_mat
	add_child(right_brow)


func _prebuild_eight_mouth_shapes() -> void:
	_mouth_cavity_mat = StandardMaterial3D.new()
	_mouth_cavity_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mouth_cavity_mat.albedo_color = Color(0.56, 0.09, 0.27, 1.0)

	_tongue_mat = StandardMaterial3D.new()
	_tongue_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tongue_mat.albedo_color = Color(1.0, 0.50, 0.72, 1.0)

	var resting_o := SphereMesh.new()
	resting_o.radius = 0.026
	resting_o.height = 0.048
	resting_o.radial_segments = 18
	resting_o.rings = 12

	var open_smile_mesh := SphereMesh.new()
	open_smile_mesh.radius = 0.046
	open_smile_mesh.height = 0.092
	open_smile_mesh.radial_segments = 22
	open_smile_mesh.rings = 14

	var speak_small_mesh := SphereMesh.new()
	speak_small_mesh.radius = 0.038
	speak_small_mesh.height = 0.078
	speak_small_mesh.radial_segments = 20
	speak_small_mesh.rings = 14

	var laugh_wide_mesh := SphereMesh.new()
	laugh_wide_mesh.radius = 0.060
	laugh_wide_mesh.height = 0.112
	laugh_wide_mesh.radial_segments = 24
	laugh_wide_mesh.rings = 16

	var surprised_o_mesh := SphereMesh.new()
	surprised_o_mesh.radius = 0.050
	surprised_o_mesh.height = 0.120
	surprised_o_mesh.radial_segments = 22
	surprised_o_mesh.rings = 14

	_mouth_shape_meshes[MouthShape.RESTING] = resting_o
	_mouth_shape_meshes[MouthShape.SMILE] = _build_curved_arc_mouth(0.068, -0.024, 0.011)
	_mouth_shape_meshes[MouthShape.OPEN_SMILE] = open_smile_mesh
	_mouth_shape_meshes[MouthShape.SPEAKING_SMALL] = speak_small_mesh
	_mouth_shape_meshes[MouthShape.LAUGHING] = laugh_wide_mesh
	_mouth_shape_meshes[MouthShape.SAD] = _build_curved_arc_mouth(0.060, 0.022, 0.0105)
	_mouth_shape_meshes[MouthShape.SURPRISED] = surprised_o_mesh
	_mouth_shape_meshes[MouthShape.POUTING] = _build_wavy_mouth(0.046, 0.010, 0.0115)

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


func get_supported_mouth_shape_count() -> int:
	return _mouth_shape_meshes.size()


func set_mouth_shape(shape_id: int) -> void:
	if not _mouth_shape_meshes.has(shape_id):
		shape_id = MouthShape.OPEN_SMILE
	current_mouth_shape = shape_id
	_refresh_mouth_mesh()


func set_expression(expr: int) -> void:
	current_expression = expr
	_emotion_eye_open_override = -1.0
	_emotion_blush_override = -1.0

	match expr:
		FaceExpression.HAPPY:
			current_mouth_shape = MouthShape.OPEN_SMILE
			_target_squint = 0.12
			_target_pupil_scale = 1.04
		FaceExpression.PLAYFUL:
			current_mouth_shape = MouthShape.LAUGHING
			_target_squint = 0.24
			_target_pupil_scale = 1.08
		FaceExpression.CURIOUS:
			current_mouth_shape = MouthShape.SPEAKING_SMALL
			_target_squint = 0.05
			_target_pupil_scale = 1.14
		FaceExpression.SLEEPY:
			current_mouth_shape = MouthShape.RESTING
			_target_squint = 0.0
			_target_pupil_scale = 0.92
		FaceExpression.HUNGRY:
			current_mouth_shape = MouthShape.SAD
			_target_squint = 0.08
			_target_pupil_scale = 1.06
		FaceExpression.AFFECTIONATE:
			current_mouth_shape = MouthShape.SMILE
			_target_squint = 0.38
			_target_pupil_scale = 1.12
		FaceExpression.DIZZY:
			current_mouth_shape = MouthShape.POUTING
			_target_squint = 0.15
			_target_pupil_scale = 0.90
		FaceExpression.SURPRISED:
			current_mouth_shape = MouthShape.SURPRISED
			_target_squint = 0.0
			_target_pupil_scale = 0.84

	_refresh_mouth_mesh()


func apply_emotion_profile(profile: Dictionary) -> void:
	var face_id: int = int(profile.get("face", FaceExpression.HAPPY))
	set_expression(face_id)
	_emotion_eye_open_override = float(profile.get("eye_open", -1.0))
	_emotion_blush_override = float(profile.get("blush", -1.0))
	_brow_tilt_target_deg = float(profile.get("brow_tilt", 4.0))
	_brow_lift_target = float(profile.get("brow_lift", 0.0))

	var key: String = str(profile.get("key", ""))
	if key in ["sad", "lonely", "tired"]:
		current_mouth_shape = MouthShape.SAD
	elif key in ["angry", "jealous_playful", "frustrated"]:
		current_mouth_shape = MouthShape.POUTING
		_target_squint = 0.30
	elif key in ["calm", "sleepy"]:
		current_mouth_shape = MouthShape.RESTING
	elif key in ["affectionate", "grateful", "shy", "reassured"]:
		current_mouth_shape = MouthShape.SMILE
		_target_squint = 0.34
	elif key in ["excited", "playful"]:
		current_mouth_shape = MouthShape.LAUGHING
		_target_squint = 0.22
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


func set_squint(amount: float) -> void:
	_target_squint = clampf(amount, 0.0, 0.85)


func set_focused_gaze(focused: bool) -> void:
	focus_intensity = 1.0 if focused else 0.0
	_target_pupil_scale = 0.86 if focused else 1.04
	if focused:
		_target_squint = maxf(_target_squint, 0.26)


func set_look_target_local_3d(target_in_face_space: Vector3) -> void:
	# حساب زاوية النظر لكل عين على حدة لتحقيق تقارب بؤري طبيعي (Independent Eye Vergence)
	var safe_z: float = maxf(target_in_face_space.z, 0.22)
	var l_origin := Vector3(-0.185, 0.08, 0.025)
	var r_origin := Vector3(0.185, 0.08, 0.025)

	var l_dir: Vector3 = (Vector3(target_in_face_space.x, target_in_face_space.y, safe_z) - l_origin).normalized()
	var r_dir: Vector3 = (Vector3(target_in_face_space.x, target_in_face_space.y, safe_z) - r_origin).normalized()

	_target_left_gaze = Vector2(
		clampf(l_dir.x * 0.038, -0.029, 0.029),
		clampf(l_dir.y * 0.030, -0.022, 0.022)
	)
	_target_right_gaze = Vector2(
		clampf(r_dir.x * 0.038, -0.029, 0.029),
		clampf(r_dir.y * 0.030, -0.022, 0.022)
	)


func set_look_direction_local(local_dir: Vector3) -> void:
	set_look_target_local_3d(local_dir * 1.6)


func trigger_blink(mode: int = BlinkMode.NATURAL) -> void:
	current_blink_mode = clampi(mode, BlinkMode.NATURAL, BlinkMode.SLOW)
	_is_blinking = true
	_blink_progress = 0.0
	match current_blink_mode:
		BlinkMode.NATURAL:
			_blink_duration = 0.14
		BlinkMode.DOUBLE:
			_blink_duration = 0.30
		BlinkMode.SLOW:
			_blink_duration = 0.42


func _refresh_mouth_mesh() -> void:
	if mouth_mesh_instance == null:
		return

	if is_lip_syncing and lip_sync_open > 0.06:
		mouth_mesh_instance.mesh = _mouth_shape_meshes[MouthShape.SPEAKING_SMALL]
		var sy: float = clampf(0.36 + lip_sync_open * 1.15, 0.30, 1.50)
		var sx: float = clampf(lip_sync_wide * (0.85 + lip_sync_open * 0.24), 0.75, 1.32)
		mouth_mesh_instance.scale = Vector3(sx, sy, 0.34)
		if tongue_mesh_instance != null:
			tongue_mesh_instance.visible = lip_sync_open > 0.22
			tongue_mesh_instance.position = Vector3(0.0, -0.018, 0.022)
			tongue_mesh_instance.scale = Vector3(1.05, 0.78, 0.55)
		return

	if _mouth_shape_meshes.has(current_mouth_shape):
		mouth_mesh_instance.mesh = _mouth_shape_meshes[current_mouth_shape]
		var is_cavity: bool = current_mouth_shape in [
			MouthShape.RESTING,
			MouthShape.OPEN_SMILE,
			MouthShape.SPEAKING_SMALL,
			MouthShape.LAUGHING,
			MouthShape.SURPRISED,
		]
		mouth_mesh_instance.scale = Vector3(1.0, 1.05, 0.34) if is_cavity else Vector3.ONE
		if tongue_mesh_instance != null:
			if _tongue_blep_active:
				tongue_mesh_instance.visible = true
				tongue_mesh_instance.position = Vector3(0.0, -0.036, 0.048)
				tongue_mesh_instance.scale = Vector3(1.18, 1.35, 0.72)
			else:
				tongue_mesh_instance.visible = is_cavity and current_mouth_shape != MouthShape.RESTING
				tongue_mesh_instance.position = Vector3(0.0, -0.018, 0.022)
				tongue_mesh_instance.scale = Vector3(1.05, 0.78, 0.55)


func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.05)

	# حركة الميكرو-ساكاد الطبيعية للعينين الحيتين
	_saccade_timer -= dt
	if _saccade_timer <= 0.0:
		_saccade_timer = _rng.randf_range(0.9, 2.4)
		var sac_scale: float = 0.0015 if focus_intensity > 0.5 else 0.0038
		_micro_saccade = Vector2(_rng.randf_range(-sac_scale, sac_scale), _rng.randf_range(-sac_scale * 0.7, sac_scale * 0.7))

	# اختيار نمط الرمش التلقائي (طبيعي، مزدوج، أو بطيء دافئ)
	if current_expression != FaceExpression.SLEEPY:
		_blink_countdown -= dt
		if _blink_countdown <= 0.0 and not _is_blinking:
			var roll: float = _rng.randf()
			if current_expression == FaceExpression.AFFECTIONATE or roll < 0.16:
				trigger_blink(BlinkMode.SLOW)
			elif current_expression == FaceExpression.CURIOUS and roll < 0.42 or roll > 0.82:
				trigger_blink(BlinkMode.DOUBLE)
			else:
				trigger_blink(BlinkMode.NATURAL)
			_blink_countdown = _rng.randf_range(2.5, 5.2)

	var blink_factor: float = 0.0
	if _is_blinking:
		_blink_progress += dt / maxf(_blink_duration, 0.08)
		if _blink_progress >= 1.0:
			_is_blinking = false
			_blink_progress = 0.0
		else:
			match current_blink_mode:
				BlinkMode.DOUBLE:
					var s2: float = sin(_blink_progress * PI * 2.0)
					blink_factor = s2 * s2
				BlinkMode.SLOW:
					blink_factor = pow(sin(_blink_progress * PI), 0.68)
				_:
					blink_factor = sin(_blink_progress * PI)

	var target_open: float = 1.0
	var target_blush: float = 0.78
	var lid_tilt_deg: float = 0.0

	match current_expression:
		FaceExpression.SLEEPY:
			target_open = 0.12
			target_blush = 0.55
		FaceExpression.AFFECTIONATE:
			target_open = 0.52
			target_blush = 1.15
			lid_tilt_deg = -9.0
		FaceExpression.PLAYFUL:
			target_open = 1.06
			target_blush = 0.94
		FaceExpression.CURIOUS:
			target_open = 1.08
			target_blush = 0.80
			lid_tilt_deg = 6.0
		FaceExpression.SURPRISED:
			target_open = 1.16
			target_blush = 0.88
		FaceExpression.HUNGRY:
			target_open = 0.90
			target_blush = 0.65
			lid_tilt_deg = 10.0
		FaceExpression.DIZZY:
			target_open = 0.85
			target_blush = 0.95
			_dizzy_phase += dt * 9.5

	if _emotion_eye_open_override > 0.0:
		target_open = _emotion_eye_open_override
	if _emotion_blush_override > 0.0:
		target_blush = _emotion_blush_override

	squint_amount = lerpf(squint_amount, _target_squint, minf(1.0, dt * 10.0))
	pupil_scale = lerpf(pupil_scale, _target_pupil_scale, minf(1.0, dt * 8.0))

	var squint_open_mult: float = 1.0 - squint_amount * 0.28
	var final_open: float = clampf(target_open * squint_open_mult * (1.0 - blink_factor * 0.92), 0.08, 1.18)
	_eye_openness = lerpf(_eye_openness, final_open, minf(1.0, dt * 18.0))
	_blush_amount = lerpf(_blush_amount, target_blush, minf(1.0, dt * 6.0))

	left_gaze_offset = left_gaze_offset.lerp(_target_left_gaze + _micro_saccade, minf(1.0, dt * 12.0))
	right_gaze_offset = right_gaze_offset.lerp(_target_right_gaze + _micro_saccade, minf(1.0, dt * 12.0))
	gaze_local_offset = (left_gaze_offset + right_gaze_offset) * 0.5

	_apply_eye_and_brow_transforms(lid_tilt_deg, dt)
	_apply_symmetric_cheeks()


func _apply_eye_and_brow_transforms(lid_tilt_deg: float, dt: float) -> void:
	var base_eye_scale := 1.42
	if left_eye_pivot != null:
		left_eye_pivot.scale = Vector3(base_eye_scale, base_eye_scale * _eye_openness, base_eye_scale)
	if right_eye_pivot != null:
		var right_open: float = _eye_openness * (0.94 if current_expression == FaceExpression.CURIOUS else 1.0)
		right_eye_pivot.scale = Vector3(base_eye_scale, base_eye_scale * right_open, base_eye_scale)

	var l_gaze: Vector2 = left_gaze_offset
	var r_gaze: Vector2 = right_gaze_offset
	if current_expression == FaceExpression.DIZZY:
		l_gaze = Vector2(cos(_dizzy_phase), sin(_dizzy_phase)) * 0.024
		r_gaze = Vector2(-cos(_dizzy_phase), sin(_dizzy_phase)) * 0.024

	var hi_shift := Vector2(-l_gaze.x * 0.85, l_gaze.y * 0.65)
	if _left_eye_mat != null:
		_left_eye_mat.set_shader_parameter("gaze_uv", l_gaze)
		_left_eye_mat.set_shader_parameter("pupil_scale", pupil_scale)
		_left_eye_mat.set_shader_parameter("highlight_shift", hi_shift)
	if _right_eye_mat != null:
		_right_eye_mat.set_shader_parameter("gaze_uv", r_gaze)
		_right_eye_mat.set_shader_parameter("pupil_scale", pupil_scale)
		_right_eye_mat.set_shader_parameter("highlight_shift", Vector2(-r_gaze.x * 0.85, r_gaze.y * 0.65))

	var lid_y: float = lerpf(0.015, 0.085, clampf(_eye_openness, 0.0, 1.0))
	if left_upper_lid != null:
		left_upper_lid.visible = _eye_openness < 0.90 or squint_amount > 0.12
		left_upper_lid.position.y = lid_y
		left_upper_lid.rotation_degrees.z = lid_tilt_deg
	if right_upper_lid != null:
		right_upper_lid.visible = _eye_openness < 0.90 or squint_amount > 0.12
		right_upper_lid.position.y = lid_y
		right_upper_lid.rotation_degrees.z = -lid_tilt_deg

	# الجفن السفلي لتضييق العينين التعبيري (Squint / Happy Smile)
	var low_lid_vis: bool = squint_amount > 0.08
	var low_lid_y: float = lerpf(-0.082, -0.038, clampf(squint_amount, 0.0, 1.0))
	if left_lower_lid != null:
		left_lower_lid.visible = low_lid_vis
		left_lower_lid.position.y = low_lid_y
	if right_lower_lid != null:
		right_lower_lid.visible = low_lid_vis
		right_lower_lid.position.y = low_lid_y

	var target_brow_y: float = 0.215 + _brow_lift_target + (lip_sync_brow_pulse if is_lip_syncing else 0.0)
	var blend: float = minf(1.0, dt * 12.0)
	if left_brow != null:
		left_brow.position.y = lerpf(left_brow.position.y, target_brow_y, blend)
		left_brow.rotation_degrees.z = lerpf(left_brow.rotation_degrees.z, _brow_tilt_target_deg, blend)
	if right_brow != null:
		right_brow.position.y = lerpf(right_brow.position.y, target_brow_y, blend)
		right_brow.rotation_degrees.z = lerpf(right_brow.rotation_degrees.z, -_brow_tilt_target_deg, blend)


func _apply_symmetric_cheeks() -> void:
	var clamped_blush: float = clampf(_blush_amount + _cheek_puff_amount * 0.25, 0.25, 1.35)
	if _blush_shader_mat != null:
		_blush_shader_mat.set_shader_parameter("blush_intensity", clamped_blush)

	var smile_lift: float = 0.014 if current_mouth_shape in [MouthShape.SMILE, MouthShape.OPEN_SMILE, MouthShape.LAUGHING] else 0.0
	var cheek_scale: float = 1.18 + _blush_amount * 0.15 + _cheek_puff_amount * 0.40
	var sym_scale := Vector3(cheek_scale, cheek_scale * (0.68 + _cheek_puff_amount * 0.22), 0.32 + _cheek_puff_amount * 0.22)

	if left_cheek != null:
		left_cheek.position = Vector3(-0.285, -0.04 + smile_lift, 0.015)
		left_cheek.scale = sym_scale
	if right_cheek != null:
		right_cheek.position = Vector3(0.285, -0.04 + smile_lift, 0.015)
		right_cheek.scale = sym_scale


func _build_soft_brow_arc(half_width: float, arch_height: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 10
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		pts.append(Vector3(lerpf(-half_width, half_width, u), sin(u * PI) * arch_height, 0.008))
	return _extrude_tube_along_points(pts, radius)


func _build_curved_arc_mouth(half_width: float, center_y_offset: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var curve: float = sin(u * PI) * center_y_offset
		pts.append(Vector3(x, curve, 0.014))
	return _extrude_tube_along_points(pts, radius)


func _build_wavy_mouth(half_width: float, amp: float, radius: float) -> ArrayMesh:
	var pts := PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		pts.append(Vector3(x, sin(u * TAU * 1.5) * amp, 0.014))
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
