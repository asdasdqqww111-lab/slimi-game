extends Node3D
## المشهد الرئيسي للعبة SLIMI: يربط الشخصية ثلاثية الأبعاد، منظومة الرفيق الذكي الناطق (10 وحدات معمارية)،
## الغرفة، نظام اللمس، الواجهة العربية الزجاجية، والحفظ المحلي.

var room: RoomEnvironment
var slime: SlimeController
var camera_pivot: Node3D
var camera: Camera3D
var touch_system: TouchInteractionSystem
var hud: HUDController
var companion_hub: SlimiInteractionManager


func _ready() -> void:
	room = get_node_or_null("CozyRoom") as RoomEnvironment
	slime = get_node_or_null("Slimi") as SlimeController
	camera_pivot = get_node_or_null("CameraRig") as Node3D
	camera = get_node_or_null("CameraRig/MainCamera3D") as Camera3D
	touch_system = get_node_or_null("TouchInteractionSystem") as TouchInteractionSystem
	hud = get_node_or_null("GameHUD") as HUDController

	# استعادة اللغة المحفوظة
	var saved_settings: Dictionary = SaveManager.get_section("settings")
	LocalizationManager.set_locale(str(saved_settings.get("locale", "ar")))

	# ربط حالة سلايمي وذاكرته المحلية المحفوظة
	if slime != null and slime.mood_system != null:
		slime.mood_system.load_state(
			SaveManager.get_section("slime_state"),
			SaveManager.get_section("memory"),
			SaveManager.last_offline_seconds
		)

	if slime != null and slime.ai_brain is AutonomousBehaviorAI:
		(slime.ai_brain as AutonomousBehaviorAI).bind_environment(room, camera)

	if slime != null and camera != null:
		slime.look_target_world = camera.global_position

	if touch_system != null:
		touch_system.camera_pivot = camera_pivot
		touch_system.camera = camera
		touch_system.slime = slime
		touch_system.room = room
		touch_system.hud = hud

	# إنشاء وربط منظومة الرفيق الذكي الموحدة (10 وحدات GDScript منفصلة متصلة بالإشارات)
	companion_hub = SlimiInteractionManager.new()
	companion_hub.name = "SlimiInteractionManager"
	add_child(companion_hub)
	companion_hub.bind_world(slime, hud)

	if hud != null and slime != null:
		hud.bind_slime_systems(slime.mood_system)
		hud.bind_companion_system(companion_hub)
		hud.feed_requested.connect(_on_feed_requested)
		hud.play_requested.connect(_on_play_requested)
		hud.nap_requested.connect(_on_nap_requested)
		hud.call_requested.connect(_on_call_requested)

	AndroidPlatformManager.back_requested.connect(_on_android_back)

	# ترحيب ذكي متغير حسب الوقت والمزاج والعلاقة دون أي عتاب على الغياب
	call_deferred("_trigger_opening_greeting")


func _trigger_opening_greeting() -> void:
	if companion_hub != null:
		companion_hub.trigger_contextual_launch_greeting()
	elif hud != null:
		hud.show_bubble_by_key("bubble_welcome_first", 4.5)


func _on_feed_requested() -> void:
	if slime == null:
		return
	var treat_pos := Vector3(0.55, 0.0, 0.45)
	if room != null:
		treat_pos = room.spawn_treat_berry()
	slime.feed_treat(treat_pos)


func _on_play_requested() -> void:
	if slime != null:
		slime.play_together()
	if companion_hub != null and companion_hub.anim_controller != null:
		companion_hub.anim_controller.play_random_non_repeating_comedy(SlimiAnimationController.Priority.USER_REACTION)


func _on_nap_requested() -> void:
	if slime != null:
		slime.toggle_nap()


func _on_call_requested() -> void:
	if touch_system != null:
		touch_system.reset_camera_view()
	if slime != null and camera != null:
		slime.call_to_front(Vector3(0.0, 0.0, 0.55), camera.global_position)
	if companion_hub != null:
		companion_hub.emotion_manager.set_emotion(SlimiEmotionManager.Emotion.CURIOUS, 3.5)


func _notification(what: int) -> void:
	if what in [
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_WM_CLOSE_REQUEST,
	]:
		if slime != null and slime.mood_system != null:
			slime.mood_system.sync_to_save_manager()
		if companion_hub != null:
			companion_hub.save_companion_state()
		SaveManager.save_to_disk()


func _on_android_back() -> void:
	if hud != null and hud.has_open_modal():
		hud.close_modals()
		SaveManager.save_to_disk()
		return
	SaveManager.save_to_disk()
