extends Node
## نظام الحفظ والاستعادة المحلي الذري (Atomic Local Save & Load) بدون الحاجة للإنترنت.

signal game_saved(path: String)
signal game_loaded(data: Dictionary)

const SCHEMA_VERSION: int = 1
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
			"ambient_enabled": true,
			"battery_saver": false,
			"haptics_enabled": true,
			"show_fps": false,
			"locale": "ar",
		}
	}


func mark_dirty() -> void:
	_dirty = true


func update_section(section: String, values: Dictionary) -> void:
	if not current_data.has(section) or typeof(current_data[section]) != TYPE_DICTIONARY:
		current_data[section] = {}
	for k in values.keys():
		current_data[section][k] = values[k]
	_dirty = true


func get_section(section: String) -> Dictionary:
	var val: Variant = current_data.get(section, {})
	if typeof(val) == TYPE_DICTIONARY:
		return (val as Dictionary).duplicate(true)
	return {}


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
		# مسار بديل آمن إذا كان النظام يمنع الاستبدال المباشر
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

	# زيادة عدّاد الجلسات عند فتح اللعبة من ملف محفوظ
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
	for key in target_defaults.keys():
		if not source.has(key):
			continue
		if typeof(target_defaults[key]) == TYPE_DICTIONARY and typeof(source[key]) == TYPE_DICTIONARY:
			_merge_with_defaults(source[key], target_defaults[key])
		else:
			target_defaults[key] = source[key]
