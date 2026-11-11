class_name SlimiPersonalityManager
extends Node
## مدير الشخصية والعلاقة المتطورة لشخصية SLIMI:
## يضبط سمات الشخصية (اللطف، الفكاهة، الفضول، الهدوء، النشاط) ويتتبع أثر معاملة المستخدم بمرور الوقت.

signal personality_updated(traits: Dictionary)
signal relationship_milestone_reached(milestone_id: String, trust_level: float)

var warmth: float = 0.88
var humor: float = 0.82
var curiosity: float = 0.80
var talkativeness: float = 0.58 # متوازن وهادئ افتراضياً حتى لا يثرثر بإزعاج
var energy_trait: float = 0.78

var trust_score: float = 55.0 # 0..100
var kindness_streak: int = 0
var unlocked_milestones: Array[String] = []


func to_dict() -> Dictionary:
	return {
		"warmth": warmth,
		"humor": humor,
		"curiosity": curiosity,
		"talkativeness": talkativeness,
		"energy_trait": energy_trait,
		"trust_score": trust_score,
		"kindness_streak": kindness_streak,
		"unlocked_milestones": unlocked_milestones.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	warmth = clampf(float(data.get("warmth", 0.88)), 0.1, 1.0)
	humor = clampf(float(data.get("humor", 0.82)), 0.1, 1.0)
	curiosity = clampf(float(data.get("curiosity", 0.80)), 0.1, 1.0)
	talkativeness = clampf(float(data.get("talkativeness", 0.58)), 0.1, 1.0)
	energy_trait = clampf(float(data.get("energy_trait", 0.78)), 0.1, 1.0)
	trust_score = clampf(float(data.get("trust_score", 55.0)), 0.0, 100.0)
	kindness_streak = maxi(0, int(data.get("kindness_streak", 0)))
	unlocked_milestones.clear()
	for item in data.get("unlocked_milestones", []):
		unlocked_milestones.append(str(item))


func set_trait(trait_name: String, val: float) -> void:
	var c: float = clampf(val, 0.1, 1.0)
	match trait_name:
		"warmth": warmth = c
		"humor": humor = c
		"curiosity": curiosity = c
		"talkativeness": talkativeness = c
		"energy_trait": energy_trait = c
	personality_updated.emit(to_dict())


func register_user_treatment(treatment_kind: StringName) -> int:
	# يعيد الشعور المقترح بناءً على معاملة المستخدم وتراكم الثقة
	match treatment_kind:
		&"pet", &"kind_words", &"feed", &"play_win":
			kindness_streak += 1
			trust_score = clampf(trust_score + 2.4, 0.0, 100.0)
			_check_milestones()
			if trust_score >= 80.0 and kindness_streak >= 3:
				return SlimiEmotionManager.Emotion.AFFECTIONATE
			return SlimiEmotionManager.Emotion.GRATEFUL if treatment_kind == &"kind_words" else SlimiEmotionManager.Emotion.HAPPY
		&"squish":
			trust_score = clampf(trust_score + 0.4, 0.0, 100.0)
			return SlimiEmotionManager.Emotion.SURPRISED
		&"rapid_poke":
			kindness_streak = 0
			return SlimiEmotionManager.Emotion.FRUSTRATED
		&"startle":
			kindness_streak = 0
			trust_score = clampf(trust_score - 1.5, 15.0, 100.0)
			return SlimiEmotionManager.Emotion.SCARED
		&"ignored_mild":
			return SlimiEmotionManager.Emotion.BORED
	return SlimiEmotionManager.Emotion.CALM


func get_relationship_tier() -> String:
	if trust_score >= 85.0:
		return "best_friend"
	elif trust_score >= 65.0:
		return "close_pal"
	return "new_friend"


func _check_milestones() -> void:
	if trust_score >= 70.0 and not unlocked_milestones.has("warm_trust"):
		unlocked_milestones.append("warm_trust")
		relationship_milestone_reached.emit("warm_trust", trust_score)
	if trust_score >= 90.0 and not unlocked_milestones.has("best_jelly_companion"):
		unlocked_milestones.append("best_jelly_companion")
		relationship_milestone_reached.emit("best_jelly_companion", trust_score)
