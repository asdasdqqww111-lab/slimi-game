class_name ArabicFontProvider
extends RefCounted
## مزوّد الخط العربي النظامي لأجهزة Android والحواسيب مع توافق كامل لوضع الاختبار Headless.

const PREFERRED_ARABIC_FONTS: PackedStringArray = [
	"Noto Sans Arabic",
	"Noto Naskh Arabic",
	"Roboto",
	"Droid Sans Arabic",
	"Geeza Pro",
	"Segoe UI",
	"Tahoma",
	"DejaVu Sans",
	"sans-serif",
]

static var _cached_font: Font = null


static func get_ui_font() -> Font:
	if _cached_font != null:
		return _cached_font
	if DisplayServer.get_name() == "headless":
		return null
	var sys_font := SystemFont.new()
	sys_font.font_names = PREFERRED_ARABIC_FONTS
	sys_font.allow_system_fallback = true
	sys_font.multichannel_signed_distance_field = false
	_cached_font = sys_font
	return _cached_font
