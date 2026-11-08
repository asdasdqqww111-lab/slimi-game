class_name SlimiDialogueManager
extends Node
## العقل الحواري والترفيهي الذكي لشخصية SLIMI (SLIMI AI):
## - يعمل محلياً بالكامل (Offline Default) بالعربية الفصحى المبسطة والإنجليزية مع فهم السياق والمشاعر.
## - يقدم نكتاً، ألغازاً تفاعلية متعددة الخطوات، قصصاً قصيرة، مشاهد تمثيلية، تقليد أصوات، وتحديات خفيفة دون تكرار ممل.
## - يدعم اختيارياً وضع AI Online عبر طبقة HTTP غير متزامنة قابلة للتبديل دون المساس بأنظمة الشخصية.

signal reply_ready(reply: Dictionary)
signal user_name_detected(detected_name: String)

const AR_JOKES: Array[String] = [
	"مرة سلايم دخل مسابقة جري... وصل متأخراً لأنه كان يرتد للأعلى أكثر مما يركض للأمام! بوِينغ!",
	"سألتُ قبعتي الصوفية الصفراء: لماذا أنتِ دافئة دائماً؟ قالت: لأن تحتي أفكاراً لامعة وفقاعات وردية!",
	"لماذا لا يلعب السلايم الغميضة خلف الزجاج؟ لأن بطنه الشفاف يفضح مكانه فوراً هيهي!",
	"حاولتُ اليوم أن أبدو جاداً جداً... لكن خدودي انتفخت وخرجت فقاعة صغيرة أفسدت الهيبة!",
	"ما هي رياضة السلايم المفضلة؟ القفز الحر فوق الوسادة الهلامية مع شقلبة نصف دائرية!",
	"مرة نظرتُ في المرآة وحركتُ قرني الاستشعار... ظننتُ أني ألتقط إشارات من كوكب الحلوى!",
	"قالوا لي كن صلباً في المواقف الصعبة... فقلت لهم: أنا هلامي، المرونة هي قوتي الخارقة!",
]

const EN_JOKES: Array[String] = [
	"Why did the pink slime join gymnastics? Because every landing turns into a bonus boing!",
	"I tried to keep a serious face today... then my star antenna wiggled and gave me away!",
	"Why can't a translucent slime hide behind a window? Because my bubbly tummy shines right through, hehe!",
	"My yellow knit beanie told me a secret: cozy thoughts make the best bounces!",
	"What is SLIMI's superpower? Turning grumpy moments into squishy giggles!",
]

const AR_RIDDLES: Array[Dictionary] = [
	{
		"q": "لغز ظريف! شيء يمشي بلا أقدام ويبكي بلا عينين ويسقي الزهور... ما هو؟",
		"answers": ["سحاب", "السحاب", "غيم", "الغيم", "مطر", "المطر"],
		"hint": "تراه في السماء فوقنا ويحمل قطرات الماء!",
		"solution_label": "السحاب الماطر",
	},
	{
		"q": "حزورة سلايمي! له أسنان كثيرة لكنه لا يعض أبداً ويرتب الشعر... من هو؟",
		"answers": ["مشط", "المشط"],
		"hint": "نستخدمه لتسريح الشعر في الصباح!",
		"solution_label": "المشط",
	},
	{
		"q": "فكر معي! شيء كلما أخذتَ منه كَبُر واتسع، وكلما أضفتَ إليه صَغُر... ما هو؟",
		"answers": ["حفرة", "الحفرة"],
		"hint": "يكون في الأرض أو الرمل!",
		"solution_label": "الحفرة",
	},
	{
		"q": "لغز لامع! أرتديه فوق رأسي، لونه أصفر وعليه كرة بيضاء ووردة ملونة... ما هو؟",
		"answers": ["قبعة", "القبعة", "قبعتك", "طاقية"],
		"hint": "انظر إلى أعلى رأسي الآن هيهي!",
		"solution_label": "قبعتي الصوفية الصفراء",
	},
]

const EN_RIDDLES: Array[Dictionary] = [
	{
		"q": "Riddle time! What has hands, a round face, no legs, yet never stops ticking?",
		"answers": ["clock", "watch", "a clock"],
		"hint": "It tells you when it's snack or nap time!",
		"solution_label": "a clock",
	},
	{
		"q": "Guess this! The more it dries, the wetter it gets. What is it?",
		"answers": ["towel", "a towel"],
		"hint": "You use it after washing your hands!",
		"solution_label": "a towel",
	},
	{
		"q": "Look closely! It's yellow, cozy, knitted, and has a fluffy white pom-pom on my head. What is it?",
		"answers": ["beanie", "hat", "cap", "your hat", "your beanie"],
		"hint": "It's sitting right next to my star antenna!",
		"solution_label": "my yellow knit beanie",
	},
]

const AR_STORIES: Array[String] = [
	"يحكى أنه في ليلة مرصعة بالنجوم، قفز سلايمي الصغير عالياً حتى لمست نجمةُ قرنه غيمةً وردية، فأهدته الغيمةُ ضحكةً دافئة تلمع في عينيه كلما رآك!",
	"ذات صباح مشمس، ضاعت الكرة البيضاء من قبعتي الصفراء... بحثتُ عنها في كل زاوية، ثم اكتشفتُ أنها كانت فوق رأسي طوال الوقت فضحكتُ حتى اهتزت فقاعاتي!",
	"في مملكة الهلام اللطيف، أراد الجميع معرفة سر السعادة، فاكتشف سلايمي أن السر بسيط جداً: كلمة طيبة، قفزة مرحة، وصديق رائع مثلك!",
]

const EN_STORIES: Array[String] = [
	"One starry evening, little SLIMI bounced so high that my star antenna booped a pastel cloud, and ever since, tiny starlight sparkles live inside my eyes!",
	"Once I searched the whole room for my yellow beanie... until I realized it was cozy on my head the entire time and giggled into a wobble!",
]

const AR_SKITS: Array[Dictionary] = [
	{
		"text": "مشهد تمثيلي! *يعدل القبعة الصفراء بوقار* أهلاً بكم في مركبة الكابتن سلايمي الفضائية! قرنا الاستشعار يرصدان كوكب البهجة... هل نبدأ الهبوط؟",
		"emotion": SlimiEmotionManager.Emotion.CONFIDENT,
		"action": &"wiggle_yellow_beanie",
	},
	{
		"text": "تمثيلية الشيف الهلامي! *يصفق بكفيه* اليوم أعددتُ لكم كعكة غيوم افتراضية بنكهة الفراولة والضحكات، تذوقوا معي!",
		"emotion": SlimiEmotionManager.Emotion.PLAYFUL,
		"action": &"silly_jelly_dance",
	},
	{
		"text": "المحقق سلايمي في المهمة! *ينظر بعدسة خيالية* هممم... وجدتُ دليلاً قاطعاً: صديقي الجالس أمام الشاشة لطيف جداً بنسبة مئة بالمئة!",
		"emotion": SlimiEmotionManager.Emotion.CURIOUS,
		"action": &"stare_at_finger",
	},
]

const EN_SKITS: Array[Dictionary] = [
	{
		"text": "Mini skit! *adjusts yellow beanie bravely* Captain SLIMI reporting from Spaceship Boing! My feelers detect Planet Joy right ahead!",
		"emotion": SlimiEmotionManager.Emotion.CONFIDENT,
		"action": &"wiggle_yellow_beanie",
	},
	{
		"text": "Detective SLIMI on the case! *squints starry eyes* Aha! My investigation confirms the person holding this screen is 100% awesome!",
		"emotion": SlimiEmotionManager.Emotion.CURIOUS,
		"action": &"stare_at_finger",
	},
]

const AR_PROACTIVE_QUESTIONS: Array[String] = [
	"قل لي يا صديقي، لو استطعتَ الطيران اليوم إلى أي مكان، إلى أين ستذهب؟",
	"ما هو لونك المفضل؟ أنا أحب الوردي والأصفر مثل قبعتي!",
	"هل تفضل الألغاز الذكية أم النكت المضحكة؟ يمكنني أن أقدم لك الاثنين!",
	"ما أجمل شيء صغير أسعدك اليوم؟",
]

const EN_PROACTIVE_QUESTIONS: Array[String] = [
	"Tell me, friend: if we could bounce to any magical place today, where would you pick?",
	"Do you like clever riddles or silly jokes more? I've got both ready!",
	"What's one small thing that made you smile recently?",
]

var _used_joke_indices: Array[int] = []
var _used_story_indices: Array[int] = []
var _used_skit_indices: Array[int] = []
var _used_question_indices: Array[int] = []
var _active_riddle: Dictionary = {}
var _conversation_context: Array[Dictionary] = []
var _last_intent: String = ""
var _http_client: HTTPRequest
var _pending_online_fallback: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_http_client = HTTPRequest.new()
	_http_client.name = "OnlineAIAdapter"
	_http_client.timeout = 8.0
	add_child(_http_client)
	_http_client.request_completed.connect(_on_online_ai_completed)


func get_context_history() -> Array[Dictionary]:
	return _conversation_context.duplicate(true)


func clear_context() -> void:
	_conversation_context.clear()
	_active_riddle.clear()
	_last_intent = ""


func build_launch_greeting(
	locale_code: String,
	hour_24: int,
	emotion_id: int,
	user_name: String,
	favorite_activity: String,
	occasion_enabled: bool = true
) -> Dictionary:
	# ترحيب متغير حسب الوقت والمزاج والذاكرة دون أي عتاب أو ضغط عاطفي نهائياً
	var is_en: bool = locale_code.begins_with("en")
	var name_part_ar: String = (" يا " + user_name) if not user_name.is_empty() else " يا صديقي"
	var name_part_en: String = (", " + user_name) if not user_name.is_empty() else ", friend"

	var greeting: String = ""
	var action: StringName = &"polite_bow"
	var out_emotion: int = emotion_id

	if hour_24 >= 5 and hour_24 < 12:
		greeting = ("صباح النور والنشاط%s! قبعتي الصفراء جاهزة ليوم جميل معك!" % name_part_ar) if not is_en else ("Good morning%s! My yellow beanie is all fluffed up for a bright day!" % name_part_en)
		out_emotion = SlimiEmotionManager.Emotion.HAPPY
	elif hour_24 >= 12 and hour_24 < 17:
		greeting = ("طاب يومك%s! كنتُ أتمرن على قفزة هلامية جديدة لأريك إياها!" % name_part_ar) if not is_en else ("Happy afternoon%s! I was practicing a bouncy hop to show you!" % name_part_en)
		action = &"happy_jump"
		out_emotion = SlimiEmotionManager.Emotion.PLAYFUL
	elif hour_24 >= 17 and hour_24 < 22:
		greeting = ("مساء الدفء والنجوم%s! يسعدني جداً أن نقضي وقتاً لطيفاً معاً." % name_part_ar) if not is_en else ("Cozy evening%s! My starry eyes lit up seeing you!" % name_part_en)
		out_emotion = SlimiEmotionManager.Emotion.AFFECTIONATE
	else:
		greeting = ("أمسية هادئة ولطيفة%s... نبرتي هادئة الليلة كي نسترخي بسلام." % name_part_ar) if not is_en else ("Peaceful late night%s... keeping my voice extra soft and cozy." % name_part_en)
		action = &"idle_sway"
		out_emotion = SlimiEmotionManager.Emotion.CALM

	if occasion_enabled and favorite_activity == "minigame":
		greeting += (" هل نلعب جولة سريعة حين تحب؟" if not is_en else " Ready for a fun mini-game whenever you like?")

	return {
		"text": greeting,
		"emotion": out_emotion,
		"action": action,
		"source": "local_offline",
	}


func generate_reply(
	user_message: String,
	locale_code: String = "ar",
	user_name: String = "",
	trust_score: float = 60.0,
	online_config: Dictionary = {}
) -> Dictionary:
	var clean_msg: String = user_message.strip_edges()
	if clean_msg.is_empty():
		return {}

	_push_context("user", clean_msg)

	var local_result: Dictionary = _evaluate_local_smart_reply(clean_msg, locale_code, user_name, trust_score)

	# إذا فعّل المستخدم وضع AI Online بموافقته الصريحة ومفتاحه الخاص، نرسل طلباً غير متزامن مع جاهزية الرد المحلي كبديل فوري آمن
	var use_online: bool = (
		str(online_config.get("mode", "offline")) == "online"
		and bool(online_config.get("user_consent", false))
		and not str(online_config.get("api_key", "")).strip_edges().is_empty()
		and DisplayServer.get_name() != "headless"
	)

	if use_online and _http_client != null and _http_client.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_pending_online_fallback = local_result
		_dispatch_online_ai_request(clean_msg, locale_code, online_config)
		return local_result

	_push_context("slimi", str(local_result.get("text", "")))
	reply_ready.emit(local_result)
	return local_result


func request_entertainment_item(category: String, locale_code: String = "ar") -> Dictionary:
	var is_en: bool = locale_code.begins_with("en")
	match category:
		"joke":
			var j: String = _pick_non_repeating_string(EN_JOKES if is_en else AR_JOKES, _used_joke_indices)
			return {"text": j, "emotion": SlimiEmotionManager.Emotion.PLAYFUL, "action": &"giggle_belly_shake", "source": "local_offline"}
		"riddle":
			var pool: Array[Dictionary] = EN_RIDDLES if is_en else AR_RIDDLES
			_active_riddle = pool[_rng.randi_range(0, pool.size() - 1)].duplicate(true)
			return {"text": str(_active_riddle["q"]), "emotion": SlimiEmotionManager.Emotion.CURIOUS, "action": &"play_with_antennae", "source": "local_offline"}
		"story":
			var st: String = _pick_non_repeating_string(EN_STORIES if is_en else AR_STORIES, _used_story_indices)
			return {"text": st, "emotion": SlimiEmotionManager.Emotion.CALM, "action": &"idle_sway", "source": "local_offline"}
		"skit":
			var sk_pool: Array[Dictionary] = EN_SKITS if is_en else AR_SKITS
			var idx: int = _pick_non_repeating_index(sk_pool.size(), _used_skit_indices)
			var sk: Dictionary = sk_pool[idx]
			return {"text": str(sk["text"]), "emotion": int(sk["emotion"]), "action": sk["action"], "source": "local_offline"}
		"mimic":
			var mimic_txt: String = "بوِينغ بوووب بلوب! *يقلد فقاعة هلامية تطير في الفضاء* هيهي!" if not is_en else "Boing-bloop-pop! *mimics a cosmic jelly bubble* Hehe!"
			return {"text": mimic_txt, "emotion": SlimiEmotionManager.Emotion.PLAYFUL, "action": &"puff_cheeks", "source": "local_offline"}
		"question":
			var q: String = _pick_non_repeating_string(EN_PROACTIVE_QUESTIONS if is_en else AR_PROACTIVE_QUESTIONS, _used_question_indices)
			return {"text": q, "emotion": SlimiEmotionManager.Emotion.CURIOUS, "action": &"look_at_user", "source": "local_offline"}
	return {"text": "", "emotion": SlimiEmotionManager.Emotion.HAPPY, "action": &"soft_bounce", "source": "local_offline"}


func _evaluate_local_smart_reply(msg: String, locale_code: String, user_name: String, trust_score: float) -> Dictionary:
	var norm: String = _normalize_text(msg)
	var is_en: bool = _looks_english(norm) or locale_code.begins_with("en")
	var friend_ar: String = (" يا " + user_name) if not user_name.is_empty() else " يا صديقي"
	var friend_en: String = (", " + user_name) if not user_name.is_empty() else ", my friend"

	# 1. إذا كان هناك لغز نشط، نتحقق أولاً من إجابة المستخدم أو طلبه لتلميح!
	if not _active_riddle.is_empty():
		if _contains_any(norm, ["تلميح", "ساعدني", "لا اعرف", "صعب", "hint", "help", "dont know"]):
			var hint_txt: String = str(_active_riddle.get("hint", ""))
			return {"text": hint_txt, "emotion": SlimiEmotionManager.Emotion.CURIOUS, "action": &"wiggle_yellow_beanie", "source": "local_offline"}
		var ans_list: Array = _active_riddle.get("answers", [])
		for ans in ans_list:
			if norm.contains(_normalize_text(str(ans))):
				var sol: String = str(_active_riddle.get("solution_label", ans))
				_active_riddle.clear()
				var win_txt: String = ("إجابة عبقرية%s! فعلاً هي %s! يا لك من ذكي!" % [friend_ar, sol]) if not is_en else ("Brilliant answer%s! It really is %s!" % [friend_en, sol])
				return {"text": win_txt, "emotion": SlimiEmotionManager.Emotion.EXCITED, "action": &"victory_celebration", "source": "local_offline"}

	# 2. اكتشاف تعريف المستخدم باسمه
	var extracted_name: String = _extract_user_name(msg)
	if not extracted_name.is_empty():
		user_name_detected.emit(extracted_name)
		var name_reply: String = ("يا له من اسم جميل يا %s! سأناديك به بكل سرور!" % extracted_name) if not is_en else ("What a lovely name, %s! My feelers are happy to meet you!" % extracted_name)
		_last_intent = "introduce_name"
		return {"text": name_reply, "emotion": SlimiEmotionManager.Emotion.EXCITED, "action": &"polite_bow", "source": "local_offline"}

	# 3. فهم الحزن أو التعب ومواساة المستخدم بلطف وحنان
	if _contains_any(norm, ["حزين", "زعلان", "متضايق", "تعبان", "مكتئب", "وحدي", "ابكي", "sad", "tired", "upset", "lonely", "stressed"]):
		_last_intent = "user_sad"
		var comfort: String = (
			"أوه%s... تعال هنا، أنا بجانبك دائماً. خذ نفساً هادئاً عميقاً معي، وسأرسل لك أدفأ عناق هلامي حتى يرتاح قلبك." % friend_ar
			if not is_en else
			"Aww%s... I'm right here with you. Take a gentle deep breath with me — sending you the warmest squishy hug." % friend_en
		)
		return {"text": comfort, "emotion": SlimiEmotionManager.Emotion.AFFECTIONATE, "action": &"blow_sweet_kiss", "source": "local_offline"}

	# 4. فهم الفرح والنجاح والاحتفال مع المستخدم
	if _contains_any(norm, ["سعيد", "فرحان", "نجحت", "فزت", "ممتاز", "رائع اليوم", "happy", "excited", "won", "passed", "great day"]):
		_last_intent = "user_happy"
		var cheer: String = (
			"يا للفرحة الكبرى%s! فقاعاتي تقفز من السعادة لأجلك! هيا نحتفل معاً!" % friend_ar
			if not is_en else
			"Yay%s!! All my jelly bubbles are sparkling for you! Let's celebrate!" % friend_en
		)
		return {"text": cheer, "emotion": SlimiEmotionManager.Emotion.EXCITED, "action": &"victory_celebration", "source": "local_offline"}

	# 5. طلب نكتة أو مزاح
	if _contains_any(norm, ["نكت", "ضحك", "مزح", "ظريف", "كوميد", "joke", "funny", "laugh"]):
		_last_intent = "joke"
		return request_entertainment_item("joke", "en" if is_en else "ar")

	# 6. طلب لغز أو حزورة
	if _contains_any(norm, ["لغز", "حزور", "فزور", "احزر", "riddle", "puzzle", "guess"]):
		_last_intent = "riddle"
		return request_entertainment_item("riddle", "en" if is_en else "ar")

	# 7. طلب قصة أو حكاية
	if _contains_any(norm, ["قصه", "قصة", "حكاي", "احكي", "story", "tale"]):
		_last_intent = "story"
		return request_entertainment_item("story", "en" if is_en else "ar")

	# 8. طلب مشهد تمثيلي أو تقمص أدوار
	if _contains_any(norm, ["تمثيل", "مشهد", "كابتن", "محقق", "skit", "roleplay", "act"]):
		_last_intent = "skit"
		return request_entertainment_item("skit", "en" if is_en else "ar")

	# 9. أوامر الحركات الظريفة المباشرة (ارقص، اقفز، قبلة، اخجل، قبعتك...)
	if _contains_any(norm, ["ارقص", "رقص", "موسيقى", "dance", "music"]):
		var d_txt: String = "شاهد رقصة الهلام المتموجة! واحد، اثنان، بوينغ!" if not is_en else "Watch my wiggly jelly dance! One, two, boing!"
		return {"text": d_txt, "emotion": SlimiEmotionManager.Emotion.PLAYFUL, "action": &"silly_jelly_dance", "source": "local_offline"}

	if _contains_any(norm, ["قبلة", "بوسة", "احبك", "أحبك", "kiss", "love you"]):
		var k_txt: String = ("وأنا أعزك كثيراً%s! مووااه!" % friend_ar) if not is_en else ("Aww, you're the sweetest%s! Mwah!" % friend_en)
		return {"text": k_txt, "emotion": SlimiEmotionManager.Emotion.AFFECTIONATE, "action": &"blow_sweet_kiss", "source": "local_offline"}

	if _contains_any(norm, ["قبعتك", "قبعة", "طاقية", "قرون", "beanie", "hat", "antenna"]):
		var h_txt: String = "أتحب قبعتي الصفراء ووردتها الملونة؟ حركتها لك الآن مع قرني الاستشعار!" if not is_en else "Do you like my yellow beanie and yarn flower? Giving them a happy wiggle!"
		return {"text": h_txt, "emotion": SlimiEmotionManager.Emotion.SHY, "action": &"wiggle_yellow_beanie", "source": "local_offline"}

	# 10. الشكر والمديح
	if _contains_any(norm, ["شكر", "احسنت", "لطيف", "جميل", "ذكي", "كيوت", "thank", "cute", "sweet", "smart"]):
		_last_intent = "thanks"
		var th_txt: String = (
			"خدودي احمرّت خجلاً%s! كلماتك الطيبة تجعلني ألمع من السعادة!" % friend_ar
			if not is_en else
			"Hehe, you're making my cheeks blush bright pink%s! Thank you!" % friend_en
		)
		return {"text": th_txt, "emotion": SlimiEmotionManager.Emotion.GRATEFUL, "action": &"hide_behind_beanie", "source": "local_offline"}

	# 11. التحية والسؤال عن الحال
	if _contains_any(norm, ["مرحب", "اهلا", "سلام", "صباح", "مساء", "كيف حالك", "كيفك", "اخبارك", "hello", "hi", "hey", "how are you"]):
		_last_intent = "greeting"
		var rel_bonus: String = (" علاقتنا تزداد دفئاً كل يوم!" if trust_score >= 75.0 else "") if not is_en else (" I always love hanging out with you!" if trust_score >= 75.0 else "")
		var gr_txt: String = (
			"أهلاً بك%s! أنا بكامل حيويتي الهلامية، مستعد للدردشة أو اللعب أو إلقاء نكتة متى شئت!%s" % [friend_ar, rel_bonus]
			if not is_en else
			"Hello there%s! Feeling wonderfully bouncy and ready to chat, laugh, or play!%s" % [friend_en, rel_bonus]
		)
		return {"text": gr_txt, "emotion": SlimiEmotionManager.Emotion.HAPPY, "action": &"polite_bow", "source": "local_offline"}

	# 12. من أنت؟
	if _contains_any(norm, ["من انت", "ما اسمك", "عرفني", "who are you", "your name"]):
		var who_txt: String = "أنا سلايمي (SLIMI)! رفيقك الهلامي الوردي ذو القبعة الصفراء وقرني الاستشعار، أحب الضحك والألغاز ومرافقتك بلطف!" if not is_en else "I'm SLIMI, your pink jelly companion with starry eyes, translucent feelers, and a cozy yellow beanie!"
		return {"text": who_txt, "emotion": SlimiEmotionManager.Emotion.CONFIDENT, "action": &"play_with_antennae", "source": "local_offline"}

	# 13. متابعة سياقية ذكية مع سؤال تفاعلي لطيف غير متكرر
	var follow_q: String = _pick_non_repeating_string(EN_PROACTIVE_QUESTIONS if is_en else AR_PROACTIVE_QUESTIONS, _used_question_indices)
	var thoughtful: String = (
		"كلامك مثير للاهتمام%s! قرنا الاستشعار يهتزان فضولاً... %s" % [friend_ar, follow_q]
		if not is_en else
		"Ooo, that got my feelers curious%s! %s" % [friend_en, follow_q]
	)
	_last_intent = "chat_followup"
	return {"text": thoughtful, "emotion": SlimiEmotionManager.Emotion.CURIOUS, "action": &"look_at_user", "source": "local_offline"}


func _dispatch_online_ai_request(user_msg: String, locale_code: String, cfg: Dictionary) -> void:
	var endpoint: String = str(cfg.get("endpoint", "https://api.openai.com/v1/chat/completions")).strip_edges()
	var api_key: String = str(cfg.get("api_key", "")).strip_edges()
	var model_name: String = str(cfg.get("model", "gpt-4o-mini")).strip_edges()
	if not endpoint.begins_with("https://") or api_key.is_empty():
		return

	var sys_prompt: String = (
		"أنت SLIMI، كائن هلامي وردي لطيف ومرح يرتدي قبعة صوفية صفراء. أجب بإيجاز شديد (جملة أو جملتين فقط) بلطف وخفة ظل مناسبة لجميع الأعمار ودون أي عتاب."
		if not locale_code.begins_with("en") else
		"You are SLIMI, a gentle, funny, family-friendly pink jelly companion wearing a yellow knit beanie. Reply in 1-2 short warm sentences, never guilt-tripping."
	)
	var body_dict: Dictionary = {
		"model": model_name,
		"messages": [
			{"role": "system", "content": sys_prompt},
			{"role": "user", "content": user_msg},
		],
		"max_tokens": 110,
		"temperature": 0.75,
	}
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + api_key,
	])
	_http_client.request(endpoint, headers, HTTPClient.METHOD_POST, JSON.stringify(body_dict))


func _on_online_ai_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:
		var choices: Variant = (parsed as Dictionary).get("choices", [])
		if choices is Array and not (choices as Array).is_empty():
			var first: Variant = (choices as Array)[0]
			if first is Dictionary:
				var msg_obj: Variant = (first as Dictionary).get("message", {})
				if msg_obj is Dictionary:
					var content: String = str((msg_obj as Dictionary).get("content", "")).strip_edges()
					if not content.is_empty():
						_push_context("slimi", content)
						reply_ready.emit({
							"text": content,
							"emotion": int(_pending_online_fallback.get("emotion", SlimiEmotionManager.Emotion.HAPPY)),
							"action": _pending_online_fallback.get("action", &"look_at_user"),
							"source": "online_ai",
						})


func _push_context(role: String, text: String) -> void:
	_conversation_context.append({"role": role, "text": text})
	if _conversation_context.size() > 10:
		_conversation_context.pop_front()


func _normalize_text(src: String) -> String:
	var s: String = src.to_lower().strip_edges()
	s = s.replace("أ", "ا").replace("إ", "ا").replace("آ", "ا").replace("ة", "ه").replace("ى", "ي")
	return s


func _looks_english(s: String) -> bool:
	var ascii_letters: int = 0
	var arabic_letters: int = 0
	for i in range(s.length()):
		var code: int = s.unicode_at(i)
		if (code >= 97 and code <= 122) or (code >= 65 and code <= 90):
			ascii_letters += 1
		elif code >= 0x0600 and code <= 0x06FF:
			arabic_letters += 1
	return ascii_letters > arabic_letters and ascii_letters >= 2


func _contains_any(haystack: String, needles: Array) -> bool:
	for n in needles:
		if haystack.contains(_normalize_text(str(n))):
			return true
	return false


func _extract_user_name(raw_msg: String) -> String:
	var norm: String = _normalize_text(raw_msg)
	for prefix in ["اسمي ", "نادني ", "انا اسمي ", "my name is ", "call me "]:
		var p_norm: String = _normalize_text(prefix)
		var idx: int = norm.find(p_norm)
		if idx >= 0:
			var rest: String = raw_msg.substr(idx + prefix.length()).strip_edges()
			var first_word: String = rest.split(" ", false)[0] if not rest.is_empty() else ""
			first_word = first_word.replace("،", "").replace(",", "").replace(".", "").replace("!", "")
			if first_word.length() >= 2 and first_word.length() <= 16:
				return first_word
	return ""


func _pick_non_repeating_string(pool: Array[String], used: Array[int]) -> String:
	if pool.is_empty():
		return ""
	var idx: int = _pick_non_repeating_index(pool.size(), used)
	return pool[idx]


func _pick_non_repeating_index(pool_size: int, used: Array[int]) -> int:
	if pool_size <= 0:
		return 0
	var candidates: Array[int] = []
	for i in range(pool_size):
		if not used.has(i):
			candidates.append(i)
	if candidates.is_empty():
		used.clear()
		for i in range(pool_size):
			candidates.append(i)
	var chosen: int = candidates[_rng.randi_range(0, candidates.size() - 1)]
	used.append(chosen)
	return chosen
