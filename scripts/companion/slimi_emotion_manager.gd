class_name SlimiEmotionManager
extends Node
## محرك المشاعر المتكامل (EMOTION ENGINE) لشخصية SLIMI:
## يدعم 20 شعوراً حقيقياً يؤثر كلٌّ منها في ملامح الوجه، الحواجب، لون ووقفة الجسم، نبرة الصوت، الحوار، والذكاء السلوكي.

signal emotion_changed(emotion_id: int, profile: Dictionary)

enum Emotion {
	HAPPY = 0,           # السعادة
	SAD = 1,             # الحزن
	AFFECTIONATE = 2,    # الحب الودود والتعلق
	CURIOUS = 3,         # الفضول
	SHY = 4,             # الخجل
	SCARED = 5,          # الخوف
	SURPRISED = 6,       # المفاجأة
	ANGRY = 7,           # الغضب اللطيف
	CALM = 8,            # الهدوء
	EXCITED = 9,         # الحماس
	BORED = 10,          # الملل
	SLEEPY = 11,         # النعاس
	TIRED = 12,          # التعب
	LONELY = 13,         # الوحدة
	CONFIDENT = 14,      # الثقة
	GRATEFUL = 15,       # الامتنان
	PLAYFUL = 16,        # المرح
	JEALOUS_PLAYFUL = 17,# الغيرة التمثيلية الخفيفة
	FRUSTRATED = 18,     # الإحباط
	REASSURED = 19,      # الاطمئنان
}

const EMOTION_PROFILES: Dictionary = {
	Emotion.HAPPY: {
		"key": "happy", "ar": "سعيد ومشرق ✨", "en": "Happy & Bright ✨",
		"face": 0, "brow_tilt": 4.0, "brow_lift": 0.012, "eye_open": 1.02, "blush": 0.78,
		"tint": Color(1.0, 1.0, 1.0, 1.0), "posture": 1.02,
		"pitch_hz": 445.0, "tempo": 1.04, "cue": &"happy_chirp",
	},
	Emotion.SAD: {
		"key": "sad", "ar": "حزين قليلاً 🥺", "en": "A Little Sad 🥺",
		"face": 4, "brow_tilt": 16.0, "brow_lift": -0.008, "eye_open": 0.86, "blush": 0.45,
		"tint": Color(0.92, 0.93, 1.0, 1.0), "posture": 0.90,
		"pitch_hz": 365.0, "tempo": 0.82, "cue": &"sad_whimper",
	},
	Emotion.AFFECTIONATE: {
		"key": "affectionate", "ar": "يشعر بالمودة والحنان 💖", "en": "Warm & Affectionate 💖",
		"face": 5, "brow_tilt": 8.0, "brow_lift": 0.010, "eye_open": 0.48, "blush": 1.18,
		"tint": Color(1.0, 0.90, 0.95, 1.0), "posture": 1.0,
		"pitch_hz": 455.0, "tempo": 0.96, "cue": &"purr_pet",
	},
	Emotion.CURIOUS: {
		"key": "curious", "ar": "فضولي يستكشف 🔍", "en": "Curious Explorer 🔍",
		"face": 2, "brow_tilt": 10.0, "brow_lift": 0.022, "eye_open": 1.10, "blush": 0.75,
		"tint": Color(1.0, 0.98, 1.0, 1.0), "posture": 1.06,
		"pitch_hz": 470.0, "tempo": 1.06, "cue": &"curious_coo",
	},
	Emotion.SHY: {
		"key": "shy", "ar": "خجول ولطيف 🌸", "en": "Bashful & Shy 🌸",
		"face": 5, "brow_tilt": 14.0, "brow_lift": 0.004, "eye_open": 0.76, "blush": 1.25,
		"tint": Color(1.0, 0.87, 0.93, 1.0), "posture": 0.92,
		"pitch_hz": 485.0, "tempo": 0.94, "cue": &"shy_squeak",
	},
	Emotion.SCARED: {
		"key": "scared", "ar": "متفاجئ وخائف قليلاً 😣", "en": "Startled & Shy 😣",
		"face": 7, "brow_tilt": 20.0, "brow_lift": 0.028, "eye_open": 1.18, "blush": 0.50,
		"tint": Color(0.95, 0.92, 1.0, 1.0), "posture": 0.86,
		"pitch_hz": 505.0, "tempo": 1.16, "cue": &"scared_tremble",
	},
	Emotion.SURPRISED: {
		"key": "surprised", "ar": "مندهش! 😮", "en": "Surprised! 😮",
		"face": 7, "brow_tilt": 2.0, "brow_lift": 0.032, "eye_open": 1.18, "blush": 0.84,
		"tint": Color(1.0, 0.97, 0.99, 1.0), "posture": 1.09,
		"pitch_hz": 515.0, "tempo": 1.14, "cue": &"surprise_gasp",
	},
	Emotion.ANGRY: {
		"key": "angry", "ar": "يتظاهر بالزعل اللطيف 😤", "en": "Cute Pouty Grump 😤",
		"face": 4, "brow_tilt": -18.0, "brow_lift": -0.012, "eye_open": 0.84, "blush": 1.05,
		"tint": Color(1.0, 0.86, 0.88, 1.0), "posture": 1.04,
		"pitch_hz": 395.0, "tempo": 1.08, "cue": &"puzzled_hum",
	},
	Emotion.CALM: {
		"key": "calm", "ar": "هادئ ومسترخٍ 🌿", "en": "Calm & Peaceful 🌿",
		"face": 0, "brow_tilt": 2.0, "brow_lift": 0.0, "eye_open": 0.88, "blush": 0.68,
		"tint": Color(0.98, 0.97, 1.0, 1.0), "posture": 0.97,
		"pitch_hz": 415.0, "tempo": 0.90, "cue": &"purr_pet",
	},
	Emotion.EXCITED: {
		"key": "excited", "ar": "متحمس جداً! 🎉", "en": "Super Excited! 🎉",
		"face": 1, "brow_tilt": 6.0, "brow_lift": 0.025, "eye_open": 1.14, "blush": 0.98,
		"tint": Color(1.0, 0.96, 0.94, 1.0), "posture": 1.08,
		"pitch_hz": 495.0, "tempo": 1.18, "cue": &"joy_sparkle",
	},
	Emotion.BORED: {
		"key": "bored", "ar": "يشعر ببعض الملل 💭", "en": "A Bit Bored 💭",
		"face": 3, "brow_tilt": 5.0, "brow_lift": -0.010, "eye_open": 0.64, "blush": 0.52,
		"tint": Color(0.96, 0.95, 0.99, 1.0), "posture": 0.91,
		"pitch_hz": 375.0, "tempo": 0.85, "cue": &"bored_sigh",
	},
	Emotion.SLEEPY: {
		"key": "sleepy", "ar": "نعسان ويغفو 🌙", "en": "Sleepy & Cozy 🌙",
		"face": 3, "brow_tilt": 6.0, "brow_lift": -0.014, "eye_open": 0.14, "blush": 0.60,
		"tint": Color(0.94, 0.93, 1.0, 1.0), "posture": 0.78,
		"pitch_hz": 355.0, "tempo": 0.76, "cue": &"sleepy_yawn",
	},
	Emotion.TIRED: {
		"key": "tired", "ar": "مرهق يحتاج للراحة 💤", "en": "Tired & Resting 💤",
		"face": 3, "brow_tilt": 11.0, "brow_lift": -0.010, "eye_open": 0.44, "blush": 0.55,
		"tint": Color(0.95, 0.94, 0.99, 1.0), "posture": 0.86,
		"pitch_hz": 365.0, "tempo": 0.80, "cue": &"bored_sigh",
	},
	Emotion.LONELY: {
		"key": "lonely", "ar": "يشتاق للعب معك 🌟", "en": "Wants Your Company 🌟",
		"face": 2, "brow_tilt": 13.0, "brow_lift": 0.005, "eye_open": 0.96, "blush": 0.64,
		"tint": Color(0.96, 0.94, 1.0, 1.0), "posture": 0.94,
		"pitch_hz": 405.0, "tempo": 0.90, "cue": &"curious_coo",
	},
	Emotion.CONFIDENT: {
		"key": "confident", "ar": "واثق وفخور ⭐", "en": "Confident & Proud ⭐",
		"face": 1, "brow_tilt": -4.0, "brow_lift": 0.016, "eye_open": 1.04, "blush": 0.84,
		"tint": Color(1.0, 0.98, 0.95, 1.0), "posture": 1.07,
		"pitch_hz": 455.0, "tempo": 1.06, "cue": &"proud_tada",
	},
	Emotion.GRATEFUL: {
		"key": "grateful", "ar": "ممتن وسعيد بك 🥰", "en": "Grateful & Warm 🥰",
		"face": 5, "brow_tilt": 9.0, "brow_lift": 0.012, "eye_open": 0.56, "blush": 1.12,
		"tint": Color(1.0, 0.92, 0.96, 1.0), "posture": 1.02,
		"pitch_hz": 450.0, "tempo": 0.98, "cue": &"giggle_soft",
	},
	Emotion.PLAYFUL: {
		"key": "playful", "ar": "مرح ويحب المزاح 🎈", "en": "Playful & Silly 🎈",
		"face": 1, "brow_tilt": 5.0, "brow_lift": 0.018, "eye_open": 1.08, "blush": 0.92,
		"tint": Color(1.0, 0.97, 0.96, 1.0), "posture": 1.05,
		"pitch_hz": 480.0, "tempo": 1.12, "cue": &"giggle_soft",
	},
	Emotion.JEALOUS_PLAYFUL: {
		"key": "jealous_playful", "ar": "يغار بدلال لطيف 🙈", "en": "Playfully Jealous 🙈",
		"face": 4, "brow_tilt": -11.0, "brow_lift": 0.002, "eye_open": 0.90, "blush": 1.08,
		"tint": Color(1.0, 0.90, 0.94, 1.0), "posture": 1.01,
		"pitch_hz": 435.0, "tempo": 1.04, "cue": &"puzzled_hum",
	},
	Emotion.FRUSTRATED: {
		"key": "frustrated", "ar": "متحير قليلاً 🌀", "en": "Mildly Stumped 🌀",
		"face": 6, "brow_tilt": -10.0, "brow_lift": -0.006, "eye_open": 0.86, "blush": 0.82,
		"tint": Color(0.98, 0.92, 0.96, 1.0), "posture": 0.95,
		"pitch_hz": 400.0, "tempo": 0.98, "cue": &"dizzy_wobble",
	},
	Emotion.REASSURED: {
		"key": "reassured", "ar": "مطمئن ويشعر بالأمان 🤍", "en": "Safe & Reassured 🤍",
		"face": 5, "brow_tilt": 6.0, "brow_lift": 0.008, "eye_open": 0.72, "blush": 0.96,
		"tint": Color(1.0, 0.95, 0.98, 1.0), "posture": 1.0,
		"pitch_hz": 430.0, "tempo": 0.94, "cue": &"purr_pet",
	},
}

var current_emotion: int = Emotion.HAPPY
var intensity: float = 0.8
var _hold_timer: float = 0.0
var _recovering_from_scare: bool = false


func get_emotion_count() -> int:
	return EMOTION_PROFILES.size()


func get_profile(emotion_id: int = -1) -> Dictionary:
	var target: int = current_emotion if emotion_id < 0 else emotion_id
	return (EMOTION_PROFILES.get(target, EMOTION_PROFILES[Emotion.HAPPY]) as Dictionary).duplicate()


func get_localized_label(locale_code: String = "ar") -> String:
	var prof: Dictionary = get_profile()
	return str(prof.get("en" if locale_code == "en" else "ar", prof["ar"]))


func set_emotion(emotion_id: int, hold_seconds: float = 4.5, new_intensity: float = 0.85) -> void:
	if not EMOTION_PROFILES.has(emotion_id):
		emotion_id = Emotion.HAPPY

	if emotion_id == Emotion.SCARED:
		_recovering_from_scare = true

	var changed: bool = (current_emotion != emotion_id)
	current_emotion = emotion_id
	intensity = clampf(new_intensity, 0.2, 1.0)
	_hold_timer = maxf(hold_seconds, 0.5)

	if changed or hold_seconds > 0.0:
		emotion_changed.emit(current_emotion, get_profile())


func tick_emotion_decay(delta: float, baseline_emotion: int = Emotion.HAPPY) -> void:
	if _hold_timer > 0.0:
		_hold_timer = maxf(0.0, _hold_timer - delta)
		if _hold_timer <= 0.0:
			if _recovering_from_scare:
				_recovering_from_scare = false
				set_emotion(Emotion.REASSURED, 4.0, 0.75)
			elif current_emotion != baseline_emotion:
				current_emotion = baseline_emotion
				emotion_changed.emit(current_emotion, get_profile())
