class_name SlimeDeformer
extends Node
## نظام الحركة الهلامية والارتداد المرن:
## يجمع بين AnimationPlayer للتنفس المستمر + فيزياء النوابض الحجمية (Squash & Stretch) +
## تفاعل قرن النجمة والقبعة الصوفية والكفّين الهلاميين والفقاعات.

@export var scale_stiffness: float = 128.0
@export var scale_damping: float = 9.0
@export var jiggle_stiffness: float = 98.0
@export var jiggle_damping: float = 7.6
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
var paws_anchor: Node3D
var left_paw: Node3D
var right_paw: Node3D
var bubbles_root: Node3D
var breathing_animator: AnimationPlayer
var shader_material: ShaderMaterial

var current_squash_stretch := Vector3.ONE
var current_jiggle := Vector3.ZERO
var is_resting_flat: bool = false
var posture_height_scale: float = 1.0
var beanie_extra_pos := Vector3.ZERO
var beanie_extra_rot := Vector3.ZERO
var antenna_extra_rot := Vector3.ZERO

var _scale_y: float = 1.0
var _scale_y_vel: float = 0.0
var _target_scale_y: float = 1.0

var _jiggle_vel := Vector3.ZERO
var _pull_target := Vector3.ZERO

var _poke_local_pos := Vector3(0.0, 0.2, 0.5)
var _poke_strength: float = 0.0
var _poke_phase: float = 0.0
var _breath_phase: float = 0.0

var _paw_gesture_timer: float = 0.0
var _paw_gesture_mode: int = 0 # 0=idle, 1=clap/happy, 2=shy_cheeks, 3=surprised, 4=kiss_blow, 5=antenna_play

var _base_face_pos := Vector3(0.0, 0.04, 0.52)
var _base_crown_pos := Vector3(0.0, 0.52, 0.0)
var _base_antenna_pos := Vector3(-0.185, 0.415, 0.05)
var _base_right_feeler_pos := Vector3(0.065, 0.455, 0.145)
var _base_right_feeler_rot := Vector3.ZERO
var _base_beanie_pos := Vector3(0.185, 0.405, 0.015)
var _base_beanie_rot := Vector3.ZERO
var _base_paws_pos := Vector3(0.0, -0.145, 0.545)


func setup(mesh_inst: MeshInstance3D, face_node: Node3D, crown_node: Node3D, acc_refs: Dictionary = {}) -> void:
	body_mesh_instance = mesh_inst
	face_anchor = face_node
	crown_anchor = crown_node

	antenna_root = acc_refs.get("antenna_root") as Node3D
	right_feeler = acc_refs.get("right_feeler") as Node3D
	star_pivot = acc_refs.get("star_pivot") as Node3D
	beanie_root = acc_refs.get("beanie_root") as Node3D
	pom_root = acc_refs.get("pom_root") as Node3D
	paws_anchor = acc_refs.get("paws_anchor") as Node3D
	left_paw = acc_refs.get("left_paw") as Node3D
	right_paw = acc_refs.get("right_paw") as Node3D
	bubbles_root = acc_refs.get("bubbles_root") as Node3D

	if face_anchor != null:
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
	if paws_anchor != null:
		_base_paws_pos = paws_anchor.position

	if body_mesh_instance != null:
		var mat: Material = body_mesh_instance.get_active_material(0)
		if mat is ShaderMaterial:
			shader_material = mat as ShaderMaterial

	_setup_breathing_animation_player()


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
	var dt: float = minf(delta, 0.05)

	_target_scale_y = 0.76 if is_resting_flat else (posture_height_scale + anim_breath_offset)
	var breath_mult: float = 0.52 if is_resting_flat else 1.0
	_breath_phase = fmod(_breath_phase + dt * breath_speed * breath_mult, TAU * 64.0)

	var scale_force: float = (_target_scale_y - _scale_y) * scale_stiffness
	_scale_y_vel = (_scale_y_vel + scale_force * dt) * exp(-scale_damping * dt)
	_scale_y = clampf(_scale_y + _scale_y_vel * dt, 0.54, 1.56)

	var inv_xz: float = 1.0 / sqrt(maxf(_scale_y, 0.45))
	current_squash_stretch = Vector3(inv_xz, _scale_y, inv_xz)

	var jiggle_force: Vector3 = (_pull_target - current_jiggle) * jiggle_stiffness
	_jiggle_vel = (_jiggle_vel + jiggle_force * dt) * exp(-jiggle_damping * dt)
	current_jiggle += _jiggle_vel * dt
	if current_jiggle.length() > 0.36:
		current_jiggle = current_jiggle.normalized() * 0.36

	if _poke_strength > 0.001:
		_poke_phase += dt * 22.0
		_poke_strength = maxf(0.0, _poke_strength - dt * 1.85)
	else:
		_poke_strength = 0.0

	if _paw_gesture_timer > 0.0:
		_paw_gesture_timer = maxf(0.0, _paw_gesture_timer - dt)
		if _paw_gesture_timer <= 0.0:
			_paw_gesture_mode = 0

	_sync_visuals(dt)


func add_vertical_impulse(impulse: float) -> void:
	_scale_y_vel += clampf(impulse, -6.5, 6.5)


func add_jiggle_impulse(local_impulse: Vector3) -> void:
	_jiggle_vel += local_impulse.limit_length(5.5)


func trigger_poke(local_point: Vector3, strength: float = 0.85) -> void:
	_poke_local_pos = local_point.limit_length(0.68)
	_poke_strength = clampf(strength, 0.15, 1.0)
	_poke_phase = 0.0

	var push_dir: Vector3 = -local_point.normalized()
	add_jiggle_impulse(Vector3(push_dir.x, 0.0, push_dir.z) * 1.9 * strength)
	add_vertical_impulse(-1.65 * strength)
	play_paw_gesture(3, 0.55)


func set_pull_offset(local_offset: Vector3) -> void:
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
	if shader_material != null:
		shader_material.set_shader_parameter("detail_level", clampi(level, 0, 2))


func _sync_visuals(dt: float) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("squash_stretch", current_squash_stretch)
		shader_material.set_shader_parameter("jiggle_offset", current_jiggle)
		shader_material.set_shader_parameter("poke_local_pos", _poke_local_pos)
		shader_material.set_shader_parameter("poke_strength", _poke_strength)
		shader_material.set_shader_parameter("poke_phase", _poke_phase)
		shader_material.set_shader_parameter("breath_phase", _breath_phase)

	var breath_val: float = sin(_breath_phase) * 0.024
	var eff_scale := Vector3(
		current_squash_stretch.x * (1.0 - breath_val * 0.46),
		current_squash_stretch.y * (1.0 + breath_val),
		current_squash_stretch.z * (1.0 - breath_val * 0.46)
	)

	if face_anchor != null:
		var face_h: float = clampf((_base_face_pos.y + 0.53) / 1.06, 0.0, 1.0)
		face_anchor.position = Vector3(
			_base_face_pos.x * eff_scale.x,
			_base_face_pos.y * eff_scale.y,
			_base_face_pos.z * eff_scale.z
		) + current_jiggle * (face_h * face_h * 0.90)
		face_anchor.rotation = Vector3(
			clampf(-current_jiggle.z * 0.78, -0.28, 0.28),
			clampf(current_jiggle.x * 0.60, -0.28, 0.28),
			clampf(-current_jiggle.x * 0.50, -0.24, 0.24)
		)

	if crown_anchor != null:
		crown_anchor.position = Vector3(
			_base_crown_pos.x * eff_scale.x,
			_base_crown_pos.y * eff_scale.y,
			_base_crown_pos.z * eff_scale.z
		) + current_jiggle * 0.94

	# تفاعل قرني الاستشعار الشفافين المرنين
	if antenna_root != null:
		antenna_root.position = Vector3(
			_base_antenna_pos.x * eff_scale.x,
			_base_antenna_pos.y * eff_scale.y,
			_base_antenna_pos.z * eff_scale.z
		) + current_jiggle * 0.88
		antenna_root.rotation = Vector3(
			clampf(current_jiggle.z * 1.45, -0.45, 0.45),
			0.0,
			sin(_breath_phase * 1.2) * 0.05 + clampf(-current_jiggle.x * 1.65, -0.48, 0.48)
		) + antenna_extra_rot
	if right_feeler != null:
		right_feeler.position = Vector3(
			_base_right_feeler_pos.x * eff_scale.x,
			_base_right_feeler_pos.y * eff_scale.y,
			_base_right_feeler_pos.z * eff_scale.z
		) + current_jiggle * 0.88
		right_feeler.rotation = _base_right_feeler_rot + Vector3(
			clampf(current_jiggle.z * 1.2, -0.35, 0.35),
			0.0,
			-sin(_breath_phase * 1.35) * 0.06 - antenna_extra_rot.z * 0.85
		)
	if star_pivot != null:
		star_pivot.rotation.z = deg_to_rad(14.0) + sin(_breath_phase * 1.7) * 0.11 - current_jiggle.x * 1.2

	# تفاعل القبعة الصوفية الصفراء وكرتها البيضاء المنفوشة
	if beanie_root != null:
		beanie_root.position = Vector3(
			_base_beanie_pos.x * eff_scale.x,
			_base_beanie_pos.y * eff_scale.y,
			_base_beanie_pos.z * eff_scale.z
		) + current_jiggle * 0.86 + beanie_extra_pos
		beanie_root.rotation = _base_beanie_rot + Vector3(
			clampf(current_jiggle.z * 0.95, -0.28, 0.28),
			0.0,
			clampf(-current_jiggle.x * 1.05, -0.30, 0.30)
		) + beanie_extra_rot
	if pom_root != null:
		pom_root.position.y = 0.275 + absf(_scale_y_vel) * 0.008 + sin(_breath_phase * 2.0) * 0.006

	# تفاعل الكفّين الهلاميين الذكي على البطن
	if paws_anchor != null:
		paws_anchor.position = Vector3(
			_base_paws_pos.x * eff_scale.x,
			_base_paws_pos.y * eff_scale.y,
			_base_paws_pos.z * eff_scale.z
		) + current_jiggle * 0.35

		if left_paw != null and right_paw != null:
			var target_l_pos := Vector3(-0.132, sin(_breath_phase) * 0.010, 0.0)
			var target_r_pos := Vector3(0.132, sin(_breath_phase) * 0.010, 0.0)
			var target_l_rot_z: float = deg_to_rad(16.0) + sin(_breath_phase) * 0.05
			var target_r_rot_z: float = deg_to_rad(-16.0) - sin(_breath_phase) * 0.05

			if _paw_gesture_mode == 1: # تصفيق/فرح
				var clap: float = absf(sin(_breath_phase * 5.2))
				target_l_pos = Vector3(-0.085 - clap * 0.065, 0.045 + clap * 0.035, 0.025)
				target_r_pos = Vector3(0.085 + clap * 0.065, 0.045 + clap * 0.035, 0.025)
				target_l_rot_z = deg_to_rad(32.0 - clap * 24.0)
				target_r_rot_z = deg_to_rad(-32.0 + clap * 24.0)
			elif _paw_gesture_mode == 2: # احتضان الخدود بخجل لطيف عند المسح
				target_l_pos = Vector3(-0.185, 0.065, 0.02)
				target_r_pos = Vector3(0.185, 0.065, 0.02)
				target_l_rot_z = deg_to_rad(36.0)
				target_r_rot_z = deg_to_rad(-36.0)
			elif _paw_gesture_mode == 3: # تفاجؤ لطيف عند اللمس
				target_l_pos = Vector3(-0.175, 0.025, 0.03)
				target_r_pos = Vector3(0.175, 0.025, 0.03)
				target_l_rot_z = deg_to_rad(-8.0)
				target_r_rot_z = deg_to_rad(8.0)
			elif _paw_gesture_mode == 4: # إرسال قبلة لطيفة (Blow Kiss)
				target_l_pos = Vector3(-0.145, 0.02, 0.01)
				target_r_pos = Vector3(0.035, 0.105, 0.075)
				target_r_rot_z = deg_to_rad(28.0)
			elif _paw_gesture_mode == 5: # اللعب بقرون الاستشعار
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
