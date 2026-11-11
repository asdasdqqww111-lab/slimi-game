class_name SlimiSplashScreen
extends Control
## شاشة البداية الافتتاحية الاحترافية السريعة (Splash Screen):
## - ظهور سلس لشعار SLIMI مع إضاءة خلفية وجزيئات متلألئة خفيفة جداً على المعالج.
## - صوت افتتاحي اختياري يحترم إعداد الكتم وتفضيل المستخدم.
## - مدة سريعة (~0.95 ثانية) قابلة للتخطي الفوري بالنقر، مع انتقال سينمائي ناعم للشاشة الرئيسية.

signal splash_finished

var logo_holder: VBoxContainer
var emblem_rect: TextureRect
var brand_label: Label
var subtitle_label: Label
var skip_hint_label: Label

var is_active: bool = false
var _elapsed: float = 0.0
var _sparkles: Array[Dictionary] = []
var _intro_tween: Tween


func _ready() -> void:
	name = "SplashScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 202611
	for _i in range(18):
		_sparkles.append({
			"uv": Vector2(rng.randf_range(0.10, 0.90), rng.randf_range(0.12, 0.88)),
			"r": rng.randf_range(3.0, 9.5),
			"speed": rng.randf_range(1.4, 3.2),
			"phase": rng.randf_range(0.0, TAU),
		})

	logo_holder = VBoxContainer.new()
	logo_holder.name = "LogoHolder"
	logo_holder.set_anchors_preset(Control.PRESET_CENTER)
	logo_holder.offset_left = -220
	logo_holder.offset_right = 220
	logo_holder.offset_top = -150
	logo_holder.offset_bottom = 150
	logo_holder.alignment = BoxContainer.ALIGNMENT_CENTER
	logo_holder.add_theme_constant_override("separation", 12)
	logo_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo_holder)

	emblem_rect = TextureRect.new()
	emblem_rect.custom_minimum_size = Vector2(116, 116)
	emblem_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	emblem_rect.texture = load("res://assets/icons/icon.svg") as Texture2D
	emblem_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_holder.add_child(emblem_rect)

	brand_label = Label.new()
	brand_label.text = "SLIMI"
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand_label.add_theme_font_size_override("font_size", 36)
	brand_label.add_theme_color_override("font_color", Color(0.32, 0.12, 0.28, 1.0))
	logo_holder.add_child(brand_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.54, 0.28, 0.46, 1.0))
	logo_holder.add_child(subtitle_label)

	skip_hint_label = Label.new()
	skip_hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	skip_hint_label.offset_top = -64
	skip_hint_label.offset_bottom = -28
	skip_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_hint_label.add_theme_font_size_override("font_size", 13)
	skip_hint_label.add_theme_color_override("font_color", Color(0.58, 0.34, 0.50, 0.80))
	skip_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(skip_hint_label)

	refresh_texts()


func refresh_texts() -> void:
	LocalizationManager.apply_rtl_to_control(self)
	if subtitle_label != null:
		subtitle_label.text = LocalizationManager.tr_key("splash_subtitle")
	if skip_hint_label != null:
		skip_hint_label.text = LocalizationManager.tr_key("splash_tap_skip")


func play_intro(slime: SlimeController = null) -> void:
	refresh_texts()
	is_active = true
	visible = true
	_elapsed = 0.0
	modulate.a = 1.0

	var settings: Dictionary = SaveManager.get_section("settings")
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	if bool(tokens.get("dark_mode", false)):
		brand_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.98, 1.0))
		subtitle_label.add_theme_color_override("font_color", Color(0.86, 0.76, 0.92, 1.0))

	if bool(settings.get("splash_sound_enabled", true)) and not AudioManager.master_muted:
		AudioManager.play_sfx(&"joy_sparkle", 0.04, -6.5)

	if slime != null and slime.motion_coordinator != null:
		slime.motion_coordinator.play_cinematic_motion(&"playful_hopping")

	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()

	if SlimiUIMotion.is_reduce_motion():
		logo_holder.modulate.a = 1.0
		logo_holder.scale = Vector2.ONE
		_intro_tween = create_tween()
		_intro_tween.tween_interval(0.45)
		_intro_tween.tween_property(self, "modulate:a", 0.0, 0.18)
		_intro_tween.tween_callback(finish_immediately)
		return

	logo_holder.pivot_offset = Vector2(220, 150)
	logo_holder.scale = Vector2(0.82, 0.82)
	logo_holder.modulate.a = 0.0

	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.tween_property(logo_holder, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(logo_holder, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.chain().tween_interval(0.42)
	_intro_tween.tween_property(self, "modulate:a", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_intro_tween.tween_callback(finish_immediately)


func finish_immediately() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	if not is_active and not visible:
		return
	is_active = false
	visible = false
	splash_finished.emit()


func _gui_input(event: InputEvent) -> void:
	if not is_active:
		return
	if (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed):
		accept_event()
		finish_immediately()


func _process(delta: float) -> void:
	if not is_active or not visible:
		return
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	var dark: bool = bool(SlimiDesignSystem.get_tokens().get("dark_mode", false))
	var top_c: Color = Color(0.14, 0.09, 0.22, 0.96) if dark else Color(0.99, 0.92, 0.97, 0.96)
	var bot_c: Color = Color(0.22, 0.14, 0.34, 0.94) if dark else Color(0.95, 0.88, 0.99, 0.94)
	draw_rect(Rect2(Vector2.ZERO, sz), top_c.lerp(bot_c, 0.5))

	# هالة ضوئية ناعمة خلف الشعار
	var center: Vector2 = sz * 0.5
	draw_circle(center - Vector2(0, 24), 128.0 + sin(_elapsed * 3.2) * 8.0, Color(1.0, 0.68, 0.88, 0.20))
	draw_circle(center - Vector2(0, 24), 84.0, Color(1.0, 0.86, 0.95, 0.26))

	# جزيئات ضوئية متلألئة خفيفة
	for sp in _sparkles:
		var uv: Vector2 = sp["uv"]
		var drift_y: float = sin(_elapsed * float(sp["speed"]) + float(sp["phase"])) * 10.0
		var pos := Vector2(uv.x * sz.x, uv.y * sz.y + drift_y)
		var alpha: float = 0.28 + 0.35 * (0.5 + 0.5 * cos(_elapsed * float(sp["speed"]) + float(sp["phase"])))
		draw_circle(pos, float(sp["r"]), Color(1.0, 0.78, 0.93, alpha))
