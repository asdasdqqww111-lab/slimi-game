class_name SlimeMemory
extends RefCounted
## الذاكرة المحلية البسيطة لسلايمي: تتذكر عادات تفاعل اللاعب ومستوى الألفة عبر الجلسات.

const RAPID_POKE_WINDOW_SEC: float = 2.2

var sessions_count: int = 1
var total_pokes: int = 0
var total_pets: int = 0
var total_feeds: int = 0
var total_plays: int = 0
var gentle_ratio: float = 1.0
var bond_points: float = 10.0
var last_interaction_type: String = "none"

var _recent_poke_times: Array[float] = []


func record_poke(now_sec: float) -> int:
	total_pokes += 1
	last_interaction_type = "poke"
	bond_points = clampf(bond_points + 0.35, 0.0, 100.0)

	_recent_poke_times.append(now_sec)
	while not _recent_poke_times.is_empty() and (now_sec - _recent_poke_times[0]) > RAPID_POKE_WINDOW_SEC:
		_recent_poke_times.pop_front()

	var is_rough: bool = _recent_poke_times.size() >= 5
	gentle_ratio = clampf(lerpf(gentle_ratio, 0.25 if is_rough else 0.75, 0.12), 0.0, 1.0)
	return _recent_poke_times.size()


func record_pet(amount: float = 1.0) -> void:
	total_pets += 1
	last_interaction_type = "pet"
	bond_points = clampf(bond_points + 1.2 * clampf(amount, 0.2, 2.0), 0.0, 100.0)
	gentle_ratio = clampf(lerpf(gentle_ratio, 1.0, 0.18), 0.0, 1.0)


func record_feed() -> void:
	total_feeds += 1
	last_interaction_type = "feed"
	bond_points = clampf(bond_points + 1.8, 0.0, 100.0)
	gentle_ratio = clampf(lerpf(gentle_ratio, 1.0, 0.15), 0.0, 1.0)


func record_play() -> void:
	total_plays += 1
	last_interaction_type = "play"
	bond_points = clampf(bond_points + 1.5, 0.0, 100.0)


func get_bond_tier_key() -> String:
	if bond_points >= 70.0:
		return "bond_best"
	if bond_points >= 32.0:
		return "bond_warm"
	return "bond_new"


func get_favorite_interaction_key() -> String:
	var best_key: String = "fav_pet"
	var best_score: int = total_pets
	if total_pokes > best_score:
		best_score = total_pokes
		best_key = "fav_poke"
	if total_feeds > best_score:
		best_score = total_feeds
		best_key = "fav_feed"
	if total_plays > best_score:
		best_score = total_plays
		best_key = "fav_play"
	return best_key


func to_dict() -> Dictionary:
	return {
		"sessions_count": sessions_count,
		"total_pokes": total_pokes,
		"total_pets": total_pets,
		"total_feeds": total_feeds,
		"total_plays": total_plays,
		"gentle_ratio": snappedf(gentle_ratio, 0.001),
		"bond_points": snappedf(bond_points, 0.01),
		"last_interaction_type": last_interaction_type,
	}


func from_dict(data: Dictionary) -> void:
	sessions_count = maxi(1, int(data.get("sessions_count", 1)))
	total_pokes = maxi(0, int(data.get("total_pokes", 0)))
	total_pets = maxi(0, int(data.get("total_pets", 0)))
	total_feeds = maxi(0, int(data.get("total_feeds", 0)))
	total_plays = maxi(0, int(data.get("total_plays", 0)))
	gentle_ratio = clampf(float(data.get("gentle_ratio", 1.0)), 0.0, 1.0)
	bond_points = clampf(float(data.get("bond_points", 10.0)), 0.0, 100.0)
	last_interaction_type = str(data.get("last_interaction_type", "none"))
