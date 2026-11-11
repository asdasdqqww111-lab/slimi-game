class_name CompanionUIBuilder
extends RefCounted
## باني الواجهة التفاعلية النظيفة لرفيق SLIMI:
## يضيف أزرار الدردشة والميكروفون وكتم الصوت والألعاب المصغرة بهدوء دون تغطية الشخصية،
## مع نوافذ منبثقة أنيقة لسجل المحادثات والألعاب وإدارة الذاكرة ومزود الذكاء الاختياري.


static func build_and_attach(hud: HUDController, companion: SlimiInteractionManager) -> Dictionary:
	var ui: Dictionary = {}
	if hud == null or hud.hud_root == null or companion == null:
		return ui

	var util_row := hud.get_node_or_null("HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/UtilityButtons") as HBoxContainer
	var top_sec := hud.get_node_or_null("HUDRoot/SafeMargin/MainLayout/TopSection") as VBoxContainer
	var dock_row := hud.get_node_or_null("HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock/DockRow") as HBoxContainer

	# 1. أزرار علوية مدمجة: كتم الصوت + الميكروفون الاختياري
	var btn_mute := _make_icon_button("BtnMute", "صوت", "res://assets/icons/ic_voice.svg", Vector2(52, 54))
	var btn_mic := _make_icon_button("BtnMic", "تحدث", "res://assets/icons/ic_mic.svg", Vector2(52, 54))
	if util_row != null:
		util_row.add_child(btn_mute)
		util_row.move_child(btn_mute, 0)
		util_row.add_child(btn_mic)
		util_row.move_child(btn_mic, 0)
	ui["btn_mute"] = btn_mute
	ui["btn_mic"] = btn_mic

	# شريط مؤشر الميكروفون الحي (مخفي دائماً إلا أثناء الاستماع الفعلي بعد موافقة المستخدم)
	var mic_banner := PanelContainer.new()
	mic_banner.name = "MicLiveBanner"
	mic_banner.visible = false
	var mic_style := StyleBoxFlat.new()
	mic_style.bg_color = Color(1.0, 0.28, 0.46, 0.92)
	mic_style.set_corner_radius_all(14)
	mic_style.content_margin_left = 14
	mic_style.content_margin_right = 14
	mic_style.content_margin_top = 6
	mic_style.content_margin_bottom = 6
	mic_banner.add_theme_stylebox_override("panel", mic_style)

	var mic_lbl := Label.new()
	mic_lbl.name = "MicLiveLabel"
	mic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mic_lbl.add_theme_color_override("font_color", Color.WHITE)
	mic_lbl.add_theme_font_size_override("font_size", 15)
	mic_lbl.text = LocalizationManager.tr_key("mic_live_badge")
	mic_banner.add_child(mic_lbl)
	if top_sec != null:
		top_sec.add_child(mic_banner)
	ui["mic_banner"] = mic_banner
	ui["mic_label"] = mic_lbl

	# 2. أزرار سفلية مدمجة في شريط الأوامر: الدردشة + الألعاب المصغرة
	var btn_chat := _make_icon_button("BtnChat", "دردشة", "res://assets/icons/ic_chat.svg", Vector2(68, 66))
	btn_chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var btn_games := _make_icon_button("BtnGames", "ألعاب", "res://assets/icons/ic_games.svg", Vector2(68, 66))
	btn_games.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if dock_row != null:
		dock_row.add_child(btn_chat)
		dock_row.add_child(btn_games)
	ui["btn_chat"] = btn_chat
	ui["btn_games"] = btn_games

	# 3. نافذة الدردشة الذكية وسجل المحادثات
	var chat_modal: ColorRect = _build_chat_modal(hud.hud_root, companion, ui)
	ui["chat_modal"] = chat_modal

	# 4. نافذة الألعاب المصغرة التفاعلية (9 ألعاب)
	var games_modal: ColorRect = _build_games_modal(hud.hud_root, companion, ui)
	ui["games_modal"] = games_modal

	# 5. ترقية نافذة الذاكرة (اللقب + خيار الحفظ + زر مسح الذاكرة المحفوظة)
	_augment_memory_modal(hud, companion, ui)

	# 6. ترقية نافذة الإعدادات بلفافة تمرير داخلية + الشخصية + وضع Offline / AI Online والمزود والخصوصية
	_augment_settings_modal(hud, companion, ui)

	_wire_companion_signals(hud, companion, ui)
	refresh_texts(companion, ui)
	return ui


static func _make_icon_button(node_name: String, label_txt: String, icon_path: String, min_sz: Vector2) -> Button:
	var b := Button.new()
	b.name = node_name
	b.custom_minimum_size = min_sz
	b.text = label_txt
	b.icon = load(icon_path) as Texture2D
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.expand_icon = true
	b.add_theme_font_size_override("font_size", 13)
	return b


static func _make_modal_backdrop(modal_name: String) -> ColorRect:
	var modal := ColorRect.new()
	modal.name = modal_name
	modal.visible = false
	modal.color = Color(0.18, 0.08, 0.22, 0.56)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	return modal


static func _make_modal_card(parent_modal: ColorRect, height_px: float = 620.0) -> VBoxContainer:
	var card := PanelContainer.new()
	card.name = "Card"
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -315.0
	card.offset_right = 315.0
	card.offset_top = -height_px * 0.5
	card.offset_bottom = height_px * 0.5
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.96, 0.99, 0.97)
	style.border_color = Color(1.0, 0.76, 0.90, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(26)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)
	parent_modal.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)
	return vbox


static func _build_chat_modal(hud_root: Control, companion: SlimiInteractionManager, ui: Dictionary) -> ColorRect:
	var modal := _make_modal_backdrop("ChatModal")
	hud_root.add_child(modal)
	var vbox := _make_modal_card(modal, 650.0)

	var title := Label.new()
	title.name = "ChatTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	ui["chat_title"] = title

	# شريط ترفيه سريع (نكتة، لغز، قصة، مشهد تمثيلي)
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 6)
	vbox.add_child(quick_row)

	var q_specs: Array[Dictionary] = [
		{"key": "quick_joke", "cat": "joke"},
		{"key": "quick_riddle", "cat": "riddle"},
		{"key": "quick_story", "cat": "story"},
		{"key": "quick_skit", "cat": "skit"},
	]
	var quick_btns: Array[Button] = []
	for sp in q_specs:
		var qb := Button.new()
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.custom_minimum_size = Vector2(0, 38)
		qb.set_meta("tr_key", sp["key"])
		var cat_id: String = str(sp["cat"])
		qb.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			companion.request_quick_entertainment(cat_id)
		)
		quick_row.add_child(qb)
		quick_btns.append(qb)
	ui["quick_btns"] = quick_btns

	# سجل المحادثات القابل للتمرير
	var scroll := ScrollContainer.new()
	scroll.name = "ChatScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var log_vbox := VBoxContainer.new()
	log_vbox.name = "ChatLogVBox"
	log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(log_vbox)
	ui["chat_log_vbox"] = log_vbox
	ui["chat_scroll"] = scroll

	# صف الكتابة والإرسال
	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	vbox.add_child(input_row)

	var chat_input := LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 46)
	input_row.add_child(chat_input)
	ui["chat_input"] = chat_input

	var btn_send := Button.new()
	btn_send.name = "BtnSendChat"
	btn_send.custom_minimum_size = Vector2(96, 46)
	input_row.add_child(btn_send)
	ui["btn_send"] = btn_send

	var send_fn := func() -> void:
		var msg: String = chat_input.text.strip_edges()
		if msg.is_empty():
			return
		chat_input.text = ""
		AudioManager.play_sfx(&"ui_click")
		companion.send_user_chat_message(msg)

	btn_send.pressed.connect(send_fn)
	chat_input.text_submitted.connect(func(_t: String) -> void: send_fn.call())

	var btn_close := Button.new()
	btn_close.name = "BtnCloseChat"
	btn_close.custom_minimum_size = Vector2(0, 42)
	btn_close.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		modal.visible = false
	)
	vbox.add_child(btn_close)
	ui["btn_close_chat"] = btn_close
	return modal


static func _build_games_modal(hud_root: Control, companion: SlimiInteractionManager, ui: Dictionary) -> ColorRect:
	var modal := _make_modal_backdrop("GamesModal")
	hud_root.add_child(modal)
	var vbox := _make_modal_card(modal, 680.0)

	var title := Label.new()
	title.name = "GamesTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	ui["games_title"] = title

	# شبكة اختيار الألعاب التسع
	var grid := GridContainer.new()
	grid.name = "GamesGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(grid)

	var game_btns: Array[Button] = []
	for g in companion.minigames.get_supported_games():
		var gb := Button.new()
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gb.custom_minimum_size = Vector2(0, 44)
		gb.add_theme_font_size_override("font_size", 13)
		gb.set_meta("game_def", g)
		var gid: String = str(g["id"])
		gb.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			companion.behavior_ai.paused_for_minigame = true
			companion.minigames.start_game(gid, LocalizationManager.current_locale)
		)
		grid.add_child(gb)
		game_btns.append(gb)
	ui["game_btns"] = game_btns

	# منطقة عرض جولة اللعبة النشطة
	var stage_panel := PanelContainer.new()
	stage_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(stage_panel)

	var stage_vbox := VBoxContainer.new()
	stage_vbox.add_theme_constant_override("separation", 10)
	stage_panel.add_child(stage_vbox)

	var prompt_lbl := Label.new()
	prompt_lbl.name = "GamePromptLabel"
	prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_lbl.add_theme_font_size_override("font_size", 17)
	stage_vbox.add_child(prompt_lbl)
	ui["game_prompt_lbl"] = prompt_lbl

	var choices_vbox := VBoxContainer.new()
	choices_vbox.name = "GameChoicesBox"
	choices_vbox.add_theme_constant_override("separation", 8)
	stage_vbox.add_child(choices_vbox)
	ui["game_choices_vbox"] = choices_vbox

	var btn_close := Button.new()
	btn_close.name = "BtnCloseGames"
	btn_close.custom_minimum_size = Vector2(0, 42)
	btn_close.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		companion.minigames.stop_game()
		companion.behavior_ai.paused_for_minigame = false
		modal.visible = false
	)
	vbox.add_child(btn_close)
	ui["btn_close_games"] = btn_close
	return modal


static func _augment_memory_modal(hud: HUDController, companion: SlimiInteractionManager, ui: Dictionary) -> void:
	var mem_vbox := hud.get_node_or_null("HUDRoot/MemoryModal/Card/VBox") as VBoxContainer
	if mem_vbox == null:
		return

	var nick_lbl := Label.new()
	nick_lbl.add_theme_font_size_override("font_size", 14)
	mem_vbox.add_child(nick_lbl)
	ui["mem_nick_lbl"] = nick_lbl

	var nick_input := LineEdit.new()
	nick_input.name = "NicknameInput"
	nick_input.text = companion.memory_manager.user_nickname
	nick_input.text_changed.connect(func(new_txt: String) -> void:
		companion.memory_manager.set_user_nickname(new_txt)
	)
	mem_vbox.add_child(nick_input)
	ui["nick_input"] = nick_input

	var chk_save_chat := CheckButton.new()
	chk_save_chat.name = "ChkSaveChatMemory"
	chk_save_chat.button_pressed = companion.memory_manager.save_chat_memory_enabled
	chk_save_chat.toggled.connect(func(on: bool) -> void:
		companion.memory_manager.save_chat_memory_enabled = on
		companion.memory_manager.persist()
	)
	mem_vbox.add_child(chk_save_chat)
	ui["chk_save_chat"] = chk_save_chat

	var btn_clear := Button.new()
	btn_clear.name = "BtnClearMemory"
	btn_clear.custom_minimum_size = Vector2(0, 40)
	btn_clear.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		companion.memory_manager.clear_all_memory()
		companion.dialogue_manager.clear_context()
		nick_input.text = ""
	)
	mem_vbox.add_child(btn_clear)
	ui["btn_clear_mem"] = btn_clear

	if hud.btn_close_memory != null:
		mem_vbox.move_child(hud.btn_close_memory, mem_vbox.get_child_count() - 1)


static func _augment_settings_modal(hud: HUDController, companion: SlimiInteractionManager, ui: Dictionary) -> void:
	var set_card := hud.get_node_or_null("HUDRoot/SettingsModal/Card") as PanelContainer
	var set_vbox := hud.get_node_or_null("HUDRoot/SettingsModal/Card/VBox") as VBoxContainer
	if set_card == null or set_vbox == null:
		return

	# نوسع البطاقة قليلاً مع إبقاء المسار الأصلي HUDRoot/SettingsModal/Card/VBox متوافقاً 100%
	set_card.offset_top = -540.0
	set_card.offset_bottom = 540.0
	set_vbox.add_theme_constant_override("separation", 6)

	var ai_box := VBoxContainer.new()
	ai_box.name = "CompanionAISection"
	ai_box.add_theme_constant_override("separation", 6)

	var sep := HSeparator.new()
	ai_box.add_child(sep)

	var sec_lbl := Label.new()
	sec_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sec_lbl.add_theme_font_size_override("font_size", 16)
	ai_box.add_child(sec_lbl)
	ui["ai_sec_lbl"] = sec_lbl

	# الفكاهة والفضول
	var hum_lbl := Label.new()
	hum_lbl.add_theme_font_size_override("font_size", 14)
	ai_box.add_child(hum_lbl)
	ui["hum_lbl"] = hum_lbl

	var hum_slider := HSlider.new()
	hum_slider.min_value = 0.2
	hum_slider.max_value = 1.0
	hum_slider.step = 0.05
	hum_slider.value = companion.personality_manager.humor
	hum_slider.value_changed.connect(func(v: float) -> void:
		companion.personality_manager.set_trait("humor", v)
		companion.save_companion_state()
	)
	ai_box.add_child(hum_slider)

	var cur_lbl := Label.new()
	cur_lbl.add_theme_font_size_override("font_size", 14)
	ai_box.add_child(cur_lbl)
	ui["cur_lbl"] = cur_lbl

	var cur_slider := HSlider.new()
	cur_slider.min_value = 0.2
	cur_slider.max_value = 1.0
	cur_slider.step = 0.05
	cur_slider.value = companion.personality_manager.curiosity
	cur_slider.value_changed.connect(func(v: float) -> void:
		companion.personality_manager.set_trait("curiosity", v)
		companion.save_companion_state()
	)
	ai_box.add_child(cur_slider)

	var chk_occ := CheckButton.new()
	chk_occ.button_pressed = companion.settings_manager.occasion_greetings_enabled
	chk_occ.toggled.connect(func(on: bool) -> void:
		companion.settings_manager.occasion_greetings_enabled = on
		companion.settings_manager.persist()
	)
	ai_box.add_child(chk_occ)
	ui["chk_occ"] = chk_occ

	# زر التبديل بين Offline (افتراضي) و AI Online (اختياري)
	var btn_mode := Button.new()
	btn_mode.name = "BtnAIMode"
	btn_mode.custom_minimum_size = Vector2(0, 38)
	ai_box.add_child(btn_mode)
	ui["btn_ai_mode"] = btn_mode

	var opt_provider := OptionButton.new()
	opt_provider.name = "OptionAIProvider"
	opt_provider.add_item("OpenAI Compatible", 0)
	opt_provider.add_item("Google Gemini API", 1)
	opt_provider.add_item("Custom HTTPS Endpoint", 2)
	var prov_keys: Array[String] = ["openai_compatible", "gemini_compatible", "custom_provider"]
	opt_provider.selected = maxi(0, prov_keys.find(companion.settings_manager.ai_provider))
	opt_provider.item_selected.connect(func(idx: int) -> void:
		companion.settings_manager.ai_provider = prov_keys[clampi(idx, 0, 2)]
		companion.settings_manager.persist()
	)
	ai_box.add_child(opt_provider)
	ui["opt_provider"] = opt_provider

	var chk_consent := CheckButton.new()
	chk_consent.name = "ChkOnlineConsent"
	chk_consent.button_pressed = companion.settings_manager.online_user_consent
	chk_consent.toggled.connect(func(on: bool) -> void:
		companion.settings_manager.online_user_consent = on
		companion.settings_manager.persist()
	)
	ai_box.add_child(chk_consent)
	ui["chk_consent"] = chk_consent

	var key_input := LineEdit.new()
	key_input.name = "ApiKeyVaultInput"
	key_input.secret = true
	key_input.text_changed.connect(func(k: String) -> void:
		companion.settings_manager.set_api_key_secure(k)
	)
	ai_box.add_child(key_input)
	ui["key_input"] = key_input

	btn_mode.pressed.connect(func() -> void:
		AudioManager.play_sfx(&"ui_click")
		companion.settings_manager.ai_mode = "online" if companion.settings_manager.ai_mode == "offline" else "offline"
		companion.settings_manager.persist()
		refresh_texts(companion, ui)
	)

	set_vbox.add_child(ai_box)
	if hud.btn_close_settings != null:
		set_vbox.move_child(hud.btn_close_settings, set_vbox.get_child_count() - 1)


static func _wire_companion_signals(hud: HUDController, companion: SlimiInteractionManager, ui: Dictionary) -> void:
	var btn_chat: Button = ui.get("btn_chat") as Button
	var btn_games: Button = ui.get("btn_games") as Button
	var btn_mic: Button = ui.get("btn_mic") as Button
	var btn_mute: Button = ui.get("btn_mute") as Button
	var chat_modal: ColorRect = ui.get("chat_modal") as ColorRect
	var games_modal: ColorRect = ui.get("games_modal") as ColorRect

	if btn_chat != null and chat_modal != null:
		btn_chat.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			hud.close_modals()
			chat_modal.visible = true
		)

	if btn_games != null and games_modal != null:
		btn_games.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			hud.close_modals()
			games_modal.visible = true
			if not companion.minigames.is_active():
				companion.minigames.start_game("emoji_face_match", LocalizationManager.current_locale)
		)

	if btn_mic != null:
		btn_mic.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			companion.toggle_microphone_with_user_consent()
		)

	if btn_mute != null:
		btn_mute.pressed.connect(func() -> void:
			var next_mute: bool = not companion.settings_manager.voice_muted
			companion.settings_manager.voice_muted = next_mute
			companion.settings_manager.persist()
			refresh_texts(companion, ui)
		)

	companion.mic_state_changed.connect(func(active: bool, rms: float) -> void:
		var banner: PanelContainer = ui.get("mic_banner") as PanelContainer
		var lbl: Label = ui.get("mic_label") as Label
		if banner != null:
			banner.visible = active
		if active and lbl != null:
			var bars: int = clampi(int(round(rms * 5.0)), 1, 5)
			lbl.text = "%s %s" % [LocalizationManager.tr_key("mic_live_badge"), "▮".repeat(bars)]
	)

	companion.chat_log_appended.connect(func(sender: String, msg: String, em_lbl: String) -> void:
		var log_vbox: VBoxContainer = ui.get("chat_log_vbox") as VBoxContainer
		if log_vbox == null:
			return
		var entry := Label.new()
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.add_theme_font_size_override("font_size", 15)
		if sender == "user":
			entry.text = "🧑: " + msg
			entry.add_theme_color_override("font_color", Color(0.32, 0.16, 0.42, 1.0))
		else:
			entry.text = "🌸 SLIMI (%s): %s" % [em_lbl, msg]
			entry.add_theme_color_override("font_color", Color(0.72, 0.14, 0.46, 1.0))
		log_vbox.add_child(entry)
		while log_vbox.get_child_count() > 24:
			var oldest: Node = log_vbox.get_child(0)
			log_vbox.remove_child(oldest)
			oldest.free()
	)

	companion.minigames.minigame_updated.connect(func(st: Dictionary) -> void:
		var p_lbl: Label = ui.get("game_prompt_lbl") as Label
		var c_box: VBoxContainer = ui.get("game_choices_vbox") as VBoxContainer
		if p_lbl != null:
			p_lbl.text = str(st.get("prompt", ""))
		if c_box != null:
			for ch in c_box.get_children():
				c_box.remove_child(ch)
				ch.free()
			var choices: Array = st.get("choices", [])
			for idx in range(choices.size()):
				var cb := Button.new()
				cb.custom_minimum_size = Vector2(0, 42)
				cb.text = str(choices[idx])
				var captured_idx: int = idx
				cb.pressed.connect(func() -> void:
					AudioManager.play_sfx(&"ui_click")
					companion.minigames.submit_choice(captured_idx, LocalizationManager.current_locale)
				)
				c_box.add_child(cb)
	)

	var on_locale := func(_l: String, _rtl: bool) -> void:
		if not is_instance_valid(companion) or not is_instance_valid(hud):
			return
		companion.settings_manager.speech_locale = LocalizationManager.current_locale
		companion.settings_manager.persist()
		refresh_texts(companion, ui)
	LocalizationManager.locale_changed.connect(on_locale)
	hud.tree_exiting.connect(func() -> void:
		if LocalizationManager.locale_changed.is_connected(on_locale):
			LocalizationManager.locale_changed.disconnect(on_locale)
	)


static func refresh_texts(companion: SlimiInteractionManager, ui: Dictionary) -> void:
	var is_en: bool = LocalizationManager.current_locale.begins_with("en")
	for m_key in ["chat_modal", "games_modal"]:
		var m_ctrl: Control = ui.get(m_key) as Control
		if m_ctrl != null:
			LocalizationManager.apply_rtl_to_control(m_ctrl)

	if ui.get("btn_chat") is Button:
		(ui["btn_chat"] as Button).text = LocalizationManager.tr_key("btn_chat")
	if ui.get("btn_games") is Button:
		(ui["btn_games"] as Button).text = LocalizationManager.tr_key("btn_games")
	if ui.get("btn_mic") is Button:
		(ui["btn_mic"] as Button).text = LocalizationManager.tr_key("btn_mic")
	if ui.get("btn_mute") is Button:
		(ui["btn_mute"] as Button).text = LocalizationManager.tr_key("btn_mute_on" if companion.settings_manager.voice_muted else "btn_mute_off")
	if ui.get("chat_title") is Label:
		(ui["chat_title"] as Label).text = LocalizationManager.tr_key("chat_title")
	if ui.get("chat_input") is LineEdit:
		(ui["chat_input"] as LineEdit).placeholder_text = LocalizationManager.tr_key("chat_placeholder")
	if ui.get("btn_send") is Button:
		(ui["btn_send"] as Button).text = LocalizationManager.tr_key("btn_send")
	if ui.get("btn_close_chat") is Button:
		(ui["btn_close_chat"] as Button).text = LocalizationManager.tr_key("btn_close")
	if ui.get("games_title") is Label:
		(ui["games_title"] as Label).text = LocalizationManager.tr_key("games_title")
	if ui.get("btn_close_games") is Button:
		(ui["btn_close_games"] as Button).text = LocalizationManager.tr_key("btn_close")

	for qb in ui.get("quick_btns", []):
		if qb is Button:
			(qb as Button).text = LocalizationManager.tr_key(str((qb as Button).get_meta("tr_key", "")))

	for gb in ui.get("game_btns", []):
		if gb is Button:
			var gdef: Dictionary = (gb as Button).get_meta("game_def", {})
			(gb as Button).text = str(gdef.get("en" if is_en else "ar", ""))

	if ui.get("mem_nick_lbl") is Label:
		(ui["mem_nick_lbl"] as Label).text = LocalizationManager.tr_key("mem_nickname_label")
	if ui.get("chk_save_chat") is CheckButton:
		(ui["chk_save_chat"] as CheckButton).text = LocalizationManager.tr_key("mem_save_chat_toggle")
	if ui.get("btn_clear_mem") is Button:
		(ui["btn_clear_mem"] as Button).text = LocalizationManager.tr_key("mem_clear_btn")

	if ui.get("ai_sec_lbl") is Label:
		(ui["ai_sec_lbl"] as Label).text = LocalizationManager.tr_key("ai_section_title")
	if ui.get("hum_lbl") is Label:
		(ui["hum_lbl"] as Label).text = LocalizationManager.tr_key("personality_humor")
	if ui.get("cur_lbl") is Label:
		(ui["cur_lbl"] as Label).text = LocalizationManager.tr_key("personality_curiosity")
	if ui.get("chk_occ") is CheckButton:
		(ui["chk_occ"] as CheckButton).text = LocalizationManager.tr_key("occasions_toggle")

	var is_online: bool = (companion.settings_manager.ai_mode == "online")
	if ui.get("btn_ai_mode") is Button:
		(ui["btn_ai_mode"] as Button).text = LocalizationManager.tr_key("ai_mode_online" if is_online else "ai_mode_offline")
	if ui.get("opt_provider") is Control:
		(ui["opt_provider"] as Control).visible = is_online
	if ui.get("chk_consent") is CheckButton:
		var cc := ui["chk_consent"] as CheckButton
		cc.visible = is_online
		cc.text = LocalizationManager.tr_key("ai_consent_toggle")
	if ui.get("key_input") is LineEdit:
		var ki := ui["key_input"] as LineEdit
		ki.visible = is_online
		ki.placeholder_text = LocalizationManager.tr_key("ai_key_placeholder")
