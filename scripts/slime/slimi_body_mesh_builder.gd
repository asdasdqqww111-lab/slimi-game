class_name SlimiBodyMeshBuilder
extends RefCounted
## مولّد طوبولوجيا الجسم الهلامي عالية الدقة (Quad-Sphere Mochi-Gel Topology + Shape Keys):
## - يستبدل SphereMesh القطبية بمجسم رباعي القسائم متساوي التوزيع (Spherified Cube-Sphere) بلا أي تشوه قطبي.
## - يحسب الناظمات الملساء (Analytical Smooth Normals) والمماسات (Tangents) وتخطيط UV المتصل.
## - يبني 6 مفاتيح شكل حقيقية (BlendShapes / Shape Keys):
##   squash, stretch, breathe_expand, curious_lean, happy_plump, sad_droop.

const BLEND_SHAPE_NAMES: Array[StringName] = [
	&"squash",
	&"stretch",
	&"breathe_expand",
	&"curious_lean",
	&"happy_plump",
	&"sad_droop",
]

static var _mesh_cache: Dictionary = {}


static func get_or_build_lod_mesh(preset_level: int) -> ArrayMesh:
	var subdiv: int = 20
	match preset_level:
		0: subdiv = 12 # LOW: 864 quads / 1,728 tris
		1: subdiv = 20 # MEDIUM: 2,400 quads / 4,800 tris
		_: subdiv = 28 # HIGH: 4,704 quads / 9,408 tris

	if _mesh_cache.has(subdiv):
		return _mesh_cache[subdiv] as ArrayMesh

	var mesh: ArrayMesh = build_quad_sphere_gel_mesh(subdiv)
	_mesh_cache[subdiv] = mesh
	return mesh


static func build_quad_sphere_gel_mesh(subdiv: int = 20) -> ArrayMesh:
	var n: int = clampi(subdiv, 8, 36)
	var face_axes: Array[Array] = [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],   # Front (+Z)
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)], # Back (-Z)
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)],  # Right (+X)
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],  # Left (-X)
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)],  # Top (+Y)
		[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],  # Bottom (-Y)
	]

	var stride: int = n + 1
	var verts_per_face: int = stride * stride
	var total_verts: int = verts_per_face * 6

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	positions.resize(total_verts)
	normals.resize(total_verts)
	tangents.resize(total_verts * 4)
	uvs.resize(total_verts)

	var unit_dirs := PackedVector3Array()
	unit_dirs.resize(total_verts)

	var v_cursor: int = 0
	for f_idx in range(6):
		var normal_axis: Vector3 = face_axes[f_idx][0]
		var right_axis: Vector3 = face_axes[f_idx][1]
		var up_axis: Vector3 = face_axes[f_idx][2]
		var base_index: int = f_idx * verts_per_face

		for iy in range(stride):
			var v_ratio: float = float(iy) / float(n)
			var b: float = v_ratio * 2.0 - 1.0
			for ix in range(stride):
				var u_ratio: float = float(ix) / float(n)
				var a: float = u_ratio * 2.0 - 1.0

				# Spherified cube mapping (توزيع متساوٍ للرؤوس على الكرة دون تكدس عند الزوايا أو الأقطاب)
				var raw_cube: Vector3 = normal_axis + right_axis * a + up_axis * b
				var x2: float = raw_cube.x * raw_cube.x
				var y2: float = raw_cube.y * raw_cube.y
				var z2: float = raw_cube.z * raw_cube.z
				var sph := Vector3(
					raw_cube.x * sqrt(maxf(0.0, 1.0 - y2 * 0.5 - z2 * 0.5 + (y2 * z2) / 3.0)),
					raw_cube.y * sqrt(maxf(0.0, 1.0 - z2 * 0.5 - x2 * 0.5 + (z2 * x2) / 3.0)),
					raw_cube.z * sqrt(maxf(0.0, 1.0 - x2 * 0.5 - y2 * 0.5 + (x2 * y2) / 3.0))
				).normalized()

				unit_dirs[v_cursor] = sph
				var rest_p: Vector3 = SlimiIdentitySpec.evaluate_mochi_rest_point(sph)
				var rest_n: Vector3 = _compute_analytical_mochi_normal(sph)

				positions[v_cursor] = rest_p
				normals[v_cursor] = rest_n

				var tang_dir: Vector3 = right_axis - rest_n * rest_n.dot(right_axis)
				if tang_dir.length_squared() < 0.0001:
					tang_dir = Vector3.RIGHT.cross(rest_n)
				tang_dir = tang_dir.normalized()
				tangents[v_cursor * 4 + 0] = tang_dir.x
				tangents[v_cursor * 4 + 1] = tang_dir.y
				tangents[v_cursor * 4 + 2] = tang_dir.z
				tangents[v_cursor * 4 + 3] = 1.0

				# UV متساوي التوزيع كروياً لسطح أملس متصل
				var u_sph: float = atan2(sph.x, sph.z) / TAU + 0.5
				var v_sph: float = acos(clampf(sph.y, -1.0, 1.0)) / PI
				uvs[v_cursor] = Vector2(u_sph, v_sph)
				v_cursor += 1

		for iy in range(n):
			for ix in range(n):
				var i00: int = base_index + iy * stride + ix
				var i10: int = i00 + 1
				var i01: int = i00 + stride
				var i11: int = i01 + 1
				# ترتيب عقارب الساعة المتوافق مع cull_back في Godot (الوجه للخارج)
				indices.append(i00)
				indices.append(i11)
				indices.append(i10)

				indices.append(i00)
				indices.append(i01)
				indices.append(i11)

	var base_arrays := []
	base_arrays.resize(Mesh.ARRAY_MAX)
	base_arrays[Mesh.ARRAY_VERTEX] = positions
	base_arrays[Mesh.ARRAY_NORMAL] = normals
	base_arrays[Mesh.ARRAY_TANGENT] = tangents
	base_arrays[Mesh.ARRAY_TEX_UV] = uvs
	base_arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	for bs_name in BLEND_SHAPE_NAMES:
		mesh.add_blend_shape(bs_name)
	mesh.blend_shape_mode = Mesh.BLEND_SHAPE_MODE_RELATIVE

	var blend_shape_arrays: Array = []
	for bs_name in BLEND_SHAPE_NAMES:
		blend_shape_arrays.append(_build_shape_key_delta(bs_name, positions, normals, tangents))

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, base_arrays, blend_shape_arrays)
	return mesh


static func _compute_analytical_mochi_normal(unit_dir: Vector3) -> Vector3:
	var eps: float = 0.025
	var ref_up := Vector3.UP if absf(unit_dir.y) < 0.92 else Vector3.RIGHT
	var t1: Vector3 = unit_dir.cross(ref_up).normalized()
	var t2: Vector3 = unit_dir.cross(t1).normalized()

	var p_center: Vector3 = SlimiIdentitySpec.evaluate_mochi_rest_point(unit_dir)
	var p_a: Vector3 = SlimiIdentitySpec.evaluate_mochi_rest_point((unit_dir + t1 * eps).normalized())
	var p_b: Vector3 = SlimiIdentitySpec.evaluate_mochi_rest_point((unit_dir + t2 * eps).normalized())

	var n: Vector3 = (p_b - p_center).cross(p_a - p_center)
	if n.dot(unit_dir) < 0.0:
		n = -n
	return n.normalized() if n.length_squared() > 0.000001 else unit_dir


static func _build_shape_key_delta(
	shape_name: StringName,
	base_pos: PackedVector3Array,
	base_norm: PackedVector3Array,
	base_tang: PackedFloat32Array
) -> Array:
	var count: int = base_pos.size()
	var d_pos := PackedVector3Array()
	var d_norm := PackedVector3Array()
	var d_tang := PackedFloat32Array()
	d_pos.resize(count)
	d_norm.resize(count)
	d_tang.resize(count * 4)

	for i in range(count):
		var p: Vector3 = base_pos[i]
		var n: Vector3 = base_norm[i]
		var h: float = clampf((p.y + 0.53) / 1.06, 0.0, 1.0)
		var target_p: Vector3 = p
		var target_n: Vector3 = n

		match shape_name:
			&"squash":
				var spread: float = 1.24 + (1.0 - h) * 0.08
				target_p = Vector3(p.x * spread, p.y * 0.68 - 0.06 * (1.0 - h), p.z * spread)
				target_n = (n * Vector3(0.82, 1.32, 0.82)).normalized()
			&"stretch":
				var narrow: float = 0.82
				target_p = Vector3(p.x * narrow, p.y * 1.34 + 0.05 * h, p.z * narrow)
				target_n = (n * Vector3(1.18, 0.78, 1.18)).normalized()
			&"breathe_expand":
				var belly_w: float = sin(h * PI)
				target_p = p + n * (0.028 * belly_w) + Vector3(0.0, 0.016 * h, 0.0)
			&"curious_lean":
				var lean_w: float = h * h
				target_p = p + Vector3(0.0, 0.035 * lean_w, 0.145 * lean_w)
				target_n = (n + Vector3(0.0, 0.05, -0.18 * h)).normalized()
			&"happy_plump":
				var cheek_band: float = exp(-pow((h - 0.42) * 3.0, 2.0))
				target_p = Vector3(p.x * (1.0 + 0.075 * cheek_band), p.y * 1.03, p.z * (1.0 + 0.055 * cheek_band))
			&"sad_droop":
				var droop: float = smoothstep(0.2, 1.0, h)
				target_p = Vector3(p.x * (1.0 + 0.06 * (1.0 - h)), p.y * 0.88 - 0.045 * droop, p.z * 1.03)

		d_pos[i] = target_p - p
		d_norm[i] = target_n - n
		d_tang[i * 4 + 0] = 0.0
		d_tang[i * 4 + 1] = 0.0
		d_tang[i * 4 + 2] = 0.0
		d_tang[i * 4 + 3] = 0.0

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = d_pos
	arr[Mesh.ARRAY_NORMAL] = d_norm
	arr[Mesh.ARRAY_TANGENT] = d_tang
	return arr


static func inspect_mesh_topology(lod_level: int) -> Dictionary:
	var mesh: ArrayMesh = get_or_build_lod_mesh(lod_level)
	var surf: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = surf[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = surf[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = surf[Mesh.ARRAY_INDEX]

	var degen: int = 0
	var tri_count: int = indices.size() / 3
	for t in range(tri_count):
		var a: Vector3 = verts[indices[t * 3 + 0]]
		var b: Vector3 = verts[indices[t * 3 + 1]]
		var c: Vector3 = verts[indices[t * 3 + 2]]
		if (b - a).cross(c - a).length_squared() < 1e-11:
			degen += 1

	var min_n: float = 999.0
	var max_n: float = 0.0
	for n in norms:
		var nl: float = n.length()
		min_n = minf(min_n, nl)
		max_n = maxf(max_n, nl)

	return {
		"vertex_count": verts.size(),
		"triangle_count": tri_count,
		"blend_shape_count": mesh.get_blend_shape_count(),
		"degenerate_triangles": degen,
		"min_normal_len": min_n,
		"max_normal_len": max_n,
	}
