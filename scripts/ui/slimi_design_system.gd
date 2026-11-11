class_name SlimiDesignSystem
extends RefCounted
## نظام الهوية البصرية الموحد لتطبيق SLIMI (Unified Premium Design System):
## يدير الألوان (الوضع الفاتح والداكن + 4 لوحات تمييز)، الخطوط وأحجامها القابلة للتكبير،
## المسافات الموحدة، البطاقات ذات الزوايا الناعمة والظلال المحسوبة، ودعم RTL/LTR الكامل.

const SP_XS: int = 4
const SP_SM: int = 8
const SP_MD: int = 12
const SP_LG: int = 16
const SP_XL: int = 22

const RAD_SM: int = 12
const RAD_MD: int = 18
const RAD_LG: int = 26
const RAD_PILL: int = 999

const TEXT_SCALES: Array[float] = [0.90, 1.00, 1.14]

const ACCENT_PALETTES: Dictionary = {
	"sakura": {
		"ar": "وردي ساكورا",
		"en": "Sakura Rose",
		"primary": Color(0.93, 0.33, 0.60, 1.0),
		"primary_hover": Color(0.97, 0.42, 0.68, 1.0),
		"primary_soft": Color(0.99, 0.84, 0.92, 0.85),
		"glow": Color(1.0, 0.56, 0.80, 0.32),
	},
	"mint": {
		"ar": "نعناعي هادئ",
		"en": "Mint Breeze",
		"primary": Color(0.18, 0.72, 0.54, 1.0),
		"primary_hover": Color(0.24, 0.80, 0.61, 1.0),
		"primary_soft": Color(0.82, 0.97, 0.91, 0.85),
		"glow": Color(0.32, 0.86, 0.68, 0.32),
	},
	"lavender": {
		"ar": "لافندر ملكي",
		"en": "Royal Lavender",
		"primary": Color(0.55, 0.36, 0.95, 1.0),
		"primary_hover": Color(0.63, 0.46, 0.98, 1.0),
		"primary_soft": Color(0.90, 0.85, 1.0, 0.85),
		"glow": Color(0.66, 0.48, 1.0, 0.32),
	},
	"honey": {
		"ar": "عسلي دافئ",
		"en": "Golden Honey",
		"primary": Color(0.88, 0.58, 0.14, 1.0),
		"primary_hover": Color(0.95, 0.66, 0.22, 1.0),
		"primary_soft": Color(1.0, 0.93, 0.78, 0.85),
		"glow": Color(1.0, 0.75, 0.28, 0.32),
	},
}


static func get_tokens() -> Dictionary:
	var prefs: Dictionary = SaveManager.get_section("ui_preferences")
	var dark: bool = bool(prefs.get("dark_mode", false))
	var accent_id: String = str(prefs.get("accent_palette", "sakura"))
	if not ACCENT_PALETTES.has(accent_id):
		accent_id = "sakura"
	var acc: Dictionary = ACCENT_PALETTES[accent_id]
	var scale_idx: int = clampi(int(prefs.get("text_scale_index", 1)), 0, 2)
	var font_scale: float = TEXT_SCALES[scale_idx]

	if dark:
		return {
			"dark_mode": true,
			"accent_id": accent_id,
			"font_scale": font_scale,
			"bg_surface": Color(0.13, 0.09, 0.20, 0.94),
			"bg_elevated": Color(0.19, 0.14, 0.28, 0.96),
			"bg_subtle": Color(0.24, 0.18, 0.35, 0.88),
			"bg_hud_glass": Color(0.15, 0.10, 0.23, 0.82),
			"border": Color(0.45, 0.34, 0.62, 0.55),
			"text_primary": Color(0.99, 0.95, 0.99, 1.0),
			"text_secondary": Color(0.82, 0.74, 0.88, 1.0),
			"text_on_accent": Color(1.0, 1.0, 1.0, 1.0),
			"accent": acc["primary"],
			"accent_hover": acc["primary_hover"],
			"accent_soft": Color(acc["primary"].r, acc["primary"].g, acc["primary"].b, 0.25),
			"shadow": Color(0.03, 0.01, 0.06, 0.42),
			"danger": Color(0.94, 0.32, 0.44, 1.0),
			"success": Color(0.24, 0.78, 0.54, 1.0),
			"chat_user_bg": acc["primary"],
			"chat_slimi_bg": Color(0.23, 0.17, 0.34, 0.96),
		}
	else:
		return {
			"dark_mode": false,
			"accent_id": accent_id,
			"font_scale": font_scale,
			"bg_surface": Color(1.0, 0.975, 0.99, 0.95),
			"bg_elevated": Color(1.0, 1.0, 1.0, 0.97),
			"bg_subtle": Color(0.97, 0.92, 0.96, 0.88),
			"bg_hud_glass": Color(1.0, 0.97, 0.99, 0.84),
			"border": Color(0.95, 0.78, 0.89, 0.85),
			"text_primary": Color(0.25, 0.11, 0.23, 1.0),
			"text_secondary": Color(0.50, 0.31, 0.46, 1.0),
			"text_on_accent": Color(1.0, 1.0, 1.0, 1.0),
			"accent": acc["primary"],
			"accent_hover": acc["primary_hover"],
			"accent_soft": acc["primary_soft"],
			"shadow": Color(0.36, 0.14, 0.28, 0.14),
			"danger": Color(0.90, 0.27, 0.40, 1.0),
			"success": Color(0.18, 0.70, 0.48, 1.0),
			"chat_user_bg": acc["primary"],
			"chat_slimi_bg": Color(0.98, 0.92, 0.97, 0.98),
		}


static func scaled_font(base_size: int, tokens: Dictionary = {}) -> int:
	var t: Dictionary = tokens if not tokens.is_empty() else get_tokens()
	return clampi(int(round(float(base_size) * float(t.get("font_scale", 1.0)))), 11, 38)


static func make_card_style(
	tokens: Dictionary = {},
	radius: int = RAD_LG,
	elevated: bool = false,
	pad_h: int = 16,
	pad_v: int = 14
) -> StyleBoxFlat:
	var t: Dictionary = tokens if not tokens.is_empty() else get_tokens()
	var sb := StyleBoxFlat.new()
	sb.bg_color = t["bg_elevated"] if elevated else t["bg_surface"]
	sb.border_color = t["border"]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = t["shadow"]
	sb.shadow_size = 10 if elevated else 6
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func make_hud_glass_style(tokens: Dictionary = {}, radius: int = 22, pad_h: int = 12, pad_v: int = 8) -> StyleBoxFlat:
	var t: Dictionary = tokens if not tokens.is_empty() else get_tokens()
	var sb := StyleBoxFlat.new()
	sb.bg_color = t["bg_hud_glass"]
	sb.border_color = t["border"]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = t["shadow"]
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


static func make_button_style(
	bg: Color,
	border_col: Color,
	radius: int = RAD_MD,
	pad_h: int = 14,
	pad_v: int = 9,
	with_shadow: bool = false
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	if with_shadow:
		sb.shadow_color = Color(0.12, 0.04, 0.14, 0.16)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	return sb


static func build_theme(tokens: Dictionary = {}) -> Theme:
	var t: Dictionary = tokens if not tokens.is_empty() else get_tokens()
	var theme := Theme.new()
	var ui_font: Font = ArabicFontProvider.get_ui_font()
	if ui_font != null:
		theme.default_font = ui_font
	theme.default_font_size = scaled_font(15, t)

	# Label
	theme.set_color("font_color", "Label", t["text_primary"])

	# Button
	var btn_normal := make_button_style(t["bg_subtle"], t["border"], RAD_MD, 12, 8)
	var btn_hover := make_button_style(t["accent_soft"], t["accent"], RAD_MD, 12, 8)
	var btn_pressed := make_button_style(t["accent"], t["accent"], RAD_MD, 12, 8)
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", btn_hover)
	theme.set_color("font_color", "Button", t["text_primary"])
	theme.set_color("font_hover_color", "Button", t["text_primary"])
	theme.set_color("font_pressed_color", "Button", t["text_on_accent"])
	theme.set_color("font_focus_color", "Button", t["text_primary"])

	# CheckButton
	theme.set_color("font_color", "CheckButton", t["text_primary"])
	theme.set_color("font_pressed_color", "CheckButton", t["accent"])
	theme.set_color("font_hover_color", "CheckButton", t["text_primary"])

	# LineEdit
	var le_normal := make_button_style(t["bg_elevated"], t["border"], RAD_MD, 12, 8)
	var le_focus := make_button_style(t["bg_elevated"], t["accent"], RAD_MD, 12, 8)
	theme.set_stylebox("normal", "LineEdit", le_normal)
	theme.set_stylebox("focus", "LineEdit", le_focus)
	theme.set_color("font_color", "LineEdit", t["text_primary"])
	theme.set_color("font_placeholder_color", "LineEdit", t["text_secondary"])
	theme.set_color("caret_color", "LineEdit", t["accent"])

	# PanelContainer
	theme.set_stylebox("panel", "PanelContainer", make_card_style(t, RAD_LG, false, 14, 10))

	# HSlider
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = t["bg_subtle"]
	slider_bg.set_corner_radius_all(6)
	slider_bg.content_margin_top = 5
	slider_bg.content_margin_bottom = 5
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = t["accent"]
	slider_fill.set_corner_radius_all(6)
	slider_fill.content_margin_top = 5
	slider_fill.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	return theme
