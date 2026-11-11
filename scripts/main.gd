extends Node3D
## المشهد الرئيسي لتطبيق SLIMI (Main Application Coordinator):
## يربط البيئة ثلاثية الأبعاد، شخصية SLIMI، نظام اللمس، نظام الكاميرا المتكيفة مع الشاشات الخمس،
## دورة الحياة (بدء سريع، شاشة البداية، الترحيب الأول، زر الرجوع في أندرويد، وتأكيد الخروج).

@onready var room: RoomEnvironment = $CozyRoom
@onready var slime: SlimeController = $Slimi
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/MainCamera3D
@onready var touch_system: TouchInteractionSystem = $TouchInteractionSystem
@onready var hud: HUDController = $GameHUD

var companion_hub: SlimiInteractionManager

var _camera_base_pos: Vector3
var _camera_target_offset: Vector3 = Vector3.ZERO
var _ui_gaze_world_target: Vector3 = Vector3.ZERO
var _ui_gaze_timer: float = 0.0
var _customize_drag_rotating: bool = false
var _customize_last_x: float = 0.0


func _ready() -> void:
	_camera_base_pos = camera.position
	touch_system.camera_pivot = camera_rig
	touch_system.camera = camera
	touch_system.slime = slime
	touch_system.room = room
	touch_system.hud = hud

	# تطبيق المظهر المحفوظ على شخصية SLIMI ثلاثية الأبعاد فور التشغيل
	SlimiCustomizationManager.apply_to_slime(slime, room)

	companion_hub = SlimiInteractionManager.new()
	companion_hub.name = "SlimiInteractionManager"
	add_child(companion_hub)
	companion_hub.bind_world(slime, hud)
	hud.bind_companion_system(companion_hub, slime, room)

	slime.mood_system.stats_updated.connect(_on_slime_stats_updated)
	slime.mood_system.thought_triggered.connect(_on_autonomous_thought)
	slime.slime_interacted.connect(_on_slime_interacted)

	hud.action_feed_requested.connect(_on_feed_requested)
	hud.action_play_requested.connect(_on_play_requested)
	hud.action_nap_requested.connect(_on_nap_requested)
	hud.action_call_requested.connect(_on_call_requested)
	hud.screen_changed.connect(_on_screen_changed)
	hud.ui_button_interacted.connect(_on_ui_button_interacted)
	hud.exit_app_confirmed.connect(_perform_clean_save_and_quit)

	AndroidPlatformManager.back_requested.connect(_on_android_back_pressed)
	AndroidPlatformManager.app_lifecycle_changed.connect(_on_app_lifecycle_changed)

	# مزامنة أولية فورية للواجهة والذاكرة
	hud.update_stats_snapshot(slime.mood_system.get_stats_snapshot())
	hud.update_memory_view(slime.mood_system.memory)

	# تشغيل شاشة البداية السريعة والترحيب الأول في الجلسات الرسومية الحية
	if DisplayServer.get_name() != "headless":
		_run_startup_sequence()
	else:
		_trigger_welcome_greeting.call_deferred()


func _run_startup_sequence() -> void:
	hud.splash_screen.splash_finished.connect(func() -> void:
		var onboarded: bool = bool(SaveManager.get_section("ui_preferences").get("onboarding_completed", false))
		if not onboarded:
			hud.onboarding_overlay.open_onboarding()
			hud.onboarding_overlay.onboarding_completed.connect(_trigger_welcome_greeting, CONNECT_ONE_SHOT)
		else:
			_trigger_welcome_greeting()
	, CONNECT_ONE_SHOT)
	hud.splash_screen.play_intro(slime)


func _unhandled_input(event: InputEvent) -> void:
	# تدوير SLIMI بالسحب الأفقي السلس في الجزء العلوي من شاشة التخصيص
	if hud.current_screen == "customize" and hud.customize_screen != null and hud.customize_screen.visible:
		if event is InputEventScreenDrag:
			var drag := event as InputEventScreenDrag
			if not hud.is_point_blocked_by_ui(drag.position):
				hud.customize_screen.rotate_preview_by_degrees(drag.relative.x * 0.45)
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb := event as InputEventMouseButton
			if mb.pressed and not hud.is_point_blocked_by_ui(mb.position):
				_customize_drag_rotating = true
				_customize_last_x = mb.position.x
			else:
				_customize_drag_rotating = false
		elif event is InputEventMouseMotion and _customize_drag_rotating:
			var mm := event as InputEventMouseMotion
			var dx: float = mm.position.x - _customize_last_x
			_customize_last_x = mm.position.x
			hud.customize_screen.rotate_preview_by_degrees(dx * 0.45)


func _process(delta: float) -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	# حركة تنفس هادئة جداً للكاميرا + تأطير ذكي للشخصية فوق لوحات الشاشات الفرعية
	var sway := Vector3(
		sin(t * 0.35) * 0.035,
		cos(t * 0.28) * 0.02,
		0.0
	)
	var desired_cam_pos: Vector3 = _camera_base_pos + _camera_target_offset + sway
	camera.position = camera.position.lerp(desired_cam_pos, minf(1.0, delta * 5.0))

	var look_focus_y: float = 0.68 if hud.current_screen == "home" else 0.12
	var look_target: Vector3 = slime.global_position.lerp(Vector3(0.0, look_focus_y, 0.0), 0.72) + Vector3(0.0, look_focus_y, 0.0) * 0.5
	camera.look_at(look_target, Vector3.UP)

	# نظرة SLIMI الحية نحو الزر الذي ضغط عليه المستخدم في الواجهة
	if _ui_gaze_timer > 0.0:
		_ui_gaze_timer = maxf(0.0, _ui_gaze_timer - delta)
		slime.look_target_world = _ui_gaze_world_target
	elif touch_system._active_pointer_id == -1 and slime.ai_brain != null and slime.ai_brain.get("current_state") == AutonomousBehaviorAI.State.IDLE_OBSERVE:
		slime.look_target_world = camera.global_position


func _on_screen_changed(screen_id: String) -> void:
	# رفع وتقريب الكاميرا بسلاسة ليظهر وجه وقبعة SLIMI بوضوح تام في النصف العلوي عند فتح أي لوحة
	match screen_id:
		"chat":
			_camera_target_offset = Vector3(0.0, 0.16, -0.35)
		"customize":
			_camera_target_offset = Vector3(0.0, 0.12, -0.55)
			if slime.ai_brain != null and slime.ai_brain.has_method("notify_player_interaction"):
				slime.ai_brain.call("notify_player_interaction", 4.0)
			slime.global_position = slime.global_position.lerp(Vector3(0.0, slime.global_position.y, 0.0), 0.85)
		"activities", "settings":
			_camera_target_offset = Vector3(0.0, 0.18, -0.22)
		_:
			_camera_target_offset = Vector3.ZERO


func _on_ui_button_interacted(screen_pos: Vector2) -> void:
	if camera == null or slime == null:
		return
	var ray_orig: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)
	_ui_gaze_world_target = ray_orig + ray_dir * 2.2
	_ui_gaze_timer = 1.15
	slime.look_target_world = _ui_gaze_world_target
	if slime.deformer != null:
		slime.deformer.add_vertical_impulse(0.32)


func _trigger_welcome_greeting() -> void:
	if companion_hub != null:
		companion_hub.trigger_contextual_launch_greeting()
	else:
		hud.show_bubble_by_key("bubble_welcome", 4.0)
	slime.perform_happy_bounce()


func _on_slime_stats_updated(stats: Dictionary) -> void:
	hud.update_stats_snapshot(stats)


func _on_autonomous_thought(message_key: String) -> void:
	hud.show_bubble_by_key(message_key, 3.4)


func _on_slime_interacted(interaction_type: StringName, _world_pos: Vector3 = Vector3.ZERO) -> void:
	hud.update_memory_view(slime.mood_system.memory)
	match interaction_type:
		&"pet":
			if randf() < 0.28:
				hud.show_bubble_by_key("bubble_pet", 2.6)
		&"poke":
			if randf() < 0.45:
				hud.show_bubble_by_key("bubble_poke", 2.4)
		&"dizzy":
			hud.show_bubble_by_key("bubble_dizzy", 3.2)


func _on_feed_requested() -> void:
	var drop_pos: Vector3 = room.spawn_treat_berry()
	slime.feed_treat(drop_pos)
	hud.update_memory_view(slime.mood_system.memory)
	hud.show_bubble_by_key("bubble_feed", 3.2)


func _on_play_requested() -> void:
	slime.play_together()
	hud.show_bubble_by_key("bubble_play", 3.0)


func _on_nap_requested() -> void:
	slime.toggle_nap()
	if slime.mood_system.is_sleeping:
		hud.show_bubble_by_key("bubble_sleep", 3.5)
	else:
		hud.show_bubble_by_key("bubble_wake", 3.0)


func _on_call_requested() -> void:
	slime.call_to_front(Vector3(0.0, 0.0, 0.48), camera.global_position)
	hud.show_bubble_by_key("bubble_welcome", 2.8)


func _on_android_back_pressed() -> void:
	hud.handle_back_navigation()


func _on_app_lifecycle_changed(is_paused: bool) -> void:
	if is_paused:
		_save_all_state()


func _save_all_state() -> void:
	if slime != null and slime.mood_system != null:
		slime.mood_system.sync_to_save_manager()
	if companion_hub != null:
		companion_hub.save_companion_state()
	SaveManager.save_to_disk()


func _perform_clean_save_and_quit() -> void:
	_save_all_state()
	get_tree().quit()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		_save_all_state()
