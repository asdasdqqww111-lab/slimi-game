class_name SlimiUIUXShowcaseCapture
extends Node
## أداة التصوير الآلي الحقيقي لشاشات واجهة وتجربة SLIMI المحدّثة (OpenGL3 720x1280):
## تُحمّل المشهد الرئيسي الفعلي Main.tscn وتلتقط لقطات شاشة حقيقية لكل شاشة من الشاشات التسع.

const MainScene := preload("res://scenes/Main.tscn")

var _out_dir: String = ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-ui="):
			_out_dir = arg.trim_prefix("--capture-ui=").strip_edges()
			break

	if not _out_dir.is_empty():
		_capture_all_screens.call_deferred()


func _capture_all_screens() -> void:
	DirAccess.make_dir_recursive_absolute(_out_dir)

	SaveManager.reset_settings_to_default()
	SlimiCustomizationManager.reset_to_default()
	LocalizationManager.set_locale("ar")
	QualityManager.apply_preset(QualityManager.Preset.HIGH, false)

	var main_inst: Node3D = MainScene.instantiate() as Node3D
	add_child(main_inst)
	await _wait_frames(4)

	var hud := main_inst.get_node("GameHUD") as HUDController
	var slime := main_inst.get_node("Slimi") as SlimeController
	var room := main_inst.get_node("CozyRoom") as RoomEnvironment
	var hub := main_inst.get_node("SlimiInteractionManager") as SlimiInteractionManager

	# إيقاف انتقال Splash التلقائي كي نصوّر كل شاشة بوضوح تام
	hud.splash_screen.finish_immediately()
	hud.close_modals()
	await _wait_frames(3)

	# 1. شاشة البداية (Splash Screen)
	hud.splash_screen.play_intro(slime)
	hud.splash_screen.logo_holder.modulate.a = 1.0
	hud.splash_screen.logo_holder.scale = Vector2.ONE
	hud.splash_screen.modulate.a = 1.0
	await _wait_frames(3)
	await _snap("ui_01_splash.png")
	hud.splash_screen.finish_immediately()

	# 2. شاشة الترحيب والإعداد الأول (Onboarding)
	hud.onboarding_overlay.open_onboarding()
	await _wait_frames(4)
	await _snap("ui_02_onboarding.png")
	hud.onboarding_overlay.skip_and_finish()

	# 3. الشاشة الرئيسية (الوضع الفاتح المشرق + العربية RTL)
	hud.navigate_to("home", false)
	hud.show_bubble_by_key("bubble_welcome", 8.0)
	await _wait_frames(5)
	await _snap("ui_03_home_rtl_light.png")

	# 4. الشاشة الرئيسية (الوضع الداكن المريح Dark Velvet + خلفية سماء النجوم)
	SaveManager.update_section("ui_preferences", {"dark_mode": true, "accent_palette": "mint", "room_backdrop": "starry_night"})
	room.apply_room_backdrop_theme("starry_night")
	hud.apply_design_system()
	await _wait_frames(5)
	await _snap("ui_04_home_dark_mode.png")

	# العودة للوضع الفاتح الوردي لتصوير بقية الشاشات بوضوح استوديو مشرق
	SaveManager.update_section("ui_preferences", {"dark_mode": false, "accent_palette": "sakura", "room_backdrop": "pastel_dream"})
	room.apply_room_backdrop_theme("pastel_dream")
	hud.apply_design_system()

	# 5. شاشة المحادثة الحديثة مع فقاعات المستخدم وSLIMI
	hud.navigate_to("chat")
	hud.chat_screen.chat_input.text = "مرحباً يا سلايمي! احكِ لي نكتة لطيفة 😊"
	hud.chat_screen.submit_current_text()
	await _wait_frames(6)
	await _snap("ui_05_chat_screen.png")

	# 6. شاشة الأنشطة والألعاب المصغرة التسع
	hud.navigate_to("activities")
	hud.activities_screen.start_minigame_round("trivia_qa")
	await _wait_frames(5)
	await _snap("ui_06_activities_games.png")
	hub.minigames.stop_game()

	# 7. استوديو التخصيص ثلاثي الأبعاد مع تدوير الشخصية
	hud.navigate_to("customize")
	hud.customize_screen.rotate_preview_by_degrees(32.0)
	await _wait_frames(6)
	await _snap("ui_07_customize_360.png")

	# 8. شاشة الإعدادات الشاملة ذات الأقسام الستة
	hud.navigate_to("settings")
	hud.settings_screen.select_category("appearance")
	await _wait_frames(5)
	await _snap("ui_08_settings_6tabs.png")

	# 9. نافذة تأكيد الخروج الأنيقة على الشاشة الرئيسية
	hud.navigate_to("home", false)
	hud.exit_modal.open_modal()
	await _wait_frames(4)
	await _snap("ui_09_exit_modal.png")
	hud.exit_modal.close_modal()

	get_tree().quit(0)


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw


func _snap(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		var full_path: String = _out_dir.path_join(filename)
		img.save_png(full_path)
		print("  [CAPTURED] %s (%dx%d)" % [full_path, img.get_width(), img.get_height()])
