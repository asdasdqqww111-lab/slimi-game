class_name SlimiMotionCoordinator
extends Node
## المنسق الحركي السينمائي المركزي لشخصية SLIMI (Central Motion & Layer Coordinator):
## - ينسق 10 أنظمة متزامنة بأوزان وتوقيتات مختلفة:
##   Body, Head, Eyes, Mouth, Antennae, Hat, Pom-Pom, Flower, Audio, Emotion.
## - يطبق المراحل السينمائية الأربع لكل حركة:
##   Anticipation -> Main Action -> Follow-Through -> Recovery.
## - يستخدم طبقات حركة وأوزان مزج واضحة، ويمنع تعارض الأنيميشن مع الفيزياء أو تداخل الأصوات.

signal cinematic_motion_started(motion_id: StringName)
signal cinematic_phase_changed(motion_id: StringName, phase_id: int)
signal cinematic_motion_completed(motion_id: StringName)

enum Phase {
	NONE = 0,
	ANTICIPATION = 1,
	MAIN_ACTION = 2,
	FOLLOW_THROUGH = 3,
	RECOVERY = 4,
}

const CINEMATIC_MOTIONS: Array[StringName] = [
	&"idle_breathing",
	&"curious_leaning",
	&"tiny_steps",
	&"playful_hopping",
	&"elastic_jump",
	&"controlled_fall",
	&"soft_landing",
	&"rolling",
	&"dancing",
	&"wobbling",
	&"stretching",
	&"squashing",
	&"laughing",
	&"crying",
	&"sleeping",
	&"waking",
	&"startled_reaction",
	&"touch_reaction",
]

# توقيتات المراحل الأربع (ثوانٍ): [Anticipation, Main, FollowThrough, Recovery]
const MOTION_TIMINGS: Dictionary = {
	&"idle_breathing":    [0.25, 0.90, 0.55, 0.40],
	&"curious_leaning":   [0.20, 0.75, 0.38, 0.32],
	&"tiny_steps":        [0.14, 0.52, 0.24, 0.20],
	&"playful_hopping":   [0.18, 0.48, 0.28, 0.24],
	&"elastic_jump":      [0.24, 0.56, 0.34, 0.28],
	&"controlled_fall":   [0.12, 0.46, 0.30, 0.26],
	&"soft_landing":      [0.08, 0.26, 0.36, 0.28],
	&"rolling":           [0.22, 0.78, 0.36, 0.28],
	&"dancing":           [0.18, 1.35, 0.38, 0.28],
	&"wobbling":          [0.10, 0.68, 0.42, 0.28],
	&"stretching":        [0.22, 0.68, 0.34, 0.26],
	&"squashing":         [0.12, 0.52, 0.38, 0.28],
	&"laughing":          [0.15, 0.95, 0.36, 0.25],
	&"crying":            [0.22, 1.05, 0.42, 0.32],
	&"sleeping":          [0.35, 1.20, 0.45, 0.30],
	&"waking":            [0.24, 0.62, 0.35, 0.28],
	&"startled_reaction": [0.08, 0.42, 0.40, 0.34],
	&"touch_reaction":    [0.06, 0.30, 0.32, 0.24],
}

var slime: SlimeController
var deformer: SlimeDeformer
var face_rig: SlimeFaceRig
var visual_root: Node3D

# أوزان طبقات المزج الأربع (Blend Layer Weights)
var layer_base_weight: float = 1.0
var layer_action_weight: float = 0.0
var layer_part_additive_weight: float = 0.0
var layer_facial_weight: float = 1.0

var active_motion: StringName = &""
var current_phase: int = Phase.NONE
var current_emotion_hint: int = 0

var _elapsed: float = 0.0
var _phase_durations: Array[float] = [0.15, 0.5, 0.3, 0.2]
var _main_impulse_fired: bool = false
var _voice_gate_timer: float = 0.0
var _sfx_gate_timer: float = 0.0
var _visual_roll_angle: float = 0.0


func setup(p_slime: SlimeController) -> void:
	slime = p_slime
	if slime != null:
		deformer = slime.deformer
		face_rig = slime.face_rig
		visual_root = slime.get_node_or_null("VisualRoot") as Node3D


func get_supported_motions() -> Array[StringName]:
	return CINEMATIC_MOTIONS.duplicate()


func is_motion_active() -> bool:
	return not active_motion.is_empty()


func play_safe_voice(cue_id: StringName, pitch_shift: float = 0.0, vol_db: float = -2.0) -> bool:
	if _voice_gate_timer > 0.0:
		return false
	_voice_gate_timer = 0.24
	return AudioManager.play_voice(cue_id, pitch_shift, vol_db)


func play_safe_sfx(sfx_id: StringName, pitch_shift: float = 0.0, vol_db: float = -3.0) -> bool:
	if _sfx_gate_timer > 0.0:
		return false
	_sfx_gate_timer = 0.09
	return AudioManager.play_sfx(sfx_id, pitch_shift, vol_db)


func play_cinematic_motion(motion_id: StringName, emotion_hint: int = -1) -> bool:
	if slime == null or not MOTION_TIMINGS.has(motion_id):
		return false

	# إعادة ضبط نظيفة لأي إمالة سابقة عند التبديل السريع بين الحركات (يمنع تراكم التحويلات!)
	_reset_coordinator_offsets()

	active_motion = motion_id
	if emotion_hint >= 0:
		current_emotion_hint = emotion_hint
	_elapsed = 0.0
	_main_impulse_fired = false
	var raw_t: Array = MOTION_TIMINGS[motion_id]
	_phase_durations = [float(raw_t[0]), float(raw_t[1]), float(raw_t[2]), float(raw_t[3])]

	current_phase = Phase.ANTICIPATION
	layer_action_weight = 1.0
	_apply_anticipation_pose(motion_id)

	cinematic_motion_started.emit(motion_id)
	cinematic_phase_changed.emit(motion_id, current_phase)
	return true


func trigger_localized_part_reaction(part_id: StringName, local_dir: Vector3, strength: float = 1.0) -> void:
	if deformer == null:
		return
	layer_part_additive_weight = 1.0
	deformer.accessory_physics.apply_part_touch_impulse(part_id, local_dir, strength)

	# استجابة بصرية وصوتية مخصصة للجزء الملموس دون تحريك الجسم كله
	match part_id:
		&"left_antenna", &"right_antenna":
			if face_rig != null:
				var side_x: float = -0.45 if part_id == &"left_antenna" else 0.45
				face_rig.set_look_target_local_3d(Vector3(side_x, 0.52, 0.65))
				face_rig.trigger_blink(SlimeFaceRig.BlinkMode.DOUBLE)
				face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SPEAKING_SMALL)
			play_safe_voice(&"curious_coo", 0.08, -3.0)
		&"beanie_hat", &"pom_pom", &"flower":
			if face_rig != null:
				face_rig.set_look_target_local_3d(Vector3(0.22, 0.55, 0.65))
				face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SMILE)
				face_rig.set_squint(0.28)
			play_safe_voice(&"giggle_soft", 0.04, -3.0)


func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.05)
	if _voice_gate_timer > 0.0:
		_voice_gate_timer = maxf(0.0, _voice_gate_timer - dt)
	if _sfx_gate_timer > 0.0:
		_sfx_gate_timer = maxf(0.0, _sfx_gate_timer - dt)

	layer_part_additive_weight = move_toward(layer_part_additive_weight, 0.0, dt * 1.8)

	if active_motion.is_empty() or slime == null:
		layer_action_weight = move_toward(layer_action_weight, 0.0, dt * 4.0)
		return

	_elapsed += dt
	var t0: float = _phase_durations[0]
	var t1: float = t0 + _phase_durations[1]
	var t2: float = t1 + _phase_durations[2]
	var t3: float = t2 + _phase_durations[3]

	var prev_phase: int = current_phase
	var phase_u: float = 0.0

	if _elapsed < t0:
		current_phase = Phase.ANTICIPATION
		phase_u = _elapsed / maxf(_phase_durations[0], 0.01)
	elif _elapsed < t1:
		current_phase = Phase.MAIN_ACTION
		phase_u = (_elapsed - t0) / maxf(_phase_durations[1], 0.01)
		if not _main_impulse_fired:
			_main_impulse_fired = true
			_fire_main_action_impulse(active_motion)
	elif _elapsed < t2:
		current_phase = Phase.FOLLOW_THROUGH
		phase_u = (_elapsed - t1) / maxf(_phase_durations[2], 0.01)
	elif _elapsed < t3:
		current_phase = Phase.RECOVERY
		phase_u = (_elapsed - t2) / maxf(_phase_durations[3], 0.01)
		layer_action_weight = 1.0 - _smooth_step01(phase_u)
	else:
		var done_id: StringName = active_motion
		_reset_coordinator_offsets()
		active_motion = &""
		current_phase = Phase.NONE
		layer_action_weight = 0.0
		cinematic_motion_completed.emit(done_id)
		return

	if current_phase != prev_phase:
		cinematic_phase_changed.emit(active_motion, current_phase)

	_evaluate_continuous_motion_curves(active_motion, current_phase, clampf(phase_u, 0.0, 1.0), dt)


func _apply_anticipation_pose(motion_id: StringName) -> void:
	if deformer == null or face_rig == null:
		return

	# مرحلة التهيؤ (Anticipation): انضغاط تحضيري وتهيئة نظر وحواجب قبل الفعل الرئيسي
	match motion_id:
		&"elastic_jump", &"playful_hopping":
			deformer.posture_height_scale = 0.80
			deformer.add_vertical_impulse(-2.2)
			face_rig.set_squint(0.25)
		&"curious_leaning":
			deformer.posture_height_scale = 0.95
			face_rig.set_focused_gaze(true)
			face_rig.trigger_blink(SlimeFaceRig.BlinkMode.DOUBLE)
		&"stretching":
			deformer.posture_height_scale = 0.88
			face_rig.set_squint(0.32)
		&"squashing", &"soft_landing":
			deformer.posture_height_scale = 1.06
		&"startled_reaction":
			deformer.posture_height_scale = 0.84
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SURPRISED)
			face_rig.set_focused_gaze(false)
		&"laughing":
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.OPEN_SMILE)
			face_rig.set_squint(0.35)
		&"crying":
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SAD)
			deformer.set_shape_key_weight(&"sad_droop", 0.55)
		&"sleeping":
			face_rig.trigger_blink(SlimeFaceRig.BlinkMode.SLOW)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.RESTING)
		&"waking":
			deformer.posture_height_scale = 0.82
			face_rig.trigger_blink(SlimeFaceRig.BlinkMode.DOUBLE)


func _fire_main_action_impulse(motion_id: StringName) -> void:
	if slime == null or deformer == null or face_rig == null:
		return

	match motion_id:
		&"idle_breathing":
			deformer.set_shape_key_weight(&"breathe_expand", 0.55)
		&"curious_leaning":
			deformer.set_shape_key_weight(&"curious_lean", 0.85)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SPEAKING_SMALL)
			play_safe_voice(&"curious_coo", 0.04, -3.5)
		&"tiny_steps":
			if slime.is_on_floor():
				slime.velocity = slime.global_transform.basis.z * 0.85 + Vector3(0.0, 1.85, 0.0)
			deformer.add_vertical_impulse(1.6)
			play_safe_sfx(&"boing_hop", 0.16, -5.0)
		&"playful_hopping":
			if slime.is_on_floor():
				slime.velocity = slime.global_transform.basis.z * 1.35 + Vector3(0.0, 3.65, 0.0)
			deformer.set_shape_key_weight(&"happy_plump", 0.65)
			deformer.add_vertical_impulse(2.85)
			deformer.play_paw_gesture(1, 0.9)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.OPEN_SMILE)
			play_safe_sfx(&"boing_hop", 0.05, -3.0)
		&"elastic_jump":
			if slime.is_on_floor():
				slime.velocity.y = slime.hop_vertical_speed * 1.24
			deformer.posture_height_scale = 1.18
			deformer.add_vertical_impulse(3.6)
			deformer.play_paw_gesture(1, 1.1)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.LAUGHING)
			play_safe_sfx(&"boing_hop", -0.05, -2.5)
		&"controlled_fall":
			deformer.posture_height_scale = 1.12
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SURPRISED)
		&"soft_landing":
			deformer.posture_height_scale = 0.78
			deformer.add_vertical_impulse(-2.8)
			play_safe_sfx(&"squish_poke", -0.12, -4.5)
		&"rolling":
			if slime.is_on_floor():
				slime.velocity = slime.global_transform.basis.x * 1.15 + Vector3(0.0, 1.55, 0.0)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.LAUGHING)
			play_safe_voice(&"giggle_soft", 0.06, -2.5)
		&"dancing":
			deformer.set_shape_key_weight(&"happy_plump", 0.75)
			deformer.play_paw_gesture(1, 1.6)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.LAUGHING)
			play_safe_voice(&"joy_sparkle", 0.0, -2.0)
		&"wobbling":
			deformer.add_jiggle_impulse(Vector3(2.4, 0.0, 1.6))
			play_safe_voice(&"jelly_wobble_soft", 0.0, -2.5)
		&"stretching":
			deformer.posture_height_scale = 1.26
			deformer.add_vertical_impulse(2.6)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.OPEN_SMILE)
			play_safe_voice(&"jelly_wobble_soft", 0.08, -3.0)
		&"squashing":
			deformer.posture_height_scale = 0.72
			deformer.add_vertical_impulse(-3.2)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.POUTING)
			play_safe_sfx(&"squish_poke", -0.08, -2.5)
		&"laughing":
			deformer.set_shape_key_weight(&"happy_plump", 0.80)
			deformer.play_paw_gesture(1, 1.2)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.LAUGHING)
			face_rig.set_squint(0.48)
			play_safe_voice(&"laugh_long", 0.0, -2.0)
		&"crying":
			deformer.posture_height_scale = 0.86
			deformer.set_shape_key_weight(&"sad_droop", 0.85)
			deformer.play_paw_gesture(2, 1.3)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SAD)
			face_rig.set_squint(0.32)
			play_safe_voice(&"sad_whimper", 0.0, -2.5)
		&"sleeping":
			deformer.is_resting_flat = true
			face_rig.set_expression(SlimeFaceRig.FaceExpression.SLEEPY)
			play_safe_voice(&"sleepy_yawn", 0.0, -3.0)
		&"waking":
			deformer.is_resting_flat = false
			deformer.posture_height_scale = 1.14
			deformer.add_vertical_impulse(2.4)
			face_rig.set_expression(SlimeFaceRig.FaceExpression.HAPPY)
			play_safe_voice(&"happy_chirp", 0.04, -2.5)
		&"startled_reaction":
			if slime.is_on_floor():
				slime.velocity = -slime.global_transform.basis.z * 1.45 + Vector3(0.0, 2.35, 0.0)
			deformer.add_vertical_impulse(2.4)
			deformer.play_paw_gesture(3, 1.0)
			face_rig.set_expression(SlimeFaceRig.FaceExpression.SURPRISED)
			play_safe_voice(&"scared_tremble", 0.0, -2.0)
		&"touch_reaction":
			face_rig.trigger_blink(SlimeFaceRig.BlinkMode.NATURAL)
			face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.OPEN_SMILE)


func _evaluate_continuous_motion_curves(motion_id: StringName, phase_id: int, u: float, dt: float) -> void:
	if deformer == null:
		return
	var s_u: float = _smooth_step01(u)

	match motion_id:
		&"curious_leaning":
			if phase_id == Phase.MAIN_ACTION:
				deformer.set_shape_key_weight(&"curious_lean", lerpf(0.35, 0.88, sin(u * PI)))
				deformer.head_tilt_offset = Vector3(-0.08, 0.0, 0.16 * sin(u * PI))
			elif phase_id == Phase.FOLLOW_THROUGH:
				deformer.head_tilt_offset = Vector3(-0.03 * (1.0 - s_u), 0.0, -0.05 * sin(u * PI))

		&"rolling":
			if phase_id == Phase.MAIN_ACTION:
				_visual_roll_angle = TAU * s_u
			elif phase_id == Phase.FOLLOW_THROUGH:
				_visual_roll_angle = sin(u * PI) * 0.12
			else:
				_visual_roll_angle = 0.0
			if visual_root != null:
				visual_root.rotation.z = _visual_roll_angle

		&"dancing":
			if phase_id == Phase.MAIN_ACTION:
				var beat: float = sin(_elapsed * 11.5)
				deformer.add_jiggle_impulse(Vector3(beat * 0.55, absf(cos(_elapsed * 23.0)) * 0.22, 0.0))
				deformer.head_tilt_offset = Vector3(0.0, beat * 0.12, -beat * 0.14)
				slime.rotation.y += beat * dt * 2.2

		&"laughing":
			if phase_id == Phase.MAIN_ACTION:
				var chuckle: float = sin(_elapsed * 24.0)
				deformer.add_jiggle_impulse(Vector3(0.0, chuckle * 0.28, chuckle * 0.18))

		&"crying":
			if phase_id == Phase.MAIN_ACTION:
				var sniffle: float = sin(_elapsed * 14.0)
				deformer.head_tilt_offset = Vector3(0.14, sniffle * 0.05, 0.0)

	if phase_id == Phase.FOLLOW_THROUGH:
		# مرحلة المتابعة (Follow-Through): عودة تدريجية للوقفة مع ارتداد ثانوي ناعم
		deformer.posture_height_scale = lerpf(deformer.posture_height_scale, 1.0, minf(1.0, dt * 8.0))
		deformer.head_tilt_offset = deformer.head_tilt_offset.lerp(Vector3.ZERO, minf(1.0, dt * 8.0))


func _reset_coordinator_offsets() -> void:
	_visual_roll_angle = 0.0
	if visual_root != null:
		visual_root.rotation = Vector3.ZERO
	if deformer != null:
		if active_motion != &"sleeping":
			deformer.posture_height_scale = 1.0
		deformer.head_tilt_offset = Vector3.ZERO
	if face_rig != null:
		face_rig.set_focused_gaze(false)


func _smooth_step01(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
