class_name SlimiIdentitySpec
extends RefCounted
## المرجع الهندسي الثابت لهوية ونسب شخصية SLIMI (Character Identity Lock):
## يضمن ثبات النسب ومواضع الملامح والإكسسوارات في جميع الزوايا والمشاهد والحركات،
## ويوفر أدوات فحص صلاحية التحويلات (NaN / Inf / Zero-Scale Guards).

# النسب المرجعية الثابتة للجسم الهلامي الوردي (وحدات مترية داخل المشهد)
const BODY_BASE_RADIUS: float = 0.56
const BODY_HALF_HEIGHT: float = 0.53
const VISUAL_ROOT_Y: float = 0.49

# مواضع الملامح المرجعية على سطح الوجه الأمامي (+Z)
const LEFT_EYE_ANCHOR := Vector3(-0.185, 0.115, 0.535)
const RIGHT_EYE_ANCHOR := Vector3(0.185, 0.115, 0.535)
const MOUTH_ANCHOR := Vector3(0.0, 0.018, 0.585)
const LEFT_CHEEK_ANCHOR := Vector3(-0.285, -0.005, 0.505)
const RIGHT_CHEEK_ANCHOR := Vector3(0.285, -0.005, 0.505)

# مواضع الإكسسوارات المرجعية الثابتة
const LEFT_ANTENNA_ANCHOR := Vector3(-0.185, 0.415, 0.050)
const RIGHT_ANTENNA_ANCHOR := Vector3(0.068, 0.452, 0.148)
const BEANIE_ANCHOR := Vector3(0.185, 0.405, 0.015)
const BEANIE_BASE_ROT_DEG := Vector3(5.0, -8.0, -24.0)
const POMPOM_LOCAL_ANCHOR := Vector3(0.0, 0.278, -0.010)
const FLOWER_LOCAL_ANCHOR := Vector3(0.096, 0.088, 0.322)
const PAWS_ANCHOR := Vector3(0.0, -0.145, 0.545)

# زوايا الكاميرا المرجعية الخمس الثابتة (Front / Side / Back / Three-Quarter / Close-Up)
const REFERENCE_VIEWS: Dictionary = {
	"front": {
		"cam_pos": Vector3(0.0, 0.62, 2.55),
		"look_at": Vector3(0.0, 0.56, 0.0),
		"fov": 38.0,
	},
	"side": {
		"cam_pos": Vector3(2.55, 0.62, 0.0),
		"look_at": Vector3(0.0, 0.56, 0.0),
		"fov": 38.0,
	},
	"back": {
		"cam_pos": Vector3(0.0, 0.62, -2.55),
		"look_at": Vector3(0.0, 0.56, 0.0),
		"fov": 38.0,
	},
	"three_quarter": {
		"cam_pos": Vector3(1.55, 0.82, 2.05),
		"look_at": Vector3(0.0, 0.55, 0.0),
		"fov": 38.0,
	},
	"close_up": {
		"cam_pos": Vector3(0.18, 0.64, 1.38),
		"look_at": Vector3(0.0, 0.58, 0.18),
		"fov": 34.0,
	},
}


static func evaluate_mochi_rest_point(unit_sphere_dir: Vector3, flatten_bottom: float = 0.24) -> Vector3:
	var p: Vector3 = unit_sphere_dir * BODY_BASE_RADIUS
	p.y *= (BODY_HALF_HEIGHT / BODY_BASE_RADIUS)

	var h: float = clampf((p.y + BODY_HALF_HEIGHT) / (BODY_HALF_HEIGHT * 2.0), 0.0, 1.0)
	var pear_x: float = lerpf(1.19, 0.89, smoothstep(0.14, 0.94, h))
	var pear_z: float = lerpf(1.14, 0.88, smoothstep(0.14, 0.94, h))
	var cheek_plump: float = 1.0 + 0.055 * exp(-pow((h - 0.34) * 3.4, 2.0))

	p.x *= pear_x * cheek_plump
	p.z *= pear_z * cheek_plump

	if p.y < -0.18:
		var bottom_t: float = clampf((-0.18 - p.y) / 0.36, 0.0, 1.0)
		p.y += bottom_t * bottom_t * flatten_bottom
		var spread: float = 1.0 + bottom_t * flatten_bottom * 0.36
		p.x *= spread
		p.z *= spread

	return p


static func sample_rest_hull_radius(unit_dir: Vector3) -> float:
	if not is_finite_vec3(unit_dir) or unit_dir.length_squared() < 0.0001:
		return BODY_BASE_RADIUS
	return evaluate_mochi_rest_point(unit_dir).length()


static func is_finite_vec3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func is_valid_transform3d(t: Transform3D) -> bool:
	if not is_finite_vec3(t.origin):
		return false
	if not is_finite_vec3(t.basis.x) or not is_finite_vec3(t.basis.y) or not is_finite_vec3(t.basis.z):
		return false
	var det: float = t.basis.determinant()
	return is_finite(det) and absf(det) > 1e-9


static func validate_subtree_transforms_finite(root: Node) -> bool:
	if root == null:
		return false
	if root is Node3D:
		if not is_valid_transform3d((root as Node3D).transform):
			return false
	for child in root.get_children():
		if not validate_subtree_transforms_finite(child):
			return false
	return true
