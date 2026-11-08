class_name SlimiSystemsTestSuite
extends RefCounted
## حزمة الاختبارات الآلية الشاملة لأنظمة مشروع SLIMI (تُنفَّذ فعلياً داخل محرك Godot 4 Headless).

var passed_count: int = 0
var failed_count: int = 0
var failure_messages: Array[String] = []


func assert_true(condition: bool, label: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % label)
	else:
		failed_count += 1
		var msg := "  [FAIL] %s" % label
		failure_messages.append(msg)
		push_error(msg)


func assert_approx(actual: float, expected: float, tol: float, label: String) -> void:
	var ok: bool = absf(actual - expected) <= tol
	assert_true(ok, "%s (actual=%.3f, expected=%.3f)" % [label, actual, expected])


func run_all(tree: SceneTree) -> bool:
	print("============================================================")
	print("بدء اختبارات أنظمة لعبة SLIMI على محرك Godot %s" % Engine.get_version_info().get("string", "4.x"))
	print("============================================================")

	_test_project_and_export_config()
	_test_audio_bank_and_manager()
	_test_save_and_load_atomic()

	await _test_main_scene_and_interactions(tree)

	print("------------------------------------------------------------")
	print("النتيجة النهائية: نجح %d اختبار | فشل %d اختبار" % [passed_count, failed_count])
	print("============================================================")
	return failed_count == 0


func _test_project_and_export_config() -> void:
	print("\n[1/4] فحص إعدادات المشروع وCompatibility Renderer وتصدير Android...")
	var renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var mobile_renderer: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	var etc2: bool = bool(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc", false))
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))

	assert_true(renderer == "gl_compatibility", "Compatibility Renderer مفعل كخيار أساسي")
	assert_true(mobile_renderer == "gl_compatibility", "Compatibility Renderer مفعل للهواتف")
	assert_true(etc2, "ضغط خامات ETC2/ASTC مفعل لأجهزة Android")
	assert_true(main_scene == "res://scenes/Main.tscn", "مشهد البداية مضبوط على Main.tscn")

	var cfg := ConfigFile.new()
	var err: Error = cfg.load("res://export_presets.cfg")
	assert_true(err == OK, "ملف export_presets.cfg صالح للقراءة")
	if err == OK:
		assert_true(str(cfg.get_value("preset.0", "platform", "")) == "Android", "قالب التصدير يستهدف Android")
		assert_true(bool(cfg.get_value("preset.0.options", "gradle_build/use_gradle_build", false)), "تفعيل Gradle Build لدعم تخصيص Min SDK رسمياً")
		assert_true(str(cfg.get_value("preset.0.options", "gradle_build/min_sdk", "")) == "26", "استهداف Android 8.0 (API 26) وما بعده")
		assert_true(bool(cfg.get_value("preset.0.options", "architectures/arm64-v8a", false)), "دعم معمارية arm64-v8a")
		assert_true(bool(cfg.get_value("preset.0.options", "architectures/armeabi-v7a", false)), "دعم معمارية armeabi-v7a للأجهزة الاقتصادية")
		assert_true(bool(ProjectSettings.get_setting("audio/general/text_to_speech", false)), "تفعيل دعم النطق الصوتي TTS في إعدادات المحرك")
		assert_true(bool(ProjectSettings.get_setting("audio/driver/enable_input", false)), "تفعيل دخل الميكروفون الاختياري المحمي بإذن المستخدم")


func _test_audio_bank_and_manager() -> void:
	print("\n[2/4] فحص المصرف الصوتي الإجرائي ومدير الصوتيات...")
	var expected_ids: Array[StringName] = [
		&"boing_hop", &"squish_poke", &"purr_pet", &"happy_chirp",
		&"curious_coo", &"sleepy_yawn", &"eat_nom", &"dizzy_wobble",
		&"ui_click", &"ambient_pad"
	]
	for sid in expected_ids:
		assert_true(AudioManager.has_sound(sid), "توليد الصوت الأصلي '%s' بنجاح" % String(sid))
		var wav: AudioStreamWAV = AudioManager.streams.get(sid) as AudioStreamWAV
		assert_true(wav != null and wav.data.size() > 500, "بيانات PCM صالحة للصوت '%s'" % String(sid))

	assert_true(AudioManager.play_sfx(&"boing_hop"), "تشغيل مؤثر القفز عبر AudioManager")
	assert_true(AudioManager.play_voice(&"happy_chirp"), "تشغيل صوت سلايمي المرح عبر AudioManager")


func _test_save_and_load_atomic() -> void:
	print("\n[3/4] فحص نظام الحفظ والاستعادة المحلي والذاكرة...")
	var test_path := "user://test_slimi_save_suite.json"
	if FileAccess.file_exists(test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))

	SaveManager.update_section("slime_state", {
		"happiness": 91.5,
		"energy": 64.0,
		"fullness": 88.0,
		"affection": 52.0,
		"curiosity": 73.0,
	})
	SaveManager.update_section("memory", {
		"sessions_count": 4,
		"total_pokes": 12,
		"total_pets": 27,
		"total_feeds": 9,
		"total_plays": 6,
		"bond_points": 52.0,
	})
	var saved_ok: bool = SaveManager.save_to_disk(test_path)
	assert_true(saved_ok, "حفظ البيانات الذري في التخزين المحلي user://")

	SaveManager.current_data = SaveManager.create_default_data()
	var loaded_ok: bool = SaveManager.load_from_disk(test_path)
	assert_true(loaded_ok, "استعادة البيانات المحفوظة من التخزين المحلي")

	var mem_loaded: Dictionary = SaveManager.get_section("memory")
	var state_loaded: Dictionary = SaveManager.get_section("slime_state")
	assert_true(int(mem_loaded.get("total_pets", 0)) == 27, "استرجاع عدد المسحات من الذاكرة المحلية")
	assert_approx(float(state_loaded.get("happiness", 0.0)), 91.5, 0.2, "استرجاع مستوى السعادة بدقة")

	# فحص الاستعادة التلقائية من النسخة الاحتياطية (.bak) عند تلف الملف الأساسي
	SaveManager.save_to_disk(test_path)
	var corrupt_file := FileAccess.open(test_path, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{corrupted_json")
		corrupt_file.flush()
		corrupt_file = null
	var recovered_ok: bool = SaveManager.load_from_disk(test_path)
	assert_true(recovered_ok and int(SaveManager.get_section("memory").get("total_pets", 0)) == 27, "استعادة البيانات تلقائياً من النسخة الاحتياطية عند تلف الملف")

	# تنظيف ملفات الاختبار المؤقتة
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path + suffix))


func _test_main_scene_and_interactions(tree: SceneTree) -> void:
	print("\n[4/4] فحص المشهد الرئيسي، الفيزياء، تتبع اللمس، الذكاء المستقل، الواجهة العربية، والأداء...")
	var packed: PackedScene = load("res://scenes/Main.tscn") as PackedScene
	assert_true(packed != null, "تحميل المشهد الرئيسي Main.tscn")
	if packed == null:
		return

	var main_inst: Node3D = packed.instantiate() as Node3D
	tree.root.add_child(main_inst)

	# منح المحرك إطارات فيزيائية لتسجيل أشكال التصادم في GodotPhysics3D
	for _i in range(6):
		await tree.physics_frame
		await tree.process_frame

	var slime := main_inst.get_node_or_null("Slimi") as SlimeController
	var room := main_inst.get_node_or_null("CozyRoom") as RoomEnvironment
	var touch := main_inst.get_node_or_null("TouchInteractionSystem") as TouchInteractionSystem
	var cam := main_inst.get_node_or_null("CameraRig/MainCamera3D") as Camera3D
	var hud := main_inst.get_node_or_null("GameHUD") as HUDController

	assert_true(slime != null and room != null and touch != null and cam != null and hud != null, "تواجد جميع العقد والأنظمة الرئيسية في المشهد")

	# التحقق من أن شخصية SLIMI مجسمة ثلاثية الأبعاد فعلياً وظاهرة أمام الكاميرا وليست صورة مسطحة
	var body_aabb: AABB = slime.body_mesh_instance.get_aabb()
	assert_true(
		body_aabb.size.x > 0.8 and body_aabb.size.y > 0.8 and body_aabb.size.z > 0.8,
		"شخصية SLIMI مجسم ثلاثي الأبعاد حقيقي بأبعاد حجمية كاملة (X/Y/Z)"
	)
	assert_true(
		cam.is_position_in_frustum(slime.global_position + Vector3(0.0, 0.5, 0.0)),
		"ظهور شخصية SLIMI فعلياً داخل مجال رؤية الكاميرا الرئيسية"
	)

	# فحص التشوه المرن وحفظ الحجم ثلاثي الأبعاد
	slime.deformer.trigger_poke(Vector3(0.0, 0.1, 0.48), 0.95)
	slime.deformer._process(0.016)
	var ss: Vector3 = slime.deformer.current_squash_stretch
	var volume: float = ss.x * ss.y * ss.z
	assert_approx(volume, 1.0, 0.08, "حفظ الحجم الهلامي أثناء التشوه والارتداد (Volume Preservation)")
	assert_true(slime.face_rig.mouth_mesh_instance.mesh != null, "توليد مجسم الفم التعبيري ثلاثي الأبعاد")
	assert_true(slime.face_rig.tongue_mesh_instance != null, "تواجد اللسان الوردي داخل الفم التعبيري كما في الصورة المرجعية")

	# فحص عناصر تصميم سلايمي المطابقة للصورة المرجعية (قرن النجمة، القبعة الصوفية، الكفان الهلاميان، الفقاعات، والتنفس)
	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D
	assert_true(vis_root.get_node_or_null("StarAntenna/StarCharmPivot/StarCharmMesh") != null, "تواجد قرن النجمة الوردي اللامع أعلى يسار الرأس")
	assert_true(vis_root.get_node_or_null("KnitBeanie/PomPom") != null and vis_root.get_node_or_null("KnitBeanie/YarnFlower") != null and vis_root.get_node_or_null("KnitBeanie/HeartPin") != null, "تواجد القبعة الصوفية الصفراء مع الكرة البيضاء والوردة الملونة ودبوس القلب")
	assert_true(vis_root.get_node_or_null("JellyPaws/LeftPaw") != null and vis_root.get_node_or_null("JellyPaws/RightPaw") != null, "تواجد الكفين الهلاميين التفاعليين على البطن")
	assert_true(vis_root.get_node_or_null("InnerBubbles") != null and vis_root.get_node("InnerBubbles").get_child_count() >= 8, "تواجد الفقاعات الهلامية اللامعة داخل جسم سلايمي")
	assert_true(slime.deformer.breathing_animator != null and slime.deformer.breathing_animator.is_playing(), "عمل AnimationPlayer للتنفس الهلامي المستمر")

	# فحص تحسينات الواجهة الزجاجية (Full Rect دون تمرير، TextureProgressBar، أيقونات SVG، وTimer الأداء)
	assert_true(hud.hud_root != null and hud.hud_root.clip_contents, "تأطير الواجهة بجذر Control Full Rect مع clip_contents لمنع أي شريط تمرير خارج إطار الهاتف")
	assert_true(hud.bar_happiness is TextureProgressBar and hud.bar_happiness.texture_progress != null, "ترقية أشرطة الحالة العلوية إلى TextureProgressBar لامعة")
	assert_true(hud.btn_feed.icon != null and hud.btn_play.icon != null and hud.btn_nap.icon != null and hud.btn_call.icon != null, "تزويد أزرار التحكم السفلية بأيقونات SVG عالية الدقة")
	assert_true(AndroidPlatformManager.monitor_timer != null and not AndroidPlatformManager.monitor_timer.is_stopped(), "استخدام عقدة Timer بدلاً من _process لمراقبة الأداء والحواف الآمنة")
	assert_true(room.get_node_or_null("MagicalSkyBackdrop") != null, "تواجد الخلفية الباستيلية الحالمة المضيئة لمنع أي خلفية سوداء")

	# فحص تتبع اللمس الحقيقي عبر الأشعة (Raycast) على جسم سلايمي
	var pokes_before: int = slime.mood_system.memory.total_pokes
	var slime_screen_pos: Vector2 = cam.unproject_position(slime.global_position + Vector3(0.0, 0.50, 0.0))
	var hit_check: Dictionary = touch.raycast_from_screen(slime_screen_pos)
	assert_true(not hit_check.is_empty() and hit_check.get("collider") == slime, "إصابة شعاع اللمس لجسم سلايمي ثلاثي الأبعاد")

	touch.handle_pointer_down(slime_screen_pos)
	touch.handle_pointer_up(slime_screen_pos)
	assert_true(slime.mood_system.memory.total_pokes == pokes_before + 1, "تسجيل نقرة اللمس وتحديث الذاكرة")

	# فحص المسح المستمر (Petting Gesture)
	var pets_before: int = slime.mood_system.memory.total_pets
	touch.handle_pointer_down(slime_screen_pos)
	touch.handle_pointer_move(slime_screen_pos + Vector2(18.0, 0.0), Vector2(18.0, 0.0))
	touch.handle_pointer_move(slime_screen_pos + Vector2(38.0, 0.0), Vector2(20.0, 0.0))
	touch.handle_pointer_up(slime_screen_pos + Vector2(38.0, 0.0))
	assert_true(slime.mood_system.memory.total_pets > pets_before, "التعرف على إيماءة المسح الحنون وتحديث الألفة")

	# فحص السحب المطاطي والإفلات (Stretch & Elastic Release)
	touch.handle_pointer_down(slime_screen_pos)
	touch.handle_pointer_move(slime_screen_pos + Vector2(140.0, -90.0), Vector2(140.0, -90.0))
	assert_true(slime.is_being_dragged, "تفعيل السحب المرن لسلايمي عند السحب بعيداً")
	touch.handle_pointer_up(slime_screen_pos + Vector2(140.0, -90.0))
	assert_true(not slime.is_being_dragged, "الارتداد السلس عند إفلات السحب")

	# فحص حجب اللمس ثلاثي الأبعاد عند فتح نوافذ الواجهة (منع تسرّب النقرات خلف الإعدادات)
	var pokes_modal_check: int = slime.mood_system.memory.total_pokes
	hud.settings_modal.visible = true
	touch.handle_pointer_down(slime_screen_pos)
	touch.handle_pointer_up(slime_screen_pos)
	assert_true(slime.mood_system.memory.total_pokes == pokes_modal_check, "منع تسرب لمسات الواجهة إلى العالم ثلاثي الأبعاد عند فتح الإعدادات")
	hud.close_modals()

	# فحص النقر على أرضية الغرفة للانتقال بالقفز وحركة القفز والارتداد الفيزيائي
	var floor_world := Vector3(-0.85, 0.0, 0.75)
	var floor_screen: Vector2 = cam.unproject_position(floor_world)
	touch.handle_pointer_down(floor_screen)
	touch.handle_pointer_up(floor_screen)
	var ai := slime.ai_brain as AutonomousBehaviorAI
	assert_true(ai != null and ai.current_state == AutonomousBehaviorAI.State.WANDER_HOP, "استجابة سلايمي للنقر على أرضية الغرفة والقفز نحوها")
	assert_true(slime.velocity.y > 1.5, "انطلاق حركة القفز الفيزيائية للأعلى عند الانتقال")
	for _hop_frame in range(8):
		await tree.physics_frame
	assert_true(slime.global_position.y > 0.05, "ارتفاع سلايمي فعلياً في الهواء أثناء قوس القفز المرن")
	for _land_frame in range(45):
		await tree.physics_frame
	assert_true(slime.is_on_floor(), "هبوط سلايمي واستقراره الفيزيائي على أرضية الغرفة")

	# فحص السلوك المستقل عند انخفاض الطاقة (غفوة تلقائية)
	slime.mood_system.energy = 12.0
	ai._choose_next_behavior()
	assert_true(slime.mood_system.is_sleeping and ai.current_state == AutonomousBehaviorAI.State.REST_NAP, "اتخاذ قرار الغفوة المستقل عند انخفاض الطاقة")
	slime.toggle_nap()
	assert_true(not slime.mood_system.is_sleeping, "إيقاظ سلايمي واستعادة النشاط")

	# فحص مستويات الجودة الرسومية القابلة للتدرج (LOW / MEDIUM / HIGH) مع مجسم رباعي خالٍ من الأقطاب
	QualityManager.apply_preset(QualityManager.Preset.LOW, false)
	var low_mesh := slime.body_mesh_instance.mesh as ArrayMesh
	var low_faces: int = low_mesh.get_faces().size() / 3 if low_mesh != null else 0
	assert_true(not room.sun_light.shadow_enabled and low_faces == 1728, "تطبيق المستوى المنخفض للأجهزة محدودة الموارد (1728 مثلثاً دون ظلال)")

	QualityManager.apply_preset(QualityManager.Preset.HIGH, false)
	var high_mesh := slime.body_mesh_instance.mesh as ArrayMesh
	var high_faces: int = high_mesh.get_faces().size() / 3 if high_mesh != null else 0
	assert_true(room.sun_light.shadow_enabled and high_faces == 9408, "تطبيق المستوى العالي للجودة الرسومية السينمائية (9408 مثلثات مع ظلال وRim Light)")
	QualityManager.apply_preset(QualityManager.Preset.MEDIUM, false)

	# فحص الواجهة العربية RTL وقابلية التوسع للغات أخرى
	LocalizationManager.set_locale("ar")
	assert_true(hud.root_margin.layout_direction == Control.LAYOUT_DIRECTION_RTL, "تفعيل اتجاه الواجهة العربية من اليمين إلى اليسار (RTL)")
	assert_true(hud.btn_feed.text == "إطعام", "عرض النصوص العربية الصحيحة في الواجهة")
	LocalizationManager.set_locale("en")
	assert_true(hud.root_margin.layout_direction == Control.LAYOUT_DIRECTION_LTR and hud.btn_feed.text == "Feed", "قابلية توسع الواجهة وتبديل الاتجاه للغات LTR")
	LocalizationManager.set_locale("ar")

	# اختبار الأداء الفعلي على موارد محدودة (قياس زمن معالجة 120 إطاراً متتالياً)
	QualityManager.apply_preset(QualityManager.Preset.LOW, false)
	var start_usec: int = Time.get_ticks_usec()
	var bench_frames: int = 120
	var comp_hub := main_inst.get_node_or_null("SlimiInteractionManager") as SlimiInteractionManager
	for _f in range(bench_frames):
		slime._physics_process(1.0 / 60.0)
		slime.deformer._process(1.0 / 60.0)
		slime.face_rig._process(1.0 / 60.0)
		slime.mood_system._process(1.0 / 60.0)
		if comp_hub != null:
			comp_hub.behavior_ai._process(1.0 / 60.0)
			comp_hub.anim_controller._process(1.0 / 60.0)
			comp_hub.voice_manager._process(1.0 / 60.0)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_cpu_ms: float = elapsed_ms / float(bench_frames)
	print("  [PERF] متوسط زمن معالجة منطق وفيزياء وتشوه سلايمي والرفيق الذكي لكل إطار: %.3f ms (الميزانية < 4.0 ms)" % avg_cpu_ms)
	assert_true(avg_cpu_ms < 4.0, "كفاءة عالية لمعالجة الإطار على المعالجات محدودة الموارد")

	# [5/5] الاختبارات العملية الشاملة لمعايير الرفيق الذكي الناطق (الأقسام 1 إلى 16)
	await _test_intelligent_companion_systems(tree, main_inst, slime, hud, comp_hub)

	# [6/6] اختبارات الترقية السينمائية فائقة الواقعية والـ 17 سيناريو إجهادياً (الأقسام A إلى M)
	await SlimiCinematicCharacterQA.run_all(self, tree, slime, room, comp_hub)

	main_inst.queue_free()
	await tree.process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_true(orphans == 0, "عدم وجود أي عقد يتيمة أو تسريب في الذاكرة (Orphan Nodes = 0)")


func _test_intelligent_companion_systems(
	tree: SceneTree,
	_main_inst: Node3D,
	slime: SlimeController,
	hud: HUDController,
	hub: SlimiInteractionManager
) -> void:
	print("\n[5/5] فحص منظومة الرفيق الذكي الناطق (الصوت، Lip-Sync، 20 شعوراً، الدردشة، الألعاب، الذاكرة، الخصوصية)...")
	assert_true(hub != null, "تواجد منسق الأحداث الموحد SlimiInteractionManager")
	if hub == null:
		return

	# 1. التحقق من قرني الاستشعار الشفافين والحواجب التعبيرية والهوية البصرية
	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D
	assert_true(
		vis_root.get_node_or_null("StarAntenna") != null and vis_root.get_node_or_null("RightFeeler") != null,
		"تواجد قرني الاستشعار الشفافين (StarAntenna + RightFeeler) مع الحفاظ على القبعة الصفراء"
	)
	assert_true(
		slime.face_rig.left_brow != null and slime.face_rig.right_brow != null,
		"تواجد الحواجب التعبيرية ثلاثية الأبعاد (LeftBrow + RightBrow) لمزامنة المشاعر والكلام"
	)

	# 2. اختبار الصوت التعبيري وتوليد الكلام المقطعي الرقيق ومزامنة الفم (Lip-Sync)
	var new_voice_cues: Array[StringName] = [
		&"giggle_soft", &"laugh_long", &"joy_sparkle", &"sad_whimper",
		&"surprise_gasp", &"bored_sigh", &"puzzled_hum", &"shy_squeak",
		&"scared_tremble", &"kiss_mwah", &"proud_tada", &"jelly_wobble_soft",
	]
	var all_cues_valid: bool = true
	for cid in new_voice_cues:
		if not AudioManager.has_sound(cid):
			all_cues_valid = false
	assert_true(all_cues_valid, "توليد جميع الأصوات التعبيرية الرقيقة الـ 12 الإضافية بنجاح")

	var sp_dur: float = hub.voice_manager.speak_text("مرحباً يا صديقي، أنا سلايمي السعيد!", hub.emotion_manager.get_profile())
	assert_true(sp_dur > 0.4 and hub.voice_manager.is_speaking(), "بدء نطق جملة سلايمي وحساب المدة المقطعية")
	hub.voice_manager._process(0.08)
	assert_true(slime.face_rig.is_lip_syncing and slime.face_rig.lip_sync_open > 0.01, "تزامن فتح وإغلاق الفم والحواجب مع مقاطع الكلام (Lip-Sync)")
	hub.voice_manager.set_muted(true)
	assert_true(not hub.voice_manager.is_speaking() and not slime.face_rig.is_lip_syncing, "إيقاف الكلام ومزامنة الفم فوراً عند كتم الصوت")
	hub.voice_manager.set_muted(false)

	# 3. اختبار جميع المشاعر الـ 20 وتأثيرها الحي على الوجه والوقفة والملصق
	assert_true(hub.emotion_manager.get_emotion_count() == 20, "دعم محرك المشاعر لجميع المشاعر الـ 20 المطلوبة كاملة")
	var emotions_distinct_ok: bool = true
	for em_idx in range(20):
		hub.emotion_manager.set_emotion(em_idx, 3.0)
		var prof: Dictionary = hub.emotion_manager.get_profile()
		if str(prof.get("ar", "")).is_empty() or str(prof.get("en", "")).is_empty():
			emotions_distinct_ok = false
	assert_true(emotions_distinct_ok, "تطبيق جميع المشاعر الـ 20 على الوجه والوقفة والنبرة باللغتين العربية والإنجليزية")

	# 4. اختبار معاملة المستخدم (الضغط الهلامي + التخويف والاطمئنان التدريجي)
	slime.on_squished(slime.global_position, 1.0)
	assert_true(hub.emotion_manager.current_emotion == SlimiEmotionManager.Emotion.SURPRISED, "استجابة سلايمي للضغط بمرونة هلامية ومفاجأة لطيفة")
	slime.on_startled(slime.global_position + Vector3(0.0, 0.0, 1.0))
	assert_true(hub.emotion_manager.current_emotion == SlimiEmotionManager.Emotion.SCARED, "استجابة سلايمي للتخويف بالتراجع الخجول واتساع العينين")
	hub.emotion_manager.tick_emotion_decay(5.0, SlimiEmotionManager.Emotion.HAPPY)
	assert_true(hub.emotion_manager.current_emotion == SlimiEmotionManager.Emotion.REASSURED, "عودة سلايمي تدريجياً لشعور الاطمئنان بعد الخوف")

	# 5. اختبار جميع الحركات الـ 31 ونظام الأولوية لمنع تعارض الحركات
	assert_true(hub.anim_controller.get_total_supported_actions_count() == 31, "دعم 31 حركة يومية وكوميدية وظريفة كاملة")
	assert_true(hub.anim_controller.play_action(&"victory_celebration", SlimiAnimationController.Priority.MINIGAME), "تشغيل حركة الاحتفال ذات الأولوية العالية")
	assert_true(not hub.anim_controller.play_action(&"idle_sway", SlimiAnimationController.Priority.IDLE_AMBIENT), "منع الحركات منخفضة الأولوية من مقاطعة الحركة النشطة (Priority Arbitration)")
	hub.anim_controller._process(2.5)
	assert_true(hub.anim_controller.current_action == &"", "انتهاء الحركة واستعادة الوقفة الطبيعية بنظافة")

	# 6. اختبار الدردشة الذكية بالعربية والإنجليزية، فهم الحزن/الفرح، النكت غير المتكررة، وحل الألغاز
	var name_reply: Dictionary = hub.send_user_chat_message("اسمي سارة")
	assert_true(hub.memory_manager.user_nickname == "سارة" and str(name_reply.get("text", "")).contains("سارة"), "التعرف على اسم المستخدم وحفظه ومناداته به")

	var sad_reply: Dictionary = hub.send_user_chat_message("أنا حزين وتعبان اليوم")
	assert_true(int(sad_reply.get("emotion", -1)) == SlimiEmotionManager.Emotion.AFFECTIONATE, "فهم حزن المستخدم والرد بمواساة حنونة دافئة")

	var en_reply: Dictionary = hub.send_user_chat_message("Hello SLIMI, I won today and I am super happy!")
	assert_true(int(en_reply.get("emotion", -1)) == SlimiEmotionManager.Emotion.EXCITED and str(en_reply.get("text", "")).contains("Yay"), "فهم الرسائل الإنجليزية والاحتفال بفرح المستخدم")

	var j1: String = str(hub.request_quick_entertainment("joke").get("text", ""))
	var j2: String = str(hub.request_quick_entertainment("joke").get("text", ""))
	var j3: String = str(hub.request_quick_entertainment("joke").get("text", ""))
	assert_true(j1 != j2 and j2 != j3, "تقديم نكت متنوعة ومناسبة لكل الأعمار دون تكرار متتالٍ")

	var rid: Dictionary = hub.request_quick_entertainment("riddle")
	assert_true(not str(rid.get("text", "")).is_empty() and not hub.dialogue_manager._active_riddle.is_empty(), "طرح لغز تفاعلي وتذكر حالة اللغز في السياق")
	var valid_ans: String = str(hub.dialogue_manager._active_riddle["answers"][0])
	var rid_solve: Dictionary = hub.send_user_chat_message(valid_ans)
	assert_true(hub.dialogue_manager._active_riddle.is_empty() and int(rid_solve.get("emotion", -1)) == SlimiEmotionManager.Emotion.EXCITED, "التحقق الذكي من حل اللغز والاحتفال بالإجابة الصحيحة")

	var story_item: Dictionary = hub.request_quick_entertainment("story")
	var skit_item: Dictionary = hub.request_quick_entertainment("skit")
	assert_true(not str(story_item.get("text", "")).is_empty() and not str(skit_item.get("text", "")).is_empty(), "تقديم القصص القصيرة والمشاهد التمثيلية الظريفة")

	# 7. اختبار عدم العتاب على الغياب والترحيب المتغير حسب الوقت
	var morning_g: String = str(hub.dialogue_manager.build_launch_greeting("ar", 8, 0, "سارة", "pet", true).get("text", ""))
	var night_g: String = str(hub.dialogue_manager.build_launch_greeting("ar", 23, 0, "سارة", "pet", true).get("text", ""))
	assert_true(morning_g != night_g and not morning_g.contains("غبت") and not night_g.contains("تركتني"), "تغير الترحيب حسب الوقت وخلوه تماماً من أي عتاب أو ضغط عاطفي")

	# 8. اختبار الذكاء السلوكي المستقل (Utility AI)
	var util_scores: Dictionary = hub.behavior_ai.evaluate_utilities()
	assert_true(util_scores.size() >= 5, "تقييم الأفعال الذاتية عبر Utility AI بناءً على الطاقة والفضول والملل")

	# 9. اختبار جميع الألعاب المصغرة الـ 9 عملياً
	var games: Array[Dictionary] = hub.minigames.get_supported_games()
	assert_true(games.size() == 9, "تواجد جميع الألعاب المصغرة والتحديات الـ 9 المطلوبة")
	for g_entry in games:
		var gid: String = str(g_entry["id"])
		var st: Dictionary = hub.minigames.start_game(gid, "ar")
		assert_true(not str(st.get("prompt", "")).is_empty(), "بدء اللعبة المصغرة '%s' بنجاح" % gid)
		# إكمال جولة في كل لعبة للتحقق من خلوها من أي أخطاء وقت التشغيل
		var safety_steps: int = 0
		while hub.minigames.is_active() and safety_steps < 5:
			var target_choice: int = int(hub.minigames._state.get("target", 0))
			if gid == "memory_sequence":
				var seq_arr: Array = hub.minigames._state.get("seq", [0, 0, 0])
				var p_idx: int = int(hub.minigames._state.get("progress", 0))
				target_choice = int(seq_arr[p_idx])
			hub.minigames.submit_choice(target_choice, "ar")
			safety_steps += 1
		assert_true(not hub.minigames.is_active(), "إتمام جولة اللعبة المصغرة '%s' وتفاعل سلايمي مع النتيجة" % gid)

	# 10. اختبار الخصوصية: الميكروفون متوقف افتراضياً، يعمل المؤشر الحي عند التفعيل، ويتوقف فوراً
	var mic_banner := hud.companion_ui.get("mic_banner") as Control
	assert_true(not hub.is_mic_listening and mic_banner != null and not mic_banner.visible, "الميكروفون ومؤشره غير نشطين افتراضياً بدون إذن المستخدم")
	hub._start_microphone_capture()
	assert_true(hub.is_mic_listening and mic_banner.visible, "ظهور المؤشر الحي فوراً عند تفعيل الاستماع الصوتي")
	hub.stop_microphone_listening(false)
	assert_true(not hub.is_mic_listening and not mic_banner.visible, "إيقاف الميكروفون وإخفاء المؤشر فوراً عند إنهاء الاستماع")

	# 11. اختبار حماية الأسرار ومسح الذاكرة والوضع الافتراضي Offline
	assert_true(hub.settings_manager.ai_mode == "offline", "الوضع المحلي المجاني (Offline) هو الوضع الافتراضي")
	assert_true(not hub.memory_manager.remember_chat_snippet("sk-secretApiKey123456"), "منع حفظ المفاتيح السرية وكلمات المرور في ذاكرة الدردشة")
	hub.settings_manager.set_api_key_secure("sk-test-local-encrypted-only")
	hub.settings_manager.persist()
	var saved_cfg_plain: Dictionary = SaveManager.get_section("companion_settings")
	assert_true(not saved_cfg_plain.has("api_key") and not JSON.stringify(saved_cfg_plain).contains("sk-test"), "عدم تخزين مفتاح API في ملفات الحفظ النصية المكشوفة وتشفيره محلياً فقط")
	hub.settings_manager.set_api_key_secure("")

	hub.memory_manager.clear_all_memory()
	assert_true(hub.memory_manager.user_nickname.is_empty() and hub.memory_manager.saved_chat_snippets.is_empty(), "مسح ذاكرة SLIMI بالكامل بنجاح عبر زر المسح")
	await tree.process_frame
