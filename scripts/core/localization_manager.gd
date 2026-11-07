extends Node
## مدير الترجمة واتجاه الواجهة (RTL للعربية افتراضياً مع قابلية التوسع لإضافة لغات جديدة).

signal locale_changed(new_locale: String, is_rtl: bool)

const RTL_LOCALES: PackedStringArray = ["ar", "fa", "ur", "he"]

var current_locale: String = "ar"
var _catalog: Dictionary = {
	"ar": {
		"app_title": "سلايمي",
		"mood_happy": "سعيد ومشرق",
		"mood_playful": "مرح ونشيط",
		"mood_curious": "فضولي يستكشف",
		"mood_sleepy": "نعسان يحتاج للراحة",
		"mood_hungry": "جائع يريد حلوى",
		"mood_affectionate": "يشعر بالمودة والأمان",
		"mood_dizzy": "دائخ من الدغدغة!",
		"stat_happiness": "السعادة",
		"stat_energy": "الطاقة",
		"stat_fullness": "الشبع",
		"stat_bond": "الألفة",
		"btn_feed": "إطعام",
		"btn_play": "لعب",
		"btn_sleep": "غفوة",
		"btn_wake": "إيقاظ",
		"btn_call": "مناداة",
		"btn_memory": "الذاكرة",
		"btn_settings": "الإعدادات",
		"btn_close": "إغلاق",
		"btn_reset_cam": "توسيط الكاميرا",
		"settings_title": "إعدادات اللعبة والجودة",
		"quality_label": "جودة الرسوميات",
		"quality_low": "منخفضة",
		"quality_medium": "متوسطة",
		"quality_high": "عالية",
		"volume_master": "الصوت العام",
		"volume_sfx": "المؤثرات والأصوات",
		"volume_ambient": "موسيقى الغرفة الهادئة",
		"battery_saver": "توفير البطارية (30 إطار/ث)",
		"haptics_toggle": "اهتزاز اللمس اللطيف",
		"show_fps": "إظهار عدّاد الأداء (FPS)",
		"lang_toggle": "اللغة: العربية",
		"memory_title": "ذاكرة سلايمي معك",
		"mem_sessions": "عدد الزيارات: {count}",
		"mem_pokes": "اللمسات المرحة: {count}",
		"mem_pets": "المسحات الحنونة: {count}",
		"mem_feeds": "وجبات الحلوى: {count}",
		"mem_plays": "مرات اللعب: {count}",
		"mem_bond_tier": "مستوى العلاقة: {tier}",
		"mem_fav": "التفاعل المفضل: {fav}",
		"bond_new": "صديق جديد",
		"bond_warm": "صديق مقرب",
		"bond_best": "رفيق الروح",
		"fav_pet": "المسح الحنون على الرأس",
		"fav_poke": "اللمس والقفز المرح",
		"fav_feed": "تناول الحلوى الوردية",
		"fav_play": "اللعب والارتداد",
		"bubble_welcome_first": "مرحباً! أنا سلايمي.. المسني أو امسح عليّ بلطف!",
		"bubble_welcome_back": "أهلاً بعودتك! تذكرتك فوراً واشتقت للعب معك!",
		"bubble_missed_you": "غبت عني قليلاً.. سعيد جداً لرؤيتك من جديد!",
		"bubble_pet": "يا سلام.. مسحتك دافئة ومريحة جداً!",
		"bubble_poke": "هييه! هذا يدغدغني!",
		"bubble_dizzy": "أوووه.. الغرفة تدور حولي بلطف!",
		"bubble_feed": "يممم! حلوى لذيذة، شكراً لك!",
		"bubble_play": "يااي! لنقفز ونمرح معاً!",
		"bubble_sleep": "تصبح على خير.. سأغفو قليلاً لأستعيد طاقتي.",
		"bubble_wake": "صباح النشاط! أنا جاهز للمرح!",
		"bubble_curious": "هممم.. ماذا يوجد هناك يا ترى؟",
		"bubble_hungry": "معدتي الهلامية تقرقر.. هل لديك قطعة حلوى؟",
		"bubble_lonely": "أنا هنا! تعال نلعب قليلاً!",
		"hint_touch": "المس سلايمي، امسح عليه، اسحبه بلطف، أو انقر على الأرض لينتقل إليها",
	},
	"en": {
		"app_title": "SLIMI",
		"mood_happy": "Happy & Bright",
		"mood_playful": "Playful & Bouncy",
		"mood_curious": "Curious Explorer",
		"mood_sleepy": "Sleepy & Cozy",
		"mood_hungry": "Hungry for Treats",
		"mood_affectionate": "Loved & Content",
		"mood_dizzy": "Giggly & Dizzy!",
		"stat_happiness": "Happiness",
		"stat_energy": "Energy",
		"stat_fullness": "Fullness",
		"stat_bond": "Bond",
		"btn_feed": "Feed",
		"btn_play": "Play",
		"btn_sleep": "Nap",
		"btn_wake": "Wake",
		"btn_call": "Call",
		"btn_memory": "Memory",
		"btn_settings": "Settings",
		"btn_close": "Close",
		"btn_reset_cam": "Center Camera",
		"settings_title": "Game & Graphics Settings",
		"quality_label": "Graphics Quality",
		"quality_low": "Low",
		"quality_medium": "Medium",
		"quality_high": "High",
		"volume_master": "Master Volume",
		"volume_sfx": "Sound Effects",
		"volume_ambient": "Cozy Room Ambient",
		"battery_saver": "Battery Saver (30 FPS)",
		"haptics_toggle": "Gentle Touch Haptics",
		"show_fps": "Show FPS Monitor",
		"lang_toggle": "Language: English",
		"memory_title": "SLIMI's Memory With You",
		"mem_sessions": "Visits together: {count}",
		"mem_pokes": "Playful pokes: {count}",
		"mem_pets": "Gentle pets: {count}",
		"mem_feeds": "Sweet treats: {count}",
		"mem_plays": "Play sessions: {count}",
		"mem_bond_tier": "Bond tier: {tier}",
		"mem_fav": "Favorite activity: {fav}",
		"bond_new": "New Friend",
		"bond_warm": "Close Companion",
		"bond_best": "Best Forever Buddy",
		"fav_pet": "Gentle head pats",
		"fav_poke": "Playful pokes & hops",
		"fav_feed": "Yummy pink treats",
		"fav_play": "Bouncy playtime",
		"bubble_welcome_first": "Hi! I'm SLIMI! Tap or gently pet me!",
		"bubble_welcome_back": "Welcome back! I remembered you right away!",
		"bubble_missed_you": "I missed you! So happy you're back!",
		"bubble_pet": "Mmm... gentle pats feel so cozy!",
		"bubble_poke": "Hehe! That tickles!",
		"bubble_dizzy": "Whoooa... everything is wobbling!",
		"bubble_feed": "Yum!! Thank you for the sweet treat!",
		"bubble_play": "Yay! Let's bounce together!",
		"bubble_sleep": "Zzz... taking a cozy nap to recharge.",
		"bubble_wake": "I'm awake and ready to play!",
		"bubble_curious": "Ooh... what's over there?",
		"bubble_hungry": "My jelly tummy is rumbling for a treat!",
		"bubble_lonely": "Over here! Come play with me!",
		"hint_touch": "Tap SLIMI, stroke gently, pull & release, or tap the floor to hop",
	}
}


func _ready() -> void:
	set_locale(current_locale)


func is_rtl() -> bool:
	return current_locale in RTL_LOCALES


func set_locale(locale_code: String) -> void:
	var normalized: String = locale_code.strip_edges().to_lower()
	if normalized.length() >= 2:
		normalized = normalized.substr(0, 2)
	if not _catalog.has(normalized):
		normalized = "ar"
	current_locale = normalized
	TranslationServer.set_locale(current_locale)
	locale_changed.emit(current_locale, is_rtl())


func toggle_locale() -> void:
	set_locale("en" if current_locale == "ar" else "ar")


func register_translations(locale_code: String, entries: Dictionary) -> void:
	if not _catalog.has(locale_code):
		_catalog[locale_code] = {}
	for key in entries.keys():
		_catalog[locale_code][key] = entries[key]


func tr_key(key: String, params: Dictionary = {}) -> String:
	var table: Dictionary = _catalog.get(current_locale, _catalog["ar"])
	var text: String = str(table.get(key, _catalog["ar"].get(key, key)))
	for param_key in params.keys():
		text = text.replace("{%s}" % str(param_key), str(params[param_key]))
	return text


func apply_rtl_to_control(root: Control) -> void:
	if root == null:
		return
	var dir: Control.LayoutDirection = (
		Control.LAYOUT_DIRECTION_RTL if is_rtl() else Control.LAYOUT_DIRECTION_LTR
	)
	root.layout_direction = dir
	if root.theme != null and root.theme.default_font == null:
		var ui_font: Font = ArabicFontProvider.get_ui_font()
		if ui_font != null:
			root.theme.default_font = ui_font
