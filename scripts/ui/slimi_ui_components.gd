class_name SlimiUIComponents
extends RefCounted
## مكتبة المكونات المشتركة لواجهة SLIMI (الأزرار، البطاقات، الشرائح، مفاتيح التبديل، ومربعات الألوان):
## تضمن توحيد المظهر والتباعد وسهولة اللمس على شاشات الهواتف دون تكرار للأكواد.


static func make_section_card(tokens: Dictionary, title_text: String = "") -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", SlimiDesignSystem.make_card_style(tokens, SlimiDesignSystem.RAD_MD, false, 14, 12))

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", SlimiDesignSystem.SP_SM)
	panel.add_child(vbox)

	var header_lbl: Label = null
	if not title_text.is_empty():
		header_lbl = Label.new()
		header_lbl.text = title_text
		header_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(15, tokens))
		header_lbl.add_theme_color_override("font_color", tokens["accent"])
		vbox.add_child(header_lbl)

	return {"card": panel, "vbox": vbox, "header": header_lbl}


static func make_styled_button(
	text_val: String,
	tokens: Dictionary,
	variant: String = "secondary",
	icon_path: String = "",
	min_size: Vector2 = Vector2(0, 44)
) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(14, tokens))

	if not icon_path.is_empty():
		btn.icon = load(icon_path) as Texture2D
		btn.expand_icon = true

	style_button_variant(btn, tokens, variant)
	SlimiUIMotion.attach_interactive_feedback(btn)
	return btn


static func style_button_variant(btn: Button, tokens: Dictionary, variant: String) -> void:
	if btn == null:
		return
	match variant:
		"primary":
			var n := SlimiDesignSystem.make_button_style(tokens["accent"], tokens["accent"], SlimiDesignSystem.RAD_MD, 16, 10, true)
			var h := SlimiDesignSystem.make_button_style(tokens["accent_hover"], tokens["accent_hover"], SlimiDesignSystem.RAD_MD, 16, 10, true)
			btn.add_theme_stylebox_override("normal", n)
			btn.add_theme_stylebox_override("hover", h)
			btn.add_theme_stylebox_override("pressed", h)
			btn.add_theme_stylebox_override("focus", h)
			btn.add_theme_color_override("font_color", tokens["text_on_accent"])
			btn.add_theme_color_override("font_hover_color", tokens["text_on_accent"])
			btn.add_theme_color_override("font_pressed_color", tokens["text_on_accent"])
		"danger":
			var dn := SlimiDesignSystem.make_button_style(Color(tokens["danger"].r, tokens["danger"].g, tokens["danger"].b, 0.14), tokens["danger"], SlimiDesignSystem.RAD_MD, 14, 9)
			var dp := SlimiDesignSystem.make_button_style(tokens["danger"], tokens["danger"], SlimiDesignSystem.RAD_MD, 14, 9)
			btn.add_theme_stylebox_override("normal", dn)
			btn.add_theme_stylebox_override("hover", dn)
			btn.add_theme_stylebox_override("pressed", dp)
			btn.add_theme_color_override("font_color", tokens["danger"])
			btn.add_theme_color_override("font_hover_color", tokens["danger"])
			btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		"selected_pill":
			var sp := SlimiDesignSystem.make_button_style(tokens["accent"], tokens["accent"], SlimiDesignSystem.RAD_PILL, 14, 7, true)
			btn.add_theme_stylebox_override("normal", sp)
			btn.add_theme_stylebox_override("hover", sp)
			btn.add_theme_stylebox_override("pressed", sp)
			btn.add_theme_color_override("font_color", tokens["text_on_accent"])
			btn.add_theme_color_override("font_hover_color", tokens["text_on_accent"])
		"pill":
			var up := SlimiDesignSystem.make_button_style(tokens["bg_subtle"], tokens["border"], SlimiDesignSystem.RAD_PILL, 14, 7)
			btn.add_theme_stylebox_override("normal", up)
			btn.add_theme_stylebox_override("hover", up)
			btn.add_theme_stylebox_override("pressed", up)
			btn.add_theme_color_override("font_color", tokens["text_primary"])
			btn.add_theme_color_override("font_hover_color", tokens["text_primary"])
		_:
			var sn := SlimiDesignSystem.make_button_style(tokens["bg_subtle"], tokens["border"], SlimiDesignSystem.RAD_MD, 14, 9)
			var sh := SlimiDesignSystem.make_button_style(tokens["accent_soft"], tokens["accent"], SlimiDesignSystem.RAD_MD, 14, 9)
			btn.add_theme_stylebox_override("normal", sn)
			btn.add_theme_stylebox_override("hover", sh)
			btn.add_theme_stylebox_override("pressed", sh)
			btn.add_theme_color_override("font_color", tokens["text_primary"])
			btn.add_theme_color_override("font_hover_color", tokens["text_primary"])


static func make_slider_row(
	parent: VBoxContainer,
	label_text: String,
	min_v: float,
	max_v: float,
	step_v: float,
	initial_v: float,
	tokens: Dictionary,
	on_changed: Callable
) -> Dictionary:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 3)
	parent.add_child(wrap)

	var top_row := HBoxContainer.new()
	wrap.add_child(top_row)

	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(14, tokens))
	top_row.add_child(lbl)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(round(initial_v * 100.0))
	val_lbl.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(13, tokens))
	val_lbl.add_theme_color_override("font_color", tokens["text_secondary"])
	top_row.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.value = initial_v
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(v: float) -> void:
		val_lbl.text = "%d%%" % int(round(v * 100.0))
		if on_changed.is_valid():
			on_changed.call(v)
	)
	wrap.add_child(slider)

	return {"label": lbl, "value_label": val_lbl, "slider": slider}


static func make_toggle_row(
	parent: VBoxContainer,
	label_text: String,
	initial_on: bool,
	tokens: Dictionary,
	on_toggled: Callable
) -> CheckButton:
	var chk := CheckButton.new()
	chk.text = label_text
	chk.button_pressed = initial_on
	chk.custom_minimum_size = Vector2(0, 40)
	chk.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(14, tokens))
	chk.toggled.connect(func(on: bool) -> void:
		AudioManager.play_sfx(&"ui_click", 0.0, -6.0)
		if on_toggled.is_valid():
			on_toggled.call(on)
	)
	parent.add_child(chk)
	return chk


static func make_color_swatch_button(swatch_col: Color, caption: String, selected: bool, tokens: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(108, 42)
	btn.add_theme_font_size_override("font_size", SlimiDesignSystem.scaled_font(12, tokens))
	var sb := StyleBoxFlat.new()
	sb.bg_color = swatch_col
	sb.border_color = tokens["accent"] if selected else Color(1.0, 1.0, 1.0, 0.85)
	sb.set_border_width_all(4 if selected else 2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	var lum: float = swatch_col.get_luminance()
	var fg := Color(0.18, 0.08, 0.18, 1.0) if lum > 0.56 else Color(1.0, 1.0, 1.0, 1.0)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	SlimiUIMotion.attach_interactive_feedback(btn)
	return btn
