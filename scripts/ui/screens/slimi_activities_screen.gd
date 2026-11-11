class_name SlimiActivitiesScreen
extends PanelContainer
## شاشة الأنشطة والألعاب التفاعلية (Activities & Mini-Games Screen):
## - تضم أنشطة حية منفذة فعلياً 100% (اللعب، الرقص، التمدد، الاسترخاء/النوم، النكت، الألغاز)
## - وتضم جميع الألعاب المصغرة والتحديات الـ 9 القابلة للعب فعلياً مع ساحة لعب تفاعلية حية.

var companion: SlimiInteractionManager
var slime: SlimeController
var hud: HUDController

var title_label: Label
var scroll: ScrollContainer
var body_vbox: VBoxContainer

var active_game_card: PanelContainer
var active_game_prompt: Label
var active_game_choices_grid: GridContainer
var wins_badge_label: Label


func setup(p_companion: SlimiInteractionManager, p_slime: SlimeController, p_hud: HUDController) -> void:
	companion = p_companion
	slime = p_slime
	hud = p_hud
	_build_ui()
	if companion != null and companion.minigames != null:
		companion.minigames.minigame_completed.connect(_on_minigame_completed)
	rebuild_content()


func _build_ui() -> void:
	name = "ActivitiesScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	add_child(root_v)

	var header := HBoxContainer.new()
	root_v.add_child(header)

	title_label = Label.new()
	title_label.name = "ActivitiesTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	wins_badge_label = Label.new()
	wins_badge_label.name = "WinsBadgeLabel"
	header.add_child(wins_badge_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(body_vbox)


func rebuild_content() -> void:
	if body_vbox == null:
		return
	for ch in body_vbox.get_children():
		body_vbox.remove_child(ch)
		ch.queue_free()

	LocalizationManager.apply_rtl_to_control(self)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 16, 12))

	title_label.text = LocalizationManager.tr_key("activities_title")
	title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
	title_label.add_theme_color_override("font_color", tokens["text_primary"])

	var wins: int = companion.memory_manager.minigame_wins if (companion != null and companion.memory_manager != null) else 0
	wins_badge_label.text = "🏆 %d" % wins
	wins_badge_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(15, tokens))
	wins_badge_label.add_theme_color_override("font_color", tokens["accent"])

	# 1. ساحة اللعبة المصغرة النشطة (تظهر بوضوح أعلى القائمة عند بدء لعبة أو نتيجة جولة)
	var arena_sec: Dictionary = SlimiUIComponents.make_section_card(tokens)
	active_game_card = arena_sec["card"]
	active_game_card.visible = companion != null and companion.minigames.is_active()
	body_vbox.add_child(active_game_card)

	var arena_v: VBoxContainer = arena_sec["vbox"]
	active_game_prompt = Label.new()
	active_game_prompt.name = "GamePromptLabel"
	active_game_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_game_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	active_game_prompt.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(15, tokens))
	arena_v.add_child(active_game_prompt)

	active_game_choices_grid = GridContainer.new()
	active_game_choices_grid.columns = 2
	active_game_choices_grid.add_theme_constant_override("h_separation", 8)
	active_game_choices_grid.add_theme_constant_override("v_separation", 8)
	arena_v.add_child(active_game_choices_grid)

	if companion != null and companion.minigames.is_active():
		_populate_active_game_arena(companion.minigames._state, tokens)

	# 2. الأنشطة التفاعلية الحية المنفذة فعلياً (6 أنشطة حقيقية)
	var live_sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("act_sec_live"))
	body_vbox.add_child(live_sec["card"])

	var live_grid := GridContainer.new()
	live_grid.columns = 2
	live_grid.add_theme_constant_override("h_separation", 8)
	live_grid.add_theme_constant_override("v_separation", 8)
	(live_sec["vbox"] as VBoxContainer).add_child(live_grid)

	var live_activities: Array[Dictionary] = [
		{"id": "play_hop", "key": "act_play_hop"},
		{"id": "dance", "key": "act_dance"},
		{"id": "stretch", "key": "act_stretch"},
		{"id": "relax", "key": "act_relax"},
		{"id": "joke", "key": "act_joke"},
		{"id": "riddle", "key": "act_riddle"},
	]
	for act in live_activities:
		var aid: String = str(act["id"])
		var btn := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key(str(act["key"])),
			tokens,
			"secondary",
			"",
			Vector2(0, 44)
		)
		btn.name = "BtnAct_" + aid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void: trigger_live_activity(aid))
		live_grid.add_child(btn)

	# 3. الألعاب المصغرة والتحديات التسعة الكاملة
	if companion != null and companion.minigames != null:
		var games_sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("act_sec_games"))
		body_vbox.add_child(games_sec["card"])

		var g_grid := GridContainer.new()
		g_grid.columns = 3
		g_grid.add_theme_constant_override("h_separation", 8)
		g_grid.add_theme_constant_override("v_separation", 8)
		(games_sec["vbox"] as VBoxContainer).add_child(g_grid)

		var is_en: bool = (LocalizationManager.current_locale == "en")
		for g in companion.minigames.get_supported_games():
			var gid: String = str(g["id"])
			var glabel: String = str(g["en"] if is_en else g["ar"])
			var gb := SlimiUIComponents.make_styled_button(
				glabel,
				tokens,
				"secondary",
				"",
				Vector2(0, 46)
			)
			gb.name = "BtnGame_" + gid
			gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gb.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))
			gb.pressed.connect(func() -> void: start_minigame_round(gid))
			g_grid.add_child(gb)


func trigger_live_activity(activity_id: String) -> void:
	if slime == null:
		return
	match activity_id:
		"play_hop":
			slime.play_together()
			if hud != null:
				hud.show_bubble_by_key("bubble_play", 3.2)
		"dance":
			if slime.motion_coordinator != null:
				slime.motion_coordinator.play_cinematic_motion(&"dancing")
			if companion != null:
				companion.emotion_manager.set_emotion(SlimiEmotionManager.Emotion.EXCITED, 4.0)
		"stretch":
			if slime.motion_coordinator != null:
				slime.motion_coordinator.play_cinematic_motion(&"stretching")
		"relax":
			slime.toggle_nap()
			if hud != null:
				hud.show_bubble_by_key("bubble_sleep" if slime.mood_system.is_sleeping else "bubble_wake", 3.4)
		"joke":
			if companion != null:
				var r: Dictionary = companion.request_quick_entertainment("joke")
				if hud != null and not str(r.get("text", "")).is_empty():
					hud.show_bubble_text(str(r["text"]), 5.2)
		"riddle":
			if companion != null:
				var rr: Dictionary = companion.request_quick_entertainment("riddle")
				if hud != null and not str(rr.get("text", "")).is_empty():
					hud.show_bubble_text(str(rr["text"]), 5.8)


func start_minigame_round(game_id: String) -> void:
	if companion == null or companion.minigames == null:
		return
	companion.behavior_ai.paused_for_minigame = true
	var st: Dictionary = companion.minigames.start_game(game_id, LocalizationManager.current_locale)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	_populate_active_game_arena(st, tokens)
	if scroll != null:
		scroll.scroll_vertical = 0


func _populate_active_game_arena(state: Dictionary, tokens: Dictionary) -> void:
	if active_game_card == null or active_game_choices_grid == null:
		return
	active_game_card.visible = true
	active_game_prompt.text = str(state.get("prompt", ""))

	for ch in active_game_choices_grid.get_children():
		active_game_choices_grid.remove_child(ch)
		ch.queue_free()

	var choices: Array = state.get("choices", [])
	for idx in range(choices.size()):
		var cb := SlimiUIComponents.make_styled_button(
			str(choices[idx]),
			tokens,
			"primary",
			"",
			Vector2(0, 44)
		)
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var choice_idx: int = idx
		cb.pressed.connect(func() -> void:
			var res: Dictionary = companion.minigames.submit_choice(choice_idx, LocalizationManager.current_locale)
			if companion.minigames.is_active():
				_populate_active_game_arena(res, SlimiDesignSystem.get_tokens())
			else:
				companion.behavior_ai.paused_for_minigame = false
				active_game_prompt.text = str(res.get("message", res.get("prompt", "")))
				for old_c in active_game_choices_grid.get_children():
					active_game_choices_grid.remove_child(old_c)
					old_c.queue_free()
		)
		active_game_choices_grid.add_child(cb)


func _on_minigame_completed(_gid: String, _won: bool, msg: String) -> void:
	if active_game_prompt != null:
		active_game_prompt.text = msg
	if wins_badge_label != null and companion != null and companion.memory_manager != null:
		wins_badge_label.text = "🏆 %d" % companion.memory_manager.minigame_wins
