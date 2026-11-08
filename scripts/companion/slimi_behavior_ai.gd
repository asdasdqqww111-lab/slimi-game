class_name SlimiBehaviorAI
extends Node
## الذكاء السلوكي المستقل (Utility AI) لشخصية SLIMI:
## يقيم الأفعال المتاحة بناءً على المشاعر والطاقة والفضول والملل وعناصر الغرفة ووجود المستخدم
## مع احترام الأولويات والهدوء التام عند عدم التفاعل (لا يزعج المستخدم بالثرثرة المستمرة).

signal autonomous_decision_made(decision_id: StringName, utility_score: float)

const ROOM_POIS: Dictionary = {
	&"cozy_cushion": Vector3(-1.35, 0.0, -0.75),
	&"star_ball": Vector3(1.25, 0.0, 0.35),
	&"treat_corner": Vector3(-0.95, 0.0, 0.90),
	&"front_camera": Vector3(0.0, 0.0, 0.55),
}

var slime: SlimeController
var emotion_manager: SlimiEmotionManager
var personality_manager: SlimiPersonalityManager
var anim_controller: SlimiAnimationController
var voice_manager: SlimiVoiceManager

var paused_for_minigame: bool = false
var idle_seconds_since_user: float = 0.0
var boredom_level: float = 0.12
var curiosity_charge: float = 0.55

var _decision_timer: float = 4.2
var _last_decision: StringName = &""
var _gentle_wave_done_this_idle: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(
	p_slime: SlimeController,
	p_emotion: SlimiEmotionManager,
	p_personality: SlimiPersonalityManager,
	p_anim: SlimiAnimationController,
	p_voice: SlimiVoiceManager
) -> void:
	slime = p_slime
	emotion_manager = p_emotion
	personality_manager = p_personality
	anim_controller = p_anim
	voice_manager = p_voice
	# نوقف المؤقت القديم في AutonomousBehaviorAI إن وجد حتى لا تتعارض القرارات مع Utility AI الموحد
	if slime != null and slime.ai_brain != null:
		slime.ai_brain.set_process(false)


func notify_user_activity() -> void:
	idle_seconds_since_user = 0.0
	boredom_level = maxf(0.0, boredom_level - 0.35)
	_gentle_wave_done_this_idle = false
	_decision_timer = _rng.randf_range(4.0, 6.5)


func _process(delta: float) -> void:
	if paused_for_minigame or slime == null:
		return
	if slime.is_being_dragged:
		return
	if voice_manager != null and voice_manager.is_speaking():
		return

	idle_seconds_since_user += delta
	boredom_level = clampf(boredom_level + delta * 0.012, 0.0, 1.0)
	curiosity_charge = clampf(curiosity_charge + delta * 0.025, 0.0, 1.0)

	if emotion_manager != null:
		var base_em: int = SlimiEmotionManager.Emotion.CALM if idle_seconds_since_user > 25.0 else SlimiEmotionManager.Emotion.HAPPY
		if slime.mood_system != null and slime.mood_system.energy < 24.0:
			base_em = SlimiEmotionManager.Emotion.SLEEPY
		elif boredom_level > 0.68:
			base_em = SlimiEmotionManager.Emotion.BORED
		emotion_manager.tick_emotion_decay(delta, base_em)

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_evaluate_and_execute_utility_decision()


func evaluate_utilities() -> Dictionary:
	var energy: float = slime.mood_system.energy if (slime != null and slime.mood_system != null) else 80.0
	var cur_trait: float = personality_manager.curiosity if personality_manager != null else 0.8
	var hum_trait: float = personality_manager.humor if personality_manager != null else 0.8

	var scores: Dictionary = {
		&"calm_observe": 0.48 + (0.22 if idle_seconds_since_user > 20.0 else 0.0),
		&"explore_poi": (curiosity_charge * 0.72 * cur_trait) if energy > 35.0 else 0.1,
		&"solo_beanie_play": boredom_level * 0.66 + 0.18,
		&"spontaneous_comedy": (hum_trait * 0.62 + _rng.randf_range(0.0, 0.24)) if (energy > 42.0 and idle_seconds_since_user < 35.0) else 0.08,
		&"cozy_rest": clampf((38.0 - energy) / 35.0, 0.0, 0.96),
		&"gentle_attention": 0.76 if (idle_seconds_since_user > 18.0 and idle_seconds_since_user < 32.0 and not _gentle_wave_done_this_idle) else 0.0,
	}

	if _last_decision != &"" and scores.has(_last_decision):
		scores[_last_decision] = float(scores[_last_decision]) * 0.45

	return scores


func _evaluate_and_execute_utility_decision() -> void:
	if anim_controller != null and anim_controller.is_busy_at_or_above(SlimiAnimationController.Priority.COMEDY_SPONTANEOUS):
		_decision_timer = 2.5
		return

	var scores: Dictionary = evaluate_utilities()
	var best_id: StringName = &"calm_observe"
	var best_score: float = -1.0
	for k in scores.keys():
		var s: float = float(scores[k])
		if s > best_score:
			best_score = s
			best_id = k

	_last_decision = best_id
	autonomous_decision_made.emit(best_id, best_score)

	match best_id:
		&"cozy_rest":
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.SLEEPY, 6.0)
			slime.hop_toward(ROOM_POIS[&"cozy_cushion"], 0.65)
			if anim_controller != null:
				anim_controller.play_action(&"big_cute_yawn", SlimiAnimationController.Priority.AUTONOMOUS)
			_decision_timer = _rng.randf_range(7.0, 10.5)

		&"explore_poi":
			curiosity_charge = 0.2
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.CURIOUS, 4.0)
			var poi_keys: Array = ROOM_POIS.keys()
			var chosen_poi: Vector3 = ROOM_POIS[poi_keys[_rng.randi_range(0, poi_keys.size() - 1)]]
			slime.hop_toward(chosen_poi, 0.82)
			_decision_timer = _rng.randf_range(5.0, 8.0)

		&"solo_beanie_play":
			boredom_level = maxf(0.15, boredom_level - 0.25)
			if anim_controller != null:
				var solo_act: StringName = &"play_with_antennae" if _rng.randf() < 0.5 else &"wiggle_yellow_beanie"
				anim_controller.play_action(solo_act, SlimiAnimationController.Priority.AUTONOMOUS)
			_decision_timer = _rng.randf_range(5.5, 8.5)

		&"spontaneous_comedy":
			if anim_controller != null:
				anim_controller.play_random_non_repeating_comedy(SlimiAnimationController.Priority.COMEDY_SPONTANEOUS)
			_decision_timer = _rng.randf_range(6.5, 10.0)

		&"gentle_attention":
			_gentle_wave_done_this_idle = true
			if emotion_manager != null:
				emotion_manager.set_emotion(SlimiEmotionManager.Emotion.LONELY, 3.5)
			slime.hop_toward(ROOM_POIS[&"front_camera"], 0.72)
			if anim_controller != null:
				anim_controller.play_action(&"polite_bow", SlimiAnimationController.Priority.AUTONOMOUS)
			_decision_timer = _rng.randf_range(8.0, 12.0)

		_:
			if anim_controller != null:
				var idle_act: StringName = &"look_at_user" if _rng.randf() < 0.55 else &"idle_sway"
				anim_controller.play_action(idle_act, SlimiAnimationController.Priority.IDLE_AMBIENT)
			# عندما يتركه المستخدم طويلًا يصبح هادئاً جداً وموفراً للطاقة
			_decision_timer = _rng.randf_range(6.0, 9.5) if idle_seconds_since_user > 25.0 else _rng.randf_range(4.2, 6.5)
