extends Node
## نظام الحفظ والاستعادة المحلي الذري (Atomic Local Save & Load) بدون الحاجة للإنترنت:
## يدعم حفظ واستعادة حالة SLIMI، الذاكرة، الإعدادات، تفضيلات الواجهة، وتخصيص المظهر بأمان تام.

signal game_saved(path: String)
signal game_loaded(data: Dictionary)
signal settings_reset

const SCHEMA_VERSION: int = 2
const DEFAULT_SAVE_PATH: String = "user://slimi_save.json"
const AUTOSAVE_INTERVAL_SEC: float = 30.0
const MAX_OFFLINE_SECONDS: float = 43200.0 # 12 ساعة كحد أقصى لتأثير الغياب اللطيف

var save_path: String = DEFAULT_SAVE_PATH
var current_data: Dictionary = {}
var last_offline_seconds: float = 0.0
var is_first_launch: bool = true

var _autosave_accum: float = 0.0
var _dirty: bool = false


func _ready() -> void:
	current_data = create_default_data()
	load_from_disk()


func _process(delta: float) -> void:
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL_SEC:
		_autosave_accum = 0.0
		if _dirty:
			save_to_disk()


func _notification(what: int) -> void:
	if what in [
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_CLOSE_REQUEST,
	]:
		if _dirty:
			save_to_disk()


func create_default_data() -> Dictionary:
	return {
		"version": SCHEMA_VERSION,
		"last_timestamp": int(Time.get_unix_time_from_system()),
		"slime_state": {
			"happiness": 82.0,
			"energy": 86.0,
			"fullness": 78.0,
			"affection": 25.0,
			"curiosity": 65.0,
		},
		"memory": {
			"sessions_count": 1,
			"total_pokes": 0,
			"total_pets": 0,
			"total_feeds": 0,
			"total_plays": 0,
			"gentle_ratio": 1.0,
			"bond_points": 10.0,
			"last_interaction_type": "none",
		},
		"settings": {
			"quality_preset": 1,
			"master_volume": 0.90,
			"sfx_volume": 0.90,
			"voice_volume": 0.92,
			"expressive_sounds_enabled": true,
			"master_muted": false,
			"ambient_enabled": true,
			"battery_saver": false,
			"haptics_enabled": true,
			"show_fps": false,
			"splash_sound_enabled": true,
			"care_notifications_enabled": true,
			"locale": "ar",
		},
		"ui_preferences": {
			"onboarding_completed": false,
			"dark_mode": false,
			"accent_palette": "sakura",
			"text_scale_index": 1,
			"reduce_motion": false,
			"room_backdrop": "pastel_dream",
			"retain_interaction_stats": true,
		},
		"customization": {
			"slimi_name": "",
			"gel_preset": "sakura_pink",
			"beanie_preset": "sunny_yellow",
			"show_flower": true,
			"show_heart_pin": true,
			"show_star_charm": true,
			"movement_speed_scale": 1.0,
		},
	}


func mark_dirty() -> void:
	_dirty = true


func set_section(section: String, values: Dictionary) -> void:
	current_data[section] = values.duplicate(true)
	_dirty = true


func update_section(section: String, values: Dictionary) -> void:
	if not current_data.has(section) or typeof(current_data[section]) != TYPE_DICTIONARY:
		current_data[section] = {}
	for k in values.keys():
		current_data[section][k] = values[k]
	_dirty = true


func get_section(section: String) -> Dictionary:
	var defaults: Dictionary = create_default_data()
	var base_sec: Dictionary = {}
	if defaults.has(section) and typeof(defaults[section]) == TYPE_DICTIONARY:
		base_sec = (defaults[section] as Dictionary).duplicate(true)
	var val: Variant = current_data.get(section, {})
	if typeof(val) == TYPE_DICTIONARY:
		for k in (val as Dictionary).keys():
			base_sec[k] = val[k]
	return base_sec


func reset_settings_to_default() -> void:
	var defaults: Dictionary = create_default_data()
	var was_onboarded: bool = bool(get_section("ui_preferences").get("onboarding_completed", false))
	current_data["settings"] = (defaults["settings"] as Dictionary).duplicate(true)
	var ui_def: Dictionary = (defaults["ui_preferences"] as Dictionary).duplicate(true)
	ui_def["onboarding_completed"] = was_onboarded
	current_data["ui_preferences"] = ui_def
	_dirty = true
	save_to_disk()
	settings_reset.emit()


func clear_temp_cache() -> int:
	var removed_files: int = 0
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.list_dir_begin()
		var fname: String = dir.get_next()
		while not fname.is_empty():
			if not dir.current_is_dir() and (fname.ends_with(".tmp") or fname.ends_with(".cache")):
				if dir.remove(fname) == OK:
					removed_files += 1
			fname = dir.get_next()
		dir.list_dir_end()
	return removed_files


func save_to_disk(custom_path: String = "") -> bool:
	var target: String = save_path if custom_path.is_empty() else custom_path
	current_data["version"] = SCHEMA_VERSION
	current_data["last_timestamp"] = int(Time.get_unix_time_from_system())

	var payload: String = JSON.stringify(current_data, "\t")
	var tmp_path: String = target + ".tmp"
	var bak_path: String = target + ".bak"

	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: تعذّر فتح ملف الحفظ المؤقت: %s" % tmp_path)
		return false
	f.store_string(payload)
	f.flush()
	f = null

	if FileAccess.file_exists(target):
		DirAccess.copy_absolute(
			ProjectSettings.globalize_path(target),
			ProjectSettings.globalize_path(bak_path)
		)

	var rename_err: Error = DirAccess.rename_absolute(
		ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(target)
	)
	if rename_err != OK:
		var direct := FileAccess.open(target, FileAccess.WRITE)
		if direct == null:
			return false
		direct.store_string(payload)
		direct.flush()
		direct = null
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))

	_dirty = false
	game_saved.emit(target)
	return true


func load_from_disk(custom_path: String = "") -> bool:
	var target: String = save_path if custom_path.is_empty() else custom_path
	var bak_path: String = target + ".bak"

	var parsed: Dictionary = _try_read_json(target)
	if parsed.is_empty() and FileAccess.file_exists(bak_path):
		parsed = _try_read_json(bak_path)

	if parsed.is_empty():
		is_first_launch = true
		last_offline_seconds = 0.0
		current_data = create_default_data()
		return false

	is_first_launch = false
	var defaults: Dictionary = create_default_data()
	_merge_with_defaults(parsed, defaults)
	current_data = defaults

	var now_ts: int = int(Time.get_unix_time_from_system())
	var saved_ts: int = int(current_data.get("last_timestamp", now_ts))
	last_offline_seconds = clampf(float(maxi(0, now_ts - saved_ts)), 0.0, MAX_OFFLINE_SECONDS)

	if custom_path.is_empty():
		var mem: Dictionary = current_data.get("memory", {})
		mem["sessions_count"] = int(mem.get("sessions_count", 1)) + 1
		current_data["memory"] = mem
		_dirty = true

	game_loaded.emit(current_data.duplicate(true))
	return true


func _try_read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f = null
	if raw.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(raw) != OK:
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data as Dictionary


func _merge_with_defaults(source: Dictionary, target_defaults: Dictionary) -> void:
	for key in source.keys():
		if not target_defaults.has(key):
			if typeof(source[key]) == TYPE_DICTIONARY:
				target_defaults[key] = (source[key] as Dictionary).duplicate(true)
			else:
				target_defaults[key] = source[key]
			continue
		if typeof(target_defaults[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_merge_with_defaults(source[key], target_defaults[key])
		else:
			target_defaults[key] = source[key]
