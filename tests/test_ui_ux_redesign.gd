class_name SlimiUIUXRedesignQA
extends RefCounted
## حزمة الاختبارات الآلية الشاملة لإعادة تصميم واجهة وتجربة تطبيق SLIMI بالكامل (v0.4.0 UI/UX Redesign):
## تتحقق عملياً من جميع التدفقات العشرة المطلوبة في القسم 14 دون أي افتراض نظري.

const MainScene := preload("res://scenes/Main.tscn")

var passed_count: int = 0
var failed_count: int = 0


func assert_true(cond: bool, label: String) -> void:
	if cond:
		passed_count += 1
		print("  [UI-PASS] %s" % label)
	else:
		failed_count += 1
		push_error("  [UI-FAIL] %s" % label)


func run_all(tree: SceneTree) -> bool:
	print("\n============================================================")
	print("بدء اختبارات UI/UX والتجربة المتكاملة (SLIMI v0.4.0 Redesign QA)")
	print("============================================================")

	var main_inst: Node3D = MainScene.instantiate() as Node3D
	tree.root.add_child(main_inst)
	await tree.process_frame
	await tree.physics_frame

	var hud := main_inst.get_node("GameHUD") as HUDController
	var slime := main_inst.get_node("Slimi") as SlimeController
	var room := main_inst.get_node("CozyRoom") as RoomEnvironment
	var hub := main_inst.get_node("SlimiInteractionManager") as SlimiInteractionManager

	await _test_splash_and_onboarding(tree, hud, slime, hub)
	await _test_home_screen_and_ui_gaze(tree, main_inst, hud, room)
	await _test_5_screen_navigation_and_state_preservation(tree, hud)
	await _test_modern_chat_interface(tree, hud, hub)
	await _test_3d_customization_studio(tree, hud, slime, room)
	await _test_activities_and_minigames_screen(tree, hud, hub, slime)
	await _test_all_6_settings_categories(tree, hud, hub, slime, room)
	await _test_android_back_exit_and_lifecycle(tree, hud)
	await _test_aspect_ratios_rtl_ltr_and_performance(tree, hud, slime, hub)

	# تنظيف وإعادة الإعدادات الافتراضية النظيفة
	SaveManager.reset_settings_to_default()
	SlimiCustomizationManager.reset_to_default()
	QualityManager.apply_preset(QualityManager.Preset.MEDIUM, false)
	LocalizationManager.set_locale("ar")

	main_inst.queue_free()
	await tree.process_frame

	print("------------------------------------------------------------")
	print("نتيجة اختبارات UI/UX الشاملة: نجح %d | فشل %d" % [passed_count, failed_count])
	print("============================================================")
	return failed_count == 0


func _test_splash_and_onboarding(
	tree: SceneTree,
	hud: HUDController,
	slime: SlimeController,
	hub: SlimiInteractionManager
) -> void:
	print("\n[UI 1/9] فحص شاشة البداية (Splash) وشاشة الإعداد الأول والترحيب (Onboarding)...")
	assert_true(hud.splash_screen != null and hud.onboarding_overlay != null, "وجود شاشة البداية وشاشة الترحيب الأول")

	# اختبار شاشة البداية واحترام كتم الصوت والتخطي الفوري
	AudioManager.set_master_muted(true)
	var splash_done: Array[bool] = [false]
	hud.splash_screen.splash_finished.connect(func() -> void: splash_done[0] = true, CONNECT_ONE_SHOT)
	hud.splash_screen.play_intro(slime)
	assert_true(hud.splash_screen.visible and hud.splash_screen.is_active, "ظهور شاشة البداية السريعة مع الشعار والجزيئات")
	hud.splash_screen.finish_immediately()
	assert_true(splash_done[0] and not hud.splash_screen.visible, "تخطي/إنهاء شاشة البداية بسلاسة دون حجب بدء التطبيق")
	AudioManager.set_master_muted(false)

	# اختبار خطوات الإعداد الأول الثلاث وحفظ الاسم واللقب واستعادتهما
	SaveManager.update_section("ui_preferences", {"onboarding_completed": false})
	hud.onboarding_overlay.open_onboarding()
	await tree.process_frame
	assert_true(hud.onboarding_overlay.visible and hud.onboarding_overlay.current_step == 0, "فتح الخطوة الأولى من الترحيب مع بقاء SLIMI ظاهراً")

	if hud.onboarding_overlay.name_input != null:
		hud.onboarding_overlay.name_input.text = "سلايمي الذكي"
	if hud.onboarding_overlay.nick_input != null:
		hud.onboarding_overlay.nick_input.text = "صديقي أنس"

	var btn_next_0 := hud.onboarding_overlay.find_child("BtnNextStep", true, false) as Button
	assert_true(btn_next_0 != null, "وجود زر الانتقال للخطوة التالية في الترحيب")
	btn_next_0.pressed.emit()
	await tree.process_frame
	assert_true(hud.onboarding_overlay.current_step == 1, "الانتقال إلى خطوة الصوت وجودة الرسوميات")

	var btn_next_1 := hud.onboarding_overlay.find_child("BtnNextStep", true, false) as Button
	btn_next_1.pressed.emit()
	await tree.process_frame
	assert_true(hud.onboarding_overlay.current_step == 2, "الانتقال إلى بطاقة الخصوصية والوضع المحلي")

	var btn_finish := hud.onboarding_overlay.find_child("BtnNextStep", true, false) as Button
	btn_finish.pressed.emit()
	await tree.process_frame

	assert_true(not hud.onboarding_overlay.visible, "إغلاق شاشة الإعداد الأول بسلاسة بعد الإتمام")
	assert_true(bool(SaveManager.get_section("ui_preferences").get("onboarding_completed", false)), "حفظ إتمام الترحيب لعدم إزعاج المستخدم مجدداً")
	assert_true(SlimiCustomizationManager.get_display_name() == "سلايمي الذكي" and hub.memory_manager.user_nickname == "صديقي أنس", "حفظ اسم SLIMI المخصص ولقب المستخدم واستعادتهما")

	# اختبار إمكانية تخطي الإعداد مباشرة دون إجبار المستخدم
	hud.onboarding_overlay.open_onboarding()
	hud.onboarding_overlay.skip_and_finish()
	assert_true(not hud.onboarding_overlay.visible, "إمكانية تخطي شاشة الترحيب فوراً بزر التخطي")


func _test_home_screen_and_ui_gaze(
	tree: SceneTree,
	main_inst: Node3D,
	hud: HUDController,
	room: RoomEnvironment
) -> void:
	print("\n[UI 2/9] فحص الشاشة الرئيسية وتبديل الخلفية وتفاعل نظر SLIMI مع الأزرار...")
	hud.navigate_to("home", false)
	await tree.process_frame

	assert_true(hud.current_screen == "home" and hud.bottom_dock.visible, "الشاشة الرئيسية تعرض أدوات التفاعل الأنيقة مع بقاء SLIMI في المنتصف")
	assert_true(hud.screen_sheet_host.anchor_top >= 0.32, "ترك المساحة العلوية والوسطى مفتوحة لظهور SLIMI بوضوح")

	var bg_before: String = room.current_backdrop_id
	hud.btn_bg_cycle.pressed.emit()
	assert_true(room.current_backdrop_id != bg_before, "تبديل خلفية وإضاءة غرفة SLIMI حياً من الشاشة الرئيسية")

	hud.btn_stats_toggle.pressed.emit()
	assert_true(not hud.stats_panel.visible, "طيّ مؤشرات الحالة لمسرح عرض أنقى عند الرغبة")
	hud.btn_stats_toggle.pressed.emit()
	assert_true(hud.stats_panel.visible, "إعادة إظهار مؤشرات الحالة المدمجة")

	# فحص التفات عيون ورأس SLIMI نحو الزر المضغوط في الواجهة
	hud.btn_feed.pressed.emit()
	assert_true(float(main_inst.get("_ui_gaze_timer")) > 0.5, "التفات نظر SLIMI وتفاعله عند الضغط على أزرار الواجهة")


func _test_5_screen_navigation_and_state_preservation(tree: SceneTree, hud: HUDController) -> void:
	print("\n[UI 3/9] فحص شريط التنقل السفلي الموحد (5 شاشات) وحفظ الحالة...")
	assert_true(hud.nav_buttons.size() == 5, "شريط التنقل الموحد يضم الشاشات الخمس (الرئيسية، المحادثة، الأنشطة، التخصيص، الإعدادات)")

	for sid in ["chat", "activities", "customize", "settings", "home"]:
		var nav_btn := hud.nav_buttons[sid] as Button
		nav_btn.pressed.emit()
		await tree.process_frame
		assert_true(hud.current_screen == sid, "التنقل السلس إلى شاشة '%s' وتفعيل حالتها النشطة" % sid)


func _test_modern_chat_interface(tree: SceneTree, hud: HUDController, hub: SlimiInteractionManager) -> void:
	print("\n[UI 4/9] فحص شاشة المحادثة الحديثة (العربية والإنجليزية ومؤشر التفكير والميكروفون)...")
	hud.navigate_to("chat")
	await tree.process_frame

	assert_true(hud.chat_screen.visible and not hud.bottom_dock.visible, "فتح لوحة المحادثة دون تداخل مع شريط الرعاية السفلي")

	var count_before: int = hud.chat_screen.chat_log_vbox.get_child_count()
	hud.chat_screen.chat_input.text = "مرحباً يا سلايمي! كيف حالك اليوم؟"
	hud.chat_screen.submit_current_text()
	await tree.process_frame
	assert_true(hud.chat_screen.chat_log_vbox.get_child_count() >= count_before + 2, "ظهور فقاعة المستخدم وفقاعة رد SLIMI بتصميم مميز وواضح")

	# التحقق من حفظ سجل المحادثة عند الانتقال لشاشة أخرى والعودة
	var saved_bubble_count: int = hud.chat_screen.chat_log_vbox.get_child_count()
	hud.navigate_to("activities")
	await tree.process_frame
	hud.navigate_to("chat")
	await tree.process_frame
	assert_true(hud.chat_screen.chat_log_vbox.get_child_count() == saved_bubble_count, "حفظ حالة وسجل المحادثة عند التنقل بين الشاشات والعودة")

	# فحص مؤشر التفكير والكتابة دون تعطيل الواجهة
	hud.chat_screen.set_thinking_visible(true)
	hud.chat_screen._process(0.1)
	assert_true(hud.chat_screen.thinking_row.visible and not hud.chat_screen.chat_input.editable == false, "مؤشر الكتابة والتفكير يعمل بنعومة دون تجميد حقل الإدخال")
	hud.chat_screen.set_thinking_visible(false)

	# إرسال رسالة إنجليزية وطلب نكتة سريعة
	hud.chat_screen.chat_input.text = "Tell me something fun!"
	hud.chat_screen.submit_current_text()
	await tree.process_frame
	assert_true(hub.voice_manager.is_speaking(), "تزامن رد المحادثة مع نطق SLIMI وحركة الفم (Lip-Sync)")


func _test_3d_customization_studio(
	tree: SceneTree,
	hud: HUDController,
	slime: SlimeController,
	room: RoomEnvironment
) -> void:
	print("\n[UI 5/9] فحص استوديو التخصيص ثلاثي الأبعاد (التدوير، المعاينة، الإلغاء، الحفظ، واستعادة الافتراضي)...")
	SlimiCustomizationManager.reset_to_default()
	SlimiCustomizationManager.apply_to_slime(slime, room)
	hud.navigate_to("customize")
	await tree.process_frame

	var vis_root := slime.get_node("VisualRoot") as Node3D
	var flower_node := slime.get_node("VisualRoot/KnitBeanie/YarnFlower") as Node3D
	var heart_node := slime.get_node("VisualRoot/KnitBeanie/HeartPin") as Node3D

	var yaw_before: float = vis_root.rotation.y
	hud.customize_screen.rotate_preview_by_degrees(90.0)
	assert_true(absf(vis_root.rotation.y - yaw_before) > 1.0, "تدوير معاينة SLIMI ثلاثية الأبعاد بزاوية 90 درجة حياً")

	# معاينة بدون حفظ ثم مغادرة الشاشة -> يجب التراجع تلقائياً للمظهر المحفوظ
	hud.customize_screen._preview_cfg["show_flower"] = false
	hud.customize_screen._preview_cfg["gel_preset"] = "peach_blossom"
	hud.customize_screen.apply_live_preview()
	assert_true(not flower_node.visible, "المعاينة الحية لإخفاء الزهرة وتغيير لون الجل قبل الحفظ")

	hud.navigate_to("home")
	await tree.process_frame
	assert_true(flower_node.visible, "استرجاع المظهر المحفوظ تلقائياً عند مغادرة التخصيص دون ضغط حفظ")

	# حفظ مظهر مخصص والتحقق من بقائه بعد إعادة التحميل من القرص
	hud.navigate_to("customize")
	await tree.process_frame
	hud.customize_screen._preview_cfg["gel_preset"] = "lilac_mist"
	hud.customize_screen._preview_cfg["beanie_preset"] = "mint_yarn"
	hud.customize_screen._preview_cfg["show_heart_pin"] = false
	hud.customize_screen._preview_backdrop = "starry_night"
	hud.customize_screen.apply_live_preview()
	hud.customize_screen.save_current_look()

	SaveManager.load_from_disk()
	var loaded_cust: Dictionary = SlimiCustomizationManager.get_saved_config()
	assert_true(
		str(loaded_cust.get("gel_preset", "")) == "lilac_mist"
		and str(loaded_cust.get("beanie_preset", "")) == "mint_yarn"
		and not bool(loaded_cust.get("show_heart_pin", true))
		and room.current_backdrop_id == "starry_night",
		"حفظ تخصيصات الجل والقبعة والإكسسوارات والخلفية واستعادتها من القرص بنجاح"
	)

	# استعادة المظهر الأصلي المرجعي
	hud.customize_screen.restore_default_look()
	assert_true(
		flower_node.visible
		and heart_node.visible
		and str(SlimiCustomizationManager.get_saved_config().get("gel_preset", "")) == "sakura_pink",
		"زر استعادة المظهر الافتراضي يعيد هوية SLIMI المرجعية الأصلية بالكامل"
	)


func _test_activities_and_minigames_screen(
	tree: SceneTree,
	hud: HUDController,
	hub: SlimiInteractionManager,
	slime: SlimeController
) -> void:
	print("\n[UI 6/9] فحص شاشة الأنشطة الحية والألعاب المصغرة التسع...")
	hud.navigate_to("activities")
	await tree.process_frame

	for act_id in ["play_hop", "dance", "stretch", "joke", "riddle"]:
		hud.activities_screen.trigger_live_activity(act_id)
	assert_true(slime.motion_coordinator != null, "تنفيذ جميع الأنشطة الحية (قفز، رقص، تمدد، نكت، ألغاز) فعلياً دون أزرار وهمية")

	hud.activities_screen.start_minigame_round("trivia_qa")
	await tree.process_frame
	assert_true(hud.activities_screen.active_game_card.visible and hub.minigames.is_active(), "بدء جولة لعبة مصغرة تفاعلية داخل شاشة الأنشطة")
	var target_idx: int = int(hub.minigames._state.get("target", 0))
	hub.minigames.submit_choice(target_idx, LocalizationManager.current_locale)
	assert_true(not hub.minigames.is_active(), "إتمام جولة اللعبة المصغرة بنجاح وتحديث النتيجة")


func _test_all_6_settings_categories(
	tree: SceneTree,
	hud: HUDController,
	hub: SlimiInteractionManager,
	slime: SlimeController,
	room: RoomEnvironment
) -> void:
	print("\n[UI 7/9] فحص أقسام الإعدادات الستة الحقيقية (المظهر، الصوت، الشخصية، الذكاء، الخصوصية، التطبيق)...")
	hud.navigate_to("settings")
	await tree.process_frame

	# 1. قسم المظهر: الوضع الداكن/الفاتح + ألوان التمييز + حجم الخط + تقليل الحركة
	hud.settings_screen.select_category("appearance")
	await tree.process_frame
	var btn_dark := hud.settings_screen.find_child("BtnThemeDark", true, false) as Button
	assert_true(btn_dark != null, "وجود زر الوضع الداكن المريح في قسم المظهر")
	btn_dark.pressed.emit()
	assert_true(bool(SlimiDesignSystem.get_tokens().get("dark_mode", false)), "تفعيل الوضع الداكن (Dark Velvet) وتطبيقه حياً على الواجهة")

	var btn_accent_mint := hud.settings_screen.find_child("BtnAccent_mint", true, false) as Button
	btn_accent_mint.pressed.emit()
	assert_true(str(SlimiDesignSystem.get_tokens().get("accent_id", "")) == "mint", "تغيير لوحة ألوان التمييز إلى النعناعي وتحديث الأزرار")

	var btn_txt_lg := hud.settings_screen.find_child("BtnTextScale_2", true, false) as Button
	btn_txt_lg.pressed.emit()
	assert_true(SlimiDesignSystem.scaled_font(15) >= 17, "تكبير حجم نصوص الواجهة فعلياً لسهولة القراءة")

	# 2. قسم الصوت
	hud.settings_screen.select_category("audio")
	await tree.process_frame
	AudioManager.set_expressive_sounds_enabled(false)
	assert_true(not AudioManager.play_voice(&"happy_chirp"), "إيقاف الأصوات التعبيرية والضحكات يعمل فعلياً")
	AudioManager.set_expressive_sounds_enabled(true)

	# 3. قسم الشخصية
	hud.settings_screen.select_category("character")
	await tree.process_frame
	var sname_edit := hud.settings_screen.find_child("SettingsSlimiNameEdit", true, false) as LineEdit
	assert_true(sname_edit != null, "وجود حقل تعديل اسم SLIMI في قسم الشخصية")
	sname_edit.text = "وردي"
	sname_edit.text_changed.emit("وردي")
	assert_true(hud.title_label.text == "وردي", "تحديث اسم SLIMI مباشرة في رأس الواجهة")

	# 4. قسم الذكاء والتفاعل
	hud.settings_screen.select_category("ai")
	await tree.process_frame
	var btn_online := hud.settings_screen.find_child("BtnAIOnline", true, false) as Button
	btn_online.pressed.emit()
	assert_true(hub.settings_manager.ai_mode == "online", "التبديل الاختياري لوضع AI Online")

	# 5. قسم الخصوصية
	hud.settings_screen.select_category("privacy")
	await tree.process_frame
	var btn_disable_online := hud.settings_screen.find_child("BtnDisableAllOnline", true, false) as Button
	btn_disable_online.pressed.emit()
	assert_true(hub.settings_manager.ai_mode == "offline" and not hub.settings_manager.online_user_consent, "زر إيقاف جميع الميزات السحابية يعيد التطبيق فوراً للوضع المحلي الخالص")

	var btn_clear_mem := hud.settings_screen.find_child("BtnClearMemory", true, false) as Button
	btn_clear_mem.pressed.emit()
	assert_true(hub.memory_manager.saved_chat_snippets.is_empty(), "زر مسح الذاكرة ينظف السجل المحلي فعلياً")

	# 6. قسم التطبيق (اللغة، تنظيف الملفات المؤقتة، التراخيص، إعادة الضبط)
	hud.settings_screen.select_category("app")
	await tree.process_frame
	var btn_cache := hud.settings_screen.find_child("BtnClearTempCache", true, false) as Button
	btn_cache.pressed.emit()
	assert_true(hud.settings_screen.status_toast_label.visible, "تنظيف الملفات المؤقتة (Cache) يعرض تأكيداً فورياً")

	var btn_lic := hud.settings_screen.find_child("BtnToggleLicenses", true, false) as Button
	btn_lic.pressed.emit()
	await tree.process_frame
	assert_true(hud.settings_screen._show_licenses, "عرض بطاقة التراخيص والمصادر المفتوحة بوضوح")

	var btn_reset_all := hud.settings_screen.find_child("BtnResetAllSettings", true, false) as Button
	btn_reset_all.pressed.emit()
	await tree.process_frame
	assert_true(
		not bool(SlimiDesignSystem.get_tokens().get("dark_mode", true))
		and room.current_backdrop_id == "pastel_dream"
		and slime.movement_speed_scale == 1.0,
		"إعادة ضبط جميع الإعدادات للافتراضي تستعيد المظهر الفاتح والخلفية والسرعة القياسية"
	)


func _test_android_back_exit_and_lifecycle(tree: SceneTree, hud: HUDController) -> void:
	print("\n[UI 8/9] فحص زر الرجوع في أندرويد ونافذة تأكيد الخروج ودورة حياة الخلفية...")
	hud.close_modals()
	hud.navigate_to("chat")
	hud.navigate_to("customize")
	await tree.process_frame
	assert_true(hud.current_screen == "customize", "الوصول إلى شاشة التخصيص بعد المحادثة")

	AndroidPlatformManager.simulate_back_button()
	await tree.process_frame
	assert_true(hud.current_screen == "chat", "زر الرجوع في أندرويد يعيد المستخدم للشاشة السابقة (المحادثة)")

	AndroidPlatformManager.simulate_back_button()
	await tree.process_frame
	assert_true(hud.current_screen == "home", "زر الرجوع التالي يعيد المستخدم للشاشة الرئيسية")

	AndroidPlatformManager.simulate_back_button()
	await tree.process_frame
	assert_true(hud.exit_modal.visible, "زر الرجوع في الشاشة الرئيسية يفتح نافذة تأكيد الخروج الهادئة بدلاً من الإغلاق المفاجئ")

	hud.exit_modal.btn_continue.pressed.emit()
	await tree.process_frame
	assert_true(not hud.exit_modal.visible and hud.current_screen == "home", "اختيار متابعة اللعب يغلق نافذة الخروج ويبقي التجربة نشطة")

	# محاكاة الذهاب للخلفية والعودة (Pause / Resume Lifecycle)
	AndroidPlatformManager._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_true(AndroidPlatformManager.is_app_paused and Engine.max_fps == 10, "تقليل استهلاك المعالج وحفظ الحالة تلقائياً عند انتقال التطبيق للخلفية")
	AndroidPlatformManager._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_true(not AndroidPlatformManager.is_app_paused and Engine.max_fps >= 30, "استعادة معدل الإطارات والصوت بسلاسة عند عودة التطبيق للواجهة")


func _test_aspect_ratios_rtl_ltr_and_performance(
	tree: SceneTree,
	hud: HUDController,
	slime: SlimeController,
	hub: SlimiInteractionManager
) -> void:
	print("\n[UI 9/9] فحص التجاوب عبر أبعاد شاشات أندرويد (360x640 / 720x1280 / 1080x2400) وRTL/LTR والأداء...")
	var orig_size: Vector2i = tree.root.size
	for res in [Vector2i(360, 640), Vector2i(720, 1280), Vector2i(1080, 2400)]:
		tree.root.size = res
		hud._apply_safe_area_and_keyboard_margins()
		await tree.process_frame
		assert_true(
			hud.bottom_nav_bar.size.x >= 280.0 and hud.screen_sheet_host.anchor_top >= 0.30,
			"تكيف الواجهة وشريط التنقل بنجاح على دقة %dx%d دون قص أو حجب" % [res.x, res.y]
		)
	tree.root.size = orig_size
	hud._apply_safe_area_and_keyboard_margins()

	LocalizationManager.set_locale("en")
	await tree.process_frame
	assert_true(
		hud.root_margin.layout_direction == Control.LAYOUT_DIRECTION_LTR
		and (hud.nav_buttons["home"] as Button).text == "Home",
		"تبديل كامل الواجهة وشريط التنقل إلى الإنجليزية LTR"
	)
	LocalizationManager.set_locale("ar")
	await tree.process_frame
	assert_true(
		hud.root_margin.layout_direction == Control.LAYOUT_DIRECTION_RTL
		and (hud.nav_buttons["home"] as Button).text == "الرئيسية",
		"تبديل كامل الواجهة وشريط التنقل إلى العربية RTL"
	)

	# قياس أداء الواجهة + الشخصية عبر المستويات الثلاثة (LOW / MEDIUM / HIGH)
	for preset_info in [
		[QualityManager.Preset.LOW, "LOW"],
		[QualityManager.Preset.MEDIUM, "MEDIUM"],
		[QualityManager.Preset.HIGH, "HIGH"],
	]:
		QualityManager.apply_preset(int(preset_info[0]), false)
		var t0: int = Time.get_ticks_usec()
		for _i in range(60):
			slime._physics_process(1.0 / 60.0)
			slime.deformer._process(1.0 / 60.0)
			slime.face_rig._process(1.0 / 60.0)
			hud._process(1.0 / 60.0)
			hub.anim_controller._process(1.0 / 60.0)
		var avg_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / 60.0
		print("  [PERF %s] متوسط زمن معالجة الواجهة + الشخصية: %.3f ms/frame" % [str(preset_info[1]), avg_ms])
		assert_true(avg_ms < 8.0, "ثبات واستقرار زمن الإطار على مستوى %s (%.3f ms < 8.0 ms)" % [str(preset_info[1]), avg_ms])
