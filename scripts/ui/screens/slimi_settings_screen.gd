class_name SlimiSettingsScreen
extends PanelContainer
## شاشة الإعدادات المتكاملة والاحترافية (Comprehensive 6-Category Settings Screen):
## مقسمة إلى 6 أقسام حقيقية ومربوطة 100% بالمنطق الفعلي دون أي زر شكلي:
## 1. المظهر (Appearance)
## 2. الصوت (Audio)
## 3. الشخصية (Character)
## 4. الذكاء والتفاعل (AI & Interaction)
## 5. الخصوصية (Privacy)
## 6. التطبيق (Application)

signal ui_preferences_updated
signal navigate_to_customize_requested
signal close_requested

var companion: SlimiInteractionManager
var slime: SlimeController
var room: RoomEnvironment
var hud: HUDController

var current_category: String = "appearance"
var title_label: Label
var btn_close: Button
var tabs_flow: HBoxContainer
var scroll: ScrollContainer
var body_vbox: VBoxContainer
var status_toast_label: Label
var _show_licenses: bool = false


func setup(
	p_companion: SlimiInteractionManager,
	p_slime: SlimeController,
	p_room: RoomEnvironment,
	p_hud: HUDController
) -> void:
	companion = p_companion
	slime = p_slime
	room = p_room
	hud = p_hud
	_build_shell()
	rebuild_category()


func _build_shell() -> void:
	name = "SettingsModal"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	add_child(root_v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_v.add_child(header)

	title_label = Label.new()
	title_label.name = "SettingsTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_label)

	btn_close = Button.new()
	btn_close.name = "BtnClose"
	btn_close.custom_minimum_size = Vector2(88, 36)
	SlimiUIMotion.attach_interactive_feedback(btn_close)
	btn_close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(btn_close)

	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs_scroll.custom_minimum_size = Vector2(0, 44)
	root_v.add_child(tabs_scroll)

	tabs_flow = HBoxContainer.new()
	tabs_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_flow.add_theme_constant_override("separation", 6)
	tabs_scroll.add_child(tabs_flow)

	status_toast_label = Label.new()
	status_toast_label.name = "SettingsStatusLabel"
	status_toast_label.visible = false
	status_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_v.add_child(status_toast_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(body_vbox)


func select_category(cat_id: String) -> void:
	current_category = cat_id
	rebuild_category()


func _show_status_toast(msg: String) -> void:
	if status_toast_label == null:
		return
	status_toast_label.text = msg
	status_toast_label.visible = true


func rebuild_category() -> void:
	if body_vbox == null or tabs_flow == null:
		return
	LocalizationManager.apply_rtl_to_control(self)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	theme = SlimiDesignSystem.build_theme(tokens)
	add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 16, 12))

	title_label.text = LocalizationManager.tr_key("settings_title")
	title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
	title_label.add_theme_color_override("font_color", tokens["text_primary"])

	btn_close.text = LocalizationManager.tr_key("btn_close")
	SlimiUIComponents.style_button_variant(btn_close, tokens, "secondary")
	status_toast_label.add_theme_color_override("font_color", tokens["accent"])

	for tc in tabs_flow.get_children():
		tabs_flow.remove_child(tc)
		tc.queue_free()

	for tab_def in [
		{"id": "appearance", "key": "set_tab_appearance"},
		{"id": "audio", "key": "set_tab_audio"},
		{"id": "character", "key": "set_tab_character"},
		{"id": "ai", "key": "set_tab_ai"},
		{"id": "privacy", "key": "set_tab_privacy"},
		{"id": "app", "key": "set_tab_app"},
	]:
		var tid: String = str(tab_def["id"])
		var tb := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key(str(tab_def["key"])),
			tokens,
			"selected_pill" if current_category == tid else "pill",
			"",
			Vector2(88, 36)
		)
		tb.name = "TabSettings_" + tid
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(func() -> void: select_category(tid))
		tabs_flow.add_child(tb)

	for ch in body_vbox.get_children():
		body_vbox.remove_child(ch)
		ch.queue_free()

	match current_category:
		"appearance":
			_build_cat_appearance(tokens)
		"audio":
			_build_cat_audio(tokens)
		"character":
			_build_cat_character(tokens)
		"ai":
			_build_cat_ai(tokens)
		"privacy":
			_build_cat_privacy(tokens)
		"app":
			_build_cat_app(tokens)


func _build_cat_appearance(tokens: Dictionary) -> void:
	var prefs: Dictionary = SaveManager.get_section("ui_preferences")
	var settings: Dictionary = SaveManager.get_section("settings")
	var is_en: bool = (LocalizationManager.current_locale == "en")

	# الوضع الفاتح / الداكن
	var theme_sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_theme_mode"))
	body_vbox.add_child(theme_sec["card"])
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	(theme_sec["vbox"] as VBoxContainer).add_child(mode_row)

	var dark_now: bool = bool(prefs.get("dark_mode", false))
	var btn_light := SlimiUIComponents.make_styled_button(
		"☀️ " + LocalizationManager.tr_key("set_theme_light"),
		tokens,
		"selected_pill" if not dark_now else "pill",
		"",
		Vector2(0, 40)
	)
	btn_light.name = "BtnThemeLight"
	btn_light.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_light.pressed.connect(func() -> void:
		SaveManager.update_section("ui_preferences", {"dark_mode": false})
		ui_preferences_updated.emit()
		rebuild_category()
	)
	mode_row.add_child(btn_light)

	var btn_dark := SlimiUIComponents.make_styled_button(
		"🌙 " + LocalizationManager.tr_key("set_theme_dark"),
		tokens,
		"selected_pill" if dark_now else "pill",
		"",
		Vector2(0, 40)
	)
	btn_dark.name = "BtnThemeDark"
	btn_dark.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_dark.pressed.connect(func() -> void:
		SaveManager.update_section("ui_preferences", {"dark_mode": true})
		ui_preferences_updated.emit()
		rebuild_category()
	)
	mode_row.add_child(btn_dark)

	# ألوان التمييز وحجم النصوص
	var acc_sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_accent_color"))
	body_vbox.add_child(acc_sec["card"])
	var acc_flow := HFlowContainer.new()
	acc_flow.add_theme_constant_override("h_separation", 8)
	acc_flow.add_theme_constant_override("v_separation", 8)
	(acc_sec["vbox"] as VBoxContainer).add_child(acc_flow)

	for pal_id in SlimiDesignSystem.ACCENT_PALETTES.keys():
		var pal: Dictionary = SlimiDesignSystem.ACCENT_PALETTES[pal_id]
		var sel: bool = (str(prefs.get("accent_palette", "sakura")) == str(pal_id))
		var pb := SlimiUIComponents.make_color_swatch_button(
			pal["primary"],
			str(pal["en"] if is_en else pal["ar"]),
			sel,
			tokens
		)
		pb.name = "BtnAccent_" + str(pal_id)
		var p_key: String = str(pal_id)
		pb.pressed.connect(func() -> void:
			SaveManager.update_section("ui_preferences", {"accent_palette": p_key})
			ui_preferences_updated.emit()
			rebuild_category()
		)
		acc_flow.add_child(pb)

	var txt_row := HBoxContainer.new()
	txt_row.add_theme_constant_override("separation", 8)
	(acc_sec["vbox"] as VBoxContainer).add_child(txt_row)
	var cur_scale: int = clampi(int(prefs.get("text_scale_index", 1)), 0, 2)
	for pair in [[0, "text_size_sm"], [1, "text_size_md"], [2, "text_size_lg"]]:
		var s_idx: int = int(pair[0])
		var sb_btn := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key("set_text_size") + ": " + LocalizationManager.tr_key(str(pair[1])),
			tokens,
			"selected_pill" if cur_scale == s_idx else "pill",
			"",
			Vector2(0, 38)
		)
		sb_btn.name = "BtnTextScale_" + str(s_idx)
		sb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sb_btn.pressed.connect(func() -> void:
			SaveManager.update_section("ui_preferences", {"text_scale_index": s_idx})
			ui_preferences_updated.emit()
			rebuild_category()
		)
		txt_row.add_child(sb_btn)

	# خلفية SLIMI وجودة الرسوميات وتقليل الحركة
	var gfx_sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("quality_label"))
	body_vbox.add_child(gfx_sec["card"])
	var gv: VBoxContainer = gfx_sec["vbox"]

	var bg_row := HFlowContainer.new()
	bg_row.add_theme_constant_override("h_separation", 6)
	bg_row.add_theme_constant_override("v_separation", 6)
	gv.add_child(bg_row)
	var cur_bg: String = str(prefs.get("room_backdrop", "pastel_dream"))
	for bg_id in RoomEnvironment.BACKDROP_THEMES.keys():
		var binfo: Dictionary = RoomEnvironment.BACKDROP_THEMES[bg_id]
		var bb := SlimiUIComponents.make_color_swatch_button(
			binfo["swatch"],
			str(binfo["en"] if is_en else binfo["ar"]),
			cur_bg == str(bg_id),
			tokens
		)
		var bkey: String = str(bg_id)
		bb.pressed.connect(func() -> void:
			SaveManager.update_section("ui_preferences", {"room_backdrop": bkey})
			if room != null:
				room.apply_room_backdrop_theme(bkey)
			rebuild_category()
		)
		bg_row.add_child(bb)

	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 8)
	gv.add_child(q_row)
	for q_pair in [
		[QualityManager.Preset.LOW, "quality_low"],
		[QualityManager.Preset.MEDIUM, "quality_medium"],
		[QualityManager.Preset.HIGH, "quality_high"],
	]:
		var qp: int = int(q_pair[0])
		var qb := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key(str(q_pair[1])),
			tokens,
			"selected_pill" if QualityManager.current_preset == qp else "pill",
			"",
			Vector2(0, 40)
		)
		qb.name = "BtnQuality_" + str(qp)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.pressed.connect(func() -> void:
			QualityManager.apply_preset(qp)
			rebuild_category()
		)
		q_row.add_child(qb)

	SlimiUIComponents.make_toggle_row(
		gv,
		LocalizationManager.tr_key("battery_saver"),
		QualityManager.battery_saver,
		tokens,
		func(on: bool) -> void: QualityManager.set_battery_saver(on)
	)
	SlimiUIComponents.make_toggle_row(
		gv,
		LocalizationManager.tr_key("show_fps"),
		bool(settings.get("show_fps", false)),
		tokens,
		func(on: bool) -> void:
			SaveManager.update_section("settings", {"show_fps": on})
			if hud != null:
				hud.set_show_fps(on)
	)
	SlimiUIComponents.make_toggle_row(
		gv,
		LocalizationManager.tr_key("set_reduce_motion"),
		bool(prefs.get("reduce_motion", false)),
		tokens,
		func(on: bool) -> void: SaveManager.update_section("ui_preferences", {"reduce_motion": on})
	)


func _build_cat_audio(tokens: Dictionary) -> void:
	var s: Dictionary = SaveManager.get_section("settings")
	var sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_tab_audio"))
	body_vbox.add_child(sec["card"])
	var av: VBoxContainer = sec["vbox"]

	SlimiUIComponents.make_toggle_row(
		av,
		LocalizationManager.tr_key("set_master_mute"),
		AudioManager.master_muted,
		tokens,
		func(on: bool) -> void: AudioManager.set_master_muted(on)
	)
	SlimiUIComponents.make_slider_row(
		av,
		LocalizationManager.tr_key("volume_master"),
		0.0, 1.0, 0.05,
		float(s.get("master_volume", 0.90)),
		tokens,
		func(v: float) -> void: AudioManager.set_bus_linear_volume("Master", v)
	)
	SlimiUIComponents.make_slider_row(
		av,
		LocalizationManager.tr_key("set_voice_vol"),
		0.0, 1.0, 0.05,
		float(s.get("voice_volume", 0.90)),
		tokens,
		func(v: float) -> void: AudioManager.set_bus_linear_volume("Voice", v)
	)
	SlimiUIComponents.make_slider_row(
		av,
		LocalizationManager.tr_key("volume_sfx"),
		0.0, 1.0, 0.05,
		float(s.get("sfx_volume", 0.90)),
		tokens,
		func(v: float) -> void: AudioManager.set_bus_linear_volume("SFX", v)
	)
	if companion != null:
		SlimiUIComponents.make_toggle_row(
			av,
			LocalizationManager.tr_key("btn_mute_off"),
			not companion.settings_manager.voice_muted,
			tokens,
			func(on: bool) -> void:
				companion.settings_manager.voice_muted = not on
				companion.settings_manager.persist()
				companion.voice_manager.set_muted(not on)
		)
	SlimiUIComponents.make_toggle_row(
		av,
		LocalizationManager.tr_key("set_expressive_sfx"),
		AudioManager.expressive_sounds_enabled,
		tokens,
		func(on: bool) -> void: AudioManager.set_expressive_sounds_enabled(on)
	)
	SlimiUIComponents.make_toggle_row(
		av,
		LocalizationManager.tr_key("ambient_sound"),
		AudioManager.ambient_enabled,
		tokens,
		func(on: bool) -> void: AudioManager.set_ambient_enabled(on)
	)
	SlimiUIComponents.make_toggle_row(
		av,
		LocalizationManager.tr_key("set_splash_sound"),
		bool(s.get("splash_sound_enabled", true)),
		tokens,
		func(on: bool) -> void: SaveManager.update_section("settings", {"splash_sound_enabled": on})
	)
	SlimiUIComponents.make_toggle_row(
		av,
		LocalizationManager.tr_key("haptics_toggle"),
		AndroidPlatformManager.haptics_enabled,
		tokens,
		func(on: bool) -> void: AndroidPlatformManager.set_haptics_enabled(on)
	)


func _build_cat_character(tokens: Dictionary) -> void:
	var cust: Dictionary = SlimiCustomizationManager.get_saved_config()
	var sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_tab_character"))
	body_vbox.add_child(sec["card"])
	var cv: VBoxContainer = sec["vbox"]

	var lbl_sname := Label.new()
	lbl_sname.text = LocalizationManager.tr_key("onb_slimi_name_label")
	cv.add_child(lbl_sname)

	var sname_edit := LineEdit.new()
	sname_edit.name = "SettingsSlimiNameEdit"
	sname_edit.max_length = 20
	sname_edit.text = str(cust.get("slimi_name", ""))
	sname_edit.placeholder_text = "SLIMI"
	sname_edit.text_changed.connect(func(txt: String) -> void:
		var c: Dictionary = SlimiCustomizationManager.get_saved_config()
		c["slimi_name"] = txt.strip_edges().substr(0, 20)
		SlimiCustomizationManager.save_config(c)
		ui_preferences_updated.emit()
	)
	cv.add_child(sname_edit)

	if companion != null and companion.memory_manager != null:
		var lbl_unick := Label.new()
		lbl_unick.text = LocalizationManager.tr_key("mem_nickname_label")
		cv.add_child(lbl_unick)

		var unick_edit := LineEdit.new()
		unick_edit.name = "SettingsUserNickEdit"
		unick_edit.max_length = 20
		unick_edit.text = companion.memory_manager.user_nickname
		unick_edit.text_changed.connect(func(txt: String) -> void:
			companion.memory_manager.set_user_nickname(txt)
		)
		cv.add_child(unick_edit)

	var btn_jump_cust := SlimiUIComponents.make_styled_button(
		"🎨 " + LocalizationManager.tr_key("customize_title"),
		tokens,
		"primary",
		"",
		Vector2(0, 42)
	)
	btn_jump_cust.pressed.connect(func() -> void: navigate_to_customize_requested.emit())
	cv.add_child(btn_jump_cust)

	SlimiUIComponents.make_slider_row(
		cv,
		LocalizationManager.tr_key("set_move_speed"),
		0.75, 1.30, 0.05,
		float(cust.get("movement_speed_scale", 1.0)),
		tokens,
		func(v: float) -> void:
			var c: Dictionary = SlimiCustomizationManager.get_saved_config()
			c["movement_speed_scale"] = v
			SlimiCustomizationManager.save_config(c)
			if slime != null:
				slime.movement_speed_scale = v
	)

	if companion != null and companion.personality_manager != null:
		SlimiUIComponents.make_slider_row(
			cv,
			LocalizationManager.tr_key("set_activity_lvl"),
			0.15, 1.0, 0.05,
			companion.personality_manager.energy_trait,
			tokens,
			func(v: float) -> void:
				companion.personality_manager.set_trait("energy_trait", v)
				companion.save_companion_state()
		)
		SlimiUIComponents.make_slider_row(
			cv,
			LocalizationManager.tr_key("set_talkative_lvl"),
			0.15, 1.0, 0.05,
			companion.personality_manager.talkativeness,
			tokens,
			func(v: float) -> void:
				companion.personality_manager.set_trait("talkativeness", v)
				companion.personality_manager.set_trait("humor", v)
				companion.save_companion_state()
		)


func _build_cat_ai(tokens: Dictionary) -> void:
	var sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("ai_section_title"))
	body_vbox.add_child(sec["card"])
	var iv: VBoxContainer = sec["vbox"]
	if companion == null:
		return

	var is_online: bool = (companion.settings_manager.ai_mode == "online")
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	iv.add_child(mode_row)

	var btn_off := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("ai_mode_offline"),
		tokens,
		"selected_pill" if not is_online else "pill",
		"",
		Vector2(0, 40)
	)
	btn_off.name = "BtnAIOffline"
	btn_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_off.pressed.connect(func() -> void:
		companion.settings_manager.ai_mode = "offline"
		companion.settings_manager.persist()
		rebuild_category()
	)
	mode_row.add_child(btn_off)

	var btn_on := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("ai_mode_online"),
		tokens,
		"selected_pill" if is_online else "pill",
		"",
		Vector2(0, 40)
	)
	btn_on.name = "BtnAIOnline"
	btn_on.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_on.pressed.connect(func() -> void:
		companion.settings_manager.ai_mode = "online"
		companion.settings_manager.persist()
		rebuild_category()
	)
	mode_row.add_child(btn_on)

	if is_online:
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
		iv.add_child(opt_provider)

		SlimiUIComponents.make_toggle_row(
			iv,
			LocalizationManager.tr_key("ai_consent_toggle"),
			companion.settings_manager.online_user_consent,
			tokens,
			func(on: bool) -> void:
				companion.settings_manager.online_user_consent = on
				companion.settings_manager.persist()
		)
		var key_edit := LineEdit.new()
		key_edit.name = "ApiKeyVaultInput"
		key_edit.secret = true
		key_edit.placeholder_text = LocalizationManager.tr_key("ai_key_placeholder")
		key_edit.text_changed.connect(func(k: String) -> void: companion.settings_manager.set_api_key_secure(k))
		iv.add_child(key_edit)

	SlimiUIComponents.make_toggle_row(
		iv,
		LocalizationManager.tr_key("mem_save_chat_toggle"),
		companion.memory_manager.save_chat_memory_enabled,
		tokens,
		func(on: bool) -> void:
			companion.memory_manager.save_chat_memory_enabled = on
			companion.memory_manager.persist()
	)
	SlimiUIComponents.make_toggle_row(
		iv,
		LocalizationManager.tr_key("set_retain_stats"),
		bool(SaveManager.get_section("ui_preferences").get("retain_interaction_stats", true)),
		tokens,
		func(on: bool) -> void: SaveManager.update_section("ui_preferences", {"retain_interaction_stats": on})
	)
	SlimiUIComponents.make_toggle_row(
		iv,
		LocalizationManager.tr_key("occasions_toggle"),
		companion.settings_manager.occasion_greetings_enabled,
		tokens,
		func(on: bool) -> void:
			companion.settings_manager.occasion_greetings_enabled = on
			companion.settings_manager.persist()
	)


func _build_cat_privacy(tokens: Dictionary) -> void:
	var sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_tab_privacy"))
	body_vbox.add_child(sec["card"])
	var pv: VBoxContainer = sec["vbox"]

	var explain := Label.new()
	explain.text = LocalizationManager.tr_key("set_privacy_explain")
	explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explain.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
	explain.add_theme_color_override("font_color", tokens["text_secondary"])
	pv.add_child(explain)

	if companion != null:
		var btn_revoke_mic := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key("set_revoke_mic"),
			tokens,
			"secondary",
			"",
			Vector2(0, 42)
		)
		btn_revoke_mic.name = "BtnRevokeMic"
		btn_revoke_mic.pressed.connect(func() -> void:
			companion.stop_microphone_listening(false)
			companion.settings_manager.mic_permission_granted_by_user = false
			companion.settings_manager.persist()
			_show_status_toast("✓ Microphone disabled")
		)
		pv.add_child(btn_revoke_mic)

		var btn_disable_online := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key("set_disable_online_all"),
			tokens,
			"secondary",
			"",
			Vector2(0, 42)
		)
		btn_disable_online.name = "BtnDisableAllOnline"
		btn_disable_online.pressed.connect(func() -> void:
			companion.settings_manager.ai_mode = "offline"
			companion.settings_manager.online_user_consent = false
			companion.settings_manager.set_api_key_secure("")
			companion.settings_manager.persist()
			_show_status_toast(LocalizationManager.tr_key("ai_mode_offline"))
		)
		pv.add_child(btn_disable_online)

		var btn_clear_mem := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key("mem_clear_btn"),
			tokens,
			"danger",
			"",
			Vector2(0, 44)
		)
		btn_clear_mem.name = "BtnClearMemory"
		btn_clear_mem.pressed.connect(func() -> void:
			companion.memory_manager.clear_all_memory()
			companion.dialogue_manager.clear_context()
			_show_status_toast("✓ Memory cleared")
		)
		pv.add_child(btn_clear_mem)


func _build_cat_app(tokens: Dictionary) -> void:
	var s: Dictionary = SaveManager.get_section("settings")
	var sec: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("set_tab_app"))
	body_vbox.add_child(sec["card"])
	var apv: VBoxContainer = sec["vbox"]

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	apv.add_child(lang_row)

	var btn_ar := SlimiUIComponents.make_styled_button(
		"العربية (RTL)",
		tokens,
		"selected_pill" if LocalizationManager.current_locale == "ar" else "pill",
		"",
		Vector2(0, 40)
	)
	btn_ar.name = "BtnLangArabic"
	btn_ar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ar.pressed.connect(func() -> void:
		LocalizationManager.set_locale("ar")
		SaveManager.update_section("settings", {"locale": "ar"})
		rebuild_category()
	)
	lang_row.add_child(btn_ar)

	var btn_en := SlimiUIComponents.make_styled_button(
		"English (LTR)",
		tokens,
		"selected_pill" if LocalizationManager.current_locale == "en" else "pill",
		"",
		Vector2(0, 40)
	)
	btn_en.name = "BtnLangEnglish"
	btn_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_en.pressed.connect(func() -> void:
		LocalizationManager.set_locale("en")
		SaveManager.update_section("settings", {"locale": "en"})
		rebuild_category()
	)
	lang_row.add_child(btn_en)

	SlimiUIComponents.make_toggle_row(
		apv,
		LocalizationManager.tr_key("set_notifications"),
		bool(s.get("care_notifications_enabled", true)),
		tokens,
		func(on: bool) -> void:
			SaveManager.update_section("settings", {"care_notifications_enabled": on})
			if companion != null:
				companion.settings_manager.occasion_greetings_enabled = on
				companion.settings_manager.persist()
	)

	var btn_cache := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("set_clear_cache"),
		tokens,
		"secondary",
		"",
		Vector2(0, 42)
	)
	btn_cache.name = "BtnClearTempCache"
	btn_cache.pressed.connect(func() -> void:
		SaveManager.clear_temp_cache()
		_show_status_toast(LocalizationManager.tr_key("set_cache_cleared"))
	)
	apv.add_child(btn_cache)

	var ver_lbl := Label.new()
	ver_lbl.text = LocalizationManager.tr_key("set_version_info")
	ver_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
	ver_lbl.add_theme_color_override("font_color", tokens["text_secondary"])
	apv.add_child(ver_lbl)

	var btn_lic := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("set_licenses_btn"),
		tokens,
		"secondary",
		"",
		Vector2(0, 40)
	)
	btn_lic.name = "BtnToggleLicenses"
	btn_lic.pressed.connect(func() -> void:
		_show_licenses = not _show_licenses
		rebuild_category()
	)
	apv.add_child(btn_lic)

	if _show_licenses:
		var lic_lbl := Label.new()
		lic_lbl.text = LocalizationManager.tr_key("set_licenses_text")
		lic_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lic_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))
		apv.add_child(lic_lbl)

	var btn_reset_all := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("set_reset_all_btn"),
		tokens,
		"danger",
		"",
		Vector2(0, 44)
	)
	btn_reset_all.name = "BtnResetAllSettings"
	btn_reset_all.pressed.connect(func() -> void:
		SaveManager.reset_settings_to_default()
		AudioManager.sync_from_saved_settings()
		QualityManager.apply_preset(QualityManager.Preset.MEDIUM)
		AndroidPlatformManager.set_haptics_enabled(true)
		if room != null:
			room.apply_room_backdrop_theme("pastel_dream")
		ui_preferences_updated.emit()
		_show_status_toast(LocalizationManager.tr_key("set_reset_done"))
		rebuild_category()
	)
	apv.add_child(btn_reset_all)
