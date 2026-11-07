extends Node
## مدير الصوتيات المركزي: يدير المؤثرات المرحة، أصوات سلايمي التعبيرية، والخلفية الهادئة بكفاءة عالية.

const POOL_SIZE: int = 6

var config: SoundBankConfig
var streams: Dictionary = {}
var ambient_enabled: bool = true

var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _ambient_player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var loaded_cfg: Resource = load("res://audio/sound_catalog.tres")
	if loaded_cfg is SoundBankConfig:
		config = loaded_cfg as SoundBankConfig
	else:
		config = SoundBankConfig.new()

	streams = ProceduralSoundBank.build_all_streams(config.sample_rate)

	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = &"SFX"
		add_child(p)
		_sfx_pool.append(p)

	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.bus = &"Ambient"
	_ambient_player.stream = streams.get(&"ambient_pad")
	_ambient_player.volume_db = -10.0
	add_child(_ambient_player)

	var settings: Dictionary = SaveManager.get_section("settings")
	set_bus_linear_volume("Master", float(settings.get("master_volume", 0.90)), false)
	set_bus_linear_volume("SFX", float(settings.get("sfx_volume", 0.90)), false)
	set_bus_linear_volume("Voice", float(settings.get("sfx_volume", 0.90)), false)
	set_ambient_enabled(bool(settings.get("ambient_enabled", true)), false)


func _exit_tree() -> void:
	if _ambient_player != null:
		_ambient_player.stop()
		_ambient_player.stream = null
	for p in _sfx_pool:
		if p != null:
			p.stop()
			p.stream = null
	streams.clear()


func has_sound(sound_id: StringName) -> bool:
	return streams.has(sound_id) and streams[sound_id] is AudioStreamWAV


func play_sfx(sound_id: StringName, pitch_shift: float = 0.0, volume_db: float = 0.0) -> bool:
	return _play_from_pool(sound_id, &"SFX", pitch_shift, volume_db)


func play_voice(sound_id: StringName, pitch_shift: float = 0.0, volume_db: float = 0.0) -> bool:
	return _play_from_pool(sound_id, &"Voice", pitch_shift, volume_db)


func _play_from_pool(sound_id: StringName, bus_name: StringName, pitch_shift: float, volume_db: float) -> bool:
	if not has_sound(sound_id) or _sfx_pool.is_empty():
		return false

	var player: AudioStreamPlayer = _sfx_pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _sfx_pool.size()

	var jitter: float = _rng.randf_range(-config.pitch_variation, config.pitch_variation)
	player.stop()
	player.bus = _resolve_bus(bus_name)
	player.stream = streams[sound_id]
	player.pitch_scale = clampf(1.0 + pitch_shift + jitter, 0.65, 1.55)
	player.volume_db = volume_db
	if DisplayServer.get_name() != "headless":
		player.play()
	return true


func _resolve_bus(bus_name: StringName) -> StringName:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	return &"Master"


func set_bus_linear_volume(bus_name: String, linear_val: float, persist: bool = true) -> void:
	var clamped: float = clampf(linear_val, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_mute(idx, clamped <= 0.005)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(clamped, 0.001)))

	if persist:
		if bus_name == "Master":
			SaveManager.update_section("settings", {"master_volume": clamped})
		elif bus_name == "SFX":
			SaveManager.update_section("settings", {"sfx_volume": clamped})


func set_ambient_enabled(enabled: bool, persist: bool = true) -> void:
	ambient_enabled = enabled
	if _ambient_player != null:
		if ambient_enabled and _ambient_player.stream != null and DisplayServer.get_name() != "headless":
			if not _ambient_player.playing:
				_ambient_player.play()
		else:
			_ambient_player.stop()
	if persist:
		SaveManager.update_section("settings", {"ambient_enabled": ambient_enabled})
