class_name HUDController
extends CanvasLayer
## واجهة المستخدم العربية (RTL) القابلة للتوسع والمصممة لشاشات هواتف Android.

signal feed_requested
signal play_requested
signal nap_requested
signal call_requested

var root_margin: MarginContainer
var title_label: Label
var mood_label: Label
var fps_label: Label

var bar_happiness: ProgressBar
var bar_energy: ProgressBar
var bar_fullness: ProgressBar
var bar_bond: ProgressBar

var lbl_happiness: Label
var lbl_energy: Label
var lbl_fullness: Label
var lbl_bond: Label

var bubble_panel: PanelContainer
var bubble_label: Label

var btn_feed: Button
var btn_play: Button
var btn_nap: Button
var btn_call: Button
var btn_memory: Button
var btn_settings: Button
var hint_label: Label

var settings_modal: ColorRect
var settings_title_label: Label
var quality_title_label: Label
var btn_q_low: Button
var btn_q_med: Button
var btn_q_high: Button
var lbl_vol_master: Label
var slider_master: HSlider
var lbl_vol_sfx: Label
var slider_sfx: HSlider
var chk_ambient: CheckButton
var chk_battery: CheckButton
var chk_haptics: CheckButton
var chk_fps: CheckButton
var btn_lang: Button
var btn_close_settings: Button

var memory_modal: ColorRect
var memory_title_label: Label
var mem_sessions_lbl: Label
var mem_pokes_lbl: Label
var mem_pets_lbl: Label
var mem_feeds_lbl: Label
var mem_plays_lbl: Label
var mem_bond_lbl: Label
var mem_fav_lbl: Label
var btn_close_memory: Button

var _is_slime_sleeping: bool = false
var _current_mood_key: String = "mood_happy"
var _cached_memory: SlimeMemory
var _bubble_tween: Tween
var _show_fps: bool = false


func _ready() -> void:
	_bind_nodes()
	_connect_signals()

	var settings: Dictionary = SaveManager.get_section("settings")
	_show_fps = bool(settings.get("show_fps", false))
	if fps_label != null:
		fps_label.visible = _show_fps

	_sync_settings_controls_from_managers()
	_apply_safe_area(AndroidPlatformManager.get_safe_area_margins())
	refresh_localization()


func bind_slime_systems(mood_sys: PersonalityMoodSystem) -> void:
	if mood_sys == null:
		return
	_cached_memory = mood_sys.memory
	mood_sys.stats_updated.connect(_on_stats_updated)
	mood_sys.mood_changed.connect(_on_mood_changed)
	mood_sys.thought_triggered.connect(show_bubble_by_key)
	_on_stats_updated(mood_sys.get_stats_snapshot())


func has_open_modal() -> bool:
	return (settings_modal != null and settings_modal.visible) or (memory_modal != null and memory_modal.visible)


func close_modals() -> void:
	if settings_modal != null:
		settings_modal.visible = false
	if memory_modal != null:
		memory_modal.visible = false


func show_bubble_by_key(text_key: String, duration: float = 3.6) -> void:
	show_bubble_text(LocalizationManager.tr_key(text_key), duration)


func show_bubble_text(message: String, duration: float = 3.6) -> void:
	if bubble_panel == null or bubble_label == null:
		return
	bubble_label.text = message
	bubble_panel.visible = true
	bubble_panel.modulate.a = 0.0
	bubble_panel.scale = Vector2(0.88, 0.88)

	if _bubble_tween != null and _bubble_tween.is_valid():
		_bubble_tween.kill()

	_bubble_tween = create_tween()
	_bubble_tween.set_parallel(true)
	_bubble_tween.tween_property(bubble_panel, "modulate:a", 1.0, 0.20)
	_bubble_tween.tween_property(bubble_panel, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.chain().tween_interval(duration)
	_bubble_tween.tween_property(bubble_panel, "modulate:a", 0.0, 0.30)
	_bubble_tween.tween_callback(func() -> void: bubble_panel.visible = false)


func refresh_localization() -> void:
	if root_margin != null:
		LocalizationManager.apply_rtl_to_control(root_margin)
	if settings_modal != null:
		LocalizationManager.apply_rtl_to_control(settings_modal)
	if memory_modal != null:
		LocalizationManager.apply_rtl_to_control(memory_modal)

	if title_label != null:
		title_label.text = LocalizationManager.tr_key("app_title")
	if mood_label != null:
		mood_label.text = LocalizationManager.tr_key(_current_mood_key)

	if lbl_happiness != null:
		lbl_happiness.text = LocalizationManager.tr_key("stat_happiness")
	if lbl_energy != null:
		lbl_energy.text = LocalizationManager.tr_key("stat_energy")
	if lbl_fullness != null:
		lbl_fullness.text = LocalizationManager.tr_key("stat_fullness")
	if lbl_bond != null:
		lbl_bond.text = LocalizationManager.tr_key("stat_bond")

	if btn_feed != null:
		btn_feed.text = LocalizationManager.tr_key("btn_feed")
	if btn_play != null:
		btn_play.text = LocalizationManager.tr_key("btn_play")
	if btn_nap != null:
		btn_nap.text = LocalizationManager.tr_key("btn_wake" if _is_slime_sleeping else "btn_sleep")
	if btn_call != null:
		btn_call.text = LocalizationManager.tr_key("btn_call")
	if btn_memory != null:
		btn_memory.text = LocalizationManager.tr_key("btn_memory")
	if btn_settings != null:
		btn_settings.text = LocalizationManager.tr_key("btn_settings")
	if hint_label != null:
		hint_label.text = LocalizationManager.tr_key("hint_touch")

	if settings_title_label != null:
		settings_title_label.text = LocalizationManager.tr_key("settings_title")
	if quality_title_label != null:
		quality_title_label.text = LocalizationManager.tr_key("quality_label")
	if btn_q_low != null:
		btn_q_low.text = LocalizationManager.tr_key("quality_low")
	if btn_q_med != null:
		btn_q_med.text = LocalizationManager.tr_key("quality_medium")
	if btn_q_high != null:
		btn_q_high.text = LocalizationManager.tr_key("quality_high")
	if lbl_vol_master != null:
		lbl_vol_master.text = LocalizationManager.tr_key("volume_master")
	if lbl_vol_sfx != null:
		lbl_vol_sfx.text = LocalizationManager.tr_key("volume_sfx")
	if chk_ambient != null:
		chk_ambient.text = LocalizationManager.tr_key("volume_ambient")
	if chk_battery != null:
		chk_battery.text = LocalizationManager.tr_key("battery_saver")
	if chk_haptics != null:
		chk_haptics.text = LocalizationManager.tr_key("haptics_toggle")
	if chk_fps != null:
		chk_fps.text = LocalizationManager.tr_key("show_fps")
	if btn_lang != null:
		btn_lang.text = LocalizationManager.tr_key("lang_toggle")
	if btn_close_settings != null:
		btn_close_settings.text = LocalizationManager.tr_key("btn_close")

	if memory_title_label != null:
		memory_title_label.text = LocalizationManager.tr_key("memory_title")
	if btn_close_memory != null:
		btn_close_memory.text = LocalizationManager.tr_key("btn_close")

	_refresh_memory_labels()
	_highlight_active_quality()


func _bind_nodes() -> void:
	root_margin = get_node_or_null("SafeMargin") as MarginContainer
	title_label = get_node_or_null("SafeMargin/MainLayout/TopBar/IdentityCard/IdentityVBox/TitleRow/TitleLabel") as Label
	mood_label = get_node_or_null("SafeMargin/MainLayout/TopBar/IdentityCard/IdentityVBox/MoodLabel") as Label
	fps_label = get_node_or_null("SafeMargin/MainLayout/TopBar/IdentityCard/IdentityVBox/TitleRow/FPSLabel") as Label

	bar_happiness = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/BarHappiness") as ProgressBar
	bar_energy = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/BarEnergy") as ProgressBar
	bar_fullness = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/BarFullness") as ProgressBar
	bar_bond = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/BarBond") as ProgressBar

	lbl_happiness = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/LblHappiness") as Label
	lbl_energy = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/LblEnergy") as Label
	lbl_fullness = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/LblFullness") as Label
	lbl_bond = get_node_or_null("SafeMargin/MainLayout/TopBar/StatsCard/StatsGrid/LblBond") as Label

	btn_memory = get_node_or_null("SafeMargin/MainLayout/TopBar/UtilityButtons/BtnMemory") as Button
	btn_settings = get_node_or_null("SafeMargin/MainLayout/TopBar/UtilityButtons/BtnSettings") as Button

	bubble_panel = get_node_or_null("SafeMargin/MainLayout/CenterArea/BubblePanel") as PanelContainer
	bubble_label = get_node_or_null("SafeMargin/MainLayout/CenterArea/BubblePanel/BubbleLabel") as Label

	hint_label = get_node_or_null("SafeMargin/MainLayout/BottomSection/HintLabel") as Label
	btn_feed = get_node_or_null("SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnFeed") as Button
	btn_play = get_node_or_null("SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnPlay") as Button
	btn_nap = get_node_or_null("SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnNap") as Button
	btn_call = get_node_or_null("SafeMargin/MainLayout/BottomSection/ActionDock/DockRow/BtnCall") as Button

	settings_modal = get_node_or_null("SettingsModal") as ColorRect
	settings_title_label = get_node_or_null("SettingsModal/Card/VBox/SettingsTitle") as Label
	quality_title_label = get_node_or_null("SettingsModal/Card/VBox/QualityLabel") as Label
	btn_q_low = get_node_or_null("SettingsModal/Card/VBox/QualityRow/BtnLow") as Button
	btn_q_med = get_node_or_null("SettingsModal/Card/VBox/QualityRow/BtnMedium") as Button
	btn_q_high = get_node_or_null("SettingsModal/Card/VBox/QualityRow/BtnHigh") as Button
	lbl_vol_master = get_node_or_null("SettingsModal/Card/VBox/LblMasterVol") as Label
	slider_master = get_node_or_null("SettingsModal/Card/VBox/SliderMaster") as HSlider
	lbl_vol_sfx = get_node_or_null("SettingsModal/Card/VBox/LblSfxVol") as Label
	slider_sfx = get_node_or_null("SettingsModal/Card/VBox/SliderSfx") as HSlider
	chk_ambient = get_node_or_null("SettingsModal/Card/VBox/ChkAmbient") as CheckButton
	chk_battery = get_node_or_null("SettingsModal/Card/VBox/ChkBattery") as CheckButton
	chk_haptics = get_node_or_null("SettingsModal/Card/VBox/ChkHaptics") as CheckButton
	chk_fps = get_node_or_null("SettingsModal/Card/VBox/ChkFps") as CheckButton
	btn_lang = get_node_or_null("SettingsModal/Card/VBox/BtnLang") as Button
	btn_close_settings = get_node_or_null("SettingsModal/Card/VBox/BtnCloseSettings") as Button

	memory_modal = get_node_or_null("MemoryModal") as ColorRect
	memory_title_label = get_node_or_null("MemoryModal/Card/VBox/MemoryTitle") as Label
	mem_sessions_lbl = get_node_or_null("MemoryModal/Card/VBox/MemSessions") as Label
	mem_pokes_lbl = get_node_or_null("MemoryModal/Card/VBox/MemPokes") as Label
	mem_pets_lbl = get_node_or_null("MemoryModal/Card/VBox/MemPets") as Label
	mem_feeds_lbl = get_node_or_null("MemoryModal/Card/VBox/MemFeeds") as Label
	mem_plays_lbl = get_node_or_null("MemoryModal/Card/VBox/MemPlays") as Label
	mem_bond_lbl = get_node_or_null("MemoryModal/Card/VBox/MemBond") as Label
	mem_fav_lbl = get_node_or_null("MemoryModal/Card/VBox/MemFav") as Label
	btn_close_memory = get_node_or_null("MemoryModal/Card/VBox/BtnCloseMemory") as Button


func _connect_signals() -> void:
	LocalizationManager.locale_changed.connect(func(_loc: String, _rtl: bool) -> void: refresh_localization())
	AndroidPlatformManager.safe_area_updated.connect(_apply_safe_area)
	AndroidPlatformManager.performance_updated.connect(_on_perf_updated)
	QualityManager.quality_changed.connect(func(_p: int, _prof: Dictionary) -> void: _highlight_active_quality())

	if btn_feed != null:
		btn_feed.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			feed_requested.emit()
		)
	if btn_play != null:
		btn_play.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			play_requested.emit()
		)
	if btn_nap != null:
		btn_nap.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			nap_requested.emit()
		)
	if btn_call != null:
		btn_call.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			call_requested.emit()
		)

	if btn_settings != null:
		btn_settings.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			if memory_modal != null:
				memory_modal.visible = false
			if settings_modal != null:
				settings_modal.visible = not settings_modal.visible
		)
	if btn_memory != null:
		btn_memory.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			_refresh_memory_labels()
			if settings_modal != null:
				settings_modal.visible = false
			if memory_modal != null:
				memory_modal.visible = not memory_modal.visible
		)

	if btn_close_settings != null:
		btn_close_settings.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			close_modals()
			SaveManager.save_to_disk()
		)
	if btn_close_memory != null:
		btn_close_memory.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			close_modals()
		)

	if btn_q_low != null:
		btn_q_low.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			QualityManager.apply_preset(QualityManager.Preset.LOW)
		)
	if btn_q_med != null:
		btn_q_med.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			QualityManager.apply_preset(QualityManager.Preset.MEDIUM)
		)
	if btn_q_high != null:
		btn_q_high.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			QualityManager.apply_preset(QualityManager.Preset.HIGH)
		)

	if slider_master != null:
		slider_master.value_changed.connect(func(v: float) -> void:
			AudioManager.set_bus_linear_volume("Master", v)
		)
	if slider_sfx != null:
		slider_sfx.value_changed.connect(func(v: float) -> void:
			AudioManager.set_bus_linear_volume("SFX", v)
			AudioManager.set_bus_linear_volume("Voice", v, false)
		)
	if chk_ambient != null:
		chk_ambient.toggled.connect(func(on: bool) -> void:
			AudioManager.set_ambient_enabled(on)
		)
	if chk_battery != null:
		chk_battery.toggled.connect(func(on: bool) -> void:
			QualityManager.set_battery_saver(on)
		)
	if chk_haptics != null:
		chk_haptics.toggled.connect(func(on: bool) -> void:
			AndroidPlatformManager.set_haptics_enabled(on)
		)
	if chk_fps != null:
		chk_fps.toggled.connect(func(on: bool) -> void:
			_show_fps = on
			if fps_label != null:
				fps_label.visible = _show_fps
			SaveManager.update_section("settings", {"show_fps": _show_fps})
		)
	if btn_lang != null:
		btn_lang.pressed.connect(func() -> void:
			AudioManager.play_sfx(&"ui_click")
			LocalizationManager.toggle_locale()
			SaveManager.update_section("settings", {"locale": LocalizationManager.current_locale})
		)


func _sync_settings_controls_from_managers() -> void:
	var s: Dictionary = SaveManager.get_section("settings")
	if slider_master != null:
		slider_master.set_value_no_signal(float(s.get("master_volume", 0.90)))
	if slider_sfx != null:
		slider_sfx.set_value_no_signal(float(s.get("sfx_volume", 0.90)))
	if chk_ambient != null:
		chk_ambient.set_pressed_no_signal(bool(s.get("ambient_enabled", true)))
	if chk_battery != null:
		chk_battery.set_pressed_no_signal(bool(s.get("battery_saver", false)))
	if chk_haptics != null:
		chk_haptics.set_pressed_no_signal(bool(s.get("haptics_enabled", true)))
	if chk_fps != null:
		chk_fps.set_pressed_no_signal(bool(s.get("show_fps", false)))
	_highlight_active_quality()


func _highlight_active_quality() -> void:
	var preset: int = QualityManager.current_preset
	if btn_q_low != null:
		btn_q_low.modulate = Color(1, 1, 1, 1) if preset == QualityManager.Preset.LOW else Color(0.88, 0.88, 0.92, 0.78)
	if btn_q_med != null:
		btn_q_med.modulate = Color(1, 1, 1, 1) if preset == QualityManager.Preset.MEDIUM else Color(0.88, 0.88, 0.92, 0.78)
	if btn_q_high != null:
		btn_q_high.modulate = Color(1, 1, 1, 1) if preset == QualityManager.Preset.HIGH else Color(0.88, 0.88, 0.92, 0.78)


func _on_stats_updated(stats: Dictionary) -> void:
	if bar_happiness != null:
		bar_happiness.value = float(stats.get("happiness", 80.0))
	if bar_energy != null:
		bar_energy.value = float(stats.get("energy", 80.0))
	if bar_fullness != null:
		bar_fullness.value = float(stats.get("fullness", 80.0))
	if bar_bond != null:
		bar_bond.value = float(stats.get("affection", 20.0))

	var sleeping_now: bool = bool(stats.get("is_sleeping", false))
	if sleeping_now != _is_slime_sleeping:
		_is_slime_sleeping = sleeping_now
		if btn_nap != null:
			btn_nap.text = LocalizationManager.tr_key("btn_wake" if _is_slime_sleeping else "btn_sleep")

	_current_mood_key = str(stats.get("mood_key", "mood_happy"))
	if mood_label != null:
		mood_label.text = LocalizationManager.tr_key(_current_mood_key)


func _on_mood_changed(_mood: int, mood_key: String) -> void:
	_current_mood_key = mood_key
	if mood_label != null:
		mood_label.text = LocalizationManager.tr_key(_current_mood_key)


func _refresh_memory_labels() -> void:
	if _cached_memory == null:
		return
	if mem_sessions_lbl != null:
		mem_sessions_lbl.text = LocalizationManager.tr_key("mem_sessions", {"count": _cached_memory.sessions_count})
	if mem_pokes_lbl != null:
		mem_pokes_lbl.text = LocalizationManager.tr_key("mem_pokes", {"count": _cached_memory.total_pokes})
	if mem_pets_lbl != null:
		mem_pets_lbl.text = LocalizationManager.tr_key("mem_pets", {"count": _cached_memory.total_pets})
	if mem_feeds_lbl != null:
		mem_feeds_lbl.text = LocalizationManager.tr_key("mem_feeds", {"count": _cached_memory.total_feeds})
	if mem_plays_lbl != null:
		mem_plays_lbl.text = LocalizationManager.tr_key("mem_plays", {"count": _cached_memory.total_plays})
	if mem_bond_lbl != null:
		var tier_txt: String = LocalizationManager.tr_key(_cached_memory.get_bond_tier_key())
		mem_bond_lbl.text = LocalizationManager.tr_key("mem_bond_tier", {"tier": tier_txt})
	if mem_fav_lbl != null:
		var fav_txt: String = LocalizationManager.tr_key(_cached_memory.get_favorite_interaction_key())
		mem_fav_lbl.text = LocalizationManager.tr_key("mem_fav", {"fav": fav_txt})


func _apply_safe_area(margins: Dictionary) -> void:
	if root_margin == null:
		return
	root_margin.add_theme_constant_override("margin_left", int(margins.get("left", 16)))
	root_margin.add_theme_constant_override("margin_top", int(margins.get("top", 16)))
	root_margin.add_theme_constant_override("margin_right", int(margins.get("right", 16)))
	root_margin.add_theme_constant_override("margin_bottom", int(margins.get("bottom", 16)))


func _on_perf_updated(fps: float, _frame_ms: float) -> void:
	if fps_label != null and _show_fps:
		fps_label.text = "%d FPS" % int(round(fps))
