class_name ArabicFontProvider
extends RefCounted
## مزوّد الخط العربي المدمج عالي الأداء:
## يعتمد مباشرة على خط المحرك المدمج في الذاكرة (Vazirmatn للعربية + OpenSans للإنجليزية)
## لتجنب بطء SystemFont ومسح ملفات خطوط النظام الضخمة على هواتف Android (ثبات 60 FPS).


static func get_ui_font() -> Font:
	return ThemeDB.fallback_font
