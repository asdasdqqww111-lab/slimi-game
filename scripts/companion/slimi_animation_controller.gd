class_name SlimiAnimationController
extends Node
## نظام الحركات الترفيهية والكوميدية واليومية لشخصية SLIMI (31 حركة مميزة)
## مع نظام أولوية صارم (Priority Arbitration) يمنع تعارض حركتين معاً ويمنع التكرار الآلي.

signal action_started(action_id: StringName, priority: int)
signal action_finished(action_id: StringName)

enum Priority {
	IDLE_AMBIENT = 0,
	AUTONOMOUS = 1,
	COMEDY_SPONTANEOUS = 2,
	USER_REACTION = 3,
	MINIGAME = 4,
}

# سجل الحركات الـ 31 المطلوبة كاملة (12 حركة يومية + 19 حركة كوميدية وظريفة ونادرة)
const DAILY_ACTIONS: Array[StringName] = [
	&"breath_soft",
	&"idle_sway",
	&"natural_blink",
	&"look_at_user",
	&"eye_scan",
	&"jelly_stretch",
	&"jelly_shrink",
	&"happy_jump",
	&"soft_bounce",
	&"gentle_spin",
	&"room_walk",
	&"excited_run",
]

const COMEDY_ACTIONS: Array[StringName] = [
	&"cute_trip_fall",       # تعثر لطيف وسقوط مضحك
	&"failed_jump_boing",    # محاولة قفز مضحكة تفشل قليلاً
	&"hide_behind_beanie",   # اختباء خجول خلف القبعة
	&"fake_sleep_peek",      # تظاهر بالنوم
	&"sudden_wake_boing",    # استيقاظ مفاجئ بطرافة
	&"big_cute_yawn",        # تثاؤب لطيف
	&"giggle_belly_shake",   # ضحك مع اهتزاز الجسم
	&"music_rhythm_sway",    # تمايل كأنه يسمع موسيقى
	&"silly_jelly_dance",    # رقصة ظريفة
	&"puff_cheeks",          # نفخ الخدود
	&"cute_tongue_blep",     # مد اللسان بشكل ظريف
	&"mock_pout_anger",      # زعل تمثيلي لطيف
	&"stare_at_finger",      # التحديق بدهشة في إصبع المستخدم
	&"dizzy_self_spin",      # الدوران حول نفسه
	&"play_with_antennae",   # اللعب بقرون الاستشعار
	&"wiggle_yellow_beanie", # تحريك القبعة الصفراء
	&"polite_bow",           # تحية بانحناءة لطيفة
	&"blow_sweet_kiss",      # إرسال قبلة لطيفة
	&"victory_celebration",  # احتفال عند الفوز
]

var slime: SlimeController
var voice_manager: SlimiVoiceManager
var emotion_manager: SlimiEmotionManager

var current_action: StringName = &""
var current_priority: int = -1
var _action_elapsed: float = 0.0
var _action_duration: float = 0.0
var _recent_comedy_history: Array[StringName] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(p_slime: SlimeController, p_voice: SlimiVoiceManager, p_emotion: SlimiEmotionManager) -> void:
	slime = p_slime
	voice_manager = p_voice
	emotion_manager = p_emotion


func get_total_supported_actions_count() -> int:
	return DAILY_ACTIONS.size() + COMEDY_ACTIONS.size()


func is_busy_at_or_above(min_priority: int) -> bool:
	return not current_action.is_empty() and current_priority >= min_priority


func play_action(action_id: StringName, priority: int = Priority.AUTONOMOUS) -> bool:
	if slime == null:
		return false
	if not current_action.is_empty() and priority < current_priority:
		return false

	_reset_transient_pose_offsets()
	current_action = action_id
	current_priority = priority
	_action_elapsed = 0.0
	_action_duration = _trigger_action_entry(action_id)
	action_started.emit(action_id, priority)
	return true


func play_random_non_repeating_comedy(priority: int = Priority.COMEDY_SPONTANEOUS) -> StringName:
	var candidates: Array[StringName] = []
	for act in COMEDY_ACTIONS:
		if not _recent_comedy_history.has(act):
			candidates.append(act)
	if candidates.is_empty():
		_recent_comedy_history.clear()
		candidates.assign(COMEDY_ACTIONS)

	var chosen: StringName = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_recent_comedy_history.append(chosen)
	if _recent_comedy_history.size() > 8:
		_recent_comedy_history.pop_front()

	play_action(chosen, priority)
	return chosen


func _trigger_action_entry(action_id: StringName) -> float:
	var def: SlimeDeformer = slime.deformer
	var face: SlimeFaceRig = slime.face_rig

	match action_id:
		# --- الحركات اليومية (12) ---
		&"breath_soft":
			if def != null:
				def.add_vertical_impulse(0.45)
			return 1.2
		&"idle_sway":
			if def != null:
				def.add_jiggle_impulse(Vector3(0.85, 0.0, 0.0))
			return 1.5
		&"natural_blink":
			if face != null:
				face.trigger_blink()
			return 0.35
		&"look_at_user":
			slime.look_target_world = Vector3(0.0, 0.85, 2.95)
			return 1.2
		&"eye_scan":
			if face != null:
				face.set_look_direction_local(Vector3(_rng.randf_range(-0.8, 0.8), 0.25, 1.0))
			return 1.1
		&"jelly_stretch":
			if def != null:
				def.posture_height_scale = 1.22
				def.add_vertical_impulse(2.2)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"jelly_wobble_soft", 0.08, -3.0)
			return 1.3
		&"jelly_shrink":
			if def != null:
				def.posture_height_scale = 0.80
				def.add_vertical_impulse(-1.8)
			return 1.2
		&"happy_jump":
			slime.perform_happy_bounce()
			return 1.1
		&"soft_bounce":
			if def != null:
				def.add_vertical_impulse(1.95)
			AudioManager.play_sfx(&"boing_hop", 0.05, -4.0)
			return 0.9
		&"gentle_spin":
			slime._spin_velocity_y = TAU * 1.15
			return 1.1
		&"room_walk":
			var walk_target := Vector3(_rng.randf_range(-1.2, 1.2), 0.0, _rng.randf_range(-0.8, 1.1))
			slime.hop_toward(walk_target, 0.72)
			return 1.2
		&"excited_run":
			var run_target := Vector3(_rng.randf_range(-1.4, 1.4), 0.0, _rng.randf_range(0.1, 1.3))
			slime.hop_toward(run_target, 1.25)
			return 1.1

		# --- الحركات الكوميدية والظريفة والنادرة (19) ---
		&"cute_trip_fall":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.SURPRISED, 2.5)
			if slime.is_on_floor():
				slime.velocity = Vector3(0.0, 2.2, 0.9)
			if def != null:
				def.posture_height_scale = 0.74
				def.add_jiggle_impulse(Vector3(0.0, -1.2, 2.6))
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"surprise_gasp", 0.04, -2.0)
			return 1.7
		&"failed_jump_boing":
			if slime.is_on_floor():
				slime.velocity.y = 1.45
			if def != null:
				def.add_vertical_impulse(-2.2)
				def.play_paw_gesture(3, 1.1)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"puzzled_hum", 0.06, -2.0)
			return 1.4
		&"hide_behind_beanie":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.SHY, 3.2)
			if def != null:
				def.posture_height_scale = 0.84
				def.beanie_extra_pos = Vector3(-0.12, -0.14, 0.19)
				def.beanie_extra_rot = Vector3(0.45, 0.0, 0.34)
				def.play_paw_gesture(2, 2.0)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"shy_squeak", 0.0, -2.0)
			return 2.0
		&"fake_sleep_peek":
			if face != null:
				face.set_expression(SlimeFaceRig.FaceExpression.SLEEPY)
			if def != null:
				def.posture_height_scale = 0.82
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"sleepy_yawn", 0.1, -4.0)
			return 2.2
		&"sudden_wake_boing":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.SURPRISED, 2.5)
			if slime.is_on_floor():
				slime.velocity.y = 3.8
			if def != null:
				def.add_vertical_impulse(3.1)
				def.play_paw_gesture(3, 1.0)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"surprise_gasp", 0.08, -1.5)
			return 1.3
		&"big_cute_yawn":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.SLEEPY, 3.0)
			if face != null:
				face.set_lip_sync_frame(1.15, 0.92, 0.02, true)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"sleepy_yawn", 0.0, -1.5)
			return 1.8
		&"giggle_belly_shake":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.PLAYFUL, 3.5)
			if def != null:
				def.play_paw_gesture(1, 1.8)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"laugh_long", 0.0, -1.5)
			return 1.8
		&"music_rhythm_sway":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.HAPPY, 3.5)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"giggle_soft", 0.04, -3.0)
			return 2.4
		&"silly_jelly_dance":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.EXCITED, 3.8)
			if def != null:
				def.play_paw_gesture(1, 2.4)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"joy_sparkle", 0.0, -1.5)
			return 2.4
		&"puff_cheeks":
			if face != null:
				face.set_cheek_puff(0.95)
			if def != null:
				def.posture_height_scale = 0.93
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"puzzled_hum", -0.05, -2.5)
			return 1.9
		&"cute_tongue_blep":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.PLAYFUL, 3.0)
			if face != null:
				face.set_tongue_blep(true)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"giggle_soft", 0.08, -2.0)
			return 1.9
		&"mock_pout_anger":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.ANGRY, 3.0)
			if face != null:
				face.set_cheek_puff(0.65)
			return 1.8
		&"stare_at_finger":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.CURIOUS, 3.2)
			slime.look_target_world = Vector3(0.0, 0.72, 1.65)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"curious_coo", 0.06, -2.0)
			return 1.8
		&"dizzy_self_spin":
			slime._spin_velocity_y = TAU * 2.8
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.PLAYFUL, 3.0)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"dizzy_wobble", 0.05, -2.0)
			return 1.7
		&"play_with_antennae":
			if def != null:
				def.play_paw_gesture(5, 2.0)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"jelly_wobble_soft", 0.12, -2.5)
			return 2.0
		&"wiggle_yellow_beanie":
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"giggle_soft", 0.0, -2.5)
			return 1.7
		&"polite_bow":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.GRATEFUL, 3.2)
			if def != null:
				def.posture_height_scale = 0.86
				def.add_jiggle_impulse(Vector3(0.0, 0.0, 2.1))
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"happy_chirp", -0.04, -2.0)
			return 1.5
		&"blow_sweet_kiss":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.AFFECTIONATE, 3.6)
			if def != null:
				def.play_paw_gesture(4, 1.8)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"kiss_mwah", 0.0, -1.5)
			return 1.8
		&"victory_celebration":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.CONFIDENT, 4.0)
			if slime.is_on_floor():
				slime.velocity.y = 4.6
			slime._spin_velocity_y = TAU * 1.6
			if def != null:
				def.add_vertical_impulse(3.5)
				def.play_paw_gesture(1, 2.2)
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"proud_tada", 0.0, -1.0)
			return 2.1

	return 1.0


func _process(delta: float) -> void:
	if current_action.is_empty() or slime == null:
		return

	_action_elapsed += delta
	var def: SlimeDeformer = slime.deformer
	var face: SlimeFaceRig = slime.face_rig

	# تحديث الحركات المستمرة زمنياً بأناقة دون ثقل على الأداء
	match current_action:
		&"giggle_belly_shake":
			if def != null:
				def.add_jiggle_impulse(Vector3(sin(_action_elapsed * 26.0) * 0.45, 0.15, 0.0))
		&"music_rhythm_sway":
			if def != null:
				def.add_jiggle_impulse(Vector3(sin(_action_elapsed * 7.5) * 0.55, 0.0, 0.0))
		&"silly_jelly_dance":
			if def != null:
				def.add_jiggle_impulse(Vector3(sin(_action_elapsed * 12.0) * 0.72, cos(_action_elapsed * 24.0) * 0.25, 0.0))
			slime.rotation.y += sin(_action_elapsed * 9.0) * delta * 2.5
		&"play_with_antennae":
			if def != null:
				def.antenna_extra_rot = Vector3(0.0, 0.0, sin(_action_elapsed * 14.0) * 0.42)
		&"wiggle_yellow_beanie":
			if def != null:
				def.beanie_extra_rot = Vector3(sin(_action_elapsed * 15.0) * 0.18, 0.0, cos(_action_elapsed * 15.0) * 0.28)
		&"fake_sleep_peek":
			if _action_elapsed > 1.35 and face != null:
				face.set_expression(SlimeFaceRig.FaceExpression.PLAYFUL)

	if _action_elapsed >= _action_duration:
		var finished_id: StringName = current_action
		_reset_transient_pose_offsets()
		current_action = &""
		current_priority = -1
		action_finished.emit(finished_id)


func _reset_transient_pose_offsets() -> void:
	if slime == null:
		return
	if slime.deformer != null:
		slime.deformer.posture_height_scale = 1.0
		slime.deformer.beanie_extra_pos = Vector3.ZERO
		slime.deformer.beanie_extra_rot = Vector3.ZERO
		slime.deformer.antenna_extra_rot = Vector3.ZERO
	if slime.face_rig != null:
		slime.face_rig.set_cheek_puff(0.0)
		slime.face_rig.set_tongue_blep(false)
		if current_action == &"big_cute_yawn":
			slime.face_rig.set_lip_sync_frame(0.0, 1.0, 0.0, false)
