class_name SlimiChatScreen
extends PanelContainer
## شاشة المحادثة الذكية العصرية (Modern Non-Blocking Chat Interface):
## - تبقي SLIMI ظاهراً وحياً في الجزء العلوي من الشاشة يتحرك فمه وتعابيره أثناء الكلام (Lip-Sync).
## - فقاعات محادثة أنيقة تميز رسائل المستخدم عن رسائل SLIMI، مؤشر تفكير وكتابة متحرك،
##   دعم الميكروفون الاختياري، دعم الكيبورد العربي ورفع الهامش تلقائياً، وعرض مريح للردود الطويلة.

var companion: SlimiInteractionManager
var slime: SlimeController

var title_label: Label
var quick_btns: Array[Button] = []
var chat_scroll: ScrollContainer
var chat_log_vbox: VBoxContainer
var thinking_row: HBoxContainer
var thinking_label: Label
var btn_mic: Button
var chat_input: LineEdit
var btn_send: Button

var _messages: Array[Dictionary] = []
var _thinking_active: bool = false
var _thinking_phase: float = 0.0
var _thinking_timer: float = 0.0


func setup(p_companion: SlimiInteractionManager, p_slime: SlimeController) -> void:
	companion = p_companion
	slime = p_slime
	_build_ui()
	_connect_companion()
	apply_design_tokens()
	refresh_localization()


func _build_ui() -> void:
	name = "ChatScreen"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root_v := VBoxContainer.new()
	root_v.add_theme_constant_override("separation", 8)
	add_child(root_v)

	# رأس شاشة الدردشة مع أفاتار SLIMI وحالته الحية
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 8)
	root_v.add_child(header_row)

	var avatar := TextureRect.new()
	avatar.custom_minimum_size = Vector2(32, 32)
	avatar.texture = load("res://assets/icons/icon.svg") as Texture2D
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header_row.add_child(avatar)

	title_label = Label.new()
	title_label.name = "ChatTitle"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_label)

	# أزرار الترفيه السريع (نكتة، لغز، قصة، مشهد)
	var quick_row := HBoxContainer.new()
	quick_row.add_theme_constant_override("separation", 6)
	root_v.add_child(quick_row)

	for sp in [
		{"key": "quick_joke", "cat": "joke"},
		{"key": "quick_riddle", "cat": "riddle"},
		{"key": "quick_story", "cat": "story"},
		{"key": "quick_skit", "cat": "skit"},
	]:
		var qb := Button.new()
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.custom_minimum_size = Vector2(0, 36)
		qb.set_meta("tr_key", sp["key"])
		var cat_id: String = str(sp["cat"])
		SlimiUIMotion.attach_interactive_feedback(qb)
		qb.pressed.connect(func() -> void:
			if companion != null:
				_pulse_thinking_briefly(0.22)
				companion.request_quick_entertainment(cat_id)
		)
		quick_row.add_child(qb)
		quick_btns.append(qb)

	# سجل المحادثات القابل للتمرير بسلاسة
	chat_scroll = ScrollContainer.new()
	chat_scroll.name = "ChatScroll"
	chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_v.add_child(chat_scroll)

	chat_log_vbox = VBoxContainer.new()
	chat_log_vbox.name = "ChatLogVBox"
	chat_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_log_vbox.add_theme_constant_override("separation", 10)
	chat_scroll.add_child(chat_log_vbox)

	# مؤشر الكتابة والتفكير المتحرك (غير معطل للواجهة مطلقاً)
	thinking_row = HBoxContainer.new()
	thinking_row.name = "ThinkingIndicatorRow"
	thinking_row.visible = false
	thinking_row.add_theme_constant_override("separation", 6)
	root_v.add_child(thinking_row)

	thinking_label = Label.new()
	thinking_label.name = "ThinkingLabel"
	thinking_row.add_child(thinking_label)

	# شريط الإدخال: زر الميكروفون + حقل النص الداعم للعربية + زر الإرسال الواضح
	var input_row := HBoxContainer.new()
	input_row.name = "InputRow"
	input_row.add_theme_constant_override("separation", 8)
	root_v.add_child(input_row)

	btn_mic = Button.new()
	btn_mic.name = "BtnChatMic"
	btn_mic.custom_minimum_size = Vector2(46, 46)
	btn_mic.icon = load("res://assets/icons/ic_mic.svg") as Texture2D
	btn_mic.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_mic.expand_icon = true
	SlimiUIMotion.attach_interactive_feedback(btn_mic)
	btn_mic.pressed.connect(func() -> void:
		if companion != null:
			companion.toggle_microphone_with_user_consent()
	)
	input_row.add_child(btn_mic)

	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_input.custom_minimum_size = Vector2(0, 46)
	chat_input.virtual_keyboard_enabled = true
	chat_input.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT
	input_row.add_child(chat_input)

	btn_send = Button.new()
	btn_send.name = "BtnSendChat"
	btn_send.custom_minimum_size = Vector2(96, 46)
	btn_send.icon = load("res://assets/icons/ic_send.svg") as Texture2D
	btn_send.expand_icon = true
	SlimiUIMotion.attach_interactive_feedback(btn_send, 90)
	input_row.add_child(btn_send)

	btn_send.pressed.connect(submit_current_text)
	chat_input.text_submitted.connect(func(_t: String) -> void: submit_current_text())


func submit_current_text() -> void:
	if chat_input == null or companion == null:
		return
	var msg: String = chat_input.text.strip_edges()
	if msg.is_empty():
		return
	chat_input.text = ""

	# إظهار مؤشر التفكير عند الإرسال في وضع Online أو نبضة تفاعل سريعة دون تجميد الواجهة
	var is_online: bool = (companion.settings_manager.ai_mode == "online" and companion.settings_manager.online_user_consent)
	_pulse_thinking_briefly(2.2 if is_online else 0.18)
	if slime != null and slime.face_rig != null:
		slime.face_rig.set_focused_gaze(true)
	companion.send_user_chat_message(msg)


func set_thinking_visible(active: bool) -> void:
	_thinking_active = active
	if thinking_row != null:
		thinking_row.visible = active


func _pulse_thinking_briefly(duration: float) -> void:
	_thinking_timer = maxf(_thinking_timer, duration)
	set_thinking_visible(true)


func _process(delta: float) -> void:
	if _thinking_active:
		_thinking_phase += delta * 6.0
		if _thinking_timer > 0.0:
			_thinking_timer = maxf(0.0, _thinking_timer - delta)
			if _thinking_timer <= 0.0:
				set_thinking_visible(false)
				if slime != null and slime.face_rig != null:
					slime.face_rig.set_focused_gaze(false)
		var dots_count: int = 1 + (int(_thinking_phase) % 3)
		if thinking_label != null:
			thinking_label.text = LocalizationManager.tr_key("chat_thinking") + " " + "●".repeat(dots_count)


func _connect_companion() -> void:
	if companion == null:
		return
	companion.chat_log_appended.connect(_on_chat_log_appended)
	companion.mic_state_changed.connect(func(listening: bool, _level: float) -> void:
		if btn_mic != null:
			btn_mic.modulate = Color(1.0, 0.45, 0.58) if listening else Color.WHITE
	)


func _on_chat_log_appended(sender: String, text: String, emotion_label: String) -> void:
	if sender == "slimi" and _thinking_timer < 0.5:
		set_thinking_visible(false)
	_messages.append({"sender": sender, "text": text, "emotion": emotion_label})
	while _messages.size() > 40:
		_messages.pop_front()
	_append_bubble_widget(sender, text, emotion_label)


func _append_bubble_widget(sender: String, text: String, emotion_label: String) -> void:
	if chat_log_vbox == null:
		return
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	var is_user: bool = (sender == "user")

	var align_row := HBoxContainer.new()
	align_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_log_vbox.add_child(align_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(36, 0)

	var bubble := PanelContainer.new()
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_stretch_ratio = 4.2
	var bs := StyleBoxFlat.new()
	bs.bg_color = tokens["chat_user_bg"] if is_user else tokens["chat_slimi_bg"]
	bs.border_color = tokens["accent"] if is_user else tokens["border"]
	bs.set_border_width_all(1 if is_user else 2)
	bs.set_corner_radius_all(18)
	if is_user:
		bs.corner_radius_bottom_left = 6 if not LocalizationManager.is_rtl() else 18
		bs.corner_radius_bottom_right = 6 if LocalizationManager.is_rtl() else 18
	else:
		bs.corner_radius_top_left = 6 if not LocalizationManager.is_rtl() else 18
		bs.corner_radius_top_right = 6 if LocalizationManager.is_rtl() else 18
	bs.content_margin_left = 14
	bs.content_margin_right = 14
	bs.content_margin_top = 10
	bs.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", bs)

	var inner_v := VBoxContainer.new()
	inner_v.add_theme_constant_override("separation", 4)
	bubble.add_child(inner_v)

	if not is_user:
		var badge_lbl := Label.new()
		var s_name: String = SlimiCustomizationManager.get_display_name()
		badge_lbl.text = s_name + (" • " + emotion_label if not emotion_label.is_empty() else "")
		badge_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))
		badge_lbl.add_theme_color_override("font_color", tokens["accent"])
		inner_v.add_child(badge_lbl)

	var msg_lbl := Label.new()
	msg_lbl.text = text
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(15, tokens))
	msg_lbl.add_theme_color_override("font_color", tokens["text_on_accent"] if is_user else tokens["text_primary"])
	inner_v.add_child(msg_lbl)

	if is_user:
		align_row.add_child(bubble)
		align_row.add_child(spacer)
	else:
		align_row.add_child(spacer)
		align_row.add_child(bubble)

	while chat_log_vbox.get_child_count() > 40:
		var oldest: Node = chat_log_vbox.get_child(0)
		chat_log_vbox.remove_child(oldest)
		oldest.queue_free()

	if is_inside_tree():
		_scroll_to_bottom.call_deferred()


func _scroll_to_bottom() -> void:
	if chat_scroll != null and chat_scroll.get_v_scroll_bar() != null:
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value) + 240


func apply_design_tokens() -> void:
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 16, 12))
	if title_label != null:
		title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(18, tokens))
		title_label.add_theme_color_override("font_color", tokens["text_primary"])
	if thinking_label != null:
		thinking_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
		thinking_label.add_theme_color_override("font_color", tokens["accent"])
	for qb in quick_btns:
		SlimiUIComponents.style_button_variant(qb, tokens, "pill")
		qb.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
	if btn_mic != null:
		SlimiUIComponents.style_button_variant(btn_mic, tokens, "secondary")
	if btn_send != null:
		SlimiUIComponents.style_button_variant(btn_send, tokens, "primary")

	# إعادة تلوين الفقاعات الحالية لتطابق الوضع الفاتح/الداكن ولون التمييز الجديد فوراً
	if chat_log_vbox != null:
		for ch in chat_log_vbox.get_children():
			chat_log_vbox.remove_child(ch)
			ch.queue_free()
		for m in _messages:
			_append_bubble_widget(str(m["sender"]), str(m["text"]), str(m["emotion"]))


func refresh_localization() -> void:
	LocalizationManager.apply_rtl_to_control(self)
	if title_label != null:
		title_label.text = LocalizationManager.tr_key("chat_title")
	if chat_input != null:
		chat_input.placeholder_text = LocalizationManager.tr_key("chat_placeholder")
	if btn_send != null:
		btn_send.text = LocalizationManager.tr_key("btn_send")
	for qb in quick_btns:
		qb.text = LocalizationManager.tr_key(str(qb.get_meta("tr_key", "quick_joke")))
