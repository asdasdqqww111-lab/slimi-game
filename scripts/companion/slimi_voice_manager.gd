class_name SlimiVoiceManager
extends Node
## نظام الصوت الاحترافي متعدد الطبقات لشخصية SLIMI (SLIMI VOICE):
## 1) أصوات تعبيرية رقيقة ودافئة لكل شعور (ضحكات، فرح، دهشة، نعاس، خجل، فضول...).
## 2) نطق الكلام العربي والإنجليزي عبر دمج النطق النظامي اللطيف (DisplayServer TTS إن توفر)
##    مع التوليد المقطعي النغمي الرقيق بحيث يتكلم SLIMI دائماً بصوت محبب غير مزعج.
## 3) مزامنة حية ودقيقة لحركة الفم واللسان والعينين والحواجب (Lip-Sync & Prosody) مع كل مقطع صوتي.

signal speech_started(text: String, emotion_id: int)
signal speech_finished
signal lip_sync_updated(mouth_open: float, mouth_wide: float, brow_lift: float, speaking: bool)

var voice_muted: bool = false
var use_os_tts_when_available: bool = true
var voice_locale: String = "ar"
var voice_pitch_scale: float = 1.28
var voice_rate_scale: float = 1.02

var _speech_player: AudioStreamPlayer
var _is_speaking: bool = false
var _speech_elapsed: float = 0.0
var _speech_duration: float = 0.0
var _active_visemes: Array[Dictionary] = []
var _tts_voices_cached: bool = false
var _arabic_tts_voice_id: String = ""
var _english_tts_voice_id: String = ""


func _ready() -> void:
	_speech_player = AudioStreamPlayer.new()
	_speech_player.name = "SlimiSpeechPlayer"
	_speech_player.bus = &"Voice" if AudioServer.get_bus_index(&"Voice") >= 0 else &"Master"
	add_child(_speech_player)
	_discover_os_tts_voices()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		stop_speaking()


func _discover_os_tts_voices() -> void:
	if _tts_voices_cached or DisplayServer.get_name() == "headless":
		return
	_tts_voices_cached = true
	if not ProjectSettings.get_setting("audio/general/text_to_speech", false):
		return
	var ar_list: PackedStringArray = DisplayServer.tts_get_voices_for_language("ar")
	if not ar_list.is_empty():
		_arabic_tts_voice_id = ar_list[0]
	var en_list: PackedStringArray = DisplayServer.tts_get_voices_for_language("en")
	if not en_list.is_empty():
		_english_tts_voice_id = en_list[0]


func set_muted(muted: bool) -> void:
	voice_muted = muted
	if voice_muted:
		stop_speaking()


func is_speaking() -> bool:
	return _is_speaking


func play_expressive_sound(cue_id: StringName, pitch_offset: float = 0.0, volume_db: float = -1.5) -> bool:
	if voice_muted:
		return false
	return AudioManager.play_voice(cue_id, pitch_offset, volume_db)


func speak_text(text: String, emotion_profile: Dictionary = {}, locale_override: String = "") -> float:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty():
		return 0.0

	stop_speaking()

	var base_hz: float = float(emotion_profile.get("pitch_hz", 445.0))
	var tempo: float = float(emotion_profile.get("tempo", 1.0)) * voice_rate_scale
	var emotion_id: int = int(emotion_profile.get("face", 0))

	var synth: Dictionary = ProceduralSoundBank.synthesize_speech_phrase(clean_text, base_hz, tempo)
	var wav: AudioStreamWAV = synth.get("stream") as AudioStreamWAV
	_speech_duration = maxf(float(synth.get("duration", 0.6)), 0.35)
	_active_visemes.clear()
	for v in synth.get("visemes", []):
		if v is Dictionary:
			_active_visemes.append(v)

	_speech_elapsed = 0.0
	_is_speaking = true
	speech_started.emit(clean_text, emotion_id)

	if not voice_muted and DisplayServer.get_name() != "headless":
		var loc: String = locale_override if not locale_override.is_empty() else voice_locale
		var tts_id: String = _english_tts_voice_id if loc.begins_with("en") else _arabic_tts_voice_id
		if use_os_tts_when_available and not tts_id.is_empty():
			# نطق الكلمات الحقيقية عبر محرك النظام بنبرة سلايمي الرقيقة مع غمغمة افتتاحية لطيفة
			var cue_id: StringName = emotion_profile.get("cue", &"happy_chirp")
			AudioManager.play_voice(cue_id, 0.04, -7.0)
			DisplayServer.tts_speak(clean_text, tts_id, 85, clampf(voice_pitch_scale, 1.05, 1.55), clampf(tempo, 0.8, 1.25), 0, true)
			_speech_duration = maxf(_speech_duration, float(clean_text.length()) * 0.055)
		elif wav != null and _speech_player != null:
			_speech_player.stream = wav
			_speech_player.volume_db = -2.0
			_speech_player.play()

	return _speech_duration


func stop_speaking() -> void:
	if _speech_player != null and _speech_player.playing:
		_speech_player.stop()
	if DisplayServer.get_name() != "headless" and ProjectSettings.get_setting("audio/general/text_to_speech", false):
		if not _arabic_tts_voice_id.is_empty() or not _english_tts_voice_id.is_empty():
			DisplayServer.tts_stop()
	if _is_speaking:
		_is_speaking = false
		_active_visemes.clear()
		lip_sync_updated.emit(0.0, 1.0, 0.0, false)
		speech_finished.emit()


func _process(delta: float) -> void:
	if not _is_speaking:
		return

	_speech_elapsed += delta
	if _speech_elapsed >= _speech_duration:
		_is_speaking = false
		_active_visemes.clear()
		lip_sync_updated.emit(0.0, 1.0, 0.0, false)
		speech_finished.emit()
		return

	var open_val: float = 0.12
	var wide_val: float = 1.0
	for v in _active_visemes:
		var s: float = float(v.get("start", 0.0))
		var e: float = float(v.get("end", 0.1))
		if _speech_elapsed >= s and _speech_elapsed <= e:
			var mid_u: float = (_speech_elapsed - s) / maxf(e - s, 0.01)
			var bell: float = sin(clampf(mid_u, 0.0, 1.0) * PI)
			open_val = float(v.get("open", 0.75)) * bell
			wide_val = lerpf(1.0, float(v.get("wide", 1.0)), bell)
			break

	var brow_pulse: float = open_val * 0.016
	lip_sync_updated.emit(open_val, wide_val, brow_pulse, true)
