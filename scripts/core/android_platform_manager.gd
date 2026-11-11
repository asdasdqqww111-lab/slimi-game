extends Node
## مدير تكامل نظام Android، دورة حياة التطبيق (الخلفية/المقدمة)، وSafe Areas والأداء:
## يستخدم عقدة Timer بدلاً من _process كل إطار لتوفير استهلاك المعالج،
## ويخفّض معدل الإطارات والنشاط الصوتي تلقائياً عند انتقال التطبيق إلى الخلفية.

signal back_requested
signal safe_area_updated(margins: Dictionary)
signal performance_updated(fps: float, frame_ms: float)
signal app_lifecycle_changed(is_paused: bool)

var haptics_enabled: bool = true
var current_fps: float = 60.0
var avg_frame_ms: float = 16.6
var is_app_paused: bool = false
var monitor_timer: Timer

var _last_window_size := Vector2i.ZERO


func _ready() -> void:
	var settings: Dictionary = SaveManager.get_section("settings")
	haptics_enabled = bool(settings.get("haptics_enabled", true))

	if DisplayServer.get_name() != "headless":
		if OS.get_name() == "Android":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_tree().set_quit_on_go_back(false)

	monitor_timer = Timer.new()
	monitor_timer.name = "PerfSafeAreaTimer"
	monitor_timer.wait_time = 0.5
	monitor_timer.autostart = true
	monitor_timer.timeout.connect(_on_monitor_timer_timeout)
	add_child(monitor_timer)


func _on_monitor_timer_timeout() -> void:
	var fps_now: float = float(Engine.get_frames_per_second())
	if fps_now > 0.0:
		current_fps = fps_now
		avg_frame_ms = 1000.0 / maxf(current_fps, 1.0)
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
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not is_app_paused:
				is_app_paused = true
				AudioServer.set_bus_mute(0, true)
				Engine.max_fps = 10 # خفض استهلاك البطارية في الخلفية
				app_lifecycle_changed.emit(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if is_app_paused:
				is_app_paused = false
				var s: Dictionary = SaveManager.get_section("settings")
				var master_vol: float = float(s.get("master_volume", 0.90))
				var muted: bool = bool(s.get("master_muted", false))
				AudioServer.set_bus_mute(0, muted or master_vol <= 0.005)
				Engine.max_fps = 30 if bool(s.get("battery_saver", false)) else 60
				app_lifecycle_changed.emit(false)


func simulate_back_button() -> void:
	back_requested.emit()


func set_haptics_enabled(enabled: bool, persist: bool = true) -> void:
	haptics_enabled = enabled
	if persist:
		SaveManager.update_section("settings", {"haptics_enabled": haptics_enabled})


func trigger_haptic(duration_ms: int = 16) -> void:
	if not haptics_enabled:
		return
	if OS.get_name() == "Android":
		Input.vibrate_handheld(clampi(duration_ms, 8, 60))


func get_virtual_keyboard_bottom_inset() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0
	var kb_px: int = DisplayServer.virtual_keyboard_get_height()
	if kb_px <= 0:
		return 0
	var win_h: float = maxf(float(DisplayServer.window_get_size().y), 1.0)
	var vp: Viewport = get_viewport()
	var vis_h: float = vp.get_visible_rect().size.y if vp != null else 1280.0
	var scale_y: float = maxf(win_h / maxf(vis_h, 1.0), 0.5)
	return clampi(int(round(float(kb_px) / scale_y)), 0, 620)


func get_safe_area_margins() -> Dictionary:
	var base := {"left": 14, "top": 14, "right": 14, "bottom": 16}
	if DisplayServer.get_name() == "headless":
		return base

	var win_size: Vector2i = DisplayServer.window_get_size()
	var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
	if win_size.x <= 0 or win_size.y <= 0 or safe_rect.size.x <= 0 or safe_rect.size.y <= 0:
		return base

	var vp: Viewport = get_viewport()
	var vis_size: Vector2 = vp.get_visible_rect().size if vp != null else Vector2(720.0, 1280.0)
	var scale_x: float = maxf(float(win_size.x) / maxf(vis_size.x, 1.0), 0.5)
	var scale_y: float = maxf(float(win_size.y) / maxf(vis_size.y, 1.0), 0.5)

	var raw_left: int = int(round(float(safe_rect.position.x) / scale_x))
	var raw_top: int = int(round(float(safe_rect.position.y) / scale_y))
	var raw_right: int = int(round(float(win_size.x - (safe_rect.position.x + safe_rect.size.x)) / scale_x))
	var raw_bottom: int = int(round(float(win_size.y - (safe_rect.position.y + safe_rect.size.y)) / scale_y))

	base["left"] = clampi(maxi(14, raw_left), 14, 64)
	base["top"] = clampi(maxi(14, raw_top), 14, 72)
	base["right"] = clampi(maxi(14, raw_right), 14, 64)
	base["bottom"] = clampi(maxi(16, raw_bottom), 16, 68)
	return base
