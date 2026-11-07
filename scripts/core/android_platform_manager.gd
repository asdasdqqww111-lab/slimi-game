extends Node
## مدير تكامل نظام Android والأداء: ملء الشاشة، الحواف الآمنة (Safe Area)، زر الرجوع، الاهتزاز، ومراقبة الإطارات.

signal back_requested
signal safe_area_updated(margins: Dictionary)
signal performance_updated(fps: float, frame_ms: float)

var haptics_enabled: bool = true
var current_fps: float = 60.0
var avg_frame_ms: float = 16.6
var is_app_paused: bool = false

var _perf_timer: float = 0.0
var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	var settings: Dictionary = SaveManager.get_section("settings")
	haptics_enabled = bool(settings.get("haptics_enabled", true))

	# تفعيل ملء الشاشة تلقائياً على الهواتف وعند التشغيل الرسومي الفعلي
	if DisplayServer.get_name() != "headless":
		if OS.get_name() == "Android":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_tree().set_quit_on_go_back(false)


func _process(delta: float) -> void:
	_perf_timer += delta
	avg_frame_ms = lerpf(avg_frame_ms, delta * 1000.0, 0.1)
	if _perf_timer >= 0.5:
		_perf_timer = 0.0
		current_fps = float(Engine.get_frames_per_second())
		if current_fps <= 0.0 and delta > 0.0:
			current_fps = 1.0 / delta
		performance_updated.emit(current_fps, avg_frame_ms)

		if DisplayServer.get_name() != "headless":
			var win_size: Vector2i = DisplayServer.window_get_size()
			if win_size != _last_window_size:
				_last_window_size = win_size
				safe_area_updated.emit(get_safe_area_margins())


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			back_requested.emit()
		NOTIFICATION_APPLICATION_PAUSED:
			is_app_paused = true
			AudioServer.set_bus_mute(0, true)
		NOTIFICATION_APPLICATION_RESUMED:
			is_app_paused = false
			var master_vol: float = float(SaveManager.get_section("settings").get("master_volume", 0.90))
			AudioServer.set_bus_mute(0, master_vol <= 0.005)


func set_haptics_enabled(enabled: bool, persist: bool = true) -> void:
	haptics_enabled = enabled
	if persist:
		SaveManager.update_section("settings", {"haptics_enabled": haptics_enabled})


func trigger_haptic(duration_ms: int = 16) -> void:
	if not haptics_enabled:
		return
	if OS.get_name() == "Android":
		Input.vibrate_handheld(clampi(duration_ms, 8, 60))


func get_safe_area_margins() -> Dictionary:
	var base := {"left": 16, "top": 16, "right": 16, "bottom": 16}
	if DisplayServer.get_name() == "headless":
		return base

	var win_size: Vector2i = DisplayServer.window_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	if win_size.x <= 0 or win_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return base

	base["left"] = maxi(16, safe_rect.position.x)
	base["top"] = maxi(16, safe_rect.position.y)
	base["right"] = maxi(16, win_size.x - (safe_rect.position.x + safe_rect.size.x))
	base["bottom"] = maxi(16, win_size.y - (safe_rect.position.y + safe_rect.size.y))
	return base
