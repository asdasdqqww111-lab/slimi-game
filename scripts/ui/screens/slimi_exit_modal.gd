class_name SlimiExitModal
extends Control
## نافذة تأكيد الخروج الأنيقة عند الضغط على زر الرجوع في الشاشة الرئيسية (Exit Confirmation Modal):
## تمنع الإغلاق الخاطئ، تحفظ حالة SLIMI، وتتيح المتابعة أو الخروج النظيف.

signal continue_requested
signal exit_confirmed

var card_panel: PanelContainer
var title_label: Label
var desc_label: Label
var btn_continue: Button
var btn_quit: Button


func _ready() -> void:
	name = "ExitConfirmModal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_rebuild_ui()


func open_modal() -> void:
	_rebuild_ui()
	visible = true
	SlimiUIMotion.animate_sheet_open(card_panel)


func close_modal() -> void:
	visible = false


func _rebuild_ui() -> void:
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()

	LocalizationManager.apply_rtl_to_control(self)
	var tokens: Dictionary = SlimiDesignSystem.get_tokens()
	theme = SlimiDesignSystem.build_theme(tokens)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.08, 0.03, 0.12, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	card_panel = PanelContainer.new()
	card_panel.custom_minimum_size = Vector2(320, 0)
	card_panel.add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_LG, true, 22, 18))
	center.add_child(card_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card_panel.add_child(vbox)

	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(56, 56)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.texture = load("res://assets/icons/icon.svg") as Texture2D
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(ic)

	title_label = Label.new()
	title_label.text = LocalizationManager.tr_key("exit_title")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(19, tokens))
	vbox.add_child(title_label)

	desc_label = Label.new()
	desc_label.text = LocalizationManager.tr_key("exit_desc")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", tokens["text_secondary"])
	vbox.add_child(desc_label)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	vbox.add_child(btns)

	btn_quit = SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("exit_quit"),
		tokens,
		"danger",
		"",
		Vector2(130, 44)
	)
	btn_quit.name = "BtnConfirmQuit"
	btn_quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_quit.pressed.connect(func() -> void:
		visible = false
		exit_confirmed.emit()
	)
	btns.add_child(btn_quit)

	btn_continue = SlimiUIComponents.make_styled_button(
		LocalizationManager.tr_key("exit_continue"),
		tokens,
		"primary",
		"",
		Vector2(140, 44)
	)
	btn_continue.name = "BtnCancelQuit"
	btn_continue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_continue.pressed.connect(func() -> void:
		close_modal()
		continue_requested.emit()
	)
	btns.add_child(btn_continue)
