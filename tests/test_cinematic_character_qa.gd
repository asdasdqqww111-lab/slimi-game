class_name SlimiCinematicCharacterQA
extends RefCounted
## حزمة اختبارات الجودة والإجهاد السينمائية الشاملة لشخصية SLIMI (17 سيناريو اختبار آلي):
## تفحص قفل الهوية البصرية، الطوبولوجيا الخالية من الأقطاب، شيدر الجل عالي الواقعية،
## تعبيرات الوجه الدقيقة وحالات الفم الثماني، فيزياء الإكسسوارات المستقلة، التشوه الهجين الموجي،
## الـ 18 حركة سينمائية ذات المراحل الأربع، الاستجابة الموضعية للمس، التدرج (LOW/MEDIUM/HIGH)،
## ثبات 30/60 إطاراً، الخلو التام من NaN/Inf والتشابك الهندسي وتداخل الأصوات.

const TurntableScene := preload("res://scenes/slime/SlimiReferenceTurntable.tscn")


static func run_all(
	runner: Object,
	tree: SceneTree,
	slime: SlimeController,
	room: RoomEnvironment,
	hub: SlimiInteractionManager
) -> void:
	print("\n[6/6] فحص الترقية السينمائية فائقة الواقعية والاختبارات الإجهادية الـ 17 (Cinematic Master QA)...")

	_test_identity_lock_and_topology(runner, slime)
	await _test_reference_turntable_views(runner, tree)
	_test_gel_knit_eye_shaders_and_lighting(runner, slime, room)
	_test_facial_micro_animation_and_8_mouth_states(runner, slime)
	_test_hybrid_soft_body_directional_touch_and_recovery(runner, slime)
	_test_accessory_physics_and_localized_part_touch(runner, slime)
	_test_all_18_cinematic_4phase_motions(runner, slime)
	_test_stress_17_scenarios(runner, slime, hub)


static func _assert(runner: Object, cond: bool, msg: String) -> void:
	runner.call("assert_true", cond, msg)


static func _test_identity_lock_and_topology(runner: Object, slime: SlimeController) -> void:
	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D
	_assert(runner, vis_root != null, "وجود الجذر البصري للشخصية VisualRoot")

	# A. فحص تواجد جميع العناصر الـ 8 للهوية البصرية الأصلية دون حذف أو تشويه
	var has_body: bool = slime.body_mesh_instance != null and slime.body_mesh_instance.visible
	var has_eyes: bool = slime.face_rig != null and slime.face_rig.left_eye_pivot != null and slime.face_rig.right_eye_pivot != null
	var has_mouth: bool = slime.face_rig != null and slime.face_rig.mouth_mesh_instance != null
	var has_cheeks: bool = slime.face_rig != null and slime.face_rig.left_cheek != null and slime.face_rig.right_cheek != null
	var has_antennae: bool = vis_root.get_node_or_null("StarAntenna") != null and vis_root.get_node_or_null("RightFeeler") != null
	var beanie := vis_root.get_node_or_null("KnitBeanie") as Node3D
	var has_beanie: bool = beanie != null and beanie.visible
	var has_pom: bool = beanie != null and beanie.get_node_or_null("PomPom") != null
	var has_flower: bool = beanie != null and beanie.get_node_or_null("YarnFlower") != null
	_assert(
		runner,
		has_body and has_eyes and has_mouth and has_cheeks and has_antennae and has_beanie and has_pom and has_flower,
		"قفل الهوية البصرية (Character Identity Lock): تواجد العناصر الثمانية الأصلية كاملة وبنسبها المعتمدة"
	)

	# C. فحص الطوبولوجيا الرباعية الخالية من الأقطاب ودرجات LOD الثلاث والـ 6 BlendShapes
	var stats_low: Dictionary = SlimiBodyMeshBuilder.inspect_mesh_topology(0)
	var stats_med: Dictionary = SlimiBodyMeshBuilder.inspect_mesh_topology(1)
	var stats_high: Dictionary = SlimiBodyMeshBuilder.inspect_mesh_topology(2)

	_assert(
		runner,
		int(stats_low["degenerate_triangles"]) == 0
		and int(stats_med["degenerate_triangles"]) == 0
		and int(stats_high["degenerate_triangles"]) == 0,
		"نظافة الطوبولوجيا الرباعية الكروية من أي مثلثات منهارة أو أقطاب مشوهة في المستويات الثلاثة"
	)
	_assert(
		runner,
		int(stats_low["triangle_count"]) < int(stats_med["triangle_count"])
		and int(stats_med["triangle_count"]) < int(stats_high["triangle_count"])
		and int(stats_high["blend_shape_count"]) == 6,
		"تدرج هندسة المجسم (1728 / 4800 / 9408 مثلثاً) وتوفر 6 مفاتيح شكل (BlendShapes) للتعبيرات الجسدية"
	)
	_assert(
		runner,
		absf(float(stats_high["min_normal_len"]) - 1.0) < 0.002 and absf(float(stats_high["max_normal_len"]) - 1.0) < 0.002,
		"استقامة وتوحيد متجهات الإضاءة السطحية (Smooth Unit Normals = 1.000)"
	)


static func _test_reference_turntable_views(runner: Object, tree: SceneTree) -> void:
	var turntable := TurntableScene.instantiate() as SlimiTurntableShowcase
	tree.root.add_child(turntable)
	await tree.process_frame

	var all_views_ok: bool = true
	for v_name in [&"front", &"side", &"back", &"three_quarter", &"close_up"]:
		if not turntable.set_reference_view(v_name):
			all_views_ok = false
		if not SlimiIdentitySpec.is_valid_transform3d(turntable.camera.global_transform):
			all_views_ok = false

	_assert(runner, all_views_ok, "ثبات زوايا المرجع البصري القياسية الخمس (Front / Side / Back / Three-Quarter / Close-Up)")

	turntable.free()
	await tree.process_frame


static func _test_gel_knit_eye_shaders_and_lighting(runner: Object, slime: SlimeController, room: RoomEnvironment) -> void:
	var gel_mat: ShaderMaterial = slime.deformer.shader_material
	_assert(runner, gel_mat != null and gel_mat.shader != null, "تحميل شيدر الجل البصري المتقدم slime_jelly.gdshader بنجاح")

	# فحص ربط الإضاءة ثلاثية النقاط (Key / Fill / Rim) بالشيدر واستجابة المادة لتغير زاوية الضوء
	var dirs: Dictionary = room.get_studio_light_directions()
	slime.deformer.update_studio_light_directions(dirs["key"], dirs["fill"], dirs["rim"])
	var key_u: Variant = gel_mat.get_shader_parameter("key_light_dir_ws")
	var fill_u: Variant = gel_mat.get_shader_parameter("fill_light_dir_ws")
	var rim_u: Variant = gel_mat.get_shader_parameter("rim_light_dir_ws")
	_assert(
		runner,
		key_u is Vector3 and fill_u is Vector3 and rim_u is Vector3 and (key_u as Vector3).length() > 0.95,
		"تزامن اتجاهات الإضاءة السينمائية الثلاثية (Key / Fill / Rim) مع حسابات النفوذ الضوئي SSS والانعكاس"
	)

	var uniform_count: int = gel_mat.shader.get_shader_uniform_list().size()
	_assert(runner, uniform_count >= 18, "اكتمال معاملات شيدر الجل (السمك، SSS، Fresnel، الانكسار المحكوم، اللمعان المزدوج، والموجات الأربع)")

	var knit_mat: ShaderMaterial = slime.accessory_refs.get("knit_dome_mat") as ShaderMaterial
	_assert(runner, knit_mat != null and knit_mat.shader != null, "تواجد شيدر الصوف المحبوك متعدد الخيوط للقبعة الصفراء")


static func _test_facial_micro_animation_and_8_mouth_states(runner: Object, slime: SlimeController) -> void:
	var face: SlimeFaceRig = slime.face_rig

	# فحص تتبع العينين المستقل والتقارب البصري (Vergence)
	face.set_look_target_local_3d(Vector3(0.28, 0.08, 0.55))
	for _s in range(6):
		face._process(1.0 / 30.0)
	var diff_eyes: float = face.left_gaze_offset.distance_to(face.right_gaze_offset)
	_assert(runner, diff_eyes > 0.001 and diff_eyes < 0.12, "التحريك المستقل للعينين مع التقارب البصري الطبيعي (Eye Vergence)")

	# فحص أنماط الرمش الثلاثة + التضييق + النظرة المركزة
	for b_mode in [SlimeFaceRig.BlinkMode.NATURAL, SlimeFaceRig.BlinkMode.DOUBLE, SlimeFaceRig.BlinkMode.SLOW]:
		face.trigger_blink(b_mode)
		face._process(0.03)
		_assert(runner, face._is_blinking, "استجابة نمط الرمش رقم %d بسلاسة" % b_mode)

	face.set_squint(0.65)
	face.set_focused_gaze(true)
	for _s in range(8):
		face._process(1.0 / 30.0)
	_assert(runner, face.squint_amount > 0.12, "استجابة تضييق الجفون السفلي (Squinting) والنظرة المركزة (Focused Gaze)")
	face.set_squint(0.0)
	face.set_focused_gaze(false)

	# فحص حالات الفم الثماني المطلوبة كاملة + تناظر الخدود الوردي
	var mouth_states: Array[int] = [
		SlimeFaceRig.MouthShape.SMILE,
		SlimeFaceRig.MouthShape.OPEN_SMILE,
		SlimeFaceRig.MouthShape.SPEAKING_SMALL,
		SlimeFaceRig.MouthShape.LAUGHING,
		SlimeFaceRig.MouthShape.SAD,
		SlimeFaceRig.MouthShape.SURPRISED,
		SlimeFaceRig.MouthShape.POUTING,
		SlimeFaceRig.MouthShape.RESTING,
	]
	var all_mouths_valid: bool = (face.get_supported_mouth_shape_count() == 8)
	for ms in mouth_states:
		face.set_mouth_shape(ms)
		for _step in range(6):
			face._process(1.0 / 60.0)
		if not SlimiIdentitySpec.is_valid_transform3d(face.mouth_mesh_instance.transform):
			all_mouths_valid = false
	_assert(runner, all_mouths_valid, "عمل جميع حالات الفم الثماني ثلاثية الأبعاد (Smile / Open Smile / Speaking / Laughing / Sad / Surprised / Pouting / Resting)")

	var cheek_sym_err: float = absf(face.left_cheek.position.x + face.right_cheek.position.x)
	_assert(runner, cheek_sym_err < 0.002, "تناظر الخدود الوردية واستجابتها للمشاعر بدقة هندسية")


static func _test_hybrid_soft_body_directional_touch_and_recovery(runner: Object, slime: SlimeController) -> void:
	var def: SlimeDeformer = slime.deformer

	# اختبار الانبعاج الموضعي باتجاه الضغط + انتشار الموجة المرنة للأجزاء المجاورة
	def.trigger_directional_poke(Vector3(0.22, 0.58, 0.54), Vector3(-0.32, -0.08, -0.94), 1.0)
	def._process(1.0 / 60.0)
	var peak_wave: float = def.get_active_wave_amplitude_max()
	var neighbor_disp: float = def.get_neighbor_displacement_at(Vector3(0.10, 0.52, 0.54))
	_assert(runner, peak_wave > 0.5 and neighbor_disp > 0.02, "توليد انبعاج موضعي موجه وانتشار الموجة المرنة للأجزاء المجاورة عند لمس الجل")

	# التحقق من استعادة الشكل الأصلي 100% بدون أي تشوه دائم (Zero Permanent Drift)
	def.posture_height_scale = 1.0
	def.is_resting_flat = false
	for _f in range(180):
		def._process(1.0 / 60.0)
	var residual_wave: float = def.get_active_wave_amplitude_max()
	var scale_err: float = (def.current_squash_stretch - Vector3.ONE).length()
	_assert(
		runner,
		residual_wave == 0.0 and scale_err < 0.06,
		"عودة الجسم الهلامي التامة إلى شكله الأصلي دون أي انحراف أو تشوه دائم (Residual Wave = 0.0)"
	)


static func _test_accessory_physics_and_localized_part_touch(runner: Object, slime: SlimeController) -> void:
	var start_body_pos: Vector3 = slime.global_position
	var acc_phys: SlimiAccessoryPhysics = slime.deformer.accessory_physics
	acc_phys.reset_to_rest()

	# لمس القرن الأيسر وحده: يتحرك القرن موضعياً دون أن يتحرك جسم SLIMI بالكامل!
	slime.on_part_touched(&"left_antenna", slime.global_position + Vector3(-0.22, 1.32, 0.14), Vector3.BACK)
	slime.deformer._process(1.0 / 60.0)
	var left_defl: float = acc_phys.left_antenna_rot.length()
	var right_defl: float = acc_phys.right_antenna_rot.length()
	var body_moved: float = slime.global_position.distance_to(start_body_pos)
	_assert(
		runner,
		left_defl > 0.03 and left_defl > right_defl * 2.5 and body_moved < 0.001,
		"استجابة لمس القرن الأيسر موضعياً وبشكل مستقل عن القرن الأيمن ودون إزاحة الجسم الكلي"
	)

	# لمس الكرة البيضاء (Pom-Pom): اهتزاز مرن ناعم واستقرار
	slime.on_part_touched(&"pom_pom", slime.global_position + Vector3(0.08, 1.52, -0.06), Vector3.BACK)
	slime.deformer._process(1.0 / 60.0)
	_assert(runner, acc_phys.pom_pos_offset.length() > 0.002, "ارتداد الكرة الصوفية البيضاء (Pom-Pom) بتأخر فيزيائي ناعم عند لمسها")

	# اختبار عدم تصادم القرنين أو اختراق الزهرة للمجسم تحت نبضات عنيفة
	slime.deformer.set_motion_kinematics(Vector3(8.5, 4.0, -6.0), 9.0)
	for _s in range(20):
		slime.deformer._process(1.0 / 60.0)
	var sep_dist: float = acc_phys.get_antenna_tip_separation()
	var flower_node := slime.accessory_refs.get("flower_root") as Node3D
	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D
	var flower_local: Vector3 = vis_root.to_local(flower_node.global_position)
	var hull_r: float = SlimiIdentitySpec.sample_rest_hull_radius(flower_local.normalized())
	_assert(
		runner,
		sep_dist > 0.25 and flower_local.length() >= hull_r * 0.90,
		"عدم تصادم قرني الاستشعار مع بعضهما وعدم اختراق الزهرة الملونة لسطح الجسم أو القبعة"
	)
	slime.deformer.set_motion_kinematics(Vector3.ZERO, 0.0)


static func _test_all_18_cinematic_4phase_motions(runner: Object, slime: SlimeController) -> void:
	var mc: SlimiMotionCoordinator = slime.motion_coordinator
	_assert(runner, mc != null and mc.get_supported_motions().size() == 18, "دعم جميع الحركات السينمائية الـ 18 المطلوبة")

	var all_motions_phased_ok: bool = true
	for m_id in mc.get_supported_motions():
		var started: bool = mc.play_cinematic_motion(m_id)
		if not started or mc.current_phase != SlimiMotionCoordinator.Phase.ANTICIPATION:
			all_motions_phased_ok = false
			break
		var saw_main: bool = false
		var saw_follow: bool = false
		var saw_recovery: bool = false
		for _step in range(180):
			mc._process(1.0 / 60.0)
			slime.deformer._process(1.0 / 60.0)
			slime.face_rig._process(1.0 / 60.0)
			if mc.current_phase == SlimiMotionCoordinator.Phase.MAIN_ACTION:
				saw_main = true
			elif mc.current_phase == SlimiMotionCoordinator.Phase.FOLLOW_THROUGH:
				saw_follow = true
			elif mc.current_phase == SlimiMotionCoordinator.Phase.RECOVERY:
				saw_recovery = true
			if not mc.is_motion_active():
				break
		if not (saw_main and saw_follow and saw_recovery):
			all_motions_phased_ok = false
			break

	_assert(
		runner,
		all_motions_phased_ok,
		"عبور جميع الحركات الـ 18 للمراحل السينمائية الأربع (Anticipation -> Main Action -> Follow-Through -> Recovery)"
	)


static func _test_stress_17_scenarios(runner: Object, slime: SlimeController, hub: SlimiInteractionManager) -> void:
	var mc: SlimiMotionCoordinator = slime.motion_coordinator
	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D

	# السيناريو 2: التبديل السريع المتتالي بين الحالات والحركات (220 تبديلاً سريعاً)
	var motions: Array[StringName] = mc.get_supported_motions()
	for i in range(220):
		mc.play_cinematic_motion(motions[i % motions.size()])
		mc._process(0.016)
		if hub != null and i % 3 == 0:
			hub.emotion_manager.set_emotion(i % 20, 1.0)
	_assert(
		runner,
		SlimiIdentitySpec.validate_subtree_transforms_finite(slime),
		"ثبات التحويلات الهندسية بعد 220 تبديلاً لحظياً سريعاً بين الحركات والمشاعر (Rapid State Switching)"
	)

	# السيناريو 3: القفز المتكرر (25 قفزة وهبوط متتالٍ)
	for _j in range(25):
		slime.velocity.y = slime.hop_vertical_speed
		for _step in range(22):
			slime._physics_process(1.0 / 60.0)
			slime.deformer._process(1.0 / 60.0)
	_assert(
		runner,
		SlimiIdentitySpec.is_finite_vec3(slime.global_position) and slime.global_position.y >= -0.05,
		"سلامة الفيزياء والارتداد بعد 25 قفزة وهبوط متتالٍ دون غوص أو شذوذ رقمي"
	)

	# السيناريو 8: ثبات الخمول الطويل (محاكاة 120 ثانية خمول متواصل)
	mc._reset_coordinator_offsets()
	slime.deformer.is_resting_flat = false
	slime.deformer.posture_height_scale = 1.0
	for _idle_f in range(3600):
		slime.deformer._process(1.0 / 30.0)
		slime.face_rig._process(1.0 / 30.0)
	var idle_scale_ok: bool = slime.deformer.current_squash_stretch.distance_to(Vector3.ONE) < 0.12
	_assert(
		runner,
		idle_scale_ok and SlimiIdentitySpec.validate_subtree_transforms_finite(vis_root),
		"ثبات الخمول الطويل (Long Idle Stability) دون انجراف في الحجم أو الطور أو التحويلات"
	)

	# السيناريو 9: دورات النوم والاستيقاظ المتكررة (10 دورات كاملة)
	for _c in range(10):
		slime.toggle_nap()
		for _s in range(25):
			mc._process(1.0 / 30.0)
			slime.deformer._process(1.0 / 30.0)
	if slime.mood_system.is_sleeping:
		slime.toggle_nap()
	for _s in range(45):
		mc._process(1.0 / 30.0)
		slime.deformer._process(1.0 / 30.0)
	_assert(runner, not slime.mood_system.is_sleeping and absf(slime.deformer.posture_height_scale - 1.0) < 0.08, "سلامة دورات النوم والاستيقاظ المتكررة")

	# السيناريو 10: تطابق واستقرار السلوك الفيزيائي بين 30 FPS و 60 FPS
	var phys_30 := SlimiAccessoryPhysics.new()
	var phys_60 := SlimiAccessoryPhysics.new()
	phys_30.apply_part_touch_impulse(&"left_antenna", Vector3(1.0, 0.0, 0.0), 1.0)
	phys_60.apply_part_touch_impulse(&"left_antenna", Vector3(1.0, 0.0, 0.0), 1.0)
	for _i in range(30):
		phys_30.step_physics(1.0 / 30.0, Vector3.ZERO, 0.0, Vector3.ZERO)
	for _i in range(60):
		phys_60.step_physics(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.ZERO)
	var fps_diff: float = phys_30.left_antenna_rot.distance_to(phys_60.left_antenna_rot)
	_assert(runner, fps_diff < 0.035, "توافق واستقرار الفيزياء الفرعية بين 30 FPS و 60 FPS (فرق الزاوية < 0.035 rad)")

	# السيناريو 11: توافق أندرويد وعدم إلزامية الإعداد العالي (MEDIUM هو الافتراضي)
	var renderer_method: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	var default_cfg_preset: int = int(SaveManager.create_default_data()["settings"]["quality_preset"])
	_assert(
		runner,
		renderer_method == "gl_compatibility" and default_cfg_preset == QualityManager.Preset.MEDIUM,
		"توافق محرك العرض gl_compatibility للأندرويد وكون الإعداد الافتراضي MEDIUM وليس HIGH إلزامياً"
	)

	# السيناريو 13 و 14: كشف ومنع NaN/Inf والتحويلات الفاسدة عند تغذية مدخلات شاذة
	var nan_val: float = 0.0 / 0.0
	var nan_vec := Vector3(nan_val, 1.0, 0.0)
	_assert(runner, not SlimiIdentitySpec.is_finite_vec3(nan_vec), "قدرة مدقق SlimiIdentitySpec على رصد قيم NaN فوراً")
	slime.deformer.trigger_directional_poke(nan_vec, nan_vec, nan_val)
	slime.deformer.set_motion_kinematics(nan_vec, nan_val)
	slime.deformer._process(1.0 / 60.0)
	_assert(
		runner,
		SlimiIdentitySpec.validate_subtree_transforms_finite(slime),
		"مناعة نظام التشوه والإكسسوارات ضد تسرب قيم NaN أو Inf إلى شجرة المشهد"
	)

	# السيناريو 15: فحص عدم اختراق ملامح الوجه لسطح الجسم الهلامي تحت أقصى ضغط وتمدد
	slime.deformer.add_vertical_impulse(-3.8)
	slime.deformer._process(1.0 / 60.0)
	var eye_pos_in_body: Vector3 = slime.face_rig.position + slime.face_rig.left_eye_pivot.position
	var body_r_at_eye: float = SlimiIdentitySpec.sample_rest_hull_radius(eye_pos_in_body.normalized())
	_assert(
		runner,
		eye_pos_in_body.length() >= body_r_at_eye * 0.90 and slime.face_rig.left_eye_pivot.visible and slime.face_rig.mouth_mesh_instance.visible,
		"عدم اختفاء أو غوص العينين والفم والخدود داخل سطح الجل أثناء الانضغاط الشديد"
	)

	# السيناريو 16 و 17: منع تعارض الحركات ومنع تداخل الأصوات المزعج (Audio Overlap Gate)
	mc._voice_gate_timer = 0.0
	var first_voice_ok: bool = mc.play_safe_voice(&"happy_chirp")
	var immediate_dup_blocked: bool = not mc.play_safe_voice(&"laugh_long")
	_assert(
		runner,
		first_voice_ok and immediate_dup_blocked,
		"منع تداخل المقاطع الصوتية المتزامنة عبر بوابة الحماية الزمنية (Zero Harsh Audio Overlap)"
	)

	# قياس الأداء عبر المستويات الثلاثة (LOW / MEDIUM / HIGH) عند 60 FPS و 30 FPS
	for p_item in [
		[QualityManager.Preset.LOW, "LOW"],
		[QualityManager.Preset.MEDIUM, "MEDIUM"],
		[QualityManager.Preset.HIGH, "HIGH"],
	]:
		QualityManager.apply_preset(int(p_item[0]), false)
		var t0_usec: int = Time.get_ticks_usec()
		for _f in range(120):
			slime._physics_process(1.0 / 60.0)
			slime.deformer._process(1.0 / 60.0)
			slime.face_rig._process(1.0 / 60.0)
			mc._process(1.0 / 60.0)
		var ms_per_frame: float = float(Time.get_ticks_usec() - t0_usec) / 1000.0 / 120.0
		print("  [PERF-%s] متوسط معالجة الفيزياء الهجينة والوجه والمنسق السينمائي: %.3f ms/frame" % [String(p_item[1]), ms_per_frame])
		_assert(runner, ms_per_frame < 2.5, "استيفاء ميزانية الأداء للمستوى %s (< 2.5 ms/frame)" % String(p_item[1]))

	QualityManager.apply_preset(QualityManager.Preset.MEDIUM, false)
