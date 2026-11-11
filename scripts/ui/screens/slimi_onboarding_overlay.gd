class_name SlimiOnboardingOverlay
extends Control
## شاشة الترحيب والإعداد الأول الذكية والسريعة (Welcome & Onboarding):
## - تترك النصف العلوي مفتوحاً ليظهر SLIMI ثلاثي الأبعاد حياً ويتفاعل مع اختيارات المستخدم.
## - 3 خطوات قصيرة قابلة للتخطي في أي لحظة:
##   (1) اللغة + اسم SLIMI + لقب المستخدم
##   (2) الصوت ومستوى الرسوميات
##   (3) شرح موجز للخصوصية والذاكرة والميكروفون الاختياري
## - تحفظ جميع التفضيلات فوراً وتستعيدها في كل تشغيل.

signal onboarding_completed

var current_step: int = 0
var slime: SlimeController
var companion: SlimiInteractionManager

var sheet_panel: PanelContainer
var step_dots_hbox: HBoxContainer
var content_vbox: VBoxContainer
var nav_hbox: HBoxContainer

var name_input: LineEdit
var nick_input: LineEdit

var _draft_slimi_name: String = ""
var _draft_user_nick: String = ""


func setup(p_slime: SlimeController, p_companion: SlimiInteractionManager) -> void:
	slime = p_slime
	companion = p_companion
	_draft_slimi_name = str(SaveManager.get_section("customization").get("slimi_name", ""))
	if companion != null and companion.memory_manager != null:
		_draft_user_nick = companion.memory_manager.user_nickname


func _ready() -> void:
	name = "OnboardingOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rebuild_card()


func open_onboarding() -> void:
	current_step = 0
	_draft_slimi_name = str(SaveManager.get_section("customization").get("slimi_name", ""))
	if companion != null and companion.memory_manager != null:
		_draft_user_nick = companion.memory_manager.user_nickname
	visible = true
	_rebuild_card()
	SlimiUIMotion.animate_sheet_open(sheet_panel)
	if slime != null and slime.motion_coordinator != null:
		slime.motion_coordinator.play_cinematic_motion(&"curious_leaning")


func skip_and_finish() -> void:
	_commit_choices_and_close()


func _commit_choices_and_close() -> void:
	_capture_text_inputs()
	var cust: Dictionary = SaveManager.get_section("customization")
	cust["slimi_name"] = _draft_slimi_name.strip_edges().substr(0, 20)
	SaveManager.set_section("customization", cust)

	if companion != null and companion.memory_manager != null and not _draft_user_nick.strip_edges().is_empty():
		companion.memory_manager.set_user_nickname(_draft_user_nick)

	SaveManager.update_section("ui_preferences", {"onboarding_completed": true})
	SaveManager.save_to_disk()
	visible = false
	onboarding_completed.emit()


func _capture_text_inputs() -> void:
	if name_input != null and is_instance_valid(name_input):
		_draft_slimi_name = name_input.text.strip_edges()
	if nick_input != null and is_instance_valid(nick_input):
		_draft_user_nick = nick_input.text.strip_edges()


func _rebuild_card() -> void:
	_capture_text_inputs()
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	LocalizationManager.apply_rtl_to_control(self)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	theme = SlimiDesignSystem.build_theme(tokens)

	# تظليل سفلي خفيف جداً يبقي SLIMI واضحاً تماماً في الأعلى
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.10, 0.04, 0.14, 0.22)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	margin.offset_top = -540
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	sheet_panel = PanelContainer.new()
	sheet_panel.add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 18, 16))
	margin.add_child(sheet_panel)

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 12)
	sheet_panel.add_child(root_v)

	# شريط علوي: مؤشر الخطوات + زر التخطي السريع
	var top_bar := HBoxContainer.new()
	root_v.add_child(top_bar)

	step_dots_hbox = HBoxContainer.new()
	step_dots_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_dots_hbox.add_theme_constant_override("separation", 6)
	for i in range(3):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26 if i == current_step else 10, 8)
		var ds := StyleBoxFlat.new()
		ds.bg_color = tokens["accent"] if i == current_step else tokens["border"]
		ds.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", ds)
		step_dots_hbox.add_child(dot)
	top_bar.add_child(step_dots_hbox)

	var btn_skip := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("btn_skip"),
		tokens,
		"pill",
		"",
		Vector2(110, 34)
	)
	btn_skip.name = "BtnSkipOnboarding"
	btn_skip.pressed.connect(skip_and_finish)
	top_bar.add_child(btn_skip)

	content_vbox = VBoxContainer.new()
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	root_v.add_child(content_vbox)

	if current_step == 0:
		_build_step_identity_and_language(tokens)
	elif current_step == 1:
		_build_step_audio_and_graphics(tokens)
	else:
		_build_step_privacy(tokens)

	nav_hbox = HBoxContainer.new()
	nav_hbox.add_theme_constant_override("separation", 10)
	root_v.add_child(nav_hbox)

	if current_step > 0:
		var btn_prev := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key("btn_back"),
			tokens,
			"secondary",
			"",
			Vector2(110, 46)
		)
		btn_prev.name = "BtnPrevStep"
		btn_prev.pressed.connect(func() -> void:
			current_step = maxi(0, current_step - 1)
			_rebuild_card()
		)
		nav_hbox.add_child(btn_prev)

	var btn_next := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("btn_start_journey" if current_step == 2 else "btn_next"),
		tokens,
		"primary",
		"",
		Vector2(0, 46)
	)
	btn_next.name = "BtnNextStep"
	btn_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_next.pressed.connect(func() -> void:
		if current_step < 2:
			current_step += 1
			if slime != null:
				slime.perform_happy_bounce()
			_rebuild_card()
		else:
			_commit_choices_and_close()
	)
	nav_hbox.add_child(btn_next)


func _build_step_identity_and_language(tokens: Dictionary) -> void:
	var title := Label.new()
	title.text = LocalizationManager.tr_key("onb_welcome_title")
	title.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(20, tokens))
	content_vbox.add_child(title)

	var desc := Label.new()
	desc.text = LocalizationManager.tr_key("onb_welcome_desc")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_color_override("font_color", tokens["text_secondary"])
	content_vbox.add_child(desc)

	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(lang_row)

	var btn_ar := SlimiUIComponents.make_styled_button(
		"العربية (RTL)",
		tokens,
		"selected_pill" if LocalizationManager.current_locale == "ar" else "pill",
		"",
		Vector2(0, 40)
	)
	btn_ar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_ar.pressed.connect(func() -> void:
		_capture_text_inputs()
		LocalizationManager.set_locale("ar")
		SaveManager.update_section("settings", {"locale": "ar"})
		_rebuild_card()
	)
	lang_row.add_child(btn_ar)

	var btn_en := SlimiUIComponents.make_styled_button(
		"English (LTR)",
		tokens,
		"selected_pill" if LocalizationManager.current_locale == "en" else "pill",
		"",
		Vector2(0, 40)
	)
	btn_en.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_en.pressed.connect(func() -> void:
		_capture_text_inputs()
		LocalizationManager.set_locale("en")
		SaveManager.update_section("settings", {"locale": "en"})
		_rebuild_card()
	)
	lang_row.add_child(btn_en)

	var names_grid := GridContainer.new()
	names_grid.columns = 2
	names_grid.add_theme_constant_override("h_separation", 10)
	names_grid.add_theme_constant_override("v_separation", 6)
	content_vbox.add_child(names_grid)

	var l_slimi := Label.new()
	l_slimi.text = LocalizationManager.tr_key("onb_slimi_name_label")
	l_slimi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names_grid.add_child(l_slimi)

	var l_nick := Label.new()
	l_nick.text = LocalizationManager.tr_key("onb_user_nick_label")
	l_nick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names_grid.add_child(l_nick)

	name_input = LineEdit.new()
	name_input.name = "OnbSlimiNameInput"
	name_input.max_length = 20
	name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_input.placeholder_text = LocalizationManager.tr_key("onb_slimi_name_ph")
	name_input.text = _draft_slimi_name
	names_grid.add_child(name_input)

	nick_input = LineEdit.new()
	nick_input.name = "OnbUserNickInput"
	nick_input.max_length = 20
	nick_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nick_input.placeholder_text = LocalizationManager.tr_key("onb_user_nick_ph")
	nick_input.text = _draft_user_nick
	names_grid.add_child(nick_input)


func _build_step_audio_and_graphics(tokens: Dictionary) -> void:
	var title := Label.new()
	title.text = LocalizationManager.tr_key("onb_audio_gfx_title")
	title.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(19, tokens))
	content_vbox.add_child(title)

	var s: Dictionary = SaveManager.get_section("settings")
	SlimiUIComponents.make_slider_row(
		content_vbox,
		LocalizationManager.tr_key("volume_master"),
		0.0, 1.0, 0.05,
		float(s.get("master_volume", 0.90)),
		tokens,
		func(v: float) -> void: AudioManager.set_bus_linear_volume("Master", v)
	)
	SlimiUIComponents.make_slider_row(
		content_vbox,
		LocalizationManager.tr_key("volume_sfx"),
		0.0, 1.0, 0.05,
		float(s.get("sfx_volume", 0.90)),
		tokens,
		func(v: float) -> void:
			AudioManager.set_bus_linear_volume("SFX", v)
			AudioManager.set_bus_linear_volume("Voice", v)
	)

	var q_lbl := Label.new()
	q_lbl.text = LocalizationManager.tr_key("quality_label")
	content_vbox.add_child(q_lbl)

	var q_row := HBoxContainer.new()
	q_row.add_theme_constant_override("separation", 8)
	content_vbox.add_child(q_row)

	for pair in [
		[QualityManager.Preset.LOW, "quality_low"],
		[QualityManager.Preset.MEDIUM, "quality_medium"],
		[QualityManager.Preset.HIGH, "quality_high"],
	]:
		var p_val: int = int(pair[0])
		var q_btn := SlimiUIComponents.make_styled_button(
			LocalizationManager.tr_key(str(pair[1])),
			tokens,
			"selected_pill" if QualityManager.current_preset == p_val else "pill",
			"",
			Vector2(0, 42)
		)
		q_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		q_btn.pressed.connect(func() -> void:
			QualityManager.apply_preset(p_val)
			_rebuild_card()
		)
		q_row.add_child(q_btn)


func _build_step_privacy(tokens: Dictionary) -> void:
	var h_row := HBoxContainer.new()
	h_row.add_theme_constant_override("separation", 10)
	content_vbox.add_child(h_row)

	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(36, 36)
	ic.texture = load("res://assets/icons/ic_shield.svg") as Texture2D
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h_row.add_child(ic)

	var title := Label.new()
	title.text = LocalizationManager.tr_key("onb_privacy_title")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
	h_row.add_child(title)

	var info_card: Dictionary = SlimiUIComponents.make_section_card(tokens)
	var desc := Label.new()
	desc.text = LocalizationManager.tr_key("onb_privacy_desc")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(14, tokens))
	(info_card["vbox"] as VBoxContainer).add_child(desc)
	content_vbox.add_child(info_card["card"])
