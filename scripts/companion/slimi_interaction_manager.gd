class_name SlimiInteractionManager
extends Node
## نظام الأحداث والتفاعل الموحد (SlimiInteractionManager) لشخصية SLIMI:
## يربط الأنظمة العشرة المنفصلة عبر إشارات Godot نظيفة (Signals)، وينسق اللمس والدردشة والصوت
## والألعاب المصغرة، ويدير الاستماع الصوتي عبر الميكروفون بإذن صريح فقط مع مؤشر حي واضح.

signal chat_log_appended(sender: String, message: String, emotion_label: String)
signal mic_state_changed(is_listening: bool, level_rms: float)
signal companion_event_emitted(event_type: StringName, payload: Dictionary)

var slime: SlimeController
var hud: HUDController

var voice_manager: SlimiVoiceManager
var emotion_manager: SlimiEmotionManager
var anim_controller: SlimiAnimationController
var personality_manager: SlimiPersonalityManager
var dialogue_manager: SlimiDialogueManager
var behavior_ai: SlimiBehaviorAI
var memory_manager: SlimiMemoryManager
var settings_manager: SlimiSettingsManager
var minigames: SlimiMiniGames

# إدارة الميكروفون الاختيارية المحمية بالخصوصية
var is_mic_listening: bool = false
var _mic_player: AudioStreamPlayer
var _mic_capture: AudioEffectCapture
var _mic_bus_idx: int = -1
var _mic_listen_elapsed: float = 0.0
var _mic_detected_speech_energy: float = 0.0
var _mic_silence_after_voice: float = 0.0


func _ready() -> void:
	emotion_manager = SlimiEmotionManager.new()
	emotion_manager.name = "SlimiEmotionManager"
	add_child(emotion_manager)

	voice_manager = SlimiVoiceManager.new()
	voice_manager.name = "SlimiVoiceManager"
	add_child(voice_manager)

	anim_controller = SlimiAnimationController.new()
	anim_controller.name = "SlimiAnimationController"
	add_child(anim_controller)

	personality_manager = SlimiPersonalityManager.new()
	personality_manager.name = "SlimiPersonalityManager"
	add_child(personality_manager)

	dialogue_manager = SlimiDialogueManager.new()
	dialogue_manager.name = "SlimiDialogueManager"
	add_child(dialogue_manager)

	behavior_ai = SlimiBehaviorAI.new()
	behavior_ai.name = "SlimiBehaviorAI"
	add_child(behavior_ai)

	memory_manager = SlimiMemoryManager.new()
	memory_manager.name = "SlimiMemoryManager"
	add_child(memory_manager)

	settings_manager = SlimiSettingsManager.new()
	settings_manager.name = "SlimiSettingsManager"
	add_child(settings_manager)

	minigames = SlimiMiniGames.new()
	minigames.name = "SlimiMiniGames"
	add_child(minigames)

	_connect_internal_bus()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		stop_microphone_listening()
		save_companion_state()


func bind_world(p_slime: SlimeController, p_hud: HUDController) -> void:
	slime = p_slime
	hud = p_hud

	settings_manager.load_from_save()
	memory_manager.load_from_save()
	personality_manager.from_dict(SaveManager.get_section("companion_personality"))

	anim_controller.setup(slime, voice_manager, emotion_manager)
	behavior_ai.setup(slime, emotion_manager, personality_manager, anim_controller, voice_manager)
	minigames.setup(slime, anim_controller, emotion_manager, voice_manager)

	_apply_settings_to_voice(settings_manager.get_public_config())

	if slime != null:
		slime.slime_interacted.connect(_on_slime_physical_interaction)

	# مزامنة المشاعر الأولية مع ملامح سلايمي
	emotion_manager.set_emotion(memory_manager.last_emotion_id, 4.0)


func trigger_contextual_launch_greeting() -> void:
	var dt_dict: Dictionary = Time.get_datetime_dict_from_system()
	var hour_24: int = int(dt_dict.get("hour", 10))
	var greet: Dictionary = dialogue_manager.build_launch_greeting(
		LocalizationManager.current_locale,
		hour_24,
		emotion_manager.current_emotion,
		memory_manager.user_nickname,
		memory_manager.favorite_interaction,
		settings_manager.occasion_greetings_enabled
	)
	_deliver_slimi_response(greet)


func send_user_chat_message(text: String) -> Dictionary:
	var cleaned: String = text.strip_edges()
	if cleaned.is_empty():
		return {}

	behavior_ai.notify_user_activity()
	memory_manager.record_interaction("chat")
	memory_manager.remember_chat_snippet(cleaned)
	chat_log_appended.emit("user", cleaned, "")

	var reply: Dictionary = dialogue_manager.generate_reply(
		cleaned,
		LocalizationManager.current_locale,
		memory_manager.user_nickname,
		personality_manager.trust_score,
		settings_manager.get_online_request_config()
	)
	personality_manager.register_user_treatment(&"kind_words")
	_deliver_slimi_response(reply)
	return reply


func request_quick_entertainment(kind: String) -> Dictionary:
	behavior_ai.notify_user_activity()
	if kind == "joke":
		memory_manager.record_interaction("joke")
	var resp: Dictionary = dialogue_manager.request_entertainment_item(kind, LocalizationManager.current_locale)
	_deliver_slimi_response(resp)
	return resp


func toggle_microphone_with_user_consent() -> bool:
	if is_mic_listening:
		stop_microphone_listening()
		return false

	# قاعدة الخصوصية الصارمة: لا نفتح الميكروفون إلا بطلب المستخدم الصريح وإذن النظام
	if OS.get_name() == "Android":
		var granted: PackedStringArray = OS.get_granted_permissions()
		var has_perm: bool = false
		for p in granted:
			if p.contains("RECORD_AUDIO"):
				has_perm = true
				break
		if not has_perm:
			OS.request_permission("RECORD_AUDIO")
			if hud != null:
				var perm_msg: String = "يرجى منح إذن الميكروفون للتحدث مع سلايمي صوتياً 🎤" if LocalizationManager.current_locale == "ar" else "Please grant Microphone permission to talk with SLIMI 🎤"
				hud.show_bubble_text(perm_msg, 3.8)
			return false

	settings_manager.mic_permission_granted_by_user = true
	settings_manager.persist()
	return _start_microphone_capture()


func _start_microphone_capture() -> bool:
	if is_mic_listening:
		return true

	voice_manager.stop_speaking()
	behavior_ai.notify_user_activity()
	emotion_manager.set_emotion(SlimiEmotionManager.Emotion.CURIOUS, 6.0)

	if DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("audio/driver/enable_input", false):
		if _mic_bus_idx < 0:
			_mic_bus_idx = AudioServer.get_bus_index(&"MicCapture")
			if _mic_bus_idx < 0:
				AudioServer.add_bus()
				_mic_bus_idx = AudioServer.bus_count - 1
				AudioServer.set_bus_name(_mic_bus_idx, &"MicCapture")
				AudioServer.set_bus_mute(_mic_bus_idx, true)
				_mic_capture = AudioEffectCapture.new()
				_mic_capture.buffer_length = 0.25
				AudioServer.add_bus_effect(_mic_bus_idx, _mic_capture)

		if _mic_player == null:
			_mic_player = AudioStreamPlayer.new()
			_mic_player.name = "OptInMicListener"
			_mic_player.bus = &"MicCapture"
			_mic_player.stream = AudioStreamMicrophone.new()
			add_child(_mic_player)
		_mic_player.play()

	is_mic_listening = true
	_mic_listen_elapsed = 0.0
	_mic_detected_speech_energy = 0.0
	_mic_silence_after_voice = 0.0
	mic_state_changed.emit(true, 0.0)
	companion_event_emitted.emit(&"mic_started", {})
	return true


func stop_microphone_listening(respond_to_captured_voice: bool = false) -> void:
	if not is_mic_listening:
		return

	is_mic_listening = false
	if _mic_player != null:
		_mic_player.stop()
	if _mic_capture != null:
		_mic_capture.clear_buffer()

	mic_state_changed.emit(false, 0.0)
	companion_event_emitted.emit(&"mic_stopped", {})

	if respond_to_captured_voice:
		var is_en: bool = LocalizationManager.current_locale.begins_with("en")
		var heard_voice: bool = _mic_detected_speech_energy > 0.015
		var spoken_reply: Dictionary
		if heard_voice:
			var ar_lines: Array[String] = [
				"سمعتُ صوتك الجميل بوضوح! نبرتك دافئة وتجعل قرني الاستشعار يرقصان سعادة!",
				"يا لها من نبرة لطيفة! أحب الاستماع إليك دائماً يا صديقي!",
				"هيهي! صوتك أسعدني جداً، هل نلعب لغزاً أم أخبرك نكتة جديدة؟",
			]
			var en_lines: Array[String] = [
				"I heard your lovely voice! Your warm tone made my feelers wiggle happily!",
				"Aww, hearing you speak makes my jelly heart sparkle! Want a joke or a riddle?",
			]
			var pool: Array[String] = en_lines if is_en else ar_lines
			var chosen: String = pool[randi() % pool.size()]
			spoken_reply = {"text": chosen, "emotion": SlimiEmotionManager.Emotion.EXCITED, "action": &"happy_jump"}
		else:
			var quiet_txt: String = "الميكروفون كان هادئاً جداً... يمكنك التحدث مجدداً أو الكتابة لي متى أحببت!" if not is_en else "It sounded super quiet... feel free to speak again or type anytime!"
			spoken_reply = {"text": quiet_txt, "emotion": SlimiEmotionManager.Emotion.CURIOUS, "action": &"look_at_user"}
		_deliver_slimi_response(spoken_reply)


func _process(delta: float) -> void:
	if not is_mic_listening:
		return

	_mic_listen_elapsed += delta
	var rms: float = 0.0
	if _mic_capture != null:
		var avail: int = _mic_capture.get_frames_available()
		if avail > 0:
			var frames: PackedVector2Array = _mic_capture.get_buffer(mini(avail, 512))
			var sum_sq: float = 0.0
			for f in frames:
				var m: float = (f.x + f.y) * 0.5
				sum_sq += m * m
			rms = sqrt(sum_sq / float(maxi(frames.size(), 1)))

	if rms > 0.02:
		_mic_detected_speech_energy = maxf(_mic_detected_speech_energy, rms)
		_mic_silence_after_voice = 0.0
	elif _mic_detected_speech_energy > 0.02:
		_mic_silence_after_voice += delta

	mic_state_changed.emit(true, clampf(rms * 6.0, 0.05, 1.0))

	# توقف تلقائي ذكي بعد انتهاء جملة المستخدم أو بعد 5.5 ثوانٍ كحد أقصى لحماية الخصوصية والبطارية
	if (_mic_detected_speech_energy > 0.02 and _mic_silence_after_voice > 1.15) or _mic_listen_elapsed >= 5.5:
		stop_microphone_listening(true)


func save_companion_state() -> void:
	memory_manager.last_emotion_id = emotion_manager.current_emotion
	memory_manager.persist()
	settings_manager.persist()
	SaveManager.set_section("companion_personality", personality_manager.to_dict())


func _connect_internal_bus() -> void:
	emotion_manager.emotion_changed.connect(_on_emotion_changed)
	voice_manager.lip_sync_updated.connect(_on_lip_sync_updated)
	dialogue_manager.user_name_detected.connect(func(n: String) -> void: memory_manager.set_user_nickname(n))
	dialogue_manager.reply_ready.connect(func(r: Dictionary) -> void:
		if str(r.get("source", "")) == "online_ai":
			_deliver_slimi_response(r)
	)
	settings_manager.companion_settings_changed.connect(_apply_settings_to_voice)
	minigames.minigame_completed.connect(func(gid: String, won: bool, msg: String) -> void:
		behavior_ai.paused_for_minigame = false
		memory_manager.record_minigame_result(gid, won)
		if won:
			personality_manager.register_user_treatment(&"play_win")
		voice_manager.speak_text(msg, emotion_manager.get_profile(), LocalizationManager.current_locale)
		if hud != null:
			hud.show_bubble_text(msg, 4.2)
	)


func _apply_settings_to_voice(cfg: Dictionary) -> void:
	voice_manager.set_muted(bool(cfg.get("voice_muted", false)))
	voice_manager.voice_locale = str(cfg.get("speech_locale", LocalizationManager.current_locale))
	AudioManager.set_bus_linear_volume("Voice", float(cfg.get("voice_volume", 0.92)), false)


func _on_emotion_changed(_emotion_id: int, profile: Dictionary) -> void:
	if slime != null:
		if slime.face_rig != null:
			slime.face_rig.apply_emotion_profile(profile)
		if slime.deformer != null:
			slime.deformer.set_mood_tint(profile.get("tint", Color.WHITE))
			slime.deformer.posture_height_scale = float(profile.get("posture", 1.0))
	if hud != null and hud.mood_label != null:
		hud.mood_label.text = emotion_manager.get_localized_label(LocalizationManager.current_locale)


func _on_lip_sync_updated(mouth_open: float, mouth_wide: float, brow_lift: float, speaking: bool) -> void:
	if slime != null and slime.face_rig != null:
		slime.face_rig.set_lip_sync_frame(mouth_open, mouth_wide, brow_lift, speaking)


func _on_slime_physical_interaction(interaction_type: StringName, _world_pos: Vector3) -> void:
	behavior_ai.notify_user_activity()
	memory_manager.record_interaction(str(interaction_type))
	var suggested_emotion: int = personality_manager.register_user_treatment(interaction_type)
	emotion_manager.set_emotion(suggested_emotion, 4.0)
	companion_event_emitted.emit(interaction_type, {"emotion": suggested_emotion})


func _deliver_slimi_response(resp: Dictionary) -> void:
	var txt: String = str(resp.get("text", "")).strip_edges()
	if txt.is_empty():
		return
	var em: int = int(resp.get("emotion", SlimiEmotionManager.Emotion.HAPPY))
	var act: StringName = resp.get("action", &"look_at_user")

	emotion_manager.set_emotion(em, 5.5)
	if not act.is_empty():
		anim_controller.play_action(act, SlimiAnimationController.Priority.USER_REACTION)

	voice_manager.speak_text(txt, emotion_manager.get_profile(em), LocalizationManager.current_locale)
	if hud != null:
		hud.show_bubble_text(txt, clampf(float(txt.length()) * 0.065, 3.8, 7.2))

	var em_lbl: String = emotion_manager.get_localized_label(LocalizationManager.current_locale)
	chat_log_appended.emit("slimi", txt, em_lbl)
