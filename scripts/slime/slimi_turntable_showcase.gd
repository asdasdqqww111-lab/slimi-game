class_name SlimiTurntableShowcase
extends Node3D
## منصة المرجع البصري والتصوير السينمائي متعدد الزوايا لشخصية SLIMI:
## - تثبّت زوايا المرجع القياسية الخمس: Front, Side, Back, Three-Quarter, Close-Up بخلفية استوديو نظيفة وموحدة.
## - تدعم التقاط الصور المرجعية وإطارات استعراض الحركة السينمائي تلقائياً عند التشغيل بـ --capture-media=<dir>.

const CozyRoomScene := preload("res://scenes/environment/CozyRoom.tscn")
const SlimiScene := preload("res://scenes/slime/Slimi.tscn")
const WallMat := preload("res://materials/room_wall_mat.tres")

var room: RoomEnvironment
var slime: SlimeController
var camera: Camera3D
var current_view: StringName = &"front"

var _capture_dir: String = ""
var _is_capturing: bool = false


func _ready() -> void:
	room = CozyRoomScene.instantiate() as RoomEnvironment
	add_child(room)
	_prepare_clean_studio_cyclorama()

	slime = SlimiScene.instantiate() as SlimeController
	add_child(slime)
	slime.position = Vector3.ZERO

	# إيقاف التجول العشوائي أثناء جلسة المرجع البصري لضمان ثبات الزوايا القياسية 100%
	if slime.ai_brain != null:
		slime.ai_brain.set_process(false)
		slime.ai_brain.set_physics_process(false)

	camera = Camera3D.new()
	camera.name = "ReferenceCamera3D"
	camera.current = true
	add_child(camera)

	if room != null and slime != null and slime.deformer != null:
		var dirs: Dictionary = room.get_studio_light_directions()
		slime.deformer.update_studio_light_directions(dirs["key"], dirs["fill"], dirs["rim"])

	set_reference_view(&"front")

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-media="):
			_capture_dir = arg.trim_prefix("--capture-media=").strip_edges()
			break

	if not _capture_dir.is_empty():
		_run_automated_media_capture.call_deferred()


func _prepare_clean_studio_cyclorama() -> void:
	if room == null:
		return
	var props := room.get_node_or_null("Props") as Node3D
	if props != null:
		props.visible = false

	# جدار خلفي أمامي ناعم عند +Z لضمان خلفية باستيل نظيفة ومتسقة حتى عند النظر من الخلف (Back View)
	var front_cyc := MeshInstance3D.new()
	front_cyc.name = "StudioFrontCyclorama"
	front_cyc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = Vector3(8.5, 4.2, 0.2)
	front_cyc.mesh = box
	front_cyc.position = Vector3(0.0, 1.8, 3.8)
	front_cyc.material_override = WallMat
	room.add_child(front_cyc)


func set_reference_view(view_id: StringName) -> bool:
	var key_str: String = String(view_id)
	if not SlimiIdentitySpec.REFERENCE_VIEWS.has(key_str) or camera == null:
		return false
	current_view = view_id
	var cfg: Dictionary = SlimiIdentitySpec.REFERENCE_VIEWS[key_str]
	var cam_pos: Vector3 = cfg["cam_pos"]
	var cam_target: Vector3 = cfg["look_at"]
	camera.fov = float(cfg["fov"])
	camera.look_at_from_position(cam_pos, cam_target, Vector3.UP)
	if slime != null:
		slime.rotation = Vector3.ZERO
		if view_id == &"front" or view_id == &"three_quarter" or view_id == &"close_up":
			slime.look_target_world = Vector3(cam_pos.x * 0.35, 0.64, 2.55)
		else:
			slime.look_target_world = Vector3(0.0, 0.62, 2.55)
	return true


func get_available_views() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in SlimiIdentitySpec.REFERENCE_VIEWS.keys():
		out.append(StringName(k))
	return out


func _run_automated_media_capture() -> void:
	if _is_capturing:
		return
	_is_capturing = true
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	DirAccess.make_dir_recursive_absolute(_capture_dir.path_join("frames"))

	QualityManager.apply_preset(QualityManager.Preset.HIGH, false)
	slime.rotation = Vector3.ZERO
	slime.position = Vector3.ZERO

	for _i in range(10):
		await get_tree().process_frame

	# 1. التقاط الزوايا المرجعية الخمس الثابتة (Front, Side, Back, Three-Quarter, Close-Up)
	var views: Array[StringName] = [&"front", &"side", &"back", &"three_quarter", &"close_up"]
	for v in views:
		slime.position = Vector3.ZERO
		slime.rotation = Vector3.ZERO
		slime.deformer.posture_height_scale = 1.0
		set_reference_view(v)
		for _w in range(6):
			slime.rotation = Vector3.ZERO
			await get_tree().process_frame
		await _save_viewport_png(_capture_dir.path_join("slimi_view_%s.png" % String(v)))

	# 2. التقاط مقارنة التدرج البصري (LOW vs MEDIUM vs HIGH) ولقطة انبعاج اللمس الموجي
	set_reference_view(&"three_quarter")
	for preset_pair in [
		[QualityManager.Preset.LOW, "slimi_preset_low.png"],
		[QualityManager.Preset.MEDIUM, "slimi_preset_medium.png"],
		[QualityManager.Preset.HIGH, "slimi_preset_high.png"],
	]:
		QualityManager.apply_preset(int(preset_pair[0]), false)
		for _w in range(5):
			slime.rotation = Vector3.ZERO
			await get_tree().process_frame
		await _save_viewport_png(_capture_dir.path_join(String(preset_pair[1])))

	QualityManager.apply_preset(QualityManager.Preset.HIGH, false)
	set_reference_view(&"close_up")
	slime.deformer.trigger_directional_poke(Vector3(0.18, 0.22, 0.54), Vector3(-0.28, -0.08, -0.95), 1.0)
	slime.face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.SURPRISED)
	for _w in range(3):
		await get_tree().process_frame
	await _save_viewport_png(_capture_dir.path_join("slimi_touch_dent_closeup.png"))

	# 3. التقاط تسلسل فيديو سينمائي 180 إطاراً (6 ثوانٍ بسرعة 30fps) يستعرض الفيزياء الهجينة والحركات الأربع
	set_reference_view(&"three_quarter")
	slime.position = Vector3.ZERO
	slime.rotation = Vector3.ZERO
	slime.face_rig.set_mouth_shape(SlimeFaceRig.MouthShape.OPEN_SMILE)

	for frame_idx in range(180):
		if frame_idx == 8:
			slime.motion_coordinator.play_cinematic_motion(&"curious_leaning")
		elif frame_idx == 52:
			slime.on_part_touched(&"left_antenna", Vector3(-0.24, 1.32, 0.14), Vector3(0.0, 0.0, 1.0))
		elif frame_idx == 78:
			slime.on_poked(Vector3(0.16, 0.60, 0.58), Vector3(0.22, 0.08, 0.96))
		elif frame_idx == 106:
			slime.motion_coordinator.play_cinematic_motion(&"elastic_jump")
		elif frame_idx == 144:
			slime.motion_coordinator.play_cinematic_motion(&"dancing")

		var orbit_angle: float = sin(float(frame_idx) / 180.0 * TAU) * 0.36
		var cam_pos := Vector3(sin(0.62 + orbit_angle) * 2.50, 0.78, cos(0.62 + orbit_angle) * 2.50)
		camera.look_at_from_position(cam_pos, Vector3(0.0, 0.58, 0.0), Vector3.UP)
		slime.look_target_world = cam_pos

		await get_tree().process_frame
		await _save_viewport_png(_capture_dir.path_join("frames/frame_%04d.png" % frame_idx))

	get_tree().quit(0)


func _save_viewport_png(file_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null and not img.is_empty():
			img.save_png(file_path)
