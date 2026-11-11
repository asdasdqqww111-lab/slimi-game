class_name SoundBankConfig
extends Resource
## إعدادات المصرف الصوتي الإجرائي لسلايمي (الترددات، التنويع العشوائي، ومستويات الصوت).

@export var sample_rate: int = 22050
@export_range(0.0, 0.35, 0.01) var pitch_variation: float = 0.09
@export var master_gain: float = 0.85
@export var enable_ambient_hum: bool = true
