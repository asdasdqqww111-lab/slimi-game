class_name SlimiCustomizationManager
extends RefCounted
## مدير التخصيص البصري الحي والآمن لشخصية SLIMI:
## يتيح معاينة وحفظ واستعادة ألوان الجل، لون القبعة المحبوكة، إظهار/إخفاء الإكسسوارات الفرعية،
## اسم SLIMI، وسرعة الحركة، مع الحفاظ الصارم 100% على الهوية المرجعية ونسب الملامح الأساسية.

const GEL_PRESETS: Dictionary = {
	"sakura_pink": {
		"ar": "وردي ساكورا الأصلي",
		"en": "Original Sakura Pink",
		"swatch": Color(0.99, 0.52, 0.78),
		"core": Color(1.0, 0.75, 0.88, 1.0),
		"mid": Color(0.99, 0.49, 0.76, 1.0),
		"edge": Color(0.95, 0.33, 0.67, 1.0),
		"sss": Color(1.0, 0.38, 0.68, 1.0),
	},
	"peach_blossom": {
		"ar": "خوخي مشرق",
		"en": "Peach Blossom",
		"swatch": Color(1.0, 0.65, 0.58),
		"core": Color(1.0, 0.84, 0.78, 1.0),
		"mid": Color(1.0, 0.58, 0.54, 1.0),
		"edge": Color(0.95, 0.40, 0.44, 1.0),
		"sss": Color(1.0, 0.48, 0.44, 1.0),
	},
	"berry_rose": {
		"ar": "توتي مخملي",
		"en": "Berry Rose",
		"swatch": Color(0.92, 0.38, 0.68),
		"core": Color(1.0, 0.70, 0.88, 1.0),
		"mid": Color(0.92, 0.38, 0.68, 1.0),
		"edge": Color(0.78, 0.22, 0.56, 1.0),
		"sss": Color(0.98, 0.30, 0.64, 1.0),
	},
	"lilac_mist": {
		"ar": "لافندر حالم",
		"en": "Lilac Mist",
		"swatch": Color(0.84, 0.62, 0.99),
		"core": Color(0.94, 0.84, 1.0, 1.0),
		"mid": Color(0.84, 0.60, 0.98, 1.0),
		"edge": Color(0.70, 0.42, 0.92, 1.0),
		"sss": Color(0.88, 0.48, 0.96, 1.0),
	},
	"sky_pastel": {
		"ar": "وردي سماوي لؤلؤي",
		"en": "Pearl Candy",
		"swatch": Color(0.96, 0.68, 0.92),
		"core": Color(0.98, 0.88, 1.0, 1.0),
		"mid": Color(0.95, 0.62, 0.90, 1.0),
		"edge": Color(0.84, 0.46, 0.84, 1.0),
		"sss": Color(0.96, 0.52, 0.88, 1.0),
	},
}

const BEANIE_PRESETS: Dictionary = {
	"sunny_yellow": {
		"ar": "أصفر شمسي (الأصلي)",
		"en": "Sunny Yellow (Default)",
		"swatch": Color(0.98, 0.80, 0.34),
		"visible": true,
		"bright": Color(1.0, 0.91, 0.56, 1.0),
		"mid": Color(0.98, 0.78, 0.35, 1.0),
		"shadow": Color(0.80, 0.53, 0.17, 1.0),
	},
	"vanilla_cream": {
		"ar": "فانيليا كريمي",
		"en": "Vanilla Cream",
		"swatch": Color(0.98, 0.94, 0.84),
		"visible": true,
		"bright": Color(1.0, 0.98, 0.92, 1.0),
		"mid": Color(0.95, 0.89, 0.78, 1.0),
		"shadow": Color(0.78, 0.69, 0.56, 1.0),
	},
	"mint_yarn": {
		"ar": "نعناعي صوفي",
		"en": "Mint Yarn",
		"swatch": Color(0.56, 0.90, 0.76),
		"visible": true,
		"bright": Color(0.78, 0.97, 0.88, 1.0),
		"mid": Color(0.52, 0.87, 0.73, 1.0),
		"shadow": Color(0.32, 0.66, 0.53, 1.0),
	},
	"lavender_yarn": {
		"ar": "بنفسجي باستيل",
		"en": "Pastel Lavender",
		"swatch": Color(0.78, 0.66, 0.98),
		"visible": true,
		"bright": Color(0.90, 0.84, 1.0, 1.0),
		"mid": Color(0.76, 0.63, 0.96, 1.0),
		"shadow": Color(0.55, 0.42, 0.78, 1.0),
	},
	"hidden": {
		"ar": "بدون قبعة",
		"en": "No Hat",
		"swatch": Color(0.76, 0.72, 0.80),
		"visible": false,
		"bright": Color(1.0, 0.91, 0.56, 1.0),
		"mid": Color(0.98, 0.78, 0.35, 1.0),
		"shadow": Color(0.80, 0.53, 0.17, 1.0),
	},
}


static func get_default_config() -> Dictionary:
	return (SaveManager.create_default_data()["customization"] as Dictionary).duplicate(true)


static func get_saved_config() -> Dictionary:
	return SaveManager.get_section("customization")


static func get_display_name(cfg: Dictionary = {}) -> String:
	var active: Dictionary = cfg if not cfg.is_empty() else get_saved_config()
	var custom_n: String = str(active.get("slimi_name", "")).strip_edges()
	if not custom_n.is_empty():
		return custom_n
	return LocalizationManager.tr_key("app_title")


static func apply_to_slime(
	slime: SlimeController,
	room: RoomEnvironment = null,
	cfg: Dictionary = {}
) -> void:
	if slime == null:
		return
	var active_cfg: Dictionary = cfg if not cfg.is_empty() else get_saved_config()

	var gel_id: String = str(active_cfg.get("gel_preset", "sakura_pink"))
	if not GEL_PRESETS.has(gel_id):
		gel_id = "sakura_pink"
	var gel_p: Dictionary = GEL_PRESETS[gel_id]

	if slime.deformer != null and slime.deformer.shader_material != null:
		var mat: ShaderMaterial = slime.deformer.shader_material
		mat.set_shader_parameter("core_milk_color", gel_p["core"])
		mat.set_shader_parameter("mid_jelly_color", gel_p["mid"])
		mat.set_shader_parameter("edge_glass_color", gel_p["edge"])
		mat.set_shader_parameter("subsurface_color", gel_p["sss"])
		mat.set_shader_parameter("albedo_top", gel_p["core"])
		mat.set_shader_parameter("albedo_bottom", gel_p["mid"])

	var beanie_id: String = str(active_cfg.get("beanie_preset", "sunny_yellow"))
	if not BEANIE_PRESETS.has(beanie_id):
		beanie_id = "sunny_yellow"
	var bp: Dictionary = BEANIE_PRESETS[beanie_id]

	var vis_root := slime.get_node_or_null("VisualRoot") as Node3D
	if vis_root != null:
		var beanie := vis_root.get_node_or_null("KnitBeanie") as Node3D
		if beanie != null:
			beanie.visible = bool(bp["visible"])
			var flower := beanie.get_node_or_null("YarnFlower") as Node3D
			if flower != null:
				flower.visible = bool(active_cfg.get("show_flower", true))
			var heart := beanie.get_node_or_null("HeartPin") as Node3D
			if heart != null:
				heart.visible = bool(active_cfg.get("show_heart_pin", true))

		var star_mesh := vis_root.get_node_or_null("StarAntenna/StarCharmPivot/StarCharmMesh") as Node3D
		if star_mesh != null:
			star_mesh.visible = bool(active_cfg.get("show_star_charm", true))

	for k_mat_name in ["knit_dome_mat", "knit_cuff_mat"]:
		var kmat := slime.accessory_refs.get(k_mat_name) as ShaderMaterial
		if kmat != null:
			kmat.set_shader_parameter("yarn_bright", bp["bright"])
			kmat.set_shader_parameter("yarn_mid", bp["mid"])
			kmat.set_shader_parameter("yarn_shadow", bp["shadow"])

	slime.movement_speed_scale = clampf(float(active_cfg.get("movement_speed_scale", 1.0)), 0.70, 1.35)

	if room != null and active_cfg.has("room_backdrop"):
		room.apply_room_backdrop_theme(str(active_cfg["room_backdrop"]))


static func reset_to_default() -> Dictionary:
	var def_cfg: Dictionary = get_default_config()
	SaveManager.set_section("customization", def_cfg)
	SaveManager.save_to_disk()
	return def_cfg.duplicate(true)


static func save_config(cfg: Dictionary) -> void:
	var clean_cfg: Dictionary = get_saved_config()
	for k in ["slimi_name", "gel_preset", "beanie_preset", "show_flower", "show_heart_pin", "show_star_charm", "movement_speed_scale"]:
		if cfg.has(k):
			clean_cfg[k] = cfg[k]
	SaveManager.set_section("customization", clean_cfg)
	if cfg.has("room_backdrop"):
		SaveManager.update_section("ui_preferences", {"room_backdrop": str(cfg["room_backdrop"])})
	SaveManager.save_to_disk()
