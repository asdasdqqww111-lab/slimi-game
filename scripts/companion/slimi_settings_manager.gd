class_name SlimiSettingsManager
extends Node
## مدير الإعدادات والخصوصية ومزود الذكاء الاصطناعي الاختياري (SlimiSettingsManager):
## - الوضع الافتراضي دائماً: Offline (محلي 100% دون أي تبعية مدفوعة أو اتصال خارجي).
## - الوضع الاختياري: AI Online فقط بموافقة المستخدم الصريحة ومفتاحه الخاص.
## - الأمان: لا يُخزن مفتاح API أبداً في ملفات اللعبة المكشوفة أو JSON العادي؛ يُشفر محلياً بملف محمي على جهاز المستخدم فقط.

signal companion_settings_changed(config: Dictionary)

const VAULT_PATH: String = "user://slimi_key_vault.enc"

const PROVIDERS: Dictionary = {
	"openai_compatible": {
		"label_ar": "OpenAI متوافق",
		"label_en": "OpenAI Compatible",
		"default_endpoint": "https://api.openai.com/v1/chat/completions",
		"default_model": "gpt-4o-mini",
	},
	"gemini_compatible": {
		"label_ar": "Google Gemini (OpenAI API)",
		"label_en": "Google Gemini (OpenAI API)",
		"default_endpoint": "https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",
		"default_model": "gemini-2.0-flash",
	},
	"custom_provider": {
		"label_ar": "مزود مخصص (Endpoint)",
		"label_en": "Custom Endpoint",
		"default_endpoint": "https://api.openai.com/v1/chat/completions",
		"default_model": "gpt-4o-mini",
	},
}

var ai_mode: String = "offline" # "offline" | "online"
var ai_provider: String = "openai_compatible"
var custom_endpoint: String = ""
var online_user_consent: bool = false
var voice_muted: bool = false
var voice_volume: float = 0.92
var speech_locale: String = "ar"
var occasion_greetings_enabled: bool = true
var mic_permission_granted_by_user: bool = false

var _runtime_api_key: String = ""


func load_from_save() -> void:
	var cfg: Dictionary = SaveManager.get_section("companion_settings")
	ai_mode = str(cfg.get("ai_mode", "offline"))
	if ai_mode != "online":
		ai_mode = "offline"
	ai_provider = str(cfg.get("ai_provider", "openai_compatible"))
	if not PROVIDERS.has(ai_provider):
		ai_provider = "openai_compatible"
	custom_endpoint = str(cfg.get("custom_endpoint", ""))
	online_user_consent = bool(cfg.get("online_user_consent", false))
	voice_muted = bool(cfg.get("voice_muted", false))
	voice_volume = clampf(float(cfg.get("voice_volume", 0.92)), 0.0, 1.0)
	speech_locale = str(cfg.get("speech_locale", LocalizationManager.current_locale))
	occasion_greetings_enabled = bool(cfg.get("occasion_greetings_enabled", true))
	mic_permission_granted_by_user = bool(cfg.get("mic_permission_granted_by_user", false))
	_runtime_api_key = _load_encrypted_api_key()


func persist() -> void:
	# لاحظ: لا نضع api_key مطلقاً في save_data.json النصي المكشوف
	SaveManager.set_section("companion_settings", {
		"ai_mode": ai_mode,
		"ai_provider": ai_provider,
		"custom_endpoint": custom_endpoint,
		"online_user_consent": online_user_consent,
		"voice_muted": voice_muted,
		"voice_volume": voice_volume,
		"speech_locale": speech_locale,
		"occasion_greetings_enabled": occasion_greetings_enabled,
		"mic_permission_granted_by_user": mic_permission_granted_by_user,
	})
	companion_settings_changed.emit(get_public_config())


func set_api_key_secure(new_key: String) -> void:
	_runtime_api_key = new_key.strip_edges()
	if _runtime_api_key.is_empty():
		if FileAccess.file_exists(VAULT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(VAULT_PATH))
	else:
		var f := FileAccess.open_encrypted_with_pass(VAULT_PATH, FileAccess.WRITE, _derive_vault_pass())
		if f != null:
			f.store_string(_runtime_api_key)
			f.close()
	companion_settings_changed.emit(get_public_config())


func has_configured_api_key() -> bool:
	return not _runtime_api_key.is_empty()


func get_online_request_config() -> Dictionary:
	var prov: Dictionary = PROVIDERS.get(ai_provider, PROVIDERS["openai_compatible"])
	var ep: String = custom_endpoint if (ai_provider == "custom_provider" and not custom_endpoint.is_empty()) else str(prov["default_endpoint"])
	return {
		"mode": ai_mode,
		"provider": ai_provider,
		"endpoint": ep,
		"model": str(prov["default_model"]),
		"user_consent": online_user_consent,
		"api_key": _runtime_api_key if online_user_consent else "",
	}


func get_public_config() -> Dictionary:
	return {
		"ai_mode": ai_mode,
		"ai_provider": ai_provider,
		"online_user_consent": online_user_consent,
		"has_api_key": has_configured_api_key(),
		"voice_muted": voice_muted,
		"voice_volume": voice_volume,
		"speech_locale": speech_locale,
		"occasion_greetings_enabled": occasion_greetings_enabled,
		"mic_permission_granted_by_user": mic_permission_granted_by_user,
	}


func _load_encrypted_api_key() -> String:
	if not FileAccess.file_exists(VAULT_PATH):
		return ""
	var f := FileAccess.open_encrypted_with_pass(VAULT_PATH, FileAccess.READ, _derive_vault_pass())
	if f == null:
		return ""
	var val: String = f.get_as_text().strip_edges()
	f.close()
	return val


func _derive_vault_pass() -> String:
	var hw: String = OS.get_unique_id()
	if hw.is_empty():
		hw = "slimi_local_device_vault"
	return ("slimi_v47_" + hw).sha256_text()
