class_name SlimeFaceRig
extends Node3D
## نظام تعبيرات وجه سلايمي ثلاثي الأبعاد: عينان كبيرتان، جفون متحركة، تتبع نظر، خدود موردة، وفم تعبيري.

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
var left_cheek: MeshInstance3D
var right_cheek: MeshInstance3D
var mouth_mesh_instance: MeshInstance3D

var current_expression: int = FaceExpression.HAPPY
var gaze_local_offset := Vector2.ZERO

var _target_gaze := Vector2.ZERO
var _blink_countdown: float = 3.1
var _blink_progress: float = 0.0
var _is_blinking: bool = false
var _eye_openness: float = 1.0
var _blush_amount: float = 0.45
var _dizzy_phase: float = 0.0

var _mouth_meshes: Dictionary = {}
var _blush_mat_instance: StandardMaterial3D
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

	if left_cheek != null and left_cheek.get_active_material(0) is StandardMaterial3D:
		_blush_mat_instance = (left_cheek.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		left_cheek.material_override = _blush_mat_instance
		if right_cheek != null:
			right_cheek.material_override = _blush_mat_instance

	_prebuild_mouth_meshes()
	set_expression(FaceExpression.HAPPY)


func set_expression(expr: int) -> void:
	current_expression = expr
	if mouth_mesh_instance != null and _mouth_meshes.has(expr):
		mouth_mesh_instance.mesh = _mouth_meshes[expr]


func set_look_direction_local(local_dir: Vector3) -> void:
	_target_gaze = Vector2(
		clampf(local_dir.x * 0.036, -0.028, 0.028),
		clampf(local_dir.y * 0.030, -0.022, 0.022)
	)


func trigger_blink() -> void:
	_is_blinking = true
	_blink_progress = 0.0


func _process(delta: float) -> void:
	# تحديث الرمش التلقائي الطبيعي
	if current_expression != FaceExpression.SLEEPY:
		_blink_countdown -= delta
		if _blink_countdown <= 0.0 and not _is_blinking:
			_is_blinking = true
			_blink_progress = 0.0
			_blink_countdown = _rng.randf_range(2.4, 5.2)

	var blink_factor: float = 0.0
	if _is_blinking:
		_blink_progress += delta / 0.15
		if _blink_progress >= 1.0:
			_is_blinking = false
			_blink_progress = 0.0
		else:
			blink_factor = sin(_blink_progress * PI)

	# تحديد فتحة العين وتورّد الخدود حسب المزاج
	var target_open: float = 1.0
	var target_blush: float = 0.42
	var lid_tilt_deg: float = 0.0

	match current_expression:
		FaceExpression.SLEEPY:
			target_open = 0.14
			target_blush = 0.35
		FaceExpression.AFFECTIONATE:
			target_open = 0.42
			target_blush = 0.88
			lid_tilt_deg = -10.0
		FaceExpression.PLAYFUL:
			target_open = 1.08
			target_blush = 0.65
		FaceExpression.CURIOUS:
			target_open = 1.12
			target_blush = 0.48
			lid_tilt_deg = 8.0
		FaceExpression.SURPRISED:
			target_open = 1.18
			target_blush = 0.58
		FaceExpression.HUNGRY:
			target_open = 0.86
			target_blush = 0.32
			lid_tilt_deg = 12.0
		FaceExpression.DIZZY:
			target_open = 0.82
			target_blush = 0.72
			_dizzy_phase += delta * 9.5

	var final_open: float = clampf(target_open * (1.0 - blink_factor * 0.92), 0.08, 1.22)
	_eye_openness = lerpf(_eye_openness, final_open, minf(1.0, delta * 16.0))
	_blush_amount = lerpf(_blush_amount, target_blush, minf(1.0, delta * 6.0))
	gaze_local_offset = gaze_local_offset.lerp(_target_gaze, minf(1.0, delta * 10.0))

	_apply_eye_transforms(lid_tilt_deg)
	_apply_blush()


func _apply_eye_transforms(lid_tilt_deg: float) -> void:
	if left_eye_pivot != null:
		left_eye_pivot.scale.y = _eye_openness
	if right_eye_pivot != null:
		var right_open: float = _eye_openness * (0.90 if current_expression == FaceExpression.CURIOUS else 1.0)
		right_eye_pivot.scale.y = right_open

	var left_gaze: Vector2 = gaze_local_offset
	var right_gaze: Vector2 = gaze_local_offset
	if current_expression == FaceExpression.DIZZY:
		left_gaze = Vector2(cos(_dizzy_phase), sin(_dizzy_phase)) * 0.022
		right_gaze = Vector2(-cos(_dizzy_phase), sin(_dizzy_phase)) * 0.022

	if left_iris_group != null:
		left_iris_group.position.x = left_gaze.x
		left_iris_group.position.y = left_gaze.y
	if right_iris_group != null:
		right_iris_group.position.x = right_gaze.x
		right_iris_group.position.y = right_gaze.y

	var lid_y: float = lerpf(0.015, 0.085, clampf(_eye_openness, 0.0, 1.0))
	if left_upper_lid != null:
		left_upper_lid.visible = _eye_openness < 0.92
		left_upper_lid.position.y = lid_y
		left_upper_lid.rotation_degrees.z = lid_tilt_deg
	if right_upper_lid != null:
		right_upper_lid.visible = _eye_openness < 0.92
		right_upper_lid.position.y = lid_y
		right_upper_lid.rotation_degrees.z = -lid_tilt_deg


func _apply_blush() -> void:
	if _blush_mat_instance != null:
		var c: Color = _blush_mat_instance.albedo_color
		c.a = clampf(_blush_amount, 0.15, 0.92)
		_blush_mat_instance.albedo_color = c
	var cheek_scale: float = 0.92 + _blush_amount * 0.24
	if left_cheek != null:
		left_cheek.scale = Vector3(cheek_scale, cheek_scale * 0.62, 0.35)
	if right_cheek != null:
		right_cheek.scale = Vector3(cheek_scale, cheek_scale * 0.62, 0.35)


func _prebuild_mouth_meshes() -> void:
	_mouth_meshes[FaceExpression.HAPPY] = _build_curve_mouth(0.075, -0.032, 0.013, false)
	_mouth_meshes[FaceExpression.PLAYFUL] = _build_curve_mouth(0.090, -0.048, 0.017, false)
	_mouth_meshes[FaceExpression.AFFECTIONATE] = _build_cat_mouth(0.082, -0.026, 0.013)
	_mouth_meshes[FaceExpression.CURIOUS] = _build_ring_mouth(0.026, 0.030, 0.011)
	_mouth_meshes[FaceExpression.SURPRISED] = _build_ring_mouth(0.034, 0.040, 0.012)
	_mouth_meshes[FaceExpression.SLEEPY] = _build_curve_mouth(0.042, -0.006, 0.010, false)
	_mouth_meshes[FaceExpression.HUNGRY] = _build_curve_mouth(0.068, 0.022, 0.012, false)
	_mouth_meshes[FaceExpression.DIZZY] = _build_wavy_mouth(0.078, 0.014, 0.011)


func _build_curve_mouth(half_width: float, arch_depth: float, radius: float, closed_loop: bool) -> ArrayMesh:
	var pts: PackedVector3Array = PackedVector3Array()
	var steps: int = 12
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var parabola: float = 1.0 - pow((u - 0.5) * 2.0, 2.0)
		var y: float = arch_depth * parabola
		var z: float = 0.012 * parabola
		pts.append(Vector3(x, y, z))
	return _extrude_tube_along_points(pts, radius, closed_loop)


func _build_cat_mouth(half_width: float, depth: float, radius: float) -> ArrayMesh:
	# فم لطيف بشكل ω
	var pts: PackedVector3Array = PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var lobe: float = absf(sin(u * PI * 2.0))
		var y: float = depth * lobe
		pts.append(Vector3(x, y, 0.010))
	return _extrude_tube_along_points(pts, radius, false)


func _build_wavy_mouth(half_width: float, amp: float, radius: float) -> ArrayMesh:
	var pts: PackedVector3Array = PackedVector3Array()
	var steps: int = 16
	for i in range(steps + 1):
		var u: float = float(i) / float(steps)
		var x: float = lerpf(-half_width, half_width, u)
		var y: float = sin(u * TAU * 1.5) * amp
		pts.append(Vector3(x, y, 0.010))
	return _extrude_tube_along_points(pts, radius, false)


func _build_ring_mouth(rx: float, ry: float, radius: float) -> ArrayMesh:
	var pts: PackedVector3Array = PackedVector3Array()
	var steps: int = 14
	for i in range(steps):
		var ang: float = TAU * float(i) / float(steps)
		pts.append(Vector3(cos(ang) * rx, sin(ang) * ry, 0.012))
	return _extrude_tube_along_points(pts, radius, true)


func _extrude_tube_along_points(points: PackedVector3Array, radius: float, closed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_sides: int = 6
	var count: int = points.size()
	if count < 2:
		return ArrayMesh.new()

	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []

	for i in range(count):
		var prev_idx: int = (count - 1 if i == 0 else i - 1) if closed else maxi(0, i - 1)
		var next_idx: int = ((i + 1) % count) if closed else mini(count - 1, i + 1)
		var tangent: Vector3 = (points[next_idx] - points[prev_idx]).normalized()
		if tangent.length_squared() < 0.001:
			tangent = Vector3.RIGHT

		var up_axis := Vector3.FORWARD
		if absf(tangent.dot(up_axis)) > 0.92:
			up_axis = Vector3.UP
		var normal_a: Vector3 = tangent.cross(up_axis).normalized()
		var normal_b: Vector3 = tangent.cross(normal_a).normalized()

		var taper: float = 1.0
		if not closed:
			var u: float = float(i) / float(count - 1)
			taper = 0.45 + 0.55 * sin(u * PI)

		var r_verts := PackedVector3Array()
		var r_norms := PackedVector3Array()
		for s in range(ring_sides):
			var theta: float = TAU * float(s) / float(ring_sides)
			var dir: Vector3 = (normal_a * cos(theta) + normal_b * sin(theta)).normalized()
			r_verts.append(points[i] + dir * (radius * taper))
			r_norms.append(dir)
		rings.append(r_verts)
		ring_normals.append(r_norms)

	var seg_count: int = count if closed else (count - 1)
	for i in range(seg_count):
		var next_i: int = (i + 1) % count
		for s in range(ring_sides):
			var next_s: int = (s + 1) % ring_sides
			var v00: Vector3 = rings[i][s]
			var v01: Vector3 = rings[i][next_s]
			var v10: Vector3 = rings[next_i][s]
			var v11: Vector3 = rings[next_i][next_s]

			var n00: Vector3 = ring_normals[i][s]
			var n01: Vector3 = ring_normals[i][next_s]
			var n10: Vector3 = ring_normals[next_i][s]
			var n11: Vector3 = ring_normals[next_i][next_s]

			st.set_normal(n00)
			st.add_vertex(v00)
			st.set_normal(n10)
			st.add_vertex(v10)
			st.set_normal(n11)
			st.add_vertex(v11)

			st.set_normal(n00)
			st.add_vertex(v00)
			st.set_normal(n11)
			st.add_vertex(v11)
			st.set_normal(n01)
			st.add_vertex(v01)

	return st.commit()
