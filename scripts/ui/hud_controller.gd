class_name HUDController
extends CanvasLayer
## المتحكم الموحد للواجهة والتنقل في SLIMI (Premium HUD & 5-Screen Navigation Controller):
## يدير الشاشة الرئيسية، شريط التنقل السفلي الموحد (5 شاشات)، شاشة البداية، الإعداد الأول،
## المحادثة، الأنشطة، التخصيص، الإعدادات المتكاملة، نافذة تأكيد الخروج، ودعم RTL/LTR وSafe Area.

signal action_feed_requested
signal action_play_requested
signal action_nap_requested
signal action_call_requested
signal screen_changed(screen_id: String)
signal ui_button_interacted(screen_pos: Vector2)
signal exit_app_confirmed

const NAV_TABS: Array[Dictionary] = [
	{"id": "home", "key": "nav_home", "icon": "res://assets/icons/ic_home.svg"},
	{"id": "chat", "key": "nav_chat", "icon": "res://assets/icons/ic_chat.svg"},
	{"id": "activities", "key": "nav_activities", "icon": "res://assets/icons/ic_play.svg"},
	{"id": "customize", "key": "nav_customize", "icon": "res://assets/icons/ic_customize.svg"},
	{"id": "settings", "key": "nav_settings", "icon": "res://assets/icons/ic_settings.svg"},
]

@onready var hud_root: Control = $HUDRoot
@onready var root_margin: MarginContainer = $HUDRoot/SafeMargin
@onready var main_column: VBoxContainer = $HUDRoot/SafeMargin/MainLayout
@onready var top_bar: HBoxContainer = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow
@onready var utility_buttons: HBoxContainer = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/UtilityButtons
@onready var brand_card: PanelContainer = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/IdentityCard
@onready var title_label: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/IdentityCard/IdentityHBox/IdentityVBox/TitleRow/TitleLabel
@onready var fps_label: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/IdentityCard/IdentityHBox/IdentityVBox/TitleRow/FPSLabel
@onready var mood_label: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/IdentityCard/IdentityHBox/IdentityVBox/MoodLabel
@onready var btn_memory: Button = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/UtilityButtons/BtnMemory
@onready var btn_settings: Button = $HUDRoot/SafeMargin/MainLayout/TopSection/HeaderRow/UtilityButtons/BtnSettings

@onready var stats_panel: PanelContainer = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard
@onready var lbl_happiness: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatHappyRow/LblHappiness
@onready var bar_happiness: TextureProgressBar = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatHappyRow/BarHappiness
@onready var lbl_energy: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatEnergyRow/LblEnergy
@onready var bar_energy: TextureProgressBar = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatEnergyRow/BarEnergy
@onready var lbl_fullness: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatFullnessRow/LblFullness
@onready var bar_fullness: TextureProgressBar = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatFullnessRow/BarFullness
@onready var lbl_bond: Label = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatBondRow/LblBond
@onready var bar_bond: TextureProgressBar = $HUDRoot/SafeMargin/MainLayout/TopSection/StatsCard/StatsGrid/StatBondRow/BarBond

@onready var bubble_panel: PanelContainer = $HUDRoot/SafeMargin/MainLayout/CenterArea/BubblePanel
@onready var bubble_label: Label = $HUDRoot/SafeMargin/MainLayout/CenterArea/BubblePanel/BubbleLabel
@onready var bottom_section: VBoxContainer = $HUDRoot/SafeMargin/MainLayout/BottomSection
@onready var hint_label: Label = $HUDRoot/SafeMargin/MainLayout/BottomSection/HintLabel

@onready var bottom_dock: PanelContainer = $HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock
@onready var btn_feed: Button = $HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnFeed
@onready var btn_play: Button = $HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnPlay
@onready var btn_nap: Button = $HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnNap
@onready var btn_call: Button = $HUDRoot/SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnCall

@onready var legacy_settings_modal: Control = $HUDRoot/SettingsModal
@onready var memory_modal: Control = $HUDRoot/MemoryModal
@onready var lbl_memory_title: Label = $HUDRoot/MemoryModal/Card/VBox/MemoryTitle
@onready var mem_sessions_lbl: Label = $HUDRoot/MemoryModal/Card/VBox/MemSessions
@onready var mem_pokes_lbl: Label = $HUDRoot/MemoryModal/Card/VBox/MemPokes
@onready var mem_pets_lbl: Label = $HUDRoot/MemoryModal/Card/VBox/MemPets
@onready var mem_feeds_lbl: Label = $HUDRoot/MemoryModal/Card/VBox/MemFeeds
@onready var mem_plays_lbl: Label = $HUDRoot/MemoryModal/Card/VBox/MemPlays
@onready var btn_close_memory: Button = $HUDRoot/MemoryModal/Card/VBox/BtnCloseMemoryBtn

# المرجع المعتمد لنافذة الإعدادات (يشير إلى شاشة الإعدادات الحديثة مع حفظ توافق الاختبارات)
var settings_modal: PanelContainer

# الشاشات والمكونات الجديدة
var current_screen: String = "home"
var btn_bg_cycle: Button
var btn_stats_toggle: Button
var bottom_nav_bar: PanelContainer
var nav_buttons: Dictionary = {}

var screen_sheet_host: MarginContainer
var chat_screen: SlimiChatScreen
var activities_screen: SlimiActivitiesScreen
var customize_screen: SlimiCustomizeScreen
var settings_screen: SlimiSettingsScreen
var splash_screen: SlimiSplashScreen
var onboarding_overlay: SlimiOnboardingOverlay
var exit_modal: SlimiExitModal
var mic_banner: PanelContainer

var companion_ref: SlimiInteractionManager
var slime_ref: SlimeController
var room_ref: RoomEnvironment
var companion_ui: Dictionary = {}

var _nav_history: Array[String] = []
var _stats_expanded_on_home: bool = true
var _bubble_timer: float = 0.0
var _show_fps: bool = false
var _last_kb_inset: int = -1


func _ready() -> void:
	hud_root.clip_contents = true
	if legacy_settings_modal != null:
		legacy_settings_modal.visible = false

	_setup_progress_bar_textures()
	_setup_home_header_extras()
	_setup_action_icons()
	_setup_mic_banner()
	_setup_bottom_navigation_bar()
	_setup_overlays()
	_connect_home_buttons()

	var saved_settings: Dictionary = SaveManager.get_section("settings")
	_show_fps = bool(saved_settings.get("show_fps", false))
	fps_label.visible = _show_fps
	bubble_panel.visible = false
	memory_modal.visible = false

	LocalizationManager.locale_changed.connect(_on_locale_changed)
	if get_viewport() != null:
		get_viewport().size_changed.connect(_apply_safe_area_and_keyboard_margins)

	apply_design_system()
	_apply_safe_area_and_keyboard_margins()
	_refresh_localized_texts()


func bind_companion_system(
	companion: SlimiInteractionManager,
	slime: SlimeController = null,
	room: RoomEnvironment = null
) -> void:
	companion_ref = companion
	slime_ref = slime if slime != null else companion.slime
	room_ref = room

	if screen_sheet_host == null:
		screen_sheet_host = MarginContainer.new()
		screen_sheet_host.name = "ScreenSheetHost"
		screen_sheet_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen_sheet_host.anchor_top = 0.36
		screen_sheet_host.offset_left = 14
		screen_sheet_host.offset_right = -14
		screen_sheet_host.offset_bottom = -94
		screen_sheet_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud_root.add_child(screen_sheet_host)

	chat_screen = SlimiChatScreen.new()
	screen_sheet_host.add_child(chat_screen)
	chat_screen.setup(companion_ref, slime_ref)

	activities_screen = SlimiActivitiesScreen.new()
	screen_sheet_host.add_child(activities_screen)
	activities_screen.setup(companion_ref, slime_ref, self)

	customize_screen = SlimiCustomizeScreen.new()
	screen_sheet_host.add_child(customize_screen)
	customize_screen.setup(slime_ref, room_ref, self)

	settings_screen = SlimiSettingsScreen.new()
	screen_sheet_host.add_child(settings_screen)
	settings_screen.setup(companion_ref, slime_ref, room_ref, self)
	settings_screen.ui_preferences_updated.connect(apply_design_system)
	settings_screen.navigate_to_customize_requested.connect(func() -> void: navigate_to("customize"))
	settings_screen.close_requested.connect(func() -> void: navigate_to("home"))
	settings_modal = settings_screen

	onboarding_overlay.setup(slime_ref, companion_ref)

	# ربط إشارات الرفيق بالمؤشر الحي والفقاعات والمشاعر
	companion_ref.emotion_manager.emotion_changed.connect(func(_id: int, profile: Dictionary) -> void:
		var lbl_txt: String = str(profile.get("en" if LocalizationManager.current_locale == "en" else "ar", ""))
		if not lbl_txt.is_empty():
			mood_label.text = lbl_txt
	)
	companion_ref.mic_state_changed.connect(func(listening: bool, _rms: float) -> void:
		if mic_banner != null:
			mic_banner.visible = listening
	)
	companion_ref.companion_event_emitted.connect(func(ev_type: StringName, payload: Dictionary) -> void:
		if ev_type == &"dialogue_reply":
			var reply_txt: String = str(payload.get("text", ""))
			if not reply_txt.is_empty() and current_screen != "chat":
				show_bubble_text(reply_txt, 4.4)
	)

	companion_ui["mic_banner"] = mic_banner
	companion_ui["chat_modal"] = chat_screen
	companion_ui["games_modal"] = activities_screen

	# أبقِ نوافذ الإغلاق والترحيب فوق مضيف الشاشات دائماً
	hud_root.move_child(memory_modal, hud_root.get_child_count() - 1)
	hud_root.move_child(onboarding_overlay, hud_root.get_child_count() - 1)
	hud_root.move_child(exit_modal, hud_root.get_child_count() - 1)
	hud_root.move_child(splash_screen, hud_root.get_child_count() - 1)

	apply_design_system()
	_refresh_localized_texts()


func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			bubble_panel.visible = false

	if _show_fps:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()

	var kb_px: int = AndroidPlatformManager.get_virtual_keyboard_bottom_inset()
	if kb_px != _last_kb_inset:
		_last_kb_inset = kb_px
		_apply_safe_area_and_keyboard_margins()


func navigate_to(screen_id: String, push_history: bool = true) -> void:
	var valid_ids: Array[String] = ["home", "chat", "activities", "customize", "settings"]
	if not (screen_id in valid_ids):
		screen_id = "home"

	if screen_id == current_screen:
		if screen_id == "settings" and settings_screen != null and not settings_screen.visible:
			settings_screen.visible = true
		return

	if push_history and current_screen != screen_id:
		if _nav_history.is_empty() or _nav_history.back() != current_screen:
			_nav_history.append(current_screen)
		while _nav_history.size() > 12:
			_nav_history.pop_front()

	if current_screen == "customize" and customize_screen != null:
		customize_screen.on_screen_closed()

	current_screen = screen_id
	memory_modal.visible = false

	var on_home: bool = (current_screen == "home")
	bottom_dock.visible = on_home
	hint_label.visible = on_home
	stats_panel.visible = on_home and _stats_expanded_on_home

	var map_screens: Dictionary = {
		"chat": chat_screen,
		"activities": activities_screen,
		"customize": customize_screen,
		"settings": settings_screen,
	}
	for sid in map_screens.keys():
		var ctrl: Control = map_screens[sid] as Control
		if ctrl == null:
			continue
		if sid == current_screen:
			if sid == "customize":
				customize_screen.on_screen_opened()
			elif sid == "activities":
				activities_screen.rebuild_content()
			elif sid == "settings":
				settings_screen.rebuild_category()
			SlimiUIMotion.animate_sheet_open(ctrl)
		else:
			SlimiUIMotion.animate_sheet_close(ctrl)

	_refresh_nav_active_states()
	screen_changed.emit(current_screen)


func handle_back_navigation() -> bool:
	if splash_screen != null and splash_screen.visible:
		splash_screen.finish_immediately()
		return true
	if onboarding_overlay != null and onboarding_overlay.visible:
		onboarding_overlay.skip_and_finish()
		return true
	if exit_modal != null and exit_modal.visible:
		exit_modal.close_modal()
		return true
	if memory_modal != null and memory_modal.visible:
		memory_modal.visible = false
		return true
	if current_screen != "home" or (settings_modal != null and settings_modal.visible):
		var target_prev: String = "home"
		while not _nav_history.is_empty():
			var cand: String = _nav_history.pop_back()
			if cand != current_screen:
				target_prev = cand
				break
		if settings_modal != null:
			settings_modal.visible = false
		navigate_to(target_prev, false)
		return true

	# نحن في الشاشة الرئيسية -> افتح نافذة تأكيد الخروج الهادئة
	if exit_modal != null:
		exit_modal.open_modal()
		return true
	return false


func close_modals() -> void:
	if legacy_settings_modal != null:
		legacy_settings_modal.visible = false
	if settings_modal != null:
		settings_modal.visible = false
	if memory_modal != null:
		memory_modal.visible = false
	if exit_modal != null:
		exit_modal.close_modal()
	if onboarding_overlay != null:
		onboarding_overlay.visible = false
	_nav_history.clear()
	if current_screen != "home":
		navigate_to("home", false)


func is_point_blocked_by_ui(screen_pos: Vector2) -> bool:
	if splash_screen != null and splash_screen.visible:
		return true
	if onboarding_overlay != null and onboarding_overlay.visible:
		return true
	if exit_modal != null and exit_modal.visible:
		return true
	if memory_modal != null and memory_modal.visible:
		return true
	if settings_modal != null and settings_modal.visible:
		return true

	for sheet in [chat_screen, activities_screen, customize_screen]:
		if sheet != null and sheet.visible and sheet.get_global_rect().has_point(screen_pos):
			return true

	if bottom_nav_bar != null and bottom_nav_bar.visible and bottom_nav_bar.get_global_rect().has_point(screen_pos):
		return true
	if bottom_dock != null and bottom_dock.visible and bottom_dock.get_global_rect().has_point(screen_pos):
		return true
	if top_bar != null and top_bar.visible and top_bar.get_global_rect().has_point(screen_pos):
		return true
	if stats_panel != null and stats_panel.visible and stats_panel.get_global_rect().has_point(screen_pos):
		return true
	return false


func set_show_fps(enabled: bool) -> void:
	_show_fps = enabled
	if fps_label != null:
		fps_label.visible = _show_fps


func update_stats_snapshot(snap: Dictionary) -> void:
	update_stats(
		float(snap.get("happiness", 80.0)),
		float(snap.get("energy", 80.0)),
		float(snap.get("fullness", 80.0)),
		float(snap.get("affection", 25.0)),
		str(snap.get("mood_key", "mood_happy"))
	)


func update_stats(happiness: float, energy: float, fullness: float, bond: float, mood_key: String) -> void:
	bar_happiness.value = happiness
	bar_energy.value = energy
	bar_fullness.value = fullness
	bar_bond.value = bond
	mood_label.text = LocalizationManager.tr_key(mood_key)


func update_memory_view(memory: Variant) -> void:
	var pokes: int = 0
	var pets: int = 0
	var feeds: int = 0
	var plays: int = 0
	var sessions: int = 1
	if memory is SlimeMemory:
		var sm := memory as SlimeMemory
		pokes = sm.total_pokes
		pets = sm.total_pets
		feeds = sm.total_feeds
		plays = sm.total_plays
		sessions = sm.sessions_count
	elif memory is Dictionary:
		var d: Dictionary = memory
		pokes = int(d.get("total_pokes", 0))
		pets = int(d.get("total_pets", 0))
		feeds = int(d.get("total_feeds", 0))
		plays = int(d.get("total_plays", 0))
		sessions = int(d.get("sessions", d.get("sessions_count", 1)))

	mem_sessions_lbl.text = LocalizationManager.tr_key("mem_sessions", {"n": sessions})
	mem_pokes_lbl.text = LocalizationManager.tr_key("mem_pokes", {"n": pokes})
	mem_pets_lbl.text = LocalizationManager.tr_key("mem_pets", {"n": pets})
	mem_feeds_lbl.text = LocalizationManager.tr_key("mem_feeds", {"n": feeds})
	mem_plays_lbl.text = LocalizationManager.tr_key("mem_plays", {"n": plays})


func show_bubble_by_key(key: String, duration: float = 3.2) -> void:
	show_bubble_text(LocalizationManager.tr_key(key), duration)


func show_bubble_text(text: String, duration: float = 3.2) -> void:
	bubble_label.text = text
	bubble_panel.visible = true
	_bubble_timer = duration
	if not SlimiUIMotion.is_reduce_motion() and is_inside_tree():
		bubble_panel.pivot_offset = bubble_panel.size * 0.5
		bubble_panel.scale = Vector2(0.86, 0.86)
		var tw := create_tween()
		tw.tween_property(bubble_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func cycle_room_backdrop() -> void:
	if room_ref == null:
		return
	var keys: Array = RoomEnvironment.BACKDROP_THEMES.keys()
	var idx: int = keys.find(room_ref.current_backdrop_id)
	var next_id: String = str(keys[(idx + 1) % keys.size()])
	room_ref.apply_room_backdrop_theme(next_id)
	SaveManager.update_section("ui_preferences", {"room_backdrop": next_id})


func apply_design_system() -> void:
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	hud_root.theme = SlimiDesignSystem.build_theme(tokens)

	var glass_sb: StyleBoxFlat = SlimiDesignSystem.make_hud_glass_style(tokens, 22, 12, 8)
	brand_card.add_theme_stylebox_override("panel", glass_sb)
	stats_panel.add_theme_stylebox_override("panel", SlimiDesignSystem.make_hud_glass_style(tokens, 20, 12, 8))
	bottom_dock.add_theme_stylebox_override("panel", SlimiDesignSystem.make_hud_glass_style(tokens, 24, 10, 8))
	bubble_panel.add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, 22, true, 16, 10))
	if bottom_nav_bar != null:
		bottom_nav_bar.add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, 26, true, 10, 8))

	title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
	title_label.add_theme_color_override("font_color", tokens["text_primary"])
	mood_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
	mood_label.add_theme_color_override("font_color", tokens["accent"])
	hint_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))
	hint_label.add_theme_color_override("font_color", tokens["text_secondary"])
	bubble_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(15, tokens))
	bubble_label.add_theme_color_override("font_color", tokens["text_primary"])

	for top_btn in [btn_bg_cycle, btn_stats_toggle, btn_memory, btn_settings]:
		if top_btn != null:
			SlimiUIComponents.style_button_variant(top_btn, tokens, "secondary")

	for care_btn in [btn_feed, btn_play, btn_nap, btn_call]:
		if care_btn != null:
			SlimiUIComponents.style_button_variant(care_btn, tokens, "secondary")
			care_btn.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))

	if chat_screen != null:
		chat_screen.apply_design_tokens()
	if activities_screen != null:
		activities_screen.rebuild_content()
	if customize_screen != null:
		customize_screen.rebuild_controls()
	if settings_screen != null:
		settings_screen.rebuild_category()

	title_label.text = SlimiCustomizationManager.get_display_name()
	_refresh_nav_active_states()


func _setup_home_header_extras() -> void:
	btn_bg_cycle = Button.new()
	btn_bg_cycle.name = "BtnCycleBackdrop"
	btn_bg_cycle.text = "🌅"
	btn_bg_cycle.custom_minimum_size = Vector2(46, 48)
	SlimiUIMotion.attach_interactive_feedback(btn_bg_cycle)
	btn_bg_cycle.pressed.connect(func() -> void:
		_emit_button_gaze(btn_bg_cycle)
		cycle_room_backdrop()
	)
	utility_buttons.add_child(btn_bg_cycle)
	utility_buttons.move_child(btn_bg_cycle, 0)

	btn_stats_toggle = Button.new()
	btn_stats_toggle.name = "BtnToggleStats"
	btn_stats_toggle.text = "📊"
	btn_stats_toggle.custom_minimum_size = Vector2(46, 48)
	SlimiUIMotion.attach_interactive_feedback(btn_stats_toggle)
	btn_stats_toggle.pressed.connect(func() -> void:
		_emit_button_gaze(btn_stats_toggle)
		_stats_expanded_on_home = not _stats_expanded_on_home
		if current_screen == "home":
			stats_panel.visible = _stats_expanded_on_home
	)
	utility_buttons.add_child(btn_stats_toggle)
	utility_buttons.move_child(btn_stats_toggle, 1)


func _setup_mic_banner() -> void:
	mic_banner = PanelContainer.new()
	mic_banner.name = "MicLiveBanner"
	mic_banner.visible = false
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.95, 0.25, 0.44, 0.92)
	ms.set_corner_radius_all(14)
	ms.content_margin_left = 12
	ms.content_margin_right = 12
	ms.content_margin_top = 5
	ms.content_margin_bottom = 5
	mic_banner.add_theme_stylebox_override("panel", ms)

	var ml := Label.new()
	ml.name = "MicBannerLabel"
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ml.add_theme_color_override("font_color", Color.WHITE)
	ml.add_theme_font_size_override("font_size", 13)
	mic_banner.add_child(ml)

	main_column.add_child(mic_banner)
	main_column.move_child(mic_banner, 3)


func _setup_bottom_navigation_bar() -> void:
	bottom_nav_bar = PanelContainer.new()
	bottom_nav_bar.name = "BottomNavBar"
	bottom_nav_bar.custom_minimum_size = Vector2(0, 62)
	bottom_section.add_child(bottom_nav_bar)

	var nav_row := HBoxContainer.new()
	nav_row.name = "NavRow"
	nav_row.add_theme_constant_override("separation", 6)
	bottom_nav_bar.add_child(nav_row)

	for tab in NAV_TABS:
		var tid: String = str(tab["id"])
		var btn := Button.new()
		btn.name = "NavBtn_" + tid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 50)
		btn.icon = load(str(tab["icon"])) as Texture2D
		btn.expand_icon = true
		btn.set_meta("tr_key", tab["key"])
		SlimiUIMotion.attach_interactive_feedback(btn, 120)
		btn.pressed.connect(func() -> void:
			_emit_button_gaze(btn)
			navigate_to(tid)
		)
		nav_row.add_child(btn)
		nav_buttons[tid] = btn


func _refresh_nav_active_states() -> void:
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	for tid in nav_buttons.keys():
		var btn: Button = nav_buttons[tid] as Button
		if btn == null:
			continue
		var active: bool = (str(tid) == current_screen)
		SlimiUIComponents.style_button_variant(btn, tokens, "primary" if active else "secondary")
		btn.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))


func _setup_overlays() -> void:
	onboarding_overlay = SlimiOnboardingOverlay.new()
	hud_root.add_child(onboarding_overlay)
	onboarding_overlay.onboarding_completed.connect(func() -> void:
		apply_design_system()
		_refresh_localized_texts()
	)

	exit_modal = SlimiExitModal.new()
	hud_root.add_child(exit_modal)
	exit_modal.exit_confirmed.connect(func() -> void: exit_app_confirmed.emit())

	splash_screen = SlimiSplashScreen.new()
	hud_root.add_child(splash_screen)


func _setup_progress_bar_textures() -> void:
	var under_tex: GradientTexture2D = _make_bar_texture(Color(0.95, 0.87, 0.92, 0.85), Color(0.92, 0.82, 0.89, 0.85))
	var happy_tex: GradientTexture2D = _make_bar_texture(Color(1.0, 0.45, 0.72), Color(1.0, 0.65, 0.83))
	var energy_tex: GradientTexture2D = _make_bar_texture(Color(0.35, 0.82, 0.68), Color(0.56, 0.92, 0.80))
	var full_tex: GradientTexture2D = _make_bar_texture(Color(1.0, 0.68, 0.34), Color(1.0, 0.82, 0.52))
	var bond_tex: GradientTexture2D = _make_bar_texture(Color(0.68, 0.48, 0.98), Color(0.84, 0.66, 1.0))

	for pair in [
		[bar_happiness, happy_tex],
		[bar_energy, energy_tex],
		[bar_fullness, full_tex],
		[bar_bond, bond_tex],
	]:
		var bar := pair[0] as TextureProgressBar
		bar.nine_patch_stretch = true
		bar.texture_under = under_tex
		bar.texture_progress = pair[1]


func _make_bar_texture(c1: Color, c2: Color) -> GradientTexture2D:
	var grad := Gradient.new()
	grad.set_color(0, c1)
	grad.set_color(1, c2)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 14
	return tex


func _setup_action_icons() -> void:
	btn_feed.icon = load("res://assets/icons/ic_feed.svg") as Texture2D
	btn_play.icon = load("res://assets/icons/ic_play.svg") as Texture2D
	btn_nap.icon = load("res://assets/icons/ic_nap.svg") as Texture2D
	btn_call.icon = load("res://assets/icons/ic_call.svg") as Texture2D
	btn_memory.icon = load("res://assets/icons/ic_memory.svg") as Texture2D
	btn_settings.icon = load("res://assets/icons/ic_settings.svg") as Texture2D

	for b in [btn_feed, btn_play, btn_nap, btn_call, btn_memory, btn_settings]:
		b.expand_icon = true
		SlimiUIMotion.attach_interactive_feedback(b)


func _connect_home_buttons() -> void:
	btn_feed.pressed.connect(func() -> void:
		_emit_button_gaze(btn_feed)
		action_feed_requested.emit()
	)
	btn_play.pressed.connect(func() -> void:
		_emit_button_gaze(btn_play)
		action_play_requested.emit()
	)
	btn_nap.pressed.connect(func() -> void:
		_emit_button_gaze(btn_nap)
		action_nap_requested.emit()
	)
	btn_call.pressed.connect(func() -> void:
		_emit_button_gaze(btn_call)
		action_call_requested.emit()
	)
	btn_settings.pressed.connect(func() -> void:
		_emit_button_gaze(btn_settings)
		navigate_to("settings")
	)
	btn_memory.pressed.connect(func() -> void:
		_emit_button_gaze(btn_memory)
		memory_modal.visible = true
	)
	btn_close_memory.pressed.connect(func() -> void:
		memory_modal.visible = false
	)


func _emit_button_gaze(btn: Control) -> void:
	if btn != null:
		ui_button_interacted.emit(btn.get_global_rect().get_center())


func _apply_safe_area_and_keyboard_margins() -> void:
	var margins: Dictionary = AndroidPlatformManager.get_safe_area_margins()
	var kb_inset: int = AndroidPlatformManager.get_virtual_keyboard_bottom_inset()
	root_margin.add_theme_constant_override("margin_top", int(margins["top"]))
	root_margin.add_theme_constant_override("margin_bottom", int(margins["bottom"]) + kb_inset)
	root_margin.add_theme_constant_override("margin_left", int(margins["left"]))
	root_margin.add_theme_constant_override("margin_right", int(margins["right"]))

	if screen_sheet_host != null:
		# في الشاشات الصغيرة جداً (360x640) نمنح اللوحة مساحة مريحة دون حجب وجه SLIMI
		var vp_h: float = get_viewport().get_visible_rect().size.y
		screen_sheet_host.anchor_top = 0.32 if vp_h < 760.0 else 0.36
		screen_sheet_host.offset_bottom = -float(86 + kb_inset)


func _on_locale_changed(_locale: String, _rtl: bool) -> void:
	_refresh_localized_texts()
	apply_design_system()


func _refresh_localized_texts() -> void:
	LocalizationManager.apply_rtl_to_control(hud_root)
	LocalizationManager.apply_rtl_to_control(root_margin)
	LocalizationManager.apply_rtl_to_control(memory_modal)

	title_label.text = SlimiCustomizationManager.get_display_name()
	lbl_happiness.text = LocalizationManager.tr_key("stat_happiness")
	lbl_energy.text = LocalizationManager.tr_key("stat_energy")
	lbl_fullness.text = LocalizationManager.tr_key("stat_fullness")
	lbl_bond.text = LocalizationManager.tr_key("stat_bond")
	hint_label.text = LocalizationManager.tr_key("hint_touch")

	btn_feed.text = LocalizationManager.tr_key("btn_feed")
	btn_play.text = LocalizationManager.tr_key("btn_play")
	btn_nap.text = LocalizationManager.tr_key("btn_nap")
	btn_call.text = LocalizationManager.tr_key("btn_call")
	btn_memory.text = ""
	btn_settings.text = ""
	btn_memory.tooltip_text = LocalizationManager.tr_key("memory_title")
	btn_settings.tooltip_text = LocalizationManager.tr_key("settings_title")

	for tid in nav_buttons.keys():
		var nb: Button = nav_buttons[tid] as Button
		if nb != null:
			nb.text = LocalizationManager.tr_key(str(nb.get_meta("tr_key", "nav_home")))

	var mic_lbl := mic_banner.get_node_or_null("MicBannerLabel") as Label if mic_banner != null else null
	if mic_lbl != null:
		mic_lbl.text = LocalizationManager.tr_key("mic_live_badge")

	lbl_memory_title.text = LocalizationManager.tr_key("memory_title")
	btn_close_memory.text = LocalizationManager.tr_key("btn_close")

	if chat_screen != null:
		chat_screen.refresh_localization()
	if splash_screen != null:
		splash_screen.refresh_texts()
