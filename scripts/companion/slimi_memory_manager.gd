class_name SlimiMemoryManager
extends Node
## مدير الذاكرة المحلية الآمنة والمحدودة لشخصية SLIMI:
## - يتذكر اسم المستخدم الاختياري، التفاعل والألعاب المفضلة، المحطات المهمة، آخر حالة، وتفضيلات الصوت واللغة.
## - يحفظ مقتطفات الدردشة فقط بموافقة المستخدم مع فلتر أمان يمنع حفظ أي كلمات سر أو مفاتيح سرية.
## - يدعم مسح الذاكرة بالكامل بضغطة زر في الإعدادات، ولا يعاتب المستخدم على الغياب مطلقاً.

signal memory_changed(snapshot: Dictionary)
signal memory_cleared

const MAX_SAVED_SNIPPETS: int = 16

var user_nickname: String = ""
var save_chat_memory_enabled: bool = true
var favorite_interaction: String = "pet"
var favorite_minigame: String = "emoji_face_match"
var last_emotion_id: int = SlimiEmotionManager.Emotion.HAPPY
var saved_chat_snippets: Array[String] = []
var minigame_wins: int = 0
var daily_challenge_completed_day: String = ""
var interaction_counts: Dictionary = {
	"pet": 0,
	"poke": 0,
	"squish": 0,
	"chat": 0,
	"minigame": 0,
	"joke": 0,
}


func load_from_save() -> void:
	var data: Dictionary = SaveManager.get_section("companion_memory")
	if data.is_empty():
		return
	user_nickname = str(data.get("user_nickname", "")).substr(0, 20)
	save_chat_memory_enabled = bool(data.get("save_chat_memory_enabled", true))
	favorite_interaction = str(data.get("favorite_interaction", "pet"))
	favorite_minigame = str(data.get("favorite_minigame", "emoji_face_match"))
	last_emotion_id = int(data.get("last_emotion_id", SlimiEmotionManager.Emotion.HAPPY))
	minigame_wins = maxi(0, int(data.get("minigame_wins", 0)))
	daily_challenge_completed_day = str(data.get("daily_challenge_completed_day", ""))

	saved_chat_snippets.clear()
	for item in data.get("saved_chat_snippets", []):
		var s: String = str(item)
		if not s.is_empty() and saved_chat_snippets.size() < MAX_SAVED_SNIPPETS:
			saved_chat_snippets.append(s)

	var counts_in: Variant = data.get("interaction_counts", {})
	if counts_in is Dictionary:
		for k in interaction_counts.keys():
			interaction_counts[k] = maxi(0, int((counts_in as Dictionary).get(k, 0)))


func persist() -> void:
	SaveManager.set_section("companion_memory", get_snapshot())
	memory_changed.emit(get_snapshot())


func get_snapshot() -> Dictionary:
	return {
		"user_nickname": user_nickname,
		"save_chat_memory_enabled": save_chat_memory_enabled,
		"favorite_interaction": favorite_interaction,
		"favorite_minigame": favorite_minigame,
		"last_emotion_id": last_emotion_id,
		"saved_chat_snippets": saved_chat_snippets.duplicate(),
		"minigame_wins": minigame_wins,
		"daily_challenge_completed_day": daily_challenge_completed_day,
		"interaction_counts": interaction_counts.duplicate(),
	}


func set_user_nickname(new_name: String) -> void:
	var cleaned: String = new_name.strip_edges().substr(0, 20)
	if _looks_sensitive(cleaned):
		return
	user_nickname = cleaned
	persist()


func record_interaction(kind: String) -> void:
	if interaction_counts.has(kind):
		interaction_counts[kind] = int(interaction_counts[kind]) + 1
	var best_k: String = favorite_interaction
	var best_v: int = -1
	for k in interaction_counts.keys():
		var v: int = int(interaction_counts[k])
		if v > best_v:
			best_v = v
			best_k = str(k)
	favorite_interaction = best_k
	persist()


func record_minigame_result(game_id: String, won: bool) -> void:
	favorite_minigame = game_id
	if won:
		minigame_wins += 1
	record_interaction("minigame")


func remember_chat_snippet(snippet: String) -> bool:
	if not save_chat_memory_enabled:
		return false
	var cleaned: String = snippet.strip_edges()
	if cleaned.is_empty() or _looks_sensitive(cleaned):
		return false
	var bounded_text: String = cleaned.substr(0, 90)
	saved_chat_snippets.append(bounded_text)
	while saved_chat_snippets.size() > MAX_SAVED_SNIPPETS:
		saved_chat_snippets.pop_front()
	persist()
	return true


func clear_all_memory() -> void:
	user_nickname = ""
	favorite_interaction = "pet"
	favorite_minigame = "emoji_face_match"
	last_emotion_id = SlimiEmotionManager.Emotion.HAPPY
	saved_chat_snippets.clear()
	minigame_wins = 0
	daily_challenge_completed_day = ""
	for k in interaction_counts.keys():
		interaction_counts[k] = 0
	persist()
	SaveManager.save_to_disk()
	memory_cleared.emit()


func _looks_sensitive(text: String) -> bool:
	var low: String = text.to_lower()
	for marker in ["sk-", "ai_key", "apikey", "password", "كلمة المرور", "كلمه السر", "token", "secret", "bearer "]:
		if low.contains(marker):
			return true
	return false
