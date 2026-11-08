class_name SlimeDeformer
extends Node
## نظام المحاكاة الهلامية المتقدم للجسم الناعم (Advanced Hybrid Soft-Body System):
## - يجمع بين مفاتيح الشكل (Mesh BlendShapes / Shape Keys) + التشوه الإجرائي حافظ الحجم +
##   حقل موجات اللمس الموجهة متعدد النقاط (4 نقاط تلامس متزامنة تنتقل تدريجياً للمناطق المجاورة) +
##   نوابض الإكسسوارات المستقلة (SlimiAccessoryPhysics).
## - يعود دائماً إلى الشكل الطبيعي بدقة تامة دون اهتزاز دائم أو تشوه متبقٍ أو قيم NaN.

@export var scale_stiffness: float = 132.0
@export var scale_damping: float = 10.2
@export var jiggle_stiffness: float = 104.0
@export var jiggle_damping: float = 8.4
@export var breath_speed: float = 2.35
@export var anim_breath_offset: float = 0.0

var body_mesh_instance: MeshInstance3D
var face_anchor: Node3D
var crown_anchor: Node3D
var antenna_root: Node3D
var right_feeler: Node3D
var star_pivot: Node3D
var beanie_root: Node3D
var pom_root: Node3D
var flower_root: Node3D
var paws_anchor: Node3D
var left_paw: Node3D
var right_paw: Node3D
var bubbles_root: Node3D
var breathing_animator: AnimationPlayer
var shader_material: ShaderMaterial
var accessory_physics := SlimiAccessoryPhysics.new()

var current_squash_stretch := Vector3.ONE
var current_jiggle := Vector3.ZERO
var is_resting_flat: bool = false
var posture_height_scale: float = 1.0
var beanie_extra_pos := Vector3.ZERO
var beanie_extra_rot := Vector3.ZERO
var antenna_extra_rot := Vector3.ZERO
var head_tilt_offset := Vector3.ZERO

# أوزان مفاتيح الشكل الستة (BlendShapes)
var shape_weights: Dictionary = {
	&"squash": 0.0,
	&"stretch": 0.0,
	&"breathe_expand": 0.0,
	&"curious_lean": 0.0,
	&"happy_plump": 0.0,
	&"sad_droop": 0.0,
}

# 4 فتحات لموجات التلامس الموضعية الموجهة
var _wave_slots: Array[Dictionary] = []
var _accessory_refs: Dictionary = {}

var _scale_y: float = 1.0
var _scale_y_vel: float = 0.0
var _target_scale_y: float = 1.0

var _jiggle_vel := Vector3.ZERO
var _pull_target := Vector3.ZERO
var _external_local_vel := Vector3.ZERO
var _external_yaw_vel: float = 0.0

var _breath_phase: float = 0.0
var _paw_gesture_timer: float = 0.0
var _paw_gesture_mode: int = 0

var _base_face_pos := Vector3(0.0, 0.04, 0.545)
var _base_crown_pos := Vector3(0.0, 0.52, 0.0)
var _base_antenna_pos := SlimiIdentitySpec.LEFT_ANTENNA_ANCHOR
var _base_right_feeler_pos := SlimiIdentitySpec.RIGHT_ANTENNA_ANCHOR
var _base_right_feeler_rot := Vector3.ZERO
var _base_beanie_pos := SlimiIdentitySpec.BEANIE_ANCHOR
var _base_beanie_rot := Vector3.ZERO
var _base_flower_rot := Vector3.ZERO
var _base_paws_pos := SlimiIdentitySpec.PAWS_ANCHOR


func _init() -> void:
	for _i in range(4):
		_wave_slots.append({
			"pos": Vector3(0.0, 0.2, 0.5),
			"dir": Vector3(0.0, 0.0, -1.0),
			"strength": 0.0,
			"phase": 0.0,
		})


func setup(mesh_inst: MeshInstance3D, face_node: Node3D, crown_node: Node3D, acc_refs: Dictionary = {}) -> void:
	body_mesh_instance = mesh_inst
	face_anchor = face_node
	crown_anchor = crown_node
	_accessory_refs = acc_refs

	antenna_root = acc_refs.get("antenna_root") as Node3D
	right_feeler = acc_refs.get("right_feeler") as Node3D
	star_pivot = acc_refs.get("star_pivot") as Node3D
	beanie_root = acc_refs.get("beanie_root") as Node3D
	pom_root = acc_refs.get("pom_root") as Node3D
	flower_root = acc_refs.get("flower_root") as Node3D
	paws_anchor = acc_refs.get("paws_anchor") as Node3D
	left_paw = acc_refs.get("left_paw") as Node3D
	right_paw = acc_refs.get("right_paw") as Node3D
	bubbles_root = acc_refs.get("bubbles_root") as Node3D

	if face_anchor != null:
		# وضع مثبت الوجه على السطح الأمامي الدقيق لمجسم الكمثرى دون غرق أو انفصال
		face_anchor.position = Vector3(0.0, 0.04, 0.545)
		_base_face_pos = face_anchor.position
	if crown_anchor != null:
		_base_crown_pos = crown_anchor.position
	if antenna_root != null:
		_base_antenna_pos = antenna_root.position
	if right_feeler != null:
		_base_right_feeler_pos = right_feeler.position
		_base_right_feeler_rot = right_feeler.rotation
	if beanie_root != null:
		_base_beanie_pos = beanie_root.position
		_base_beanie_rot = beanie_root.rotation
	if flower_root != null:
		_base_flower_rot = flower_root.rotation
	if paws_anchor != null:
		_base_paws_pos = paws_anchor.position

	if body_mesh_instance != null:
		var mat: Material = body_mesh_instance.get_active_material(0)
		if mat is ShaderMaterial:
			shader_material = mat as ShaderMaterial
		apply_mesh_lod(QualityManager.current_preset if QualityManager != null else 1)

	_setup_breathing_animation_player()


func apply_mesh_lod(preset_level: int) -> void:
	if body_mesh_instance == null:
		return
	body_mesh_instance.mesh = SlimiBodyMeshBuilder.get_or_build_lod_mesh(preset_level)
	if shader_material != null:
		shader_material.set_shader_parameter("is_prebaked_mochi", true)
	_sync_blend_shapes_to_mesh()


func set_motion_kinematics(local_vel: Vector3, yaw_vel: float) -> void:
	if SlimiIdentitySpec.is_finite_vec3(local_vel) and is_finite(yaw_vel):
		_external_local_vel = local_vel
		_external_yaw_vel = yaw_vel


func set_shape_key_weight(key_name: StringName, weight: float) -> void:
	if shape_weights.has(key_name) and is_finite(weight):
		shape_weights[key_name] = clampf(weight, 0.0, 1.0)


func set_breathing_cadence(speed: float, _amp: float = 0.03) -> void:
	if is_finite(speed):
		breath_speed = clampf(speed, 1.0, 4.2)


func get_active_wave_amplitude_max() -> float:
	var best: float = 0.0
	for slot in _wave_slots:
		best = maxf(best, float(slot["strength"]))
	return best


func get_active_wave_energy() -> float:
	var total: float = 0.0
	for slot in _wave_slots:
		total += float(slot["strength"])
	return total


func get_neighbor_displacement_at(sample_local_pos: Vector3) -> float:
	var total_disp: float = 0.0
	for slot in _wave_slots:
		var s: float = float(slot["strength"])
		if s <= 0.001:
			continue
		var d: float = sample_local_pos.distance_to(slot["pos"])
		var ph: float = float(slot["phase"])
		var primary: float = exp(-d * d * 11.5) * 0.145
		var ring_r: float = clampf(ph * 0.055, 0.0, 0.85)
		var neighbor_ring: float = exp(-pow((d - ring_r) * 4.8, 2.0)) * exp(-ph * 0.14) * 0.048
		total_disp += (primary + neighbor_ring) * s
	return total_disp


func _setup_breathing_animation_player() -> void:
	if breathing_animator != null:
		return
	breathing_animator = AnimationPlayer.new()
	breathing_animator.name = "BreathingAnimator"
	add_child(breathing_animator)

	var anim := Animation.new()
	anim.length = 2.6
	anim.loop_mode = Animation.LOOP_LINEAR

	var track_idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, NodePath(".:anim_breath_offset"))
	anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_CUBIC)
	anim.track_insert_key(track_idx, 0.0, 0.0)
	anim.track_insert_key(track_idx, 0.65, 0.018)
	anim.track_insert_key(track_idx, 1.30, 0.0)
	anim.track_insert_key(track_idx, 1.95, -0.016)
	anim.track_insert_key(track_idx, 2.60, 0.0)

	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle_breathing", anim)
	breathing_animator.add_animation_library(&"", lib)
	breathing_animator.play(&"idle_breathing")


func play_paw_gesture(mode: int, duration: float = 1.1) -> void:
	_paw_gesture_mode = mode
	_paw_gesture_timer = duration


func _process(delta: float) -> void:
	var clamped_dt: float = clampf(delta, 0.0005, 0.06)
	# Sub-stepping لضمان نفس السلوك الفيزيائي المستقر على 30 FPS و 60 FPS
	var substeps: int = 2 if clamped_dt > 0.020 else 1
	var h: float = clamped_dt / float(substeps)

	_target_scale_y = 0.76 if is_resting_flat else (posture_height_scale + anim_breath_offset)
	var breath_mult: float = 0.52 if is_resting_flat else 1.0
	_breath_phase = fmod(_breath_phase + clamped_dt * breath_speed * breath_mult, TAU * 64.0)

	for _s in range(substeps):
		var scale_force: float = (_target_scale_y - _scale_y) * scale_stiffness
		_scale_y_vel = (_scale_y_vel + scale_force * h) * exp(-scale_damping * h)
		_scale_y = clampf(_scale_y + _scale_y_vel * h, 0.56, 1.52)

		var jiggle_force: Vector3 = (_pull_target - current_jiggle) * jiggle_stiffness
		_jiggle_vel = (_jiggle_vel + jiggle_force * h) * exp(-jiggle_damping * h)
		current_jiggle += _jiggle_vel * h
		if current_jiggle.length() > 0.34:
			current_jiggle = current_jiggle.normalized() * 0.34

	# تصفير التذبذبات المتناهية الصغر لضمان استقرار تام عند السكون
	if absf(_scale_y - _target_scale_y) < 0.0004 and absf(_scale_y_vel) < 0.001:
		_scale_y = _target_scale_y
		_scale_y_vel = 0.0
	if _pull_target == Vector3.ZERO and current_jiggle.length() < 0.0004 and _jiggle_vel.length() < 0.001:
		current_jiggle = Vector3.ZERO
		_jiggle_vel = Vector3.ZERO

	var inv_xz: float = 1.0 / sqrt(maxf(_scale_y, 0.45))
	current_squash_stretch = Vector3(inv_xz, _scale_y, inv_xz)

	# تحديث أوزان Shape Keys التلقائية من حالة الانضغاط والتمدد والتنفس
	shape_weights[&"squash"] = clampf((1.0 - _scale_y) * 1.45, 0.0, 0.65)
	shape_weights[&"stretch"] = clampf((_scale_y - 1.0) * 1.35, 0.0, 0.65)
	shape_weights[&"breathe_expand"] = clampf(sin(_breath_phase) * 0.5 + 0.5, 0.0, 1.0) * 0.35
	shape_weights[&"curious_lean"] = move_toward(float(shape_weights[&"curious_lean"]), 0.0, clamped_dt * 1.2)
	shape_weights[&"happy_plump"] = move_toward(float(shape_weights[&"happy_plump"]), 0.0, clamped_dt * 0.9)
	shape_weights[&"sad_droop"] = move_toward(float(shape_weights[&"sad_droop"]), 0.0, clamped_dt * 0.9)

	# تحديث موجات اللمس الأربع وانتقالها للمناطق المجاورة ثم تلاشيها المرن
	for slot in _wave_slots:
		var st: float = float(slot["strength"])
		if st > 0.001:
			slot["phase"] = float(slot["phase"]) + clamped_dt * 19.5
			slot["strength"] = maxf(0.0, st * exp(-2.8 * clamped_dt) - clamped_dt * 0.18)
		else:
			slot["strength"] = 0.0
			slot["phase"] = 0.0

	if _paw_gesture_timer > 0.0:
		_paw_gesture_timer = maxf(0.0, _paw_gesture_timer - clamped_dt)
		if _paw_gesture_timer <= 0.0:
			_paw_gesture_mode = 0

	accessory_physics.step_physics(
		clamped_dt,
		_external_local_vel,
		_external_yaw_vel,
		_jiggle_vel,
		antenna_extra_rot,
		beanie_extra_rot
	)

	_sanitize_internal_state()
	_sync_blend_shapes_to_mesh()
	_sync_visuals(clamped_dt)


func add_vertical_impulse(impulse: float) -> void:
	if is_finite(impulse):
		_scale_y_vel += clampf(impulse, -6.5, 6.5)


func add_jiggle_impulse(local_impulse: Vector3) -> void:
	if SlimiIdentitySpec.is_finite_vec3(local_impulse):
		_jiggle_vel += local_impulse.limit_length(5.5)


func trigger_poke(local_point: Vector3, strength: float = 0.85) -> void:
	var inward: Vector3 = -local_point.normalized() if local_point.length_squared() > 0.001 else Vector3(0.0, 0.0, -1.0)
	trigger_directional_poke(local_point, inward, strength)


func trigger_directional_poke(local_point: Vector3, local_inward_dir: Vector3, strength: float = 0.85) -> void:
	if not SlimiIdentitySpec.is_finite_vec3(local_point) or not SlimiIdentitySpec.is_finite_vec3(local_inward_dir) or not is_finite(strength):
		return

	var clamped_pt: Vector3 = local_point.limit_length(0.68)
	var clean_dir: Vector3 = local_inward_dir.normalized() if local_inward_dir.length_squared() > 0.0001 else Vector3(0.0, 0.0, -1.0)
	var clamped_s: float = clampf(strength, 0.12, 1.0)

	# اختيار الفتحة الأضعف لإضافة موجة لمس جديدة دون فقدان الموجات النشطة المجاورة
	var best_idx: int = 0
	var min_s: float = 999.0
	for i in range(_wave_slots.size()):
		var cur_s: float = float(_wave_slots[i]["strength"])
		if cur_s < min_s:
			min_s = cur_s
			best_idx = i

	_wave_slots[best_idx] = {
		"pos": clamped_pt,
		"dir": clean_dir,
		"strength": clamped_s,
		"phase": 0.0,
	}

	add_jiggle_impulse(Vector3(clean_dir.x, 0.0, clean_dir.z) * 1.75 * clamped_s)
	add_vertical_impulse(-1.45 * clamped_s)
	play_paw_gesture(3, 0.55)


func set_pull_offset(local_offset: Vector3) -> void:
	if not SlimiIdentitySpec.is_finite_vec3(local_offset):
		return
	_pull_target = local_offset.limit_length(0.26)
	var stretch_bonus: float = clampf(local_offset.y * 0.45, -0.18, 0.28)
	_scale_y = lerpf(_scale_y, _target_scale_y + stretch_bonus, 0.25)


func release_pull() -> void:
	if _pull_target.length() > 0.015:
		_jiggle_vel -= _pull_target * 14.0
		add_vertical_impulse(1.85)
		play_paw_gesture(1, 0.85)
	_pull_target = Vector3.ZERO


func set_mood_tint(tint: Color) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("mood_tint", tint)


func set_shader_detail(level: int) -> void:
	var lvl: int = clampi(level, 0, 2)
	if shader_material != null:
		shader_material.set_shader_parameter("detail_level", lvl)
	var dome_mat := _accessory_refs.get("knit_dome_mat") as ShaderMaterial
	var cuff_mat := _accessory_refs.get("knit_cuff_mat") as ShaderMaterial
	if dome_mat != null:
		dome_mat.set_shader_parameter("detail_level", lvl)
	if cuff_mat != null:
		cuff_mat.set_shader_parameter("detail_level", lvl)


func update_studio_light_directions(key_ws: Vector3, fill_ws: Vector3, rim_ws: Vector3) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("key_light_dir_ws", key_ws)
		shader_material.set_shader_parameter("fill_light_dir_ws", fill_ws)
		shader_material.set_shader_parameter("rim_light_dir_ws", rim_ws)
	var dome_mat := _accessory_refs.get("knit_dome_mat") as ShaderMaterial
	var cuff_mat := _accessory_refs.get("knit_cuff_mat") as ShaderMaterial
	if dome_mat != null:
		dome_mat.set_shader_parameter("key_light_dir_ws", key_ws)
	if cuff_mat != null:
		cuff_mat.set_shader_parameter("key_light_dir_ws", key_ws)


func _sync_blend_shapes_to_mesh() -> void:
	if body_mesh_instance == null or body_mesh_instance.mesh == null:
		return
	var bs_count: int = body_mesh_instance.get_blend_shape_count()
	if bs_count <= 0:
		return
	for idx in range(mini(bs_count, SlimiBodyMeshBuilder.BLEND_SHAPE_NAMES.size())):
		var b_name: StringName = SlimiBodyMeshBuilder.BLEND_SHAPE_NAMES[idx]
		body_mesh_instance.set_blend_shape_value(idx, float(shape_weights.get(b_name, 0.0)))


func _sync_visuals(dt: float) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("squash_stretch", current_squash_stretch)
		shader_material.set_shader_parameter("jiggle_offset", current_jiggle)
		shader_material.set_shader_parameter("breath_phase", _breath_phase)
		shader_material.set_shader_parameter("poke_strength", 0.0)
		for i in range(4):
			var sl: Dictionary = _wave_slots[i]
			var p: Vector3 = sl["pos"]
			var d: Vector3 = sl["dir"]
			shader_material.set_shader_parameter("poke_slot_pos_%d" % i, Vector4(p.x, p.y, p.z, float(sl["strength"])))
			shader_material.set_shader_parameter("poke_slot_dir_%d" % i, Vector4(d.x, d.y, d.z, float(sl["phase"])))

	var breath_val: float = sin(_breath_phase) * 0.020
	var lean_z: float = float(shape_weights.get(&"curious_lean", 0.0)) * 0.145
	# حساب نصف القطر الخارجي الفعلي لسطح الهلام مع تأثير مفاتيح الشكل (Shape Keys) لمنع غوص الوجه أو الإكسسوارات
	var sq_w: float = float(shape_weights.get(&"squash", 0.0))
	var st_w: float = float(shape_weights.get(&"stretch", 0.0))
	var hp_w: float = float(shape_weights.get(&"happy_plump", 0.0))
	var sd_w: float = float(shape_weights.get(&"sad_droop", 0.0))

	var shape_xz_mult: float = 1.0 + sq_w * 0.25 - st_w * 0.18 + hp_w * 0.06
	var shape_y_mult: float = 1.0 - sq_w * 0.30 + st_w * 0.32 + hp_w * 0.03 - sd_w * 0.12

	var eff_scale := Vector3(
		current_squash_stretch.x * (1.0 - breath_val * 0.46) * shape_xz_mult,
		current_squash_stretch.y * (1.0 + breath_val) * shape_y_mult,
		current_squash_stretch.z * (1.0 - breath_val * 0.46) * shape_xz_mult
	)

	# تثبيت ملامح الوجه فوق سطح الهلام بدقة تمنع التداخل أو الغوص حتى عند أقصى ضغط
	if face_anchor != null:
		var face_h: float = clampf((_base_face_pos.y + 0.53) / 1.06, 0.0, 1.0)
		var front_poke_push: float = 0.0
		for sl in _wave_slots:
			var s_val: float = float(sl["strength"])
			if s_val > 0.002 and (sl["pos"] as Vector3).z > 0.15:
				var fd: float = _base_face_pos.distance_to(sl["pos"])
				front_poke_push += exp(-fd * fd * 8.0) * 0.08 * s_val

		var safe_front_z: float = maxf(_base_face_pos.z * eff_scale.z - front_poke_push, 0.42) + 0.012
		face_anchor.position = Vector3(
			_base_face_pos.x * eff_scale.x,
			_base_face_pos.y * eff_scale.y,
			safe_front_z + lean_z * face_h * face_h
		) + current_jiggle * (face_h * face_h * 0.88)

		face_anchor.rotation = Vector3(
			clampf(-current_jiggle.z * 0.72 + head_tilt_offset.x, -0.32, 0.32),
			clampf(current_jiggle.x * 0.56 + head_tilt_offset.y, -0.32, 0.32),
			clampf(-current_jiggle.x * 0.46 + head_tilt_offset.z, -0.26, 0.26)
		)

	if crown_anchor != null:
		crown_anchor.position = Vector3(
			_base_crown_pos.x * eff_scale.x,
			_base_crown_pos.y * eff_scale.y,
			_base_crown_pos.z * eff_scale.z
		) + current_jiggle * 0.94

	# القرنان المستقلان بنوابض SlimiAccessoryPhysics
	if antenna_root != null:
		antenna_root.position = Vector3(
			_base_antenna_pos.x * eff_scale.x,
			_base_antenna_pos.y * eff_scale.y,
			_base_antenna_pos.z * eff_scale.z + lean_z * 0.82
		) + current_jiggle * 0.88
		antenna_root.rotation = accessory_physics.left_antenna_rot + Vector3(0.0, 0.0, sin(_breath_phase * 1.15) * 0.035)

	if star_pivot != null:
		star_pivot.rotation.z = deg_to_rad(14.0) + accessory_physics.star_tip_rot_z + sin(_breath_phase * 1.6) * 0.06

	if right_feeler != null:
		right_feeler.position = Vector3(
			_base_right_feeler_pos.x * eff_scale.x,
			_base_right_feeler_pos.y * eff_scale.y,
			_base_right_feeler_pos.z * eff_scale.z + lean_z * 0.85
		) + current_jiggle * 0.88
		right_feeler.rotation = _base_right_feeler_rot + accessory_physics.right_antenna_rot + Vector3(0.0, 0.0, -sin(_breath_phase * 1.35) * 0.04)

	# القبعة الصوفية الصفراء + الكرة البيضاء المتأخرة قصورياً + الزهرة الثابتة
	if beanie_root != null:
		beanie_root.position = Vector3(
			_base_beanie_pos.x * eff_scale.x,
			_base_beanie_pos.y * eff_scale.y,
			_base_beanie_pos.z * eff_scale.z + lean_z * 0.80
		) + current_jiggle * 0.86 + beanie_extra_pos
		beanie_root.rotation = _base_beanie_rot + accessory_physics.beanie_rot_offset

	if pom_root != null:
		pom_root.position = SlimiIdentitySpec.POMPOM_LOCAL_ANCHOR + accessory_physics.pom_pos_offset

	if flower_root != null:
		flower_root.position = SlimiIdentitySpec.FLOWER_LOCAL_ANCHOR
		flower_root.rotation = _base_flower_rot + accessory_physics.flower_rot_offset

	# الكفّان الهلاميان على البطن
	if paws_anchor != null:
		paws_anchor.position = Vector3(
			_base_paws_pos.x * eff_scale.x,
			_base_paws_pos.y * eff_scale.y,
			maxf(_base_paws_pos.z * eff_scale.z, 0.44)
		) + current_jiggle * 0.35

		if left_paw != null and right_paw != null:
			var target_l_pos := Vector3(-0.132, sin(_breath_phase) * 0.010, 0.0)
			var target_r_pos := Vector3(0.132, sin(_breath_phase) * 0.010, 0.0)
			var target_l_rot_z: float = deg_to_rad(16.0) + sin(_breath_phase) * 0.05
			var target_r_rot_z: float = deg_to_rad(-16.0) - sin(_breath_phase) * 0.05

			if _paw_gesture_mode == 1:
				var clap: float = absf(sin(_breath_phase * 5.2))
				target_l_pos = Vector3(-0.085 - clap * 0.065, 0.045 + clap * 0.035, 0.025)
				target_r_pos = Vector3(0.085 + clap * 0.065, 0.045 + clap * 0.035, 0.025)
				target_l_rot_z = deg_to_rad(32.0 - clap * 24.0)
				target_r_rot_z = deg_to_rad(-32.0 + clap * 24.0)
			elif _paw_gesture_mode == 2:
				target_l_pos = Vector3(-0.185, 0.065, 0.02)
				target_r_pos = Vector3(0.185, 0.065, 0.02)
				target_l_rot_z = deg_to_rad(36.0)
				target_r_rot_z = deg_to_rad(-36.0)
			elif _paw_gesture_mode == 3:
				target_l_pos = Vector3(-0.175, 0.025, 0.03)
				target_r_pos = Vector3(0.175, 0.025, 0.03)
				target_l_rot_z = deg_to_rad(-8.0)
				target_r_rot_z = deg_to_rad(8.0)
			elif _paw_gesture_mode == 4:
				target_l_pos = Vector3(-0.145, 0.02, 0.01)
				target_r_pos = Vector3(0.035, 0.105, 0.075)
				target_r_rot_z = deg_to_rad(28.0)
			elif _paw_gesture_mode == 5:
				var wave: float = sin(_breath_phase * 4.5) * 0.025
				target_l_pos = Vector3(-0.165, 0.235 + wave, 0.03)
				target_r_pos = Vector3(0.135, 0.02, 0.01)
				target_l_rot_z = deg_to_rad(-42.0)

			var blend: float = minf(1.0, dt * 12.0)
			left_paw.position = left_paw.position.lerp(target_l_pos, blend)
			right_paw.position = right_paw.position.lerp(target_r_pos, blend)
			left_paw.rotation.z = lerpf(left_paw.rotation.z, target_l_rot_z, blend)
			right_paw.rotation.z = lerpf(right_paw.rotation.z, target_r_rot_z, blend)

	if bubbles_root != null:
		bubbles_root.scale = eff_scale


func _sanitize_internal_state() -> void:
	if not is_finite(_scale_y) or not is_finite(_scale_y_vel):
		_scale_y = 1.0
		_scale_y_vel = 0.0
	if not SlimiIdentitySpec.is_finite_vec3(current_jiggle) or not SlimiIdentitySpec.is_finite_vec3(_jiggle_vel):
		current_jiggle = Vector3.ZERO
		_jiggle_vel = Vector3.ZERO
