class_name SlimiMiniGames
extends Node
## منظومة الألعاب المصغرة الداخلية المتكاملة مع SLIMI (9 ألعاب وتحديات تفاعلية):
## 1) الغميضة (Hide & Seek)  2) تقليد الحركات (Copy Moves)  3) لعبة الذاكرة (Memory Sequence)
## 4) لعبة التخمين (Guessing) 5) القفز على الإيقاع (Rhythm Hop) 6) مطاردة الإصبع (Finger Chase)
## 7) اختيار الوجه التعبيري (Emoji Face Match) 8) أسئلة وأجوبة (Trivia Q&A) 9) التحدي اليومي (Daily Challenge)

signal minigame_updated(view_state: Dictionary)
signal minigame_completed(game_id: String, won: bool, message: String)

const GAME_LIST: Array[Dictionary] = [
	{"id": "hide_and_seek", "ar": "🙈 لعبة الغميضة", "en": "🙈 Hide & Seek"},
	{"id": "copy_moves", "ar": "🕺 تقليد الحركات", "en": "🕺 Copy Moves"},
	{"id": "memory_sequence", "ar": "🧠 لعبة الذاكرة", "en": "🧠 Memory Sequence"},
	{"id": "number_guess", "ar": "🔢 تخمين الرقم", "en": "🔢 Guess the Number"},
	{"id": "rhythm_hop", "ar": "🎵 القفز على الإيقاع", "en": "🎵 Rhythm Hop"},
	{"id": "finger_chase", "ar": "👆 مطاردة الإصبع", "en": "👆 Finger Chase"},
	{"id": "emoji_face_match", "ar": "😊 الوجه التعبيري", "en": "😊 Emoji Face Match"},
	{"id": "trivia_qa", "ar": "💡 أسئلة وأجوبة", "en": "💡 Fun Q&A"},
	{"id": "daily_challenge", "ar": "🌟 التحدي اليومي", "en": "🌟 Daily Challenge"},
]

var slime: SlimeController
var anim_controller: SlimiAnimationController
var emotion_manager: SlimiEmotionManager
var voice_manager: SlimiVoiceManager

var active_game_id: String = ""
var _state: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func setup(p_slime: SlimeController, p_anim: SlimiAnimationController, p_emotion: SlimiEmotionManager, p_voice: SlimiVoiceManager) -> void:
	slime = p_slime
	anim_controller = p_anim
	emotion_manager = p_emotion
	voice_manager = p_voice


func get_supported_games() -> Array[Dictionary]:
	return GAME_LIST.duplicate(true)


func is_active() -> bool:
	return not active_game_id.is_empty()


func stop_game() -> void:
	active_game_id = ""
	_state.clear()


func start_game(game_id: String, locale_code: String = "ar") -> Dictionary:
	var is_en: bool = locale_code.begins_with("en")
	active_game_id = game_id
	_state.clear()

	match game_id:
		"hide_and_seek":
			var spot: int = _rng.randi_range(0, 2)
			var spot_positions: Array[Vector3] = [Vector3(-1.25, 0.0, -0.65), Vector3(0.0, 0.0, -0.85), Vector3(1.25, 0.0, -0.55)]
			if slime != null:
				slime.hop_toward(spot_positions[spot], 0.95)
			if anim_controller != null:
				anim_controller.play_action(&"hide_behind_beanie", SlimiAnimationController.Priority.MINIGAME)
			_state = {
				"game_id": game_id,
				"target": spot,
				"prompt": "اختبأتُ خلف قبعتي! احزر في أي ركن أنا؟" if not is_en else "I hid behind my beanie! Guess which cozy spot I chose?",
				"choices": ["🛋️ الوسادة اليسرى", "⭐ وسط الغرفة", "🎈 ركن الكرة الأيمن"] if not is_en else ["🛋️ Left Cushion", "⭐ Center Rug", "🎈 Right Ball Corner"],
			}

		"copy_moves":
			var moves: Array[Dictionary] = [
				{"act": &"silly_jelly_dance", "ar": "💃 رقصة الهلام", "en": "💃 Jelly Dance"},
				{"act": &"wiggle_yellow_beanie", "ar": "🧢 هز القبعة الصفراء", "en": "🧢 Wiggle Beanie"},
				{"act": &"blow_sweet_kiss", "ar": "💖 إرسال قبلة", "en": "💖 Sweet Kiss"},
			]
			var pick: int = _rng.randi_range(0, moves.size() - 1)
			if anim_controller != null:
				anim_controller.play_action(moves[pick]["act"], SlimiAnimationController.Priority.MINIGAME)
			_state = {
				"game_id": game_id,
				"target": pick,
				"prompt": "راقب حركتي الآن! أي حركة قمتُ بها لتقلدني؟" if not is_en else "Watch SLIMI closely! Which move did I just perform?",
				"choices": [moves[0]["en" if is_en else "ar"], moves[1]["en" if is_en else "ar"], moves[2]["en" if is_en else "ar"]],
			}

		"memory_sequence":
			var symbols: Array[String] = ["⭐", "🌸", "💛"]
			var seq: Array[int] = [_rng.randi_range(0, 2), _rng.randi_range(0, 2), _rng.randi_range(0, 2)]
			var seq_str: String = "%s → %s → %s" % [symbols[seq[0]], symbols[seq[1]], symbols[seq[2]]]
			if anim_controller != null:
				anim_controller.play_action(&"play_with_antennae", SlimiAnimationController.Priority.MINIGAME)
			_state = {
				"game_id": game_id,
				"seq": seq,
				"progress": 0,
				"prompt": ("احفظ الترتيب وأعده بالضغط بالترتيب:  %s" % seq_str) if not is_en else ("Memorize & tap in order:  %s" % seq_str),
				"choices": ["⭐ نجمة", "🌸 وردة", "💛 قبعة"] if not is_en else ["⭐ Star", "🌸 Flower", "💛 Beanie"],
			}

		"number_guess":
			var secret: int = _rng.randi_range(0, 3) # يمثل الأرقام 1..4
			_state = {
				"game_id": game_id,
				"target": secret,
				"tries": 0,
				"prompt": "فكرتُ في رقم سري بين 1 و 4! لديك محاولتان لتخمينه!" if not is_en else "I'm thinking of a secret number from 1 to 4! You get 2 tries!",
				"choices": ["1️⃣", "2️⃣", "3️⃣", "4️⃣"],
			}

		"rhythm_hop":
			if anim_controller != null:
				anim_controller.play_action(&"music_rhythm_sway", SlimiAnimationController.Priority.MINIGAME)
			_state = {
				"game_id": game_id,
				"hops": 0,
				"goal": 3,
				"prompt": "اقفز معي على الإيقاع 3 مرات متتالية! (0 / 3)" if not is_en else "Hop to the rhythm with me 3 times! (0 / 3)",
				"choices": ["🎵 بوِينغ! (قفزة إيقاعية)", "🎶 شقلبة موسيقية"] if not is_en else ["🎵 Boing Beat!", "🎶 Musical Spin!"],
			}

		"finger_chase":
			var pos_idx: int = _rng.randi_range(0, 2)
			_move_slime_for_chase(pos_idx)
			_state = {
				"game_id": game_id,
				"target": pos_idx,
				"caught": 0,
				"prompt": "أمسك بي بإصبعك بينما أقفز! أين قفزتُ الآن؟ (0 / 2)" if not is_en else "Catch me as I hop! Tap where I jumped! (0 / 2)",
				"choices": ["⬅️ يمين الغرفة", "⬆️ الوسط", "➡️ يسار الغرفة"] if not is_en else ["⬅️ Left Side", "⬆️ Center", "➡️ Right Side"],
			}

		"emoji_face_match":
			var faces: Array[Dictionary] = [
				{"em": SlimiEmotionManager.Emotion.HAPPY, "ar": "😊 سعيد", "en": "😊 Happy"},
				{"em": SlimiEmotionManager.Emotion.SURPRISED, "ar": "😮 مندهش", "en": "😮 Surprised"},
				{"em": SlimiEmotionManager.Emotion.SLEEPY, "ar": "😴 نعسان", "en": "😴 Sleepy"},
			]
			var idx: int = _rng.randi_range(0, 2)
			if emotion_manager != null:
				emotion_manager.set_emotion(int(faces[idx]["em"]), 8.0)
			_state = {
				"game_id": game_id,
				"target": idx,
				"prompt": "انظر إلى ملامح وجهي الآن! أي شعور أُظهره لك؟" if not is_en else "Look at my face right now! Which emotion am I showing?",
				"choices": [faces[0]["en" if is_en else "ar"], faces[1]["en" if is_en else "ar"], faces[2]["en" if is_en else "ar"]],
			}

		"trivia_qa":
			var qas: Array[Dictionary] = [
				{
					"q_ar": "سؤال ممتع! كم قرن استشعار شفافاً يملك سلايمي؟",
					"q_en": "Fun Trivia! How many translucent feelers does SLIMI have?",
					"c_ar": ["قرن واحد", "قرنان شفافان (2)", "أربعة قرون"],
					"c_en": ["Just 1", "2 Translucent Feelers", "4 Feelers"],
					"ans": 1,
				},
				{
					"q_ar": "سؤال ذكي! ما لون قبعة سلايمي الصوفية المحبوكة؟",
					"q_en": "Quick Trivia! What color is SLIMI's cozy knitted beanie?",
					"c_ar": ["أصفر مشرق 💛", "أزرق داكن 💙", "رمادي 🩶"],
					"c_en": ["Sunny Yellow 💛", "Dark Blue 💙", "Gray 🩶"],
					"ans": 0,
				},
			]
			var q: Dictionary = qas[_rng.randi_range(0, qas.size() - 1)]
			_state = {
				"game_id": game_id,
				"target": int(q["ans"]),
				"prompt": str(q["q_en" if is_en else "q_ar"]),
				"choices": q["c_en" if is_en else "c_ar"],
			}

		"daily_challenge":
			_state = {
				"game_id": game_id,
				"steps": 0,
				"prompt": "تحدي اليوم اللطيف: امنح سلايمي تحية مرحة ثم قفزة احتفالية! (0 / 2)" if not is_en else "Today's Cozy Challenge: Give SLIMI a wave then a victory hop! (0 / 2)",
				"choices": ["👋 تحية لطيفة", "🎉 قفزة احتفالية"] if not is_en else ["👋 Warm Wave", "🎉 Victory Hop"],
			}

	minigame_updated.emit(_state.duplicate(true))
	return _state.duplicate(true)


func submit_choice(choice_index: int, locale_code: String = "ar") -> Dictionary:
	if active_game_id.is_empty():
		return {}
	var is_en: bool = locale_code.begins_with("en")
	var gid: String = active_game_id

	match gid:
		"hide_and_seek", "copy_moves", "emoji_face_match", "trivia_qa":
			var won: bool = (choice_index == int(_state.get("target", 0)))
			return _conclude(gid, won, is_en)

		"memory_sequence":
			var seq: Array = _state.get("seq", [0, 1, 2])
			var prog: int = int(_state.get("progress", 0))
			if choice_index != int(seq[prog]):
				return _conclude(gid, false, is_en)
			prog += 1
			_state["progress"] = prog
			if voice_manager != null:
				voice_manager.play_expressive_sound(&"happy_chirp", float(prog) * 0.06, -2.5)
			if prog >= seq.size():
				return _conclude(gid, true, is_en)
			_state["prompt"] = ("أحسنت! تابع الخطوة (%d / %d)..." % [prog, seq.size()]) if not is_en else ("Nice! Keep going (%d / %d)..." % [prog, seq.size()])
			minigame_updated.emit(_state.duplicate(true))
			return _state.duplicate(true)

		"number_guess":
			var target: int = int(_state.get("target", 0))
			if choice_index == target:
				return _conclude(gid, true, is_en)
			var tries: int = int(_state.get("tries", 0)) + 1
			_state["tries"] = tries
			if tries >= 2:
				return _conclude(gid, false, is_en)
			var hint_higher: bool = choice_index < target
			_state["prompt"] = (
				("قريب جداً! الرقم السري أكبر من اختيارك، جرب مرة أخرى!" if hint_higher else "قريب جداً! الرقم السري أصغر من اختيارك، جرب مرة أخرى!")
				if not is_en else
				("So close! My number is higher — one more try!" if hint_higher else "So close! My number is lower — one more try!")
			)
			minigame_updated.emit(_state.duplicate(true))
			return _state.duplicate(true)

		"rhythm_hop":
			var hops: int = int(_state.get("hops", 0)) + 1
			_state["hops"] = hops
			if slime != null:
				slime.perform_happy_bounce()
			if hops >= int(_state.get("goal", 3)):
				return _conclude(gid, true, is_en)
			_state["prompt"] = ("إيقاع رائع! استمر (%d / 3) 🎵" % hops) if not is_en else ("Great beat! Keep hopping (%d / 3) 🎵" % hops)
			minigame_updated.emit(_state.duplicate(true))
			return _state.duplicate(true)

		"finger_chase":
			if choice_index == int(_state.get("target", 0)):
				var caught: int = int(_state.get("caught", 0)) + 1
				_state["caught"] = caught
				if caught >= 2:
					return _conclude(gid, true, is_en)
				var next_spot: int = (choice_index + 1 + _rng.randi_range(0, 1)) % 3
				_state["target"] = next_spot
				_move_slime_for_chase(next_spot)
				_state["prompt"] = "هيهي أمسكتني مرة! قفزتُ لمكان جديد، أمسكني مجدداً! (1 / 2)" if not is_en else "Hehe you got me once! Catch my next hop! (1 / 2)"
				minigame_updated.emit(_state.duplicate(true))
				return _state.duplicate(true)
			return _conclude(gid, false, is_en)

		"daily_challenge":
			var steps: int = int(_state.get("steps", 0)) + 1
			_state["steps"] = steps
			if anim_controller != null:
				anim_controller.play_action(&"polite_bow" if choice_index == 0 else &"happy_jump", SlimiAnimationController.Priority.MINIGAME)
			if steps >= 2:
				return _conclude(gid, true, is_en)
			_state["prompt"] = "خطوة جميلة! بقيت خطوة واحدة لإتمام تحدي اليوم 🌟 (1 / 2)" if not is_en else "Awesome! One more step to finish Today's Challenge 🌟 (1 / 2)"
			minigame_updated.emit(_state.duplicate(true))
			return _state.duplicate(true)

	return {}


func _move_slime_for_chase(idx: int) -> void:
	if slime == null:
		return
	var xs: Array[float] = [-1.15, 0.0, 1.15]
	slime.hop_toward(Vector3(xs[clampi(idx, 0, 2)], 0.0, 0.35), 1.0)


func _conclude(game_id: String, won: bool, is_en: bool) -> Dictionary:
	active_game_id = ""
	var msg: String = ""
	if won:
		msg = "يااي فزتَ بجدارة! 🎉 شقلبة احتفالية من سلايمي لك!" if not is_en else "Yay, you won!! 🎉 Doing a happy victory flip for you!"
		if emotion_manager != null:
			emotion_manager.set_emotion(SlimiEmotionManager.Emotion.EXCITED, 5.0)
		if anim_controller != null:
			anim_controller.play_action(&"victory_celebration", SlimiAnimationController.Priority.MINIGAME)
	else:
		msg = "محاولة جميلة جداً يا صديقي! 🤍 لنضحك ونلعب جولة أخرى متى أحببت!" if not is_en else "Such a fun try, friend! 🤍 Let's giggle and play again anytime!"
		if emotion_manager != null:
			emotion_manager.set_emotion(SlimiEmotionManager.Emotion.REASSURED, 4.5)
		if anim_controller != null:
			anim_controller.play_action(&"polite_bow", SlimiAnimationController.Priority.MINIGAME)

	var result: Dictionary = {"game_id": game_id, "finished": true, "won": won, "prompt": msg, "choices": []}
	minigame_completed.emit(game_id, won, msg)
	minigame_updated.emit(result)
	return result
