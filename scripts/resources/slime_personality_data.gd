class_name SlimePersonalityData
extends Resource
## بيانات شخصية سلايمي الأساسية القابلة للتخصيص والتوسع عبر ملفات الموارد (.tres).

@export_group("Identity")
@export var display_name_ar: String = "سلايمي"
@export var display_name_en: String = "SLIMI"

@export_group("Personality Traits")
@export_range(0.0, 2.0, 0.05) var playfulness: float = 1.15
@export_range(0.0, 2.0, 0.05) var curiosity_bias: float = 1.10
@export_range(0.0, 2.0, 0.05) var sociability: float = 1.25
@export_range(0.5, 2.0, 0.05) var bounciness: float = 1.10

@export_group("Need Decay Per Minute")
@export_range(0.1, 10.0, 0.1) var happiness_decay_per_min: float = 1.4
@export_range(0.1, 10.0, 0.1) var energy_decay_per_min: float = 1.1
@export_range(0.1, 10.0, 0.1) var fullness_decay_per_min: float = 1.6
@export_range(0.1, 20.0, 0.1) var sleep_energy_recovery_per_min: float = 14.0

@export_group("Interaction Gains")
@export var poke_happiness_gain: float = 2.5
@export var pet_happiness_gain: float = 5.5
@export var pet_affection_gain: float = 2.2
@export var feed_fullness_gain: float = 24.0
@export var feed_happiness_gain: float = 7.0
@export var play_happiness_gain: float = 11.0
@export var play_energy_cost: float = 6.0
@export var rapid_poke_dizzy_threshold: int = 6
