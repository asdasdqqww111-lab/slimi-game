class_name SlimeDeformer
extends Node
## نظام الحركة المرنة والتشوه الفيزيائي الهلامي (Squash & Stretch + 3D Jiggle + Touch Ripple).

@export var scale_stiffness: float = 125.0
@export var scale_damping: float = 9.2
@export var jiggle_stiffness: float = 96.0
@export var jiggle_damping: float = 7.8
@export var breath_speed: float = 2.35

var body_mesh_instance: MeshInstance3D
var face_anchor: Node3D
var crown_anchor: Node3D
var shader_material: ShaderMaterial

var current_squash_stretch := Vector3.ONE
var current_jiggle := Vector3.ZERO
var is_resting_flat: bool = false

var _scale_y: float = 1.0
var _scale_y_vel: float = 0.0
var _target_scale_y: float = 1.0

var _jiggle_vel := Vector3.ZERO
var _pull_target := Vector3.ZERO

var _poke_local_pos := Vector3(0.0, 0.2, 0.5)
var _poke_strength: float = 0.0
var _poke_phase: float = 0.0
var _breath_phase: float = 0.0

var _base_face_pos := Vector3(0.0, 0.06, 0.46)
var _base_crown_pos := Vector3(0.0, 0.52, 0.0)


func setup(mesh_inst: MeshInstance3D, face_node: Node3D, crown_node: Node3D) -> void:
	body_mesh_instance = mesh_inst
	face_anchor = face_node
	crown_anchor = crown_node

	if face_anchor != null:
		_base_face_pos = face_anchor.position
	if crown_anchor != null:
		_base_crown_pos = crown_anchor.position

	if body_mesh_instance != null:
		var mat: Material = body_mesh_instance.get_active_material(0)
		if mat is ShaderMaterial:
			shader_material = mat as ShaderMaterial


func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.05)

	_target_scale_y = 0.74 if is_resting_flat else 1.0
	var breath_mult: float = 0.55 if is_resting_flat else 1.0
	_breath_phase = fmod(_breath_phase + dt * breath_speed * breath_mult, TAU * 64.0)

	# نابض الارتداد الرأسي مع حفظ الحجم الهلامي (Volume Preservation)
	var scale_force: float = (_target_scale_y - _scale_y) * scale_stiffness
	_scale_y_vel = (_scale_y_vel + scale_force * dt) * exp(-scale_damping * dt)
	_scale_y = clampf(_scale_y + _scale_y_vel * dt, 0.52, 1.58)

	var inv_xz: float = 1.0 / sqrt(maxf(_scale_y, 0.45))
	current_squash_stretch = Vector3(inv_xz, _scale_y, inv_xz)

	# نابض الاهتزاز ثلاثي الأبعاد (Jiggle & Pull)
	var jiggle_force: Vector3 = (_pull_target - current_jiggle) * jiggle_stiffness
	_jiggle_vel = (_jiggle_vel + jiggle_force * dt) * exp(-jiggle_damping * dt)
	current_jiggle += _jiggle_vel * dt
	if current_jiggle.length() > 0.36:
		current_jiggle = current_jiggle.normalized() * 0.36

	# تلاشي موجة اللمس الموضعية
	if _poke_strength > 0.001:
		_poke_phase += dt * 22.0
		_poke_strength = maxf(0.0, _poke_strength - dt * 1.85)
	else:
		_poke_strength = 0.0

	_sync_visuals()


func add_vertical_impulse(impulse: float) -> void:
	_scale_y_vel += clampf(impulse, -6.5, 6.5)


func add_jiggle_impulse(local_impulse: Vector3) -> void:
	_jiggle_vel += local_impulse.limit_length(5.5)


func trigger_poke(local_point: Vector3, strength: float = 0.85) -> void:
	_poke_local_pos = local_point.limit_length(0.65)
	_poke_strength = clampf(strength, 0.15, 1.0)
	_poke_phase = 0.0

	# دفع مرن معاكس لمكان اللمسة
	var push_dir: Vector3 = -local_point.normalized()
	add_jiggle_impulse(Vector3(push_dir.x, 0.0, push_dir.z) * 1.9 * strength)
	add_vertical_impulse(-1.65 * strength)


func set_pull_offset(local_offset: Vector3) -> void:
	_pull_target = local_offset.limit_length(0.26)
	var stretch_bonus: float = clampf(local_offset.y * 0.45, -0.18, 0.28)
	_scale_y = lerpf(_scale_y, _target_scale_y + stretch_bonus, 0.25)


func release_pull() -> void:
	if _pull_target.length() > 0.015:
		# ارتداد مطاطي مبهج عند الإفلات
		_jiggle_vel -= _pull_target * 14.0
		add_vertical_impulse(1.8)
	_pull_target = Vector3.ZERO


func set_mood_tint(tint: Color) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("mood_tint", tint)


func set_shader_detail(level: int) -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("detail_level", clampi(level, 0, 2))


func _sync_visuals() -> void:
	if shader_material != null:
		shader_material.set_shader_parameter("squash_stretch", current_squash_stretch)
		shader_material.set_shader_parameter("jiggle_offset", current_jiggle)
		shader_material.set_shader_parameter("poke_local_pos", _poke_local_pos)
		shader_material.set_shader_parameter("poke_strength", _poke_strength)
		shader_material.set_shader_parameter("poke_phase", _poke_phase)
		shader_material.set_shader_parameter("breath_phase", _breath_phase)

	var breath_val: float = sin(_breath_phase) * 0.022
	var eff_scale := Vector3(
		current_squash_stretch.x * (1.0 - breath_val * 0.48),
		current_squash_stretch.y * (1.0 + breath_val),
		current_squash_stretch.z * (1.0 - breath_val * 0.48)
	)

	if face_anchor != null:
		var face_h: float = clampf((_base_face_pos.y + 0.55) / 1.1, 0.0, 1.0)
		face_anchor.position = Vector3(
			_base_face_pos.x * eff_scale.x,
			_base_face_pos.y * eff_scale.y,
			_base_face_pos.z * eff_scale.z
		) + current_jiggle * (face_h * face_h * 0.92)
		face_anchor.rotation = Vector3(
			clampf(-current_jiggle.z * 0.85, -0.32, 0.32),
			clampf(current_jiggle.x * 0.65, -0.32, 0.32),
			clampf(-current_jiggle.x * 0.55, -0.28, 0.28)
		)

	if crown_anchor != null:
		crown_anchor.position = Vector3(
			_base_crown_pos.x * eff_scale.x,
			_base_crown_pos.y * eff_scale.y,
			_base_crown_pos.z * eff_scale.z
		) + current_jiggle * 0.96
		crown_anchor.rotation = Vector3(
			clampf(current_jiggle.z * 1.9, -0.6, 0.6),
			0.0,
			clampf(-current_jiggle.x * 1.9, -0.6, 0.6)
		)
