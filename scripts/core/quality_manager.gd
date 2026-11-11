extends Node
## مدير مستويات جودة الرسوميات والأداء القابل للتدرج (LOW / MEDIUM / HIGH):
## - الإعداد الافتراضي هو MEDIUM (لا يفرض HIGH أبداً على الأجهزة المتوسطة أو الاقتصادية).
## - يضبط دقة طوبولوجيا مجسم الهلام، تعقيد الشيدر، الظلال، الإضاءة الحافية (Rim/Fill)، ومضاد التعرج MSAA.

signal quality_changed(preset: int, profile: Dictionary)

enum Preset {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
}

const PROFILES: Dictionary = {
	Preset.LOW: {
		"name_key": "quality_low",
		"render_scale": 0.85,
		"msaa": Viewport.MSAA_DISABLED,
		"shadows_enabled": false,
		"shadow_atlas_size": 0,
		"fill_light": false,
		"rim_light": false,
		"accent_light": false,
		"slime_subdiv": 12,
		"shader_detail": 0,
	},
	Preset.MEDIUM: {
		"name_key": "quality_medium",
		"render_scale": 1.00,
		"msaa": Viewport.MSAA_DISABLED,
		"shadows_enabled": true,
		"shadow_atlas_size": 1024,
		"fill_light": true,
		"rim_light": true,
		"accent_light": false,
		"slime_subdiv": 20,
		"shader_detail": 1,
	},
	Preset.HIGH: {
		"name_key": "quality_high",
		"render_scale": 1.00,
		"msaa": Viewport.MSAA_2X,
		"shadows_enabled": true,
		"shadow_atlas_size": 2048,
		"fill_light": true,
		"rim_light": true,
		"accent_light": true,
		"slime_subdiv": 28,
		"shader_detail": 2,
	},
}

var current_preset: int = Preset.MEDIUM
var battery_saver: bool = false


func _ready() -> void:
	var settings: Dictionary = SaveManager.get_section("settings")
	current_preset = clampi(int(settings.get("quality_preset", Preset.MEDIUM)), Preset.LOW, Preset.HIGH)
	battery_saver = bool(settings.get("battery_saver", false))
	apply_preset(current_preset, false)
	set_battery_saver(battery_saver, false)


func get_current_profile() -> Dictionary:
	return (PROFILES.get(current_preset, PROFILES[Preset.MEDIUM]) as Dictionary).duplicate()


func apply_preset(preset: int, persist: bool = true) -> void:
	current_preset = clampi(preset, Preset.LOW, Preset.HIGH)
	var profile: Dictionary = get_current_profile()

	var vp: Viewport = get_viewport()
	if vp != null:
		vp.scaling_3d_scale = float(profile["render_scale"])
		vp.msaa_3d = int(profile["msaa"]) as Viewport.MSAA
		vp.positional_shadow_atlas_size = int(profile["shadow_atlas_size"])

	if DisplayServer.get_name() != "headless":
		var s_size: int = maxi(int(profile["shadow_atlas_size"]), 512)
		RenderingServer.directional_shadow_atlas_set_size(s_size, true)

	if persist:
		SaveManager.update_section("settings", {"quality_preset": current_preset})

	quality_changed.emit(current_preset, profile)


func set_battery_saver(enabled: bool, persist: bool = true) -> void:
	battery_saver = enabled
	Engine.max_fps = 30 if battery_saver else 60
	if persist:
		SaveManager.update_section("settings", {"battery_saver": battery_saver})
