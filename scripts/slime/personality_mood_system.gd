class_name PersonalityMoodSystem
extends Node
## نظام الشخصية والمزاج والاحتياجات لسلايمي مع ربط مباشر بالذاكرة المحلية.

signal mood_changed(new_mood: int, mood_key: String)
signal stats_updated(stats: Dictionary)
signal thought_triggered(bubble_key: String)

enum Mood {
	HAPPY = 0,
	PLAYFUL = 1,
	CURIOUS = 2,
	SLEEPY = 3,
	HUNGRY = 4,
	AFFECTIONATE = 5,
	DIZZY = 6,
}

const MOOD_KEYS: Dictionary = {
	Mood.HAPPY: "mood_happy",
	Mood.PLAYFUL: "mood_playful",
	Mood.CURIOUS: "mood_curious",
	Mood.SLEEPY: "mood_sleepy",
	Mood.HUNGRY: "mood_hungry",
	Mood.AFFECTIONATE: "mood_affectionate",
	Mood.DIZZY: "mood_dizzy",
}

@export var personality: SlimePersonalityData

var memory := SlimeMemory.new()

var happiness: float = 82.0
var energy: float = 86.0
var fullness: float = 78.0
var affection: float = 25.0
var curiosity: float = 65.0

var current_mood: int = Mood.HAPPY
var is_sleeping: bool = false

var _dizzy_timer: float = 0.0
var _affectionate_timer: float = 0.0
var _curious_timer: float = 0.0
var _sync_accum: float = 0.0
var _persist_accum: float = 0.0


func _ready() -> void:
	if personality == null:
		var res: Resource = load("res://resources/slime_default_personality.tres")
		if res is SlimePersonalityData:
			personality = res as SlimePersonalityData
		else:
			personality = SlimePersonalityData.new()


func load_state(state_dict: Dictionary, memory_dict: Dictionary, offline_seconds: float = 0.0) -> void:
	happiness = clampf(float(state_dict.get("happiness", 82.0)), 0.0, 100.0)
	energy = clampf(float(state_dict.get("energy", 86.0)), 0.0, 100.0)
	fullness = clampf(float(state_dict.get("fullness", 78.0)), 0.0, 100.0)
	affection = clampf(float(state_dict.get("affection", 25.0)), 0.0, 100.0)
	curiosity = clampf(float(state_dict.get("curiosity", 65.0)), 0.0, 100.0)
	memory.from_dict(memory_dict)
	affection = maxf(affection, memory.bond_points)

	if offline_seconds > 60.0:
		var offline_hours: float = offline_seconds / 3600.0
		fullness = clampf(fullness - offline_hours * 5.5, 22.0, 100.0)
		happiness = clampf(happiness - offline_hours * 3.5, 30.0, 100.0)
		energy = clampf(energy + offline_hours * 8.0, 35.0, 100.0)

	_recompute_mood(true)
	stats_updated.emit(get_stats_snapshot())


func export_state() -> Dictionary:
	return {
		"happiness": snappedf(happiness, 0.1),
		"energy": snappedf(energy, 0.1),
		"fullness": snappedf(fullness, 0.1),
		"affection": snappedf(affection, 0.1),
		"curiosity": snappedf(curiosity, 0.1),
	}


func get_stats_snapshot() -> Dictionary:
	return {
		"happiness": happiness,
		"energy": energy,
		"fullness": fullness,
		"affection": memory.bond_points,
		"curiosity": curiosity,
		"mood": current_mood,
		"mood_key": get_mood_key(),
		"is_sleeping": is_sleeping,
	}


func get_mood_key() -> String:
	return str(MOOD_KEYS.get(current_mood, "mood_happy"))


func get_mood_tint() -> Color:
	match current_mood:
		Mood.AFFECTIONATE:
			return Color(1.0, 0.90, 0.94, 1.0)
		Mood.PLAYFUL:
			return Color(1.0, 0.97, 0.93, 1.0)
		Mood.SLEEPY:
			return Color(0.94, 0.93, 1.0, 1.0)
		Mood.HUNGRY:
			return Color(0.98, 0.94, 0.90, 1.0)
		Mood.DIZZY:
			return Color(0.96, 0.90, 1.0, 1.0)
		_:
			return Color(1.0, 1.0, 1.0, 1.0)


func _process(delta: float) -> void:
	var dt_min: float = delta / 60.0

	if _dizzy_timer > 0.0:
		_dizzy_timer = maxf(0.0, _dizzy_timer - delta)
	if _affectionate_timer > 0.0:
		_affectionate_timer = maxf(0.0, _affectionate_timer - delta)
	if _curious_timer > 0.0:
		_curious_timer = maxf(0.0, _curious_timer - delta)

	if is_sleeping:
		energy = clampf(energy + personality.sleep_energy_recovery_per_min * dt_min, 0.0, 100.0)
		fullness = clampf(fullness - personality.fullness_decay_per_min * 0.45 * dt_min, 0.0, 100.0)
		if energy >= 98.5:
			set_sleeping(false)
			thought_triggered.emit("bubble_wake")
	else:
		happiness = clampf(happiness - personality.happiness_decay_per_min * dt_min, 0.0, 100.0)
		energy = clampf(energy - personality.energy_decay_per_min * dt_min, 0.0, 100.0)
		fullness = clampf(fullness - personality.fullness_decay_per_min * dt_min, 0.0, 100.0)

	_recompute_mood(false)

	_sync_accum += delta
	if _sync_accum >= 0.4:
		_sync_accum = 0.0
		stats_updated.emit(get_stats_snapshot())

	_persist_accum += delta
	if _persist_accum >= 5.0:
		_persist_accum = 0.0
		sync_to_save_manager()


func register_poke(now_sec: float) -> Dictionary:
	if is_sleeping:
		set_sleeping(false)

	var rapid_count: int = memory.record_poke(now_sec)
	var became_dizzy: bool = rapid_count >= personality.rapid_poke_dizzy_threshold
	if became_dizzy:
		_dizzy_timer = 3.2
		happiness = clampf(happiness - 1.0, 0.0, 100.0)
		thought_triggered.emit("bubble_dizzy")
	else:
		happiness = clampf(happiness + personality.poke_happiness_gain, 0.0, 100.0)
		curiosity = clampf(curiosity + 3.0, 0.0, 100.0)
		if rapid_count == 2:
			thought_triggered.emit("bubble_poke")

	affection = memory.bond_points
	_recompute_mood(false)
	stats_updated.emit(get_stats_snapshot())
	_persist_to_save()
	return {"became_dizzy": became_dizzy, "mood": current_mood, "rapid_count": rapid_count}


func register_pet(strength: float = 1.0) -> void:
	if is_sleeping:
		# المسح اللطيف أثناء النوم يريح سلايمي أكثر دون إزعاجه
		happiness = clampf(happiness + 1.5 * strength, 0.0, 100.0)
		memory.record_pet(strength * 0.5)
		affection = memory.bond_points
		stats_updated.emit(get_stats_snapshot())
		_persist_to_save()
		return

	memory.record_pet(strength)
	affection = memory.bond_points
	happiness = clampf(happiness + personality.pet_happiness_gain * strength, 0.0, 100.0)
	_affectionate_timer = 4.5
	_dizzy_timer = maxf(0.0, _dizzy_timer - 1.0)
	_recompute_mood(false)
	thought_triggered.emit("bubble_pet")
	stats_updated.emit(get_stats_snapshot())
	_persist_to_save()


func register_feed() -> void:
	if is_sleeping:
		set_sleeping(false)
	memory.record_feed()
	affection = memory.bond_points
	fullness = clampf(fullness + personality.feed_fullness_gain, 0.0, 100.0)
	happiness = clampf(happiness + personality.feed_happiness_gain, 0.0, 100.0)
	energy = clampf(energy + 4.0, 0.0, 100.0)
	_recompute_mood(false)
	thought_triggered.emit("bubble_feed")
	stats_updated.emit(get_stats_snapshot())
	_persist_to_save()


func register_play() -> void:
	if is_sleeping:
		set_sleeping(false)
	memory.record_play()
	affection = memory.bond_points
	happiness = clampf(happiness + personality.play_happiness_gain, 0.0, 100.0)
	energy = clampf(energy - personality.play_energy_cost, 5.0, 100.0)
	curiosity = clampf(curiosity + 6.0, 0.0, 100.0)
	_recompute_mood(false)
	thought_triggered.emit("bubble_play")
	stats_updated.emit(get_stats_snapshot())
	_persist_to_save()


func register_curiosity_focus(duration: float = 3.0) -> void:
	if is_sleeping:
		return
	_curious_timer = maxf(_curious_timer, duration)
	curiosity = clampf(curiosity + 4.0, 0.0, 100.0)
	_recompute_mood(false)


func set_sleeping(sleeping: bool) -> void:
	if is_sleeping == sleeping:
		return
	is_sleeping = sleeping
	if is_sleeping:
		_dizzy_timer = 0.0
		thought_triggered.emit("bubble_sleep")
	_recompute_mood(false)
	stats_updated.emit(get_stats_snapshot())
	_persist_to_save()


func _recompute_mood(force_emit: bool) -> void:
	var next_mood: int = Mood.HAPPY

	if _dizzy_timer > 0.0:
		next_mood = Mood.DIZZY
	elif is_sleeping or energy < 24.0:
		next_mood = Mood.SLEEPY
	elif fullness < 28.0:
		next_mood = Mood.HUNGRY
	elif _affectionate_timer > 0.0:
		next_mood = Mood.AFFECTIONATE
	elif _curious_timer > 0.0:
		next_mood = Mood.CURIOUS
	elif happiness >= 76.0 and energy >= 60.0:
		next_mood = Mood.PLAYFUL
	else:
		next_mood = Mood.HAPPY

	if force_emit or next_mood != current_mood:
		current_mood = next_mood
		mood_changed.emit(current_mood, get_mood_key())


func sync_to_save_manager() -> void:
	_persist_to_save()


func _persist_to_save() -> void:
	if SaveManager != null:
		SaveManager.update_section("slime_state", export_state())
		SaveManager.update_section("memory", memory.to_dict())
