class_name SlimiCustomizeScreen
extends PanelContainer
## شاشة تخصيص مظهر SLIMI والغرفة التفاعلية (3D Customization Studio):
## - تترك الجزء العلوي مفتوحاً لمعاينة SLIMI ثلاثي الأبعاد مع تدوير 360 درجة حي.
## - تدعم تغيير لون الجل الهلامي، لون خيط القبعة، إظهار/إخفاء الإكسسوارات، وتبديل خلفية الغرفة.
## - تفصل بين المعاينة الحية المؤقتة (Preview) والحفظ الدائم (Save) واستعادة المظهر الأصلي (Restore Default).

signal room_backdrop_requested(theme_id: String, persist: bool)

var slime: SlimeController
var room: RoomEnvironment
var hud: HUDController

var title_label: Label
var scroll: ScrollContainer
var body_vbox: VBoxContainer
var rotate_slider: HSlider

var _preview_cfg: Dictionary = {}
var _preview_backdrop: String = "pastel_dream"
var _has_unsaved_changes: bool = false
var _base_yaw: float = 0.0


func setup(p_slime: SlimeController, p_room: RoomEnvironment, p_hud: HUDController) -> void:
	slime = p_slime
	room = p_room
	hud = p_hud
	_build_ui()
	sync_from_saved()


func _build_ui() -> void:
	name = "CustomizeScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	add_child(root_v)

	title_label = Label.new()
	title_label.name = "CustomizeTitle"
	root_v.add_child(title_label)

	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(scroll)

	body_vbox = VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(body_vbox)


func _get_visual_root() -> Node3D:
	return slime.get_node_or_null("VisualRoot") as Node3D if slime != null else null


func on_screen_opened() -> void:
	var vr := _get_visual_root()
	if vr != null:
		_base_yaw = vr.rotation.y
	sync_from_saved()


func on_screen_closed() -> void:
	if _has_unsaved_changes:
		revert_unsaved_preview()
	var vr := _get_visual_root()
	if vr != null:
		vr.rotation.y = _base_yaw


func sync_from_saved() -> void:
	_preview_cfg = SlimiCustomizationManager.get_saved_config()
	_preview_backdrop = str(SaveManager.get_section("ui_preferences").get("room_backdrop", "pastel_dream"))
	_has_unsaved_changes = false
	rebuild_controls()


func revert_unsaved_preview() -> void:
	var saved_cfg: Dictionary = SlimiCustomizationManager.get_saved_config()
	if slime != null:
		SlimiCustomizationManager.apply_to_slime(slime, room, saved_cfg)
	var saved_bg: String = str(SaveManager.get_section("ui_preferences").get("room_backdrop", "pastel_dream"))
	if room != null:
		room.apply_room_backdrop_theme(saved_bg)
	_preview_cfg = saved_cfg
	_preview_backdrop = saved_bg
	_has_unsaved_changes = false


func rotate_preview_by_degrees(deg_delta: float) -> void:
	var vr := _get_visual_root()
	if vr == null:
		return
	var current_deg: float = rad_to_deg(vr.rotation.y - _base_yaw)
	var next_deg: float = wrapf(current_deg + deg_delta, -180.0, 180.0)
	vr.rotation.y = _base_yaw + deg_to_rad(next_deg)
	if rotate_slider != null:
		rotate_slider.set_value_no_signal(next_deg)


func apply_live_preview() -> void:
	_has_unsaved_changes = true
	if slime != null:
		SlimiCustomizationManager.apply_to_slime(slime, room, _preview_cfg)
	if room != null:
		room.apply_room_backdrop_theme(_preview_backdrop)


func save_current_look() -> void:
	SlimiCustomizationManager.save_config(_preview_cfg)
	SaveManager.update_section("ui_preferences", {"room_backdrop": _preview_backdrop})
	SaveManager.save_to_disk()
	_has_unsaved_changes = false
	room_backdrop_requested.emit(_preview_backdrop, true)
	if slime != null:
		SlimiCustomizationManager.apply_to_slime(slime, room, _preview_cfg)
		slime.perform_happy_bounce()
	if hud != null:
		hud.show_bubble_by_key("msg_look_saved", 3.2)
	rebuild_controls()


func restore_default_look() -> void:
	_preview_cfg = SlimiCustomizationManager.reset_to_default()
	_preview_backdrop = "pastel_dream"
	SaveManager.update_section("ui_preferences", {"room_backdrop": "pastel_dream"})
	SaveManager.save_to_disk()
	_has_unsaved_changes = false
	if slime != null:
		SlimiCustomizationManager.apply_to_slime(slime, room, _preview_cfg)
		var vr := _get_visual_root()
		if vr != null:
			vr.rotation.y = _base_yaw
		slime.perform_happy_bounce()
	if room != null:
		room.apply_room_backdrop_theme("pastel_dream")
	if hud != null:
		hud.show_bubble_by_key("msg_look_reset", 3.2)
	rebuild_controls()


func rebuild_controls() -> void:
	if body_vbox == null:
		return
	for ch in body_vbox.get_children():
		body_vbox.remove_child(ch)
		ch.queue_free()

	LocalizationManager.apply_rtl_to_control(self)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 16, 12))

	title_label.text = LocalizationManager.tr_key("customize_title")
	title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
	title_label.add_theme_color_override("font_color", tokens["text_primary"])

	var is_en: bool = (LocalizationManager.current_locale == "en")

	# 1. شريط التدوير ثلاثي الأبعاد 360°
	var rot_card: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("customize_rotate_lbl"))
	body_vbox.add_child(rot_card["card"])
	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 8)
	(rot_card["vbox"] as VBoxContainer).add_child(rot_row)

	var btn_rot_l := SlimiUIComponents.make_styled_button("↺ 45°", tokens, "secondary", "", Vector2(74, 38))
	btn_rot_l.name = "BtnRotateLeft"
	btn_rot_l.pressed.connect(func() -> void: rotate_preview_by_degrees(-45.0))
	rot_row.add_child(btn_rot_l)

	var cur_vr := _get_visual_root()
	rotate_slider = HSlider.new()
	rotate_slider.name = "RotateSlider360"
	rotate_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotate_slider.min_value = -180.0
	rotate_slider.max_value = 180.0
	rotate_slider.step = 1.0
	rotate_slider.value = rad_to_deg((cur_vr.rotation.y - _base_yaw) if cur_vr != null else 0.0)
	rotate_slider.value_changed.connect(func(deg_v: float) -> void:
		var vr := _get_visual_root()
		if vr != null:
			vr.rotation.y = _base_yaw + deg_to_rad(deg_v)
	)
	rot_row.add_child(rotate_slider)

	var btn_rot_r := SlimiUIComponents.make_styled_button("45° ↻", tokens, "secondary", "", Vector2(74, 38))
	btn_rot_r.name = "BtnRotateRight"
	btn_rot_r.pressed.connect(func() -> void: rotate_preview_by_degrees(45.0))
	rot_row.add_child(btn_rot_r)

	# 2. لون الجل الهلامي (يحافظ على شفافية الجل ولمعة المجرة في العيون)
	var gel_card: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("customize_gel_lbl"))
	body_vbox.add_child(gel_card["card"])
	var gel_flow := HFlowContainer.new()
	gel_flow.add_theme_constant_override("h_separation", 8)
	gel_flow.add_theme_constant_override("v_separation", 8)
	(gel_card["vbox"] as VBoxContainer).add_child(gel_flow)

	for gid in SlimiCustomizationManager.GEL_PRESETS.keys():
		var g_info: Dictionary = SlimiCustomizationManager.GEL_PRESETS[gid]
		var is_sel: bool = (str(_preview_cfg.get("gel_preset", "sakura_pink")) == str(gid))
		var g_btn := SlimiUIComponents.make_color_swatch_button(
			g_info["swatch"],
			str(g_info["en"] if is_en else g_info["ar"]),
			is_sel,
			tokens
		)
		g_btn.name = "BtnGel_" + str(gid)
		var g_key: String = str(gid)
		g_btn.pressed.connect(func() -> void:
			_preview_cfg["gel_preset"] = g_key
			apply_live_preview()
			rebuild_controls()
		)
		gel_flow.add_child(g_btn)

	# 3. لون خيط القبعة الصوفية (مع خيار إخفاء القبعة)
	var hat_card: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("customize_hat_lbl"))
	body_vbox.add_child(hat_card["card"])
	var hat_flow := HFlowContainer.new()
	hat_flow.add_theme_constant_override("h_separation", 8)
	hat_flow.add_theme_constant_override("v_separation", 8)
	(hat_card["vbox"] as VBoxContainer).add_child(hat_flow)

	for bid in SlimiCustomizationManager.BEANIE_PRESETS.keys():
		var b_info: Dictionary = SlimiCustomizationManager.BEANIE_PRESETS[bid]
		var is_sel: bool = (str(_preview_cfg.get("beanie_preset", "sunny_yellow")) == str(bid))
		var b_btn := SlimiUIComponents.make_color_swatch_button(
			b_info["swatch"],
			str(b_info["en"] if is_en else b_info["ar"]),
			is_sel,
			tokens
		)
		b_btn.name = "BtnBeanie_" + str(bid)
		var b_key: String = str(bid)
		b_btn.pressed.connect(func() -> void:
			_preview_cfg["beanie_preset"] = b_key
			apply_live_preview()
			rebuild_controls()
		)
		hat_flow.add_child(b_btn)

	# 4. الإكسسوارات المميزة (الزهرة، دبوس القلب، نجمة القرن)
	var acc_card: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("customize_acc_lbl"))
	body_vbox.add_child(acc_card["card"])
	var acc_row := HBoxContainer.new()
	acc_row.add_theme_constant_override("separation", 8)
	(acc_card["vbox"] as VBoxContainer).add_child(acc_row)

	for acc_item in [
		{"field": "show_flower", "key": "acc_flower"},
		{"field": "show_heart_pin", "key": "acc_heart"},
		{"field": "show_star_charm", "key": "acc_star"},
	]:
		var f_name: String = str(acc_item["field"])
		var active_acc: bool = bool(_preview_cfg.get(f_name, true))
		var ab := SlimiUIComponents.make_styled_button(
			("✓ " if active_acc else "○ ") + LocalizationManager.tr_key(str(acc_item["key"])),
			tokens,
			"selected_pill" if active_acc else "pill",
			"",
			Vector2(0, 40)
		)
		ab.name = "BtnToggle_" + f_name
		ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ab.pressed.connect(func() -> void:
			_preview_cfg[f_name] = not bool(_preview_cfg.get(f_name, true))
			apply_live_preview()
			rebuild_controls()
		)
		acc_row.add_child(ab)

	# 5. خلفية الغرفة والإضاءة الجوية
	var bg_card: Dictionary = SlimiUIComponents.make_section_card(tokens, LocalizationManager.tr_key("customize_bg_lbl"))
	body_vbox.add_child(bg_card["card"])
	var bg_flow := HFlowContainer.new()
	bg_flow.add_theme_constant_override("h_separation", 8)
	bg_flow.add_theme_constant_override("v_separation", 8)
	(bg_card["vbox"] as VBoxContainer).add_child(bg_flow)

	for bg_id in RoomEnvironment.BACKDROP_THEMES.keys():
		var bg_info: Dictionary = RoomEnvironment.BACKDROP_THEMES[bg_id]
		var is_bg_sel: bool = (_preview_backdrop == str(bg_id))
		var bg_btn := SlimiUIComponents.make_color_swatch_button(
			bg_info["swatch"],
			str(bg_info["en"] if is_en else bg_info["ar"]),
			is_bg_sel,
			tokens
		)
		bg_btn.name = "BtnBackdrop_" + str(bg_id)
		var bg_key: String = str(bg_id)
		bg_btn.pressed.connect(func() -> void:
			_preview_backdrop = bg_key
			apply_live_preview()
			rebuild_controls()
		)
		bg_flow.add_child(bg_btn)

	# 6. أزرار حفظ المظهر واستعادة الافتراضي
	var actions_row := HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 10)
	body_vbox.add_child(actions_row)

	var btn_reset := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("btn_reset_look"),
		tokens,
		"secondary",
		"",
		Vector2(0, 46)
	)
	btn_reset.name = "BtnResetDefaultLook"
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.pressed.connect(restore_default_look)
	actions_row.add_child(btn_reset)

	var btn_save := SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("btn_save_look"),
		tokens,
		"primary",
		"",
		Vector2(0, 46)
	)
	btn_save.name = "BtnSaveCustomizeLook"
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.pressed.connect(save_current_look)
	actions_row.add_child(btn_save)
