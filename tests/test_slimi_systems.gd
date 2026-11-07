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
		assert_true(not bool(cfg.get_value("preset.0.options", "permissions/internet", true)), "اللعبة تعمل دون صلاحية إنترنت")


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

	# فحص مستويات الجودة الرسومية (منخفضة / متوسطة / عالية)
	QualityManager.apply_preset(QualityManager.Preset.LOW, false)
	var low_mesh := slime.body_mesh_instance.mesh as SphereMesh
	assert_true(not room.sun_light.shadow_enabled and low_mesh.radial_segments == 24, "تطبيق المستوى المنخفض للأجهزة محدودة الموارد")

	QualityManager.apply_preset(QualityManager.Preset.HIGH, false)
	assert_true(room.sun_light.shadow_enabled and low_mesh.radial_segments == 48, "تطبيق المستوى العالي للجودة الرسومية")
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
	for _f in range(bench_frames):
		slime._physics_process(1.0 / 60.0)
		slime.deformer._process(1.0 / 60.0)
		slime.face_rig._process(1.0 / 60.0)
		slime.mood_system._process(1.0 / 60.0)
		ai._process(1.0 / 60.0)
	var elapsed_ms: float = float(Time.get_ticks_usec() - start_usec) / 1000.0
	var avg_cpu_ms: float = elapsed_ms / float(bench_frames)
	print("  [PERF] متوسط زمن معالجة منطق وفيزياء وتشوه سلايمي لكل إطار: %.3f ms (الميزانية < 4.0 ms)" % avg_cpu_ms)
	assert_true(avg_cpu_ms < 4.0, "كفاءة عالية لمعالجة الإطار على المعالجات محدودة الموارد")

	main_inst.queue_free()
	await tree.process_frame
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	assert_true(orphans == 0, "عدم وجود أي عقد يتيمة أو تسريب في الذاكرة (Orphan Nodes = 0)")
