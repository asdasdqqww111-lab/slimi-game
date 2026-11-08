class_name SlimiAccessoryPhysics
extends RefCounted
## محاكاة النوابض المخمدة المستقلة للإكسسوارات (Antenna, Beanie, Pom-Pom, Flower Secondary Physics):
## - استجابة نابضية مستقلة لكل قرن استشعار مع تأخر قصوري (Inertial Lag) وحدود تصادم تمنع التداخل مع الرأس أو القبعة.
## - حركة ثانوية متزنة للقبعة الصفراء.
## - ارتداد ناعم متأخر (Delayed Follow-Through) للكرة البيضاء (Pom-Pom).
## - ثبات عالٍ للزهرة الملونة دون اختراق للقبعة.

# حالات نوابض القرنين (زوايا راديان وسرعات زاوية مستقلة)
var left_antenna_rot := Vector3.ZERO
var left_antenna_vel := Vector3.ZERO
var star_tip_rot_z: float = 0.0
var star_tip_vel_z: float = 0.0

var right_antenna_rot := Vector3.ZERO
var right_antenna_vel := Vector3.ZERO

# حالة القبعة الصوفية (ميلان ثانوي محدود)
var beanie_rot_offset := Vector3.ZERO
var beanie_rot_vel := Vector3.ZERO

# حالة الكرة البيضاء (Pom-Pom) في الفضاء المحلي للقبعة (تأخر قصوري + ارتداد ناعم)
var pom_pos_offset := Vector3.ZERO
var pom_pos_vel := Vector3.ZERO

# حالة الزهرة الملونة (حركة ثانوية دقيقة جداً وآمنة من التداخل)
var flower_rot_offset := Vector3.ZERO
var flower_rot_vel := Vector3.ZERO

var _prev_head_world_vel := Vector3.ZERO
var _prev_yaw_vel: float = 0.0


func reset_to_rest() -> void:
	left_antenna_rot = Vector3.ZERO
	left_antenna_vel = Vector3.ZERO
	star_tip_rot_z = 0.0
	star_tip_vel_z = 0.0
	right_antenna_rot = Vector3.ZERO
	right_antenna_vel = Vector3.ZERO
	beanie_rot_offset = Vector3.ZERO
	beanie_rot_vel = Vector3.ZERO
	pom_pos_offset = Vector3.ZERO
	pom_pos_vel = Vector3.ZERO
	flower_rot_offset = Vector3.ZERO
	flower_rot_vel = Vector3.ZERO
	_prev_head_world_vel = Vector3.ZERO
	_prev_yaw_vel = 0.0


func apply_part_touch_impulse(part_id: StringName, local_dir: Vector3, strength: float = 1.0) -> void:
	var s: float = clampf(strength, 0.2, 2.0)
	match part_id:
		&"left_antenna":
			left_antenna_vel += Vector3(local_dir.z * 5.2, 0.0, -local_dir.x * 6.5 + 3.4) * s
			star_tip_vel_z += 8.5 * s
		&"right_antenna":
			right_antenna_vel += Vector3(local_dir.z * 5.8, 0.0, local_dir.x * 6.8 - 3.8) * s
		&"beanie_hat":
			beanie_rot_vel += Vector3(local_dir.z * 2.8, local_dir.x * 1.6, -local_dir.x * 3.2) * s
			pom_pos_vel += Vector3(-local_dir.x * 0.45, 0.55, local_dir.z * 0.45) * s
		&"pom_pom":
			pom_pos_vel += Vector3(local_dir.x * 0.85, 0.95, local_dir.z * 0.85) * s
			beanie_rot_vel += Vector3(0.4, 0.0, -0.5) * s
		&"flower":
			flower_rot_vel += Vector3(0.9, 0.0, 1.35) * s
			beanie_rot_vel += Vector3(0.35, 0.0, -0.4) * s


func step_physics(
	delta: float,
	local_body_vel: Vector3,
	yaw_angular_vel: float,
	jiggle_vel: Vector3,
	additive_antenna_target: Vector3 = Vector3.ZERO,
	additive_beanie_target: Vector3 = Vector3.ZERO
) -> void:
	# تقسيم الزمن الفرعي (Sub-stepping) لضمان تطابق استقرار النوابض بين 30 FPS و 60 FPS بدون تذبذب لانهائي
	var clamped_dt: float = clampf(delta, 0.0005, 0.06)
	var substeps: int = 2 if clamped_dt > 0.020 else 1
	var h: float = clamped_dt / float(substeps)

	var head_accel: Vector3 = (local_body_vel - _prev_head_world_vel) / maxf(clamped_dt, 0.008)
	head_accel = head_accel.limit_length(28.0)
	var yaw_accel: float = clampf((yaw_angular_vel - _prev_yaw_vel) / maxf(clamped_dt, 0.008), -35.0, 35.0)
	_prev_head_world_vel = local_body_vel
	_prev_yaw_vel = yaw_angular_vel

	for _s in range(substeps):
		# 1. القرن الأيسر (تردد طبيعي أبطأ قليلاً بسبب وزن نجمة القمة -> تأخر قصوري واضح)
		var l_inertia := Vector3(
			clampf(-head_accel.z * 0.014 - jiggle_vel.z * 0.08, -0.45, 0.45),
			clampf(-yaw_accel * 0.008, -0.25, 0.25),
			clampf(head_accel.x * 0.015 + head_accel.y * 0.010 + jiggle_vel.x * 0.09, -0.48, 0.48)
		)
		var l_force: Vector3 = (additive_antenna_target + l_inertia - left_antenna_rot) * 112.0
		left_antenna_vel = (left_antenna_vel + l_force * h) * exp(-7.2 * h)
		left_antenna_rot += left_antenna_vel * h
		# حدود أمان ضد التصادم مع الجسم أو القبعة: لا يهبط القرن داخل الرأس مطلقاً
		left_antenna_rot.x = clampf(left_antenna_rot.x, -0.42, 0.42)
		left_antenna_rot.y = clampf(left_antenna_rot.y, -0.32, 0.32)
		left_antenna_rot.z = clampf(left_antenna_rot.z, -0.28, 0.52)

		# مفصل النجمة الطرفي المتأخر عن ساق القرن الأيسر
		var star_target: float = -left_antenna_rot.z * 0.65 - left_antenna_vel.z * 0.04
		star_tip_vel_z = (star_tip_vel_z + (star_target - star_tip_rot_z) * 135.0 * h) * exp(-6.8 * h)
		star_tip_rot_z = clampf(star_tip_rot_z + star_tip_vel_z * h, -0.55, 0.55)

		# 2. القرن الأيمن (معامل نابض وتخميد مختلفان لحركة مستقلة تماماً عن القرن الأيسر!)
		var r_inertia := Vector3(
			clampf(-head_accel.z * 0.012 - jiggle_vel.z * 0.07, -0.38, 0.38),
			clampf(yaw_accel * 0.007, -0.22, 0.22),
			clampf(-head_accel.x * 0.014 - head_accel.y * 0.009 - jiggle_vel.x * 0.08, -0.40, 0.40)
		)
		var r_target := Vector3(additive_antenna_target.x * 0.85, -additive_antenna_target.y, -additive_antenna_target.z * 0.90) + r_inertia
		var r_force: Vector3 = (r_target - right_antenna_rot) * 142.0
		right_antenna_vel = (right_antenna_vel + r_force * h) * exp(-8.4 * h)
		right_antenna_rot += right_antenna_vel * h
		# حدود تصادم مع القبعة الصفراء المجاورة
		right_antenna_rot.x = clampf(right_antenna_rot.x, -0.34, 0.34)
		right_antenna_rot.y = clampf(right_antenna_rot.y, -0.24, 0.24)
		right_antenna_rot.z = clampf(right_antenna_rot.z, -0.38, 0.24)

		# 3. القبعة الصوفية الصفراء (تثبيت مستقر مع حركة ثانوية مضبوطة)
		var b_inertia := Vector3(
			clampf(-head_accel.z * 0.006, -0.18, 0.18),
			clampf(-yaw_accel * 0.003, -0.10, 0.10),
			clampf(head_accel.x * 0.007 - head_accel.y * 0.004, -0.20, 0.20)
		)
		var b_force: Vector3 = (additive_beanie_target + b_inertia - beanie_rot_offset) * 168.0
		beanie_rot_vel = (beanie_rot_vel + b_force * h) * exp(-12.5 * h)
		beanie_rot_offset += beanie_rot_vel * h
		beanie_rot_offset.x = clampf(beanie_rot_offset.x, -0.28, 0.48)
		beanie_rot_offset.y = clampf(beanie_rot_offset.y, -0.18, 0.18)
		beanie_rot_offset.z = clampf(beanie_rot_offset.z, -0.26, 0.38)

		# 4. الكرة البيضاء (Pom-Pom) — تأخر قصوري واضح وارتداد ناعم ثم استقرار طبيعي
		var pom_drive := Vector3(
			-head_accel.x * 0.0022 - beanie_rot_vel.z * 0.012,
			clampf(-head_accel.y * 0.0028, -0.035, 0.045),
			-head_accel.z * 0.0022 + beanie_rot_vel.x * 0.012
		)
		var pom_force: Vector3 = (pom_drive - pom_pos_offset) * 86.0
		pom_pos_vel = (pom_pos_vel + pom_force * h) * exp(-6.9 * h)
		pom_pos_offset += pom_pos_vel * h
		pom_pos_offset.x = clampf(pom_pos_offset.x, -0.055, 0.055)
		pom_pos_offset.y = clampf(pom_pos_offset.y, -0.025, 0.065)
		pom_pos_offset.z = clampf(pom_pos_offset.z, -0.055, 0.055)

		# 5. الزهرة الملونة — حركة ثانوية ضئيلة جداً ومثبتة بأمان فوق الحافة دون اختراق
		var fl_drive := Vector3(-head_accel.y * 0.0015, 0.0, head_accel.x * 0.0018)
		var fl_force: Vector3 = (fl_drive - flower_rot_offset) * 240.0
		flower_rot_vel = (flower_rot_vel + fl_force * h) * exp(-16.0 * h)
		flower_rot_offset += flower_rot_vel * h
		flower_rot_offset.x = clampf(flower_rot_offset.x, -0.06, 0.06)
		flower_rot_offset.y = 0.0
		flower_rot_offset.z = clampf(flower_rot_offset.z, -0.07, 0.07)

	_sanitize_states()


func get_antenna_tip_separation() -> float:
	var l_basis := Basis.from_euler(left_antenna_rot)
	var r_basis := Basis.from_euler(right_antenna_rot)
	var l_tip: Vector3 = SlimiIdentitySpec.LEFT_ANTENNA_ANCHOR + l_basis * Vector3(-0.08, 0.34, 0.0)
	var r_tip: Vector3 = SlimiIdentitySpec.RIGHT_ANTENNA_ANCHOR + r_basis * Vector3(0.08, 0.28, 0.0)
	return l_tip.distance_to(r_tip)


func _sanitize_states() -> void:
	if not SlimiIdentitySpec.is_finite_vec3(left_antenna_rot):
		reset_to_rest()
	elif not SlimiIdentitySpec.is_finite_vec3(right_antenna_rot) or not SlimiIdentitySpec.is_finite_vec3(pom_pos_offset):
		reset_to_rest()
